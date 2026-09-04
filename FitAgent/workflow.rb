require 'scout-ai'
require 'fileutils'

FITAGENT_ROOT = File.dirname(File.expand_path(__FILE__))

# Deterministic scenario catalogue + scorer (no inference anywhere in them)
$LOAD_PATH.unshift(File.join(FITAGENT_ROOT, 'lib'))
require 'FitAgent/scenarios'
require 'FitAgent/scoring'
require 'FitAgent/runner'

Workflow.directory = Scout.var.jobs.find(:lib)
module FitAgent
  extend Workflow

  input :agents, :path, 'Path to agent definitions', Scout.agents.Test
  input :use_case, :path, 'Path to use case dir', Scout.use_case.Test
  input :endpoint, :select, 'Endpoint to use for both the run and the analyst', :qwen
  input :main_agent, :string, 'Main agent to run', 'FitMain'
  input :repo, :path, 'Optional target repository to stage inside the sandbox (copied or linked per repo_mode)', nil
  input :repo_mode, :select, 'How to stage :repo (copy = isolated snapshot, link = shared, live)', 'copy'
  input :exclude, :array, 'Path patterns to exclude when staging :repo in copy mode', ['var', '.git', 'tmp']
  task :use_case => :text do |agents,use_case,endpoint,main_agent,repo,repo_mode,exclude|

    # Prepare sandbox with use case
    use_case = Path.setup(use_case.to_s).find
    # Accept a use_case JOB path (result file of a previous FitAgent#use_case
    # run): remap to the staged use_case dir inside that job so analyze can be
    # re-invoked over an existing run without re-staging from a result file.
    staged = use_case.to_s.sub(/\.info$/, '') + '.files/sandbox/use_case'
    use_case = staged if Open.directory?(staged) && ! Open.directory?(use_case)
    agents = Path.setup(agents.to_s).find
    sandbox = file('sandbox')
    # Defensive: a stray FILE named sandbox (from an aborted run) would make
    # mkdir_p raise EEXIST; remove it so the sandbox dir can be created.
    FileUtils.rm_f(sandbox) if File.exist?(sandbox) && ! File.directory?(sandbox)
    FileUtils.mkdir_p sandbox unless Open.directory?(sandbox)
    Open.cp use_case, sandbox
    Open.mkdir sandbox.lib unless Open.exists?(sandbox.lib)
    # Local var/cache inside sandbox: with ~/.scout read-only today, Scout.var
    # would otherwise resolve the ask-cache to ~/.scout/var/cache (EROFS).
    # A sandbox-local var dir wins the resolution order and keeps writes inside the job.
    Open.mkdir sandbox.var.cache.ask

    # Copy endpoint definitions (etc/AI) into the sandbox so the inner agent
    # resolves -e <endpoint> from its own cwd instead of a global ~/.scout.
    # Hygiene: the openwebui backend does NOT resolve env: placeholders, so a
    # literal env: value would 401. Instead the sandbox file materializes the
    # key from SCOUT_AI_<NAME>_KEY when present; the file then contains the
    # key, but it lives only in the per-run job sandbox, is never committed,
    # and git-ignored patterns cover it. When the env var is absent we copy
    # the repo etc/AI verbatim and warn (keeps offline/other setups working).
    endpoint_etc = Path.setup('etc/AI')
    if endpoint_etc.exists?
      Open.mkdir sandbox.etc.AI.find
      Dir.glob(File.join(endpoint_etc.find, '*')).sort.each do |ep_file|
        ep_name = File.basename(ep_file.to_s)
        body = Open.read(ep_file.to_s)
        env_key = ENV["SCOUT_AI_#{ep_name.upcase}_KEY"]
        if env_key
          body = body.gsub(/^(key\s*:\s*)\S.*$/) { "#{$1}#{env_key}" }
          Log.info "FitAgent: sandbox key for endpoint #{ep_name} injected from env SCOUT_AI_#{ep_name.upcase}_KEY"
        else
          Log.warn "FitAgent: SCOUT_AI_#{ep_name.upcase}_KEY not set; copying etc/AI/#{ep_name} verbatim into the run sandbox"
        end
        Open.write(sandbox.etc.AI[ep_name].find, body)
      end
    end

    # Add agent directory
    Open.cp agents, sandbox.Agent

    # Stage the target repository, if any, so the agent actually works on the
    # code under test instead of an empty sandbox (supports "any repository").
    if repo && Open.exists?(repo)
      repo = Path.setup(repo.to_s)
      target = sandbox[File.basename(repo.to_s.sub(/\/$/,''))]
      case repo_mode.to_s
      when 'link'
        FileUtils.ln_s(repo.realpath, target) unless Open.exists?(target)
      else
        if Open.directory?(repo['.git'])
          CMD.cmd("git clone -q --no-hardlinks '#{repo}' #{target}")
        else
          CMD.cmd("rsync -a --exclude var --exclude .git --exclude tmp --exclude etc/AI '#{repo}/' #{target}/")
        end
        # Never let endpoint credentials travel with a staged repository copy.
        Open.rm_rf target['etc/AI'].find if Open.exists?(target['etc/AI'].find)
      end
    end

    # Link the workflows referenced by the agent suite (introduce:/tool:
    # entries) into the sandbox, so the inner agent resolves them locally
    # instead of attempting a GitHub clone that fails offline/behind proxies.
    # FitAgent always ships MiniTools into the sandbox: the agent under test
    # gets a working set of execution primitives (sh, read, write, list) no
    # matter which checkout the run was started from. Heavyweight tool
    # workflows (ComputerUse etc.) are often unavailable from inside the
    # sandbox (checkout layout, missing repo, offline autoinstall).
    introduced = ['MiniTools']
    agents = Path.setup(agents.to_s)
    agents.glob("**/start_chat").each do |f|
      next unless File.file?(f.to_s)
      Open.read(f).scan(/^\s*(?:introduce|tool):\s*(\S+)/).each do |m|
        introduced << m.first unless introduced.include?(m.first)
      end
    end if agents.exists?
    sandbox_workflows = sandbox.workflows
    Open.mkdir sandbox_workflows unless Open.exists?(sandbox_workflows)
    wf_search = [File.join(FITAGENT_ROOT, 'workflows'), File.dirname(FITAGENT_ROOT),
                 'workflows', Workflow.workflow_dir.to_s].compact.map(&:to_s).uniq
    introduced.each do |name|
      next if name == 'none' || Open.exists?(sandbox_workflows[name])
      found = wf_search.map { |p| File.join(p.to_s, name) }.find { |p| Open.directory?(p) }
      FileUtils.ln_s(File.realpath(found), sandbox_workflows[name]) if found
    end

    # Run
    Misc.in_dir sandbox do 
      Misc.with_env_hash({
        'SCOUT_NO_ASK_CACHE' => 'recursive',
        'ASK_PERSIST' => 'false',
        'SCOUT_WORKFLOW_AUTOINSTALL' => 'false',

        # ~/.scout is read-only in this session; inner agent process gets a
        # writable HOME with etc/software symlinked to the real one.
        #'SCOUT_WORKFLOW_DIR' => '/tmp/scouthome/.scout/workflows',
        #'HOME' => '/tmp/scouthome',
        # We are already inside an outer bwrap sandbox here; nested user
        # namespaces are denied by the kernel, so the agent's exec tools must
        # not try to create their own bwrap (documented escape hatch).
        'BWRAP_PATH' => 'false',
      }) do
        CMD.cmd('scout-ai', "agent ask #{main_agent} -c main.chat -e #{endpoint} --log 0 -ck 'directory #{Scout.var.jobs.find(:lib)} workflow_jobs'", save_stderr: file('log.txt')).join
      end
    end
  end

  # Forwarded inputs (same names as use_case) so the dependency resolves to
  # the same job the matrix runner already ran (cache hit, no agent rerun).
  # Dynamic dep: when +use_case_job+ (path to a previous use_case result)
  # is given, attach to that finished job instead of resolving from inputs,
  # so analyze can be re-run over existing runs with no agent re-execution.
  dep do |inputname,inputs|
    uj = inputs[:use_case_job]
    if uj && ! uj.to_s.strip.empty?
      uj = Path.setup(uj.to_s).find
      raise ParameterException, "use_case_job #{uj} has no .info sidecar" unless Open.exists?(uj + '.info')
      job = Step.new(uj)
      status = job.info[:status] rescue nil
      raise ParameterException, "use_case_job #{uj} is not done (status: #{status})" unless status.to_s == "done"
      job
    else
      FitAgent.job(:use_case, nil,
                   agents: inputs[:agents], use_case: inputs[:use_case],
                   main_agent: inputs[:main_agent], endpoint: inputs[:endpoint],
                   repo: inputs[:repo], repo_mode: inputs[:repo_mode],
                   exclude: inputs[:exclude])
    end
  end
  input :agents, :path, 'Forwarded to use_case dependency', 'agents/Test'
  input :use_case, :path, 'Forwarded to use_case dependency', 'use_case/Test'
  input :main_agent, :string, 'Forwarded to use_case dependency', 'FitMain'
  input :repo, :path, 'Forwarded to use_case dependency', nil
  input :repo_mode, :select, 'Forwarded to use_case dependency', 'copy'
  input :exclude, :array, 'Forwarded to use_case dependency', ['var', '.git', 'tmp']
  input :use_case_job, :path, 'Path to a previous FitAgent#use_case job result; analyze attaches to it without re-running the agent', nil
  input :instructions, :text, "Instructions for the ChatAnalyst, defaults to use case instructions or default instructions"
  input :experiment, :string, "Experiment tag recorded in the report header for cross-repo bookkeeping", "Default"
  input :endpoint, :select, 'Endpoint used by the analyst AND forwarded to the use_case dep (fixpoint of the same name)', :qwen
  extension :md
  task :analyze => :text do |agents,use_case,main_agent,repo,repo_mode,exclude,use_case_job,instructions,experiment,endpoint|
    use_case = dependencies.first
    main_chat = use_case.file('sandbox/main.chat')
    analyze_chat = use_case.file('sandbox/use_case/analyze.chat')

    analyst_path = Path.setup(File.join(FITAGENT_ROOT, 'agents', 'ChatAnalyst'))
    analyst = LLM::Agent.new(start_chat: LLM.chat(analyst_path['start_chat'].find), endpoint: endpoint)

    analyst.start

    if instructions && ! instructions.strip.empty?
      analyst.user instructions
    elsif analyze_chat.exists?
      analyst.follow LLM.chat(analyze_chat)
    else
      analyst.user <<-EOF
