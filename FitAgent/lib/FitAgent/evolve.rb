require 'scout-ai'
require 'FitAgent/scenarios'
require 'FitAgent/runner'
require 'digest/sha1'

module FitAgent
  # Deterministic evolution-loop core (research/07 §2 steps 4-7 + addenda).
  #
  # Everything here is pure Ruby over recorded evidence: scores, proposal
  # objects, and file manifests. NO model calls and NO endpoint selection —
  # the actual proposal generation is injected as a `proposer` object
  # (default: FitAgent::Evolve::StubProposer, a fixed first proposal), so the
  # loop logic is fully testable offline. The live default-endpoint proposer
  # plugs in with the same interface in a later unit.
  #
  # A PROPOSAL is a Hash:
  #   'instructions' => String (the system prose)
  #   'tools'        => Array of tool spec lines
  #                     ('Workflow [task [input|name=value ...]]', 'Workflow',
  #                      'noinputs'/hidden forms per the Cortex brief grammar)
  #   'agent'        => optional agent name (defaults to the agent under test)
  module Evolve
    BUDGET_DEFAULT = 3
    MAX_REPAIRS = 2

    # Grammar of a tool spec line (research/05 §2 + Cortex brief tools):
    #   Workflow
    #   Workflow task
    #   Workflow task input
    #   Workflow task name=value
    #   Workflow task noinputs|none
    # 'Workflow' is a bare CamelCase token (may contain '::'). Task and
    # input tokens allow word chars, =, /, ., - and : (paths and name=value).
    TOOL_SPEC_RE = /\A[A-Z][A-Za-z0-9:]*+( \S+)*+\z/
    INPUT_TOKEN_RE = /\A[\w\.\/\-:=]+\z/
    RESERVED_INPUT_TOKENS = %w[noinputs none].freeze

    class << self
      # -- proposal prompt ---------------------------------------------------

      # Build the proposal prompt from the rubric JSON summary, the failing
      # scenario ids and the per-arm scores. Pure string building; the caller
      # decides what to do with it (a model, a human, or a stub).
      def propose_prompt(experiment, prior_scores, rubric_summary)
        prior = Array(prior_scores)
        arms = prior.map { |row| row['arm'].to_s }.uniq
        lines = []
        lines << "Improve the agent instructions for experiment #{experiment}."
        lines << ''
        lines << 'Rubric summary (deterministic expectations the runs are scored against):'
        lines << indent_block(summarize_rubric(rubric_summary))
        lines << ''
        if arms.empty?
          lines << 'No prior runs recorded; this is the first generation.'
        else
          lines << 'Prior run scores (per arm and scenario):'
          prior.each do |row|
            arm = row['arm'].to_s
            sc = row['scenario'].to_s
            verdict = row['verdict'].to_s
            score = row['score'].to_s
            fails = Array(row['failures']).join(';')
            lines << "  #{arm} #{sc}: #{verdict} score=#{score}#{fails.empty? ? '' : " failures=#{fails}"}"
          end
          lines << ''
          failing = prior.select { |row| row['verdict'].to_s != 'PASS' }
          if failing.empty?
            lines << 'All scenarios PASS for every arm; only refine instructions without regressions.'
          else
            lines << 'Failing scenarios to fix:'
            failing.each do |row|
              lines << "  #{row['arm']}: #{row['scenario']} (#{Array(row['failures']).join('; ')})"
            end
          end
        end
        lines << ''
        lines.concat(tools_grammar_lines)
        lines << ''
        lines << 'Rewrite the agent instructions so the failing scenarios pass while'
        lines << 'passing scenarios stay passing. Output the proposal as YAML with the'
        lines << 'keys instructions (string) and tools (array of tool spec lines).'
        lines.join("\n") + "\n"
      end

      # Tools grammar block appended to every proposal prompt. The live run
      # results/patch-mini-1 died because the model emitted tool descriptions
      # / Hashes instead of spec lines, so the grammar, concrete valid
      # examples, the "spec lines, not descriptions" note and the "empty is
      # valid" escape hatch are all pinned here explicitly.
# The concrete example spec line quoted in the grammar block: the
# primary tool of the CONFIGURED target (data from its config file,
# never a workflow name hardcoded here), falling back to a generic
# placeholder that still satisfies the grammar.
def default_tool_example
  Scenarios.loaded_target&.primary_tool || 'Workflow task'
