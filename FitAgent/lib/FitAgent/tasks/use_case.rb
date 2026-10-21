module FitAgent
  input :agents, :path, 'Path to agent definitions'
  input :use_case, :path, 'Path to use case dir', nil, required: true
  input :endpoint, :select, 'Endpoint to use for both the run and the analyst'
  input :main_agent, :string, 'Main agent to run', 'MainAgent'
  input :repo, :path, 'Optional target repository to stage inside the sandbox (copied or linked per repo_mode)', nil
  input :repo_mode, :select, 'How to stage :repo (copy = isolated snapshot, link = shared, live, git = clone if repo or copy)', 'copy'
  input :exclude, :array, 'Path patterns to exclude when staging :repo in copy mode', ['var', '.git', 'tmp']
  task :use_case => :text do |agents,use_case,endpoint,main_agent,repo,repo_mode,exclude|

    agents = Path.setup(agents.to_s).find if agents

    # Accept a use_case JOB path (result file of a previous FitAgent#use_case
    # run): remap to the staged use_case dir inside that job so analyze can be
    # re-invoked over an existing run without re-staging from a result file.
    use_case = Path.setup(use_case.to_s).find
    staged = use_case.to_s.sub(/\.info$/, '') + '.files/sandbox/use_case'
    use_case = staged if Open.directory?(staged) && ! Open.directory?(use_case)

    Open.mkdir files_dir
    # Stage the target repository, if any, so the agent actually works on the
    # code under test instead of an empty sandbox (supports "any repository").
    if repo && Open.exists?(repo)
      repo = Path.setup(repo.to_s)
      repo_name = File.basename(repo.to_s.sub(/\/*$/,''))
      target = file(repo_name)

      case repo_mode.to_s
      when 'link'
        Open.ln_s(repo.realpath, target) unless Open.exists?(target)
      else
        if Open.directory?(repo['.git']) && repo_mode == 'git'
          CMD.cmd("git clone -q --no-hardlinks '#{repo}' #{target}")
        else
          CMD.cmd_log("rsync -a --exclude main.chat.files --exclude .git --exclude tmp --exclude etc/AI '#{repo}/' #{target}/")
        end unless Open.exists?(target)
        # Never let endpoint credentials travel with a staged repository copy.
        Open.rm_rf target['etc/AI'].find if Open.exists?(target['etc/AI'].find)
      end

      sandbox = target
    else
      sandbox = file('sandbox')
    end

    set_info :sandbox, sandbox

    log :copy_use_case, 'Preparing use case'
    use_case.glob('*').each do |file|
      raise "Should not copy files in 'link' mode" if repo && repo_mode.to_s == 'link'
      Open.cp file, sandbox[File.basename(file)]
    end

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
      log :copy_endpoints, 'Preparing endpoints'
      Open.mkdir sandbox.etc.AI.find
      Dir.glob(File.join(endpoint_etc.find, '*')).sort.each do |ep_file|
        ep_name = File.basename(ep_file.to_s)
        body = Open.read(ep_file.to_s)
        env_key = ENV["SCOUT_AI_#{ep_name.upcase}_KEY"]
        if env_key
          body = body.gsub(/^(key\s*:\s*)\S.*$/) { "#{$1}#{env_key}" }
          Log.info "FitAgent: sandbox key for endpoint #{ep_name} injected from env SCOUT_AI_#{ep_name.upcase}_KEY"
        else
          Log.high "FitAgent: SCOUT_AI_#{ep_name.upcase}_KEY not set; copying etc/AI/#{ep_name} verbatim into the run sandbox"
        end
        Open.write(sandbox.etc.AI[ep_name].find, body)
      end
    end

    # Add agent directory
    log :copy_agents, 'Preparing agents'
    Open.cp agents, sandbox.Agent if agents

    # Link the workflows referenced by the agent suite (introduce:/tool:
    # entries) into the sandbox, so the inner agent resolves them locally
    # instead of attempting a GitHub clone that fails offline/behind proxies.
    # FitAgent always ships MiniTools into the sandbox: the agent under test
    # gets a working set of execution primitives (sh, read, write, list) no
    # matter which checkout the run was started from. Heavyweight tool
    # workflows (the configured target workflow etc.) are often unavailable
    # from inside the sandbox (checkout layout, missing repo, offline
    # autoinstall).
    
    introduced = ['MiniTools']

    agents = Path.setup(agents.to_s)

    chat_files = []
    chat_files << sandbox['main.chat'] if sandbox['main.chat'].exists?
    chat_files += agents.glob("**/start_chat") if agents.exists?
    chat_files.each do |f|
      next unless File.file?(f.to_s)
      Open.read(f).scan(/^\s*(?:introduce|tool):\s*(\S+)/).each do |m|
        introduced << m.first unless introduced.include?(m.first)
      end
    end

    wf_search = [File.join(FITAGENT_ROOT, 'workflows'), File.dirname(FITAGENT_ROOT),
                 'workflows', Workflow.workflow_dir.to_s].compact.map(&:to_s).uniq

    log :copy_workflows, 'Preparing workflows'
    sandbox_workflows = sandbox.workflows
    Open.mkdir sandbox_workflows unless Open.exists?(sandbox_workflows)
    introduced.each do |name|
      next if name == 'none' || Open.exists?(sandbox_workflows[name])
      found = wf_search.map { |p| File.join(p.to_s, name) }.find { |p| Open.directory?(p) }
      FileUtils.ln_s(File.realpath(found), sandbox_workflows[name]) if found
    end

    severity = config :severity, :log, :log_ask, default: Log.severity
   # Run
    log :ask, "Asking #{main_agent}"
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
        # The config continue prevents erasing the job.
        'BWRAP_PATH' => 'false',
      }) do
        begin
          logfile = file('log.txt')
          io =CMD.cmd('scout-ai', "agent ask #{main_agent} -c main.chat -e #{endpoint} --log #{severity} -ck 'directory #{Scout.var.jobs.find(:current)} workflow_jobs,path /usr/bin/bwrap bwrap,continue true error' > #{self.tmp_path} 2> #{logfile}", pipe: true)

          tail = CMD.cmd("tail -f '#{logfile}'", pipe: true)
          Open.consume_stream(tail, true, STDERR, false)
        ensure
          io.join
        end
        nil
      end
    end
  end


  dep :use_case
  input :instructions, :text, "Instructions for the ChatAnalyst, defaults to use case instructions or default instructions"
  input :experiment, :string, "Experiment tag recorded in the report header for cross-repo bookkeeping", "Default"
  input :endpoint_analyst, :select, 'Endpoint used by the analyst AND forwarded to the use_case dep (fixpoint of the same name)'
  extension :md
  # DEPRECATED (fit-era): superseded by the deterministic Scoring.score_scenario
  # rubric path (score task); kept for compatibility with existing job references.
  task :analyze => :text do |instructions,experiment,endpoint|
    use_case = dependencies.first
    sandbox = Path.setup(use_case.info[:sandbox] || use_case.file('sandbox'))
    main_chat = sandbox['main.chat']
    analyze_chat = sandbox['analyze.chat']

    analyst = LLM.load_agent :ChatAnalyst
    analyst.endpoint = endpoint if endpoint
    Chat.allow_job use_case

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

    analyst.user <<-EOF
Below is the Use Case report
    EOF

    analyst.file use_case.path

    analyst.user <<-EOF
The Use Case was ran here: #{use_case.file('sandbox')}, and chat file is here: #{main_chat}.
    EOF

    response = analyst.chat
    analyst.save('analysis.chat')
    response
  end
end
