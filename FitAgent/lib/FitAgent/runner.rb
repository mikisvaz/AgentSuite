require 'scout-ai'
require 'FitAgent/scoring'
require 'fileutils'
require 'json'
require 'yaml'

module FitAgent
  # Multi-arm scenario runner (research/07 section 2 step 1, design
  # fitagent-improvement-loop-v1: "Agent override dir -> run matrix -> score").
  #
  # An ARM is a named staged Agent override directory:
  #
  #   <arms_dir>/<arm>/Agent/<AgentName>/start_chat   (and any other files)
  #
  # The special arm `baseline` (or an arm whose directory does not exist)
  # means NO override: the canonical agent runs unmodified.
  #
  # Per arm the runner, for each scenario:
  #   1. stages the run sandbox: scenario set copied in, work tree reset to
  #      the pristine pre-state (probe harness contract, tmp/patch_probes),
  #      override dir staged as sandbox/Agent/<AgentName>/ (use_case staging
  #      conventions);
  #   2. runs one agent turn over the scenario patch (v1 contract: one
  #      `patch` tool call; live `use_case` wiring arrives in a later unit);
  #   3. records the transcript + work tree;
  #   4. scores with FitAgent::Scoring.score_scenario (pure Ruby, no model).
  #
  # Output layout per arm:
  #   results/<experiment>/<arm>/scores.tsv   one row per scenario
  #   results/<experiment>/<arm>/scores.json  detailed per-scenario breakdown
  #   results/<experiment>/<arm>/arms.json    arm manifest (staged override,
  #                                           chat + work paths, scenario ids)
  module Runner

    BASELINE = 'baseline'
    AGENT_PLACEHOLDER = 'FitAgent::Runner::StubAgent'

    class << self
      # -- override staging --------------------------------------------------

      # Materialize a candidate override start_chat (grammar per research/05):
      # instructions + tool lines. Pure file write, canonical agent files are
      # never touched.
      # `dir` is the ARM directory: the override is staged at <dir>/Agent/<agent>.
      # Passing the parent of several arms (an arms dir) is the classic mistake
      # the layout check below catches.
      def write_override(dir, agent, instructions, tools = [])
        dir = dir.to_s
        agent_dir = File.join(dir, 'Agent', agent.to_s)
        FileUtils.mkdir_p agent_dir
        body = build_start_chat(instructions, tools)
        File.open(File.join(agent_dir, 'start_chat'), 'wb') { |f| f.write(body) }
        { 'dir' => agent_dir, 'start_chat' => File.join(agent_dir, 'start_chat'),
          'instructions' => instructions.to_s, 'tools' => Array(tools).map(&:to_s) }
      end

      # start_chat = instructions block + optional tool wiring lines.
      # Grammar (research/05 section 2): `introduce: Workflow`,
      # `tool: Workflow [task [inputs...]]`. Kept verbatim from the brief's
      # tools array; nothing is validated against a workflow here (resolution
      # happens at run time inside the sandbox).
      def build_start_chat(instructions, tools)
        lines = []
        lines << instructions.to_s.chomp
        Array(tools).each do |t|
          next if t.to_s.strip.empty?
          lines << 'tool: ' + t.to_s.strip
        end
        lines.join("\n") + "\n"
      end

      # -- sandbox staging ---------------------------------------------------

      # Prepare <arm_box>: copy the scenario set in, reset each scenario's
      # work/ tree to the pristine pre-state (patch.txt and fixtures are
      # copied into work/ minus expected/ and metadata, as run_all.sh does),
      # and stage the arm's override dir if it has one.
      #
      # Returns the staged arm box path.
      def stage_arm(arm_box, scenarios_dir, override_dir, agent)
        arm_box = arm_box.to_s
        FileUtils.rm_rf arm_box if Open.directory?(arm_box)
        FileUtils.mkdir_p arm_box

        set = File.join(arm_box, 'scenarios')
        FileUtils.cp_r(scenarios_dir.to_s, set)
        reset_work_trees(set)

        if override_dir && Open.directory?(File.join(override_dir.to_s, 'Agent'))
          # Shadow by copy (sandbox Agent dir wins over the canonical one at
          # run time via the sandbox's own agents path).
          FileUtils.cp_r(File.join(override_dir.to_s, 'Agent'), File.join(arm_box, 'Agent'))
        end

        arm_box
      end

      # run_all.sh semantics: work/ contains the pristine fixtures (every
      # top-level file except the patch and the metadata/expected dirs).
      def reset_work_trees(set_dir)
        each_scenario(set_dir) do |id, dir|
          work = File.join(dir, 'work')
          FileUtils.rm_rf work
          FileUtils.mkdir_p work
          Dir.glob(File.join(dir, '*')).each do |f|
            next unless File.file?(f)
            base = File.basename(f)
            next if base.start_with?('patch')
            next if base == 'job_result.json'
            next if %w[rubric.yaml scenario.yaml manifest.json].include?(base)
            FileUtils.cp(f, work)
          end
        end
      end

      def each_scenario(set_dir)
        Dir.glob(File.join(set_dir.to_s, '*')).select do |d|
          File.directory?(d) && File.file?(File.join(d, 'rubric.yaml'))
        end.sort.each { |d| yield File.basename(d), d }
      end

      # -- agent turn --------------------------------------------------------

      # Run the agent turn for one scenario.
      #
      # v1 contract: the "agent" is an object exposing +call(scenario_dir,
      # arm_box)+ (or +run+) that produces a main.chat transcript inside
      # arm_box and mutates the scenario work tree; a recorded-chat stub
      # (tests) or a real use_case wiring (later unit) satisfy it. The default
      # RecordAgent replays a fixed transcript shape with a configurable
      # payload, so deterministic paths stay testable with no model at all.
      def run_agent_turn(agent_obj, scenario_dir, arm_box)
        if agent_obj.respond_to?(:call)
          agent_obj.call(scenario_dir, arm_box)
        elsif agent_obj.respond_to?(:run)
          agent_obj.run(scenario_dir, arm_box)
        else
          raise ArgumentError, "agent object #{agent_obj.inspect} must respond to call or run"
        end
      end

      # -- arm loop ----------------------------------------------------------

      # Run one arm over the whole scenario set and score it.
      #
      #   experiment    experiment name (results dir component)
      #   scenarios_dir materialized scenario set (catalogue output)
      #   arm           arm label; BASELINE (or any label without a staged
      #                 dir) runs the canonical agent with no override
      #   arms_dir      directory holding <arm>/Agent/<AgentName>/...
      #   agent         agent name under test (Agent/<name>)
      #   agent_obj     the agent-turn object (StubAgent or live wiring)
      #   out_dir       optional results root; defaults to <repo>/results
      #
      # Returns the per-scenario results hash; also writes scores.tsv +
      # scores.json + arms.json under results/<experiment>/<arm>/.
      def run_arm(experiment, scenarios_dir, arm, arms_dir, agent,
                  agent_obj = StubAgent.new, out_dir: nil)
        scenarios_dir = scenarios_dir.to_s
        arm = arm.to_s
        raise ArgumentError, "no scenario set at #{scenarios_dir}" unless Open.directory?(scenarios_dir)
        raise ArgumentError, "no scenarios in #{scenarios_dir}" if scenario_ids(scenarios_dir).empty?

        override_dir = File.join(arms_dir.to_s, arm)
        has_override = Open.directory?(File.join(override_dir, 'Agent'))
        if arm == BASELINE && has_override
          raise ArgumentError, "baseline arm must not carry an override (found #{override_dir})"
        end

        out_root = out_dir || File.join(Dir.pwd, 'results')
        arm_out = File.join(out_root.to_s, experiment.to_s, arm)
        arm_box = File.join(arm_out, 'sandbox')
        stage_arm(arm_box, scenarios_dir, has_override ? override_dir : nil, agent)

        results = {}
        runs = {}
        each_scenario(File.join(arm_box, 'scenarios')) do |id, dir|
          chat = run_agent_turn(agent_obj, dir, arm_box)
          rubric = YAML.load_file(File.join(dir, 'rubric.yaml'))
          results[id] = Scoring.score_scenario(File.join(dir, 'work'), rubric, chat,
                                               'arm' => arm, 'experiment' => experiment,
                                               'override' => has_override ? override_dir : nil,
                                               'agent' => agent)
          runs[id] = { 'chat' => chat, 'work' => File.join(dir, 'work') }
        end

        FileUtils.mkdir_p arm_out
        Open.write(File.join(arm_out, 'scores.json'), JSON.pretty_generate(results) + "\n")
        Open.write(File.join(arm_out, 'arms.json'),
                   JSON.pretty_generate('experiment' => experiment, 'arm' => arm,
                                         'agent' => agent,
                                         'override' => has_override ? override_dir : nil,
                                         'scenarios' => results.keys.sort,
                                         'runs' => runs) + "\n")
        tsv = scores_tsv(results)
        Open.write(File.join(arm_out, 'scores.tsv'), tsv)
        { 'arm' => arm, 'results' => results, 'scores_tsv' => tsv, 'dir' => arm_out }
      end

      # Run all arms (baseline first). Arms are the subdirectories of
      # arms_dir containing Agent/, plus the implicit baseline.
      def run_arms(experiment, scenarios_dir, arms_dir, agent,
                   agent_factory = ->(arm) { StubAgent.new }, arms: nil, out_dir: nil)
        arms_dir = arms_dir.to_s
        explicit = Array(arms).map(&:to_s).reject(&:empty?)
        labels = explicit.empty? ? arm_labels(arms_dir) : explicit
        raise ArgumentError, 'no arms given or found under arms_dir' if Array(labels).empty?

        out = {}
        ([BASELINE] + labels).uniq.each do |arm|
          obj = agent_factory.call(arm)
          out[arm] = run_arm(experiment, scenarios_dir, arm, arms_dir, agent, obj, out_dir: out_dir)
        end
        out
      end

      def arm_labels(arms_dir)
        Dir.glob(File.join(arms_dir.to_s, '*')).select do |d|
          Open.directory?(File.join(d, 'Agent'))
        end.map { |d| File.basename(d) }.sort
      end

      def scenario_ids(set_dir)
        Dir.glob(File.join(set_dir.to_s, '*')).select do |d|
          File.directory?(d) && File.file?(File.join(d, 'rubric.yaml'))
        end.map { |d| File.basename(d) }.sort
      end

      def scores_tsv(results)
        tsv = TSV.setup({}, key: 'scenario', type: :list)
        tsv.fields = %w[verdict score functional_ok message_ok failures chat]
        results.keys.sort.each do |id|
          r = results[id]
          tsv[id] = [r['verdict'], r['score'].to_s,
                     r['functional']['files'].values.all? { |v| v['ok'] } ? 'true' : 'false',
                     r['message']['count_ok'].to_s,
                     r['failures'].join(';'),
                     r['evidence']['chat']]
        end
        tsv.to_s
      end
    end

  # Deterministic stub agent: writes a main.chat with one patch call per
  # invocation and (optionally) applies the scenario patch to the work
  # tree by copying expected/ over work/ (the "perfect agent"), or leaves
  # the tree untouched (the "bad agent").
  class StubAgent
    def initialize(payload: { 'exit_status' => 0, 'applied' => true, 'used_strip' => 1,
                              'stdout' => 'patching file', 'stderr' => '' },
                   apply_expected: true, calls: 1, chat_name: 'main.chat',
                 force_payload: nil)
      @payload = payload
      @apply_expected = apply_expected
      @calls = calls
      @chat_name = chat_name
      @force_payload = force_payload
    end

    def call(scenario_dir, arm_box)
      scenario_dir = scenario_dir.to_s
      rubric = YAML.load_file(File.join(scenario_dir, 'rubric.yaml'))
      payload = @force_payload || self.class.payload_for(rubric)
      if @apply_expected
        apply_expected_state(scenario_dir)
      end
      write_chat(File.join(arm_box.to_s, @chat_name), payload, @calls)
      File.join(arm_box.to_s, @chat_name)
    end

    # The stub emulates the tool payload the rubric FROZE for the scenario:
    # error scenarios (E01/E02) expect a refused patch (exit 1, not applied),
    # everything else a clean apply. Derived from the rubric's message_rules
    # expectations so the stub satisfies the rubric by construction.
    def self.payload_for(rubric)
      rules = rubric['message_rules'] || {}
      exp = rules['expect'] || {}
      if exp['applied'] == false
        { 'exit_status' => 1, 'applied' => false, 'used_strip' => 0,
          'stdout' => '', 'stderr' => 'Hunk #1 FAILED' }
      else
        { 'exit_status' => 0, 'applied' => true, 'used_strip' => exp['used_strip'] || 1,
          'stdout' => 'patching file', 'stderr' => '' }
      end
    end

    def apply_expected_state(scenario_dir)
      exp = File.join(scenario_dir, 'expected')
      work = File.join(scenario_dir, 'work')
      FileUtils.mkdir_p work
      # E06-style: expected/ empty => the pristine files are REMOVED
      expected_files = Dir.glob(File.join(exp, '**', '*')).select { |f| File.file?(f) }
      if expected_files.empty?
        Dir.glob(File.join(work, '*')).each { |f| FileUtils.rm_rf(f) }
      else
        expected_files.each do |f|
          rel = f.sub(%r{^#{Regexp.escape(exp)}/}, '')
          dst = File.join(work, rel)
          FileUtils.mkdir_p(File.dirname(dst))
          FileUtils.cp(f, dst)
        end
      end
    end

    private

    def write_chat(path, payload, n_calls)
      lines = ['user:', '', 'Apply the patch.', '']
      n_calls.times do |i|
        id = "c#{i}"
        lines << 'function_call: ' + JSON.generate('name' => 'patch',
                                                   'arguments' => { 'patch' => '...' }, 'id' => id)
        lines << ''
        lines << 'function_call_output: ' + JSON.generate('name' => 'patch',
                                                          'content' => JSON.generate(payload), 'id' => id)
        lines << ''
      end
      lines += ['assistant:', '', 'done', '']
      File.open(path, 'wb') { |f| f.write(lines.join("\n")) }
    end
  end
  end
end