end

def tools_grammar_lines(example = default_tool_example)
        [
          'Tools grammar (strict; every tools entry must match it):',
          '  Workflow [task [input|name=value|noinputs ...]]',
          'Each tools entry is ONE spec line following that grammar — it is a',
          'workflow/task/input reference, never a description, signature,',
          'explanation or structured object. Valid examples:',
          "  #{example}",
          '  ScoutCoder help_workflow',
          '  Baking cake name=chocolate',
          '  MiniTools sum noinputs',
          'tools: [] is valid and means: keep the default tooling.'
        ]
      end

      def summarize_rubric(rubric_summary)
        case rubric_summary
        when String then rubric_summary.to_s
        when Hash then JSON.pretty_generate(rubric_summary)
        when Array then rubric_summary.map(&:to_s).join("\n")
        else rubric_summary.to_s
        end
      end

      # -- proposal validation -----------------------------------------------

      # Validate a proposal object. Returns an Array of error Strings; empty
      # means valid. Checks (research/07 §2 step 7):
      #   - instructions present, non-empty after strip
      #   - tools is a list; each entry matches the tool-spec grammar
      #   - no endpoint-ish keys sneak into the proposal
      def validate_proposal(proposal)
        errors = []
        unless proposal.is_a?(Hash)
          return ["proposal must be a Hash with instructions and tools, got #{proposal.class}"]
        end

        instructions = proposal['instructions']
        if !instructions.is_a?(String) || instructions.strip.empty?
          errors << 'instructions must be a non-empty string'
        end

        tools = proposal['tools']
        if tools.nil?
          errors << 'tools must be an array (may be empty)'
        elsif !tools.is_a?(Array)
          errors << "tools must be an array, got #{tools.class}"
        else
          tools.each_with_index do |t, i|
            errors.concat(tool_spec_errors(t, i))
          end
        end

        %w[endpoint endpoint_name model inference].each do |k|
          errors << "proposal must not carry #{k} (endpoints are never specified in proposals)" if proposal.key?(k)
        end

        errors
      end

      def tool_spec_errors(tool, index)
        label = "tools[#{index}]"
        return ["#{label} must be a string, got #{tool.class}"] unless tool.is_a?(String)

        spec = tool.strip
        return ["#{label} is empty"] if spec.empty?

        unless spec =~ TOOL_SPEC_RE
          return ["#{label} #{spec.inspect} must be 'Workflow [task [input|name=value ...]]'"]
        end

        tokens = spec.split(/\s+/)
        errors = []
        tokens[1..-1].each do |tok|
          next if RESERVED_INPUT_TOKENS.include?(tok)
          errors << "#{label} input token #{tok.inspect} is not a bare name or name=value" unless tok =~ INPUT_TOKEN_RE
        end
        errors
      end

      # Validate with bounded repairs: ask the proposer again (with the
      # validation errors appended) up to MAX_REPAIRS times. Returns
      # [final_proposal_or_nil, attempts(Array of {attempt:, errors:})].
      def validate_with_repairs(proposal, proposer)
        attempts = []
        current = proposal
        0.upto(MAX_REPAIRS) do |attempt|
          errors = validate_proposal(current)
          attempts << { 'attempt' => attempt, 'errors' => errors }
          return [current, attempts] if errors.empty?
          break if attempt == MAX_REPAIRS || !proposer.respond_to?(:repair)

          current = proposer.repair(current, errors)
        end
        [nil, attempts]
      end

      # -- stop rules ----------------------------------------------------------

      # Evaluate the deterministic stop rules from the evolution history.
      #
      #   history  Array of generation records:
      #              { 'generation' => Integer, 'candidate' => name,
      #                'digest' => manifest digest, 'score' => Float (mean),
      #                'pass_all' => bool, 'verdicts' => {scenario => verdict} }
      #   budget   max generations (default 3)
      #   min_improve minimum score improvement that counts as progress
      #
      # Returns nil when the loop should continue, or a String stop reason
      # ('budget_exhausted', 'all_pass', 'no_op_twice', 'regression').
      def stop?(history, budget: BUDGET_DEFAULT, min_improve: 0.0)
        history = Array(history)
        return nil if history.empty?

        gens = history.map { |h| h['generation'].to_i }
        last = history.last
        # rule 1 budget: generation count reached the budget
        return 'budget_exhausted' if gens.max.to_i >= budget

        # rule 2 all_pass: latest generation passes every scenario
        return 'all_pass' if last['pass_all']

        # two consecutive no-op proposals (identical manifest digests)
        if history.length >= 2
          a, b = history[-2], history[-1]
          return 'no_op_twice' if a['digest'] == b['digest']
        end

        # regression vs the best score seen so far (excluding the last entry)
        best = history[0..-2].map { |h| h['score'].to_f }.max || -1.0
        return 'regression' if last['score'].to_f < best - min_improve.to_f

        nil
      end

      # -- generation loop ---------------------------------------------------

      # Run the bounded evolution loop (research/07 §2) over candidates
      # staged as <arms_dir>/candidates/<gen>/Agent/<agent>/start_chat.
      #
      #   experiment    name (results dir component)
      #   scenarios_dir materialized scenario set (catalogue output)
      #   arms_dir      where candidates are staged
      #   agent         agent under test
      #   proposer      object responding to call(experiment, prompt) ->
      #                 proposal Hash (and optionally repair(proposal, errors))
      #   agent_factory factory for the agent-turn object (Runner contract;
      #                 default StubAgent — deterministic, no model)
      #   budget        max generations
      #   out_dir       results root (REQUIRED since Unit B: the loop used to
      #                 default to Dir.pwd/results and silently write wherever
      #                 the caller happened to stand; now it raises instead)
      #
      # Writes results/<experiment>/evolution.json with per-generation
      # records (candidate manifest digest, scores, stop-reason evaluation)
      # and returns the full history Array.
      def evolve_loop(experiment, scenarios_dir, arms_dir, agent,
                      proposer = StubProposer.new,
                      agent_factory: ->(arm) { Runner::StubAgent.new },
                      budget: BUDGET_DEFAULT, out_dir: nil,
                      min_improve: 0.0)
        budget = budget.to_i
        raise ArgumentError, 'budget must be >= 1' if budget < 1
        raise ArgumentError, "proposer #{proposer.inspect} must respond to call" unless proposer.respond_to?(:call)
        raise ArgumentError, 'out_dir is required (was: silent Dir.pwd/results default)' if out_dir.nil? || out_dir.to_s.strip.empty?

        out_root = out_dir
        evolution_path = File.join(out_root.to_s, experiment.to_s, 'evolution.json')

        history = []
        gen = 1
        while gen <= budget
          prompt = propose_prompt(experiment, flat_scores(history), rubric_summary_for(scenarios_dir))
          raw = proposer.call(experiment, prompt, generation: gen)
          proposal, attempts = validate_with_repairs(raw, proposer)
          if proposal.nil?
            history << dead_generation(experiment, gen, agent, raw, attempts)
            break
          end

          candidate = "candidates/#{gen}"
          override = Runner.write_override(File.join(arms_dir.to_s, candidate), agent,
                                           proposal['instructions'], proposal['tools'])
          # arms for this generation: baseline + best-so-far + new candidate
          # (run_arms prepends baseline itself; deterministic scoring means
          # re-running baseline/best each generation yields identical rows,
          # keeping the comparison inside every generation record fresh).
          best = best_candidate(history)
          arms = ([best, candidate].compact)
          runs = Runner.run_arms(experiment, scenarios_dir, arms_dir, agent,
                                 agent_factory, arms: arms, out_dir: out_root)
          run = runs[candidate]
          record = generation_record(experiment, gen, candidate, agent, override, run, attempts)
          record['arms_run'] = [Runner::BASELINE] + arms
          record['comparison'] = runs.keys.each_with_object({}) do |arm, h|
            h[arm] = { 'score' => mean_score(runs[arm]['results']),
                       'pass_all' => runs[arm]['results'].values.all? { |r| r['verdict'] == 'PASS' } }
          end
          history << record

          Open.write(evolution_path, JSON.pretty_generate('experiment' => experiment,
                                                          'history' => history,
                                                          'stopped' => stop?(history, budget: budget, min_improve: min_improve)) + "\n")
          break if stop?(history, budget: budget, min_improve: min_improve)

          gen += 1
        end

        Open.write(evolution_path, JSON.pretty_generate('experiment' => experiment,
                                                        'history' => history,
                                                        'stopped' => stop?(history, budget: budget, min_improve: min_improve)) + "\n") if history.any?
        history
      end

      # -- loop helpers --------------------------------------------------------

      def flat_scores(history)
        Array(history).flat_map do |h|
          next [] if h['dead']
          verdicts = h['verdicts'] || {}
          verdicts.map do |scenario, verdict|
            scenario_score = verdict == 'PASS' ? 1.0 : 0.0
            { 'arm' => h['candidate'], 'generation' => h['generation'],
              'scenario' => scenario, 'verdict' => verdict, 'score' => scenario_score,
              'failures' => Array(h['failures'][scenario]) }
          end
        end
      end

      # Best non-dead generation so far (highest mean score; ties -> earliest).
      def best_candidate(history)
        alive = Array(history).reject { |h| h['dead'] }
        return nil if alive.empty?
        alive.max_by { |h| h['score'].to_f }['candidate']
      end

      def rubric_summary_for(scenarios_dir)
        Runner.scenario_ids(scenarios_dir).map do |id|
          rubric = YAML.load_file(File.join(scenarios_dir.to_s, id, 'rubric.yaml'))
          "#{id}: #{rubric['description']} [#{rubric['class']}]"
        end.join("\n")
      end

      def generation_record(experiment, gen, candidate, agent, override, run, attempts)
        results = run['results'] || {}
        verdicts = results.map { |id, r| [id, r['verdict']] }.to_h
        failures = results.map { |id, r| [id, r['failures']] }.to_h
        {
          'experiment' => experiment,
          'generation' => gen,
          'candidate' => candidate,
          'agent' => agent,
          'digest' => manifest_digest(override['start_chat']),
          'instructions' => override['instructions'],
          'tools' => override['tools'],
          'score' => mean_score(results),
          'pass_all' => verdicts.values.all? { |v| v == 'PASS' },
          'verdicts' => verdicts,
          'failures' => failures,
          'attempts' => attempts,
          'dir' => run['dir']
        }
      end

      def dead_generation(experiment, gen, agent, raw, attempts)
        { 'experiment' => experiment, 'generation' => gen, 'agent' => agent,
          'dead' => true,
          'raw' => raw.to_s[0, 2000],
          'attempts' => attempts,
          'digest' => "dead:#{Digest::SHA1.hexdigest(raw.to_s)}",
          'score' => 0.0, 'pass_all' => false, 'verdicts' => {}, 'failures' => {} }
      end

      def mean_score(results)
        return 0.0 if results.empty?
        results.values.map { |r| r['score'].to_f }.sum / results.length
      end

      def manifest_digest(start_chat_path)
        Digest::SHA1.hexdigest(Open.read(start_chat_path))
      end
    end

    def self.indent_block(text)
      text.to_s.lines.map { |l| '  ' + l.chomp }.join("\n").gsub(/\A\n+|\n+\z/, '')
    end

    # Default proposer: returns a fixed first proposal and echoes the same one
    # afterwards (so the no-op-twice stop rule triggers deterministically).
    # The live default-endpoint proposer plugs in with the same interface.
    class StubProposer
def initialize(instructions: 'Apply the scenario patch exactly as given.',
               tools: nil)
  @instructions = instructions
  # tools: nil means "derive from the configured target" (its primary
  # tool spec); an explicit array always wins.
  @tools = tools.nil? ? [Evolve.default_tool_example] : Array(tools)
        @repairs = 0
      end

      def call(_experiment, _prompt, generation: nil)
        { 'instructions' => @instructions, 'tools' => @tools.dup }
      end

      def repair(_proposal, errors)
        # naive repair: if instructions were missing/empty, supply the default
        { 'instructions' => @instructions, 'tools' => @tools.dup }
      end
    end

    # A proposer that yields scripted proposals in order (tests).
    class ScriptedProposer
      def initialize(proposals)
        @proposals = Array(proposals)
        @i = 0
      end

      def call(_experiment, _prompt, generation: nil)
        p = @proposals[@i] || @proposals.last
        @i += 1
        p
      end

      def repair(_proposal, _errors)
        call(nil, nil)
      end
    end
  end
end