Analyse the chat to evaluate following this criteria:

- was it sucessfull
- was tool calling used, and used appropriatedly
- was the token usage reasonable, consider also cached tokens when appropriate
- if there were complex multi-agent patterns, did they succeed

Follow any job and agent dependencies that you find to explore the entire chat provenance
      EOF
    end

    # Escape role-like headers inside the transcript so Chat.parse treats the
    # whole transcript as one user message instead of splitting on the inner
    # `user:`/`assistant:`/`function_call:` lines.
    transcript = Open.read(main_chat).lines.map do |l|
      l =~ /^(user|assistant|system|meta|function_call|function_call_output|agent|endpoint|model|persist|format|previous_response_id|clear):/ ? "\\#{l}" : l
    end.join
    analyst.user <<-EOF

The text below is the chat transcript of the run (native format: user/assistant
turns, function_call entries, function_call_output entries, and meta lines with
token counts). Analyze that transcript.

<transcript>
#{transcript}
</transcript>

Return a markdown report.

End the report with a fenced ```yaml block (no other content after it) with exactly these keys:

```yaml
experiment: #{experiment}
verdict: PASS | PARTIAL | FAIL
autonomy: <0-5, retrieval autonomy ladder: 0 retrieves what was asked, 1 retrieves relevant unspecified evidence, 2 combines prior results, 3 identifies unstated relationship, 4 proposes falsifiable prediction, 5 retrieves evidence to test own prediction>
rationale: <one line>
```
    EOF

    response = analyst.chat
    analyst.save file('main.chat')
    response
  end

  # ---- compare: multi-arm experiment runner --------------------------------
  #
  # Runs several arms of one experiment through use_case+analyze and writes a
  # canonical results directory <repo>/results/<experiment>/ containing:
  #   runs.tsv     one row per agent run (arm, endpoint, agent, use_case, status,
  #                job path, report path)
  #   results.tsv  one row per analyzed run (arm, endpoint, agent, use_case,
  #                verdict, autonomy)
  # Arm configuration comes from the target repo: <repo>/arms/<experiment>.yaml
  # listing, per arm: agents, use_case, main_agent, endpoint (optional,
  # defaults to the task endpoint), repeats (default 1), repo (optional
  # override), repo_mode (default copy).
  input :arms, :array, 'Arm labels to run; defaults to all arms in the experiment file', []
  input :experiment, :string, 'Experiment tag; also the name of arms/<experiment>.yaml', 'Default'
  input :repo, :path, 'Target repository holding arms/<experiment>.yaml and receiving results/<experiment>/', 'sandbox/demo_repo'
  input :repo_mode, :select, 'How to stage each arm repo', 'copy'
  input :endpoint, :select, 'Default endpoint for arms that do not define one', :qwen
  task :compare => :tsv do |arms,experiment,repo,repo_mode,endpoint|
    repo = Path.setup(repo.to_s).find
    arms_file = repo['arms'][experiment + '.yaml']
    raise ParameterException, "no arms file #{arms_file}" unless arms_file.exists?
    conf = YAML.load_file(arms_file.find)
    raise ParameterException, "arms file #{arms_file} is empty or malformed" unless Hash === conf && conf.any?
    selected = Array(arms).empty? ? conf.keys : arms
    unknown = selected - conf.keys
    raise ParameterException, "unknown arms #{unknown.inspect} for experiment #{experiment}" unless unknown.empty?

    out_dir = repo['results'][experiment]
    FileUtils.mkdir_p out_dir.find
    runs = TSV.setup({}, key: 'arm', type: :list)
    runs.fields = %w[arm endpoint agent use_case status job report]
    results = TSV.setup({}, key: 'arm', type: :list)
    results.fields = %w[arm endpoint agent use_case verdict autonomy]

    selected.each do |arm|
      spec = conf[arm] || {}
      spec_agent = spec['agents'] or raise ParameterException, "arm #{arm}: missing agents"
      spec_uc = spec['use_case'] or raise ParameterException, "arm #{arm}: missing use_case"
      # Resolve arm-relative paths against the target repo, so compare can be
      # launched from anywhere (not only from inside the repo checkout).
      spec_agent = File.expand_path(spec_agent, repo.find.to_s) unless Path.setup(spec_agent.to_s).exists?
      spec_uc = File.expand_path(spec_uc, repo.find.to_s) unless Path.setup(spec_uc.to_s).exists?
      arm_endpoint = spec['endpoint'] || endpoint
      arm_repo = spec['repo'] || repo
      arm_mode = spec['repo_mode'] || repo_mode
      main_agent = spec['main_agent'] || 'FitMain'
      repeats = (spec['repeats'] || 1).to_i

      1.upto(repeats) do |rep|
        tag = "#{experiment}_#{arm}#{repeats > 1 ? "_r#{rep}" : ''}"
        uc_job = FitAgent.job(:use_case, tag,
                              agents: spec_agent, use_case: spec_uc,
                              endpoint: arm_endpoint, main_agent: main_agent,
                              repo: arm_repo, repo_mode: arm_mode)
        uc_job.produce
        status = uc_job.status.to_s
        an_job = FitAgent.job(:analyze, nil, use_case_job: uc_job.path,
                              experiment: tag, endpoint: arm_endpoint)
        an_job.produce rescue nil
        verdict = autonomy = 'NA'
        if an_job.done? && Open.exists?(an_job.path.to_s)
          yaml_block = Open.read(an_job.path).scan(/```yaml\s*\n(.*?)```/m).flatten.last
          if yaml_block
            begin
              fields = YAML.safe_load(yaml_block, permitted_classes: [Symbol], aliases: false) || {}
            rescue Psych::SyntaxError
              # Fallback: line-wise regex so a malformed rationale (colons etc.)
              # never kills the whole compare run.
              fields = {}
              yaml_block.each_line do |line|
                kv = line.match(/^\s*(verdict|autonomy)\s*:\s*(\S+)\s*$/)
                fields[kv[1]] = kv[2] if kv
              end
            end
            verdict, autonomy = fields['verdict'], fields['autonomy']
          end
        end
        row_key = repeats > 1 ? "#{arm}_r#{rep}" : arm
        runs[row_key] = [arm, arm_endpoint, spec_agent, spec_uc, status, uc_job.path, an_job.path]
        results[row_key] = [arm, arm_endpoint, spec_agent, spec_uc, verdict, autonomy]
      end
    end

    Open.write(out_dir['runs.tsv'].find, runs.to_s)
    Open.write(out_dir['results.tsv'].find, results.to_s)
    results.to_s
  end

  # ---- evolve: automatic instruction-evolution loop -----------------------
  #
  # Evolves agent instructions inside a target repo:
  #   Gen0 = the seed agent (agents/<seed>)
  #   each next generation's start_chat is proposed by an LLM from the previous
  #   generation's analyst report, written to agents/<seed>_Gen<N> and run over
  #   the same matrix (agents x use cases given in evolve/<experiment>.yaml).
  # Lineage is recorded in results/<experiment>/lineage.tsv.
  input :seed, :string, 'Seed agent name under <repo>/agents to evolve from', 'MiniBare'
  input :generations, :integer, 'Number of generations to produce (Gen1..GenN)', 2
  input :use_cases, :array, 'Use cases (dir names) under <repo>/use_case for the matrix', []
  input :endpoints, :array, 'Endpoints for the matrix', ['qwen']
  input :experiment, :string, 'Experiment tag; also the name of evolve/<experiment>.yaml', 'Default'
  input :repo, :path, 'Target repository holding evolve/<experiment>.yaml, agents/ and results/', 'sandbox/demo_repo'
  input :repo_mode, :select, 'How to stage the repo for each run', 'copy'
  input :endpoint, :select, 'Endpoint used for instruction proposals and default analysis', :qwen
  task :evolve => :tsv do |seed,generations,use_cases,endpoints,experiment,repo,repo_mode,endpoint|
    repo = Path.setup(repo.to_s).find
    agents_dir = repo['agents']
    raise ParameterException, "seed agent #{agents_dir[seed]} not found" unless agents_dir[seed]['FitMain/start_chat'].exists?
    uc_list = use_cases
    raise ParameterException, "no use cases given (input :use_cases)" if Array(uc_list).empty?
    ev_file = repo['evolve'][experiment + '.yaml']
    if ev_file.exists?
      conf = YAML.load_file(ev_file.find) || {}
      uc_list = conf['use_cases'] if Array(use_cases).empty?
      seed = conf['seed'] if seed == 'MiniBare' && conf['seed']
      generations = conf['generations'] if generations == 2 && conf['generations']
    end

    out_dir = repo['results'][experiment]
    FileUtils.mkdir_p out_dir.find
    lineage = TSV.setup({}, key: 'agent', type: :list)
    lineage.fields = %w[generation endpoint use_case verdict autonomy job]

    propose = lambda do |gen_name, base_chat, feedback|
      l = LLM.chat
      l.endpoint endpoint
      l.user <<~PROMPT
          You are improving agent system instructions for a Scout agent.
          Current start_chat (system instructions + tool wiring):

          <current>
          #{base_chat}
          </current>

          Analyst feedback on the latest run with these instructions:

          <feedback>
          #{feedback}
          </feedback>

          Rewrite the start_chat to fix the problems the analyst found while
          keeping the tool wiring lines (introduce:/tool:) unchanged.
          Output ONLY the new start_chat text, nothing else.
      PROMPT
      resp = l.chat
      resp.is_a?(Array) ? resp.last : resp
    end

    current_agent = seed
    base_chat = Open.read(agents_dir[current_agent]['FitMain/start_chat'].find)
    feedback = 'No run yet; the seed agent is being evaluated for the first time.'
    0.upto(generations) do |gen|
      break if gen > 0 && ! agents_dir[current_agent]['FitMain/start_chat'].exists?
      verdicts = []
      Array(endpoints).each do |ep|
        Array(uc_list).each do |uc|
          tag = "#{experiment}_#{current_agent}_g#{gen}"
          uc_job = FitAgent.job(:use_case, tag,
                                agents: agents_dir[current_agent], use_case: repo['use_case'][uc],
                                endpoint: ep, repo: repo, repo_mode: repo_mode)
          uc_job.produce
          an_job = FitAgent.job(:analyze, tag, use_case_job: uc_job.path,
                                experiment: tag, endpoint: ep)
          an_job.produce rescue nil
          verdict = autonomy = 'NA'
          rationale = ''
          if an_job.done? && Open.exists?(an_job.path.to_s)
            yaml_block = Open.read(an_job.path).scan(/```yaml\s*\n(.*?)```/m).flatten.last
            if yaml_block
              y = YAML.load(yaml_block)
              verdict, autonomy = y.values_at('verdict','autonomy')
              rationale = y['rationale'].to_s
            else
              verdict, autonomy = 'NA', 'NA'
            end
          end
          lineage[current_agent] = [gen.to_s, ep, uc, verdict, autonomy.to_s, uc_job.path]
          verdicts << [uc, ep, verdict, autonomy, rationale, an_job.path.to_s]
        end
      end
      Open.write(out_dir['lineage.tsv'].find, lineage.to_s)

      # propose the next generation from the accumulated analyst feedback
      feedback = verdicts.map do |uc, ep, v, a, rat, rep|
        "#{uc} (#{ep}): #{v}, autonomy #{a}. #{rat} [report #{rep}]"
      end.join("\n")
      next if gen == generations
      gen_name = "#{seed}_Gen#{gen+1}"
      new_chat = propose.call(gen_name, base_chat, feedback)
      # no-op guard: a proposal identical to the base (modulo whitespace) means
      # the analyst feedback gave the LLM nothing concrete to fix; record and
      # stop instead of advancing the lineage with a fake generation.
      if new_chat.to_s.gsub(/\s+/, ' ').strip == base_chat.gsub(/\s+/, ' ').strip
        lineage["#{gen_name}_NOOP"] = [(gen+1).to_s, Array(endpoints).first, 'NOOP: proposal identical to base', 'NA', 'NA', 'NA']
        Open.write(out_dir['lineage.tsv'].find, lineage.to_s)
        break
      end
      new_dir = agents_dir[gen_name]['FitMain']
      FileUtils.mkdir_p new_dir.find
      Open.write(new_dir['start_chat'].find, new_chat)
      current_agent = gen_name
      base_chat = new_chat
    end

    Open.write(out_dir['lineage.tsv'].find, lineage.to_s)
    lineage.to_s
  end

  # Deterministic scenario catalogue (research/07 §3, research/08): materialize
  # the frozen patch-probe scenario set as fixtures under <scenario_set>/<id>/
  # with scenario.yaml, rubric.yaml, patch.txt, work/, expected/ and a
  # manifest.json digest. Pure generator (seeded), no inference, no endpoint.
  input :scenario_set, :path, 'Directory to materialize the scenario set into', 'scenarios'
  input :ids, :array, 'Scenario ids to materialize; defaults to the whole catalogue', []
  task :catalogue => :json do |scenario_set,ids|
    # return the Hash itself: the :json result type serializes once; returning
    # a pre-encoded string would double-encode the job output.
    FitAgent::Scenarios.materialize(scenario_set, ids: ids)
  end

  # ---- override: stage a candidate Agent override directory ---------------
  #
  # Materializes sandbox/Agent/<name>/start_chat from instructions + tool
  # lines (grammar per research/05 section 2: `introduce:`/`tool:` lines,
  # `Workflow [task [input|name=value ...]]` spec strings). Pure write into a
  # candidate manifest directory; canonical agent definitions and other
  # workflows' sources are never touched. No inference, no endpoint.
  input :name, :string, 'Candidate name; becomes sandbox/Agent/<name>/', 'candidate'
  input :instructions, :text, 'System instructions for the candidate start_chat', ''
  input :tools, :array, 'Tool spec lines (Workflow [task [inputs]]), verbatim into tool: lines', []
  task :override => :json do |name,instructions,tools|
    dir = File.join(Dir.pwd, 'sandbox')
    info = FitAgent::Runner.write_override(dir, name, instructions, tools)
    info.merge('path' => info['start_chat'])
  end

  # Deterministic scorer (research/04): evaluate a recorded run against the
  # scenario rubrics. Evidence only — the sandbox work trees the agent
  # actually produced plus the run transcript (main.chat) parsed with
  # Chat.tool_calls. No model calls, no endpoint, nothing re-executed.
  #
  # One row per scenario: verdict, score, functional/message tiers, failures.
  # A detailed per-scenario breakdown is written to scores.json in the job.
  input :scenarios, :path, 'Scenario set directory (holds <id>/rubric.yaml; produced by catalogue)', 'scenarios'
  input :use_case_job, :path, 'Path to a finished FitAgent#use_case job whose .files/sandbox is scored', nil
  input :sandbox, :path, 'Explicit sandbox directory containing scenarios/ and main.chat; overrides use_case_job', nil
  task :score => :tsv do |scenarios,use_case_job,sandbox|
    set = Path.setup(scenarios.to_s).find
    ids = FitAgent::Scenarios.scenario_ids(set.find)
    raise ParameterException, "scenario set #{set} contains no scenarios (catalogue not materialized?)" if Array(ids).empty?

    box = nil
    if sandbox && ! sandbox.to_s.strip.empty?
      box = Path.setup(sandbox.to_s).find
    elsif use_case_job && ! use_case_job.to_s.strip.empty?
      box = Path.setup(use_case_job.to_s.sub(/\.info$/, '') + '.files/sandbox').find
    else
      raise ParameterException, 'score needs :sandbox or :use_case_job'
    end
    raise ParameterException, "no sandbox #{box}" unless Open.directory?(box)
    chat = box['main.chat']
    raise ParameterException, "no main.chat under #{box}" unless chat.exists?

    results = {}
    ids.each do |id|
      rubric_file = set[id]['rubric.yaml']
      raise ParameterException, "no rubric for #{id} under #{set}" unless rubric_file.exists?
      rubric = YAML.load_file(rubric_file.find)
      work = box['scenarios'][id]['work']
      raise ParameterException, "no work tree for #{id} under #{box['scenarios']}" unless Open.directory?(work)
      results[id] = FitAgent::Scoring.score_scenario(work.find, rubric, chat.find,
                                                     'use_case_job' => use_case_job.to_s,
                                                     'sandbox' => box.find)
    end

    Open.write(file('scores.json'), JSON.pretty_generate(results) + "\n")
    tsv = TSV.setup({}, key: 'scenario', type: :list)
    tsv.fields = %w[verdict score functional_ok message_ok failures chat]
    ids.each do |id|
      r = results[id]
      tsv[id] = [r['verdict'], r['score'].to_s,
                 r['functional']['files'].values.all? { |v| v['ok'] } ? 'true' : 'false',
                 r['message']['count_ok'].to_s,
                 r['failures'].join(';'),
                 r['evidence']['chat']]
    end
    tsv.to_s
  end

  # ---- run_arms: multi-arm scenario runner --------------------------------
  #
  # Runs the scenario catalogue for every arm and scores each one
  # deterministically. An arm is a staged Agent override directory
  # <arms_dir>/<arm>/Agent/<agent>/start_chat; `baseline` (and any label
  # without a staged dir) runs the canonical agent with NO override.
  # Output: results/<experiment>/<arm>/{scores.tsv,scores.json,arms.json}.
  #
  # The agent turn itself is injected through :agent_turn (an object
  # responding to call(scenario_dir, arm_box) that writes main.chat and
  # mutates the work tree); the default runs the built-in deterministic
  # stub so this task is testable with no model. Live use_case wiring for
  # the agent turn arrives in a later unit and will be passed the same way.
  # No endpoint input anywhere: runs are deterministic-only by contract.
  input :experiment, :string, 'Experiment name (results dir component)', 'default'
  input :scenarios_dir, :path, 'Materialized scenario set (catalogue output)', 'scenarios'
  input :arms_dir, :path, 'Directory holding <arm>/Agent/<agent>/ override dirs', 'arms'
  input :agent, :string, 'Agent under test (name under Agent/)', 'FitMain'
  task :run_arms => :json do |experiment,scenarios_dir,arms_dir,agent|
    FitAgent::Runner.run_arms(experiment, scenarios_dir, arms_dir, agent,
                              out_dir: File.join(Dir.pwd, 'results'))
  end
end
