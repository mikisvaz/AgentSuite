require 'json'
require 'yaml'
require 'tmpdir'
require 'securerandom'
require 'fileutils'

module FitAgent
  # Real agent session per scenario (research/07 §2 step 1, live form).
  #
  # LiveAgentChat runs an actual LLM::Agent seeded with the scenario brief
  # ("Apply the following patch to the repo at hand: <patch.txt contents>"),
  # with the TARGET workflow (FitAgent::TargetSpec) exposed as the agent's
  # toolset, executing with PWD = the scenario work tree. Which workflow
  # that is — where its checkout lives, which tools it offers — is DATA
  # supplied by the target spec; this class never names a concrete
  # workflow.
  #
  # Endpoint policy (research/07 addendum 2026-09-05, decision 1): NO
  # endpoint is ever specified here — the agent is built plain
  # (LLM::Agent.new) so the configured default applies by omission. The
  # child process may still read the ambient endpoint configuration that
  # the surrounding job environment provides, but this class never names
  # or selects an endpoint.
  #
  # Nested-sandbox rule (research/07 §5.3 / research/08 Finding A):
  # BWRAP_PATH=false is exported to the child so the target workflow's
  # exec tools never try to spawn their own bwrap.
  #
  # The full session (user turn, tool calls, tool outputs, assistant turns)
  # is serialized with Chat#write into <arm_box>/main.chat, which is exactly
  # the file Scoring.tool_calls parses; an `meta: staged_agent=` line
  # records override provenance when a candidate override is staged.
  class LiveAgentChat
    # The generated child script is materialized OUTSIDE lib/ (lib/ holds
    # authored sources only) into a deterministic, writable run-time
    # location: <workflow root>/var/fitagent_live_chat.rb (var/ is
    # git-ignored). Re-written on every session_script call so the file can
    # never drift from SESSION_SCRIPT.
    SCRIPT_NAME = 'fitagent_live_chat.rb'

    # +target+      FitAgent::TargetSpec (or a target config path) naming
    #               the workflow checkout the child requires
    # +agent_dir+   override dir to stage (<arms_dir>/<arm>); when nil (the
    #               baseline arm) no Agent/ dir is staged and the agent runs
    #               with only the scenario brief + tooling as its seed.
    # +timeout+     seconds per scenario session
    def initialize(target:, agent_dir: nil, timeout: 900,
                   tag_prefix: 'livechat')
      @target = target.is_a?(TargetSpec) ? target : TargetSpec.load(target)
      @agent_dir = agent_dir
      @timeout = timeout
      @tag_prefix = tag_prefix
    end

    # The workflow checkout the child process requires (from the target).
    def workflow_dir
      @target.workflow_dir!
    end

    # Runner contract: call(scenario_dir, arm_box) -> chat file path.
    def call(scenario_dir, arm_box)
      scenario_dir = scenario_dir.to_s
      arm_box = arm_box.to_s

      require 'tmpdir'
      require 'securerandom'
      Dir.mktmpdir("fitagent-livechat-#{SecureRandom.hex(4)}") do |tmp|
        chat_out = File.join(arm_box, 'main.chat')
        out = File.join(tmp, 'session.json')
        script = self.class.session_script
        work = File.join(scenario_dir, 'work')
        start_chat = staged_start_chat
        cmd = ['ruby', script, scenario_dir, work, out, chat_out,
               workflow_dir, start_chat.to_s].map { |a| a.inspect }.join(' ')
        o, e, s = run_with_timeout(cmd)
        payload = if Open.exists?(out)
                    JSON.parse(Open.read(out))
                  else
                    { 'ok' => false,
                      'error' => (e.to_s.empty? ? "exit #{s}" : e.to_s.split("\n").first).to_s }
                  end
        unless Open.exists?(chat_out)
          # the child died before writing the transcript: leave a minimal
          # valid chat so scoring reports the failure instead of raising.
          write_failure_chat(chat_out, payload, start_chat)
        end
        chat_out
      end
    end
    alias run call

    private

    def staged_start_chat
      return nil if @agent_dir.nil?
      Dir.glob(File.join(@agent_dir.to_s, 'Agent', '*', 'start_chat')).sort.first
    end

    def run_with_timeout(cmd)
      out, err, status = '', '', nil
      begin
        io = CMD.cmd("env BWRAP_PATH=false #{cmd}", stderr: true, pipe: true,
                                                    log: 0, timeout: @timeout)
        out = io.read
        io.close
        err = io.stderr.read if io.respond_to?(:stderr) && !io.stderr.closed?
        status = 0
      rescue StandardError => e
        err = e.message
        status = 1
      end
      [out, err, status]
    end

    def write_failure_chat(path, payload, start_chat)
      FileUtils.mkdir_p(File.dirname(path))
      lines = ['user:', '', 'Apply the patch.', '']
      lines << 'meta: staged_agent=' + start_chat if start_chat
      lines.concat(['assistant:', '', (payload['error'] || 'live session failed'), ''])
      File.open(path, 'wb') { |f| f.write(lines.join("\n")) }
    end

    # Child script: staged HOME policy, PWD = work, plain LLM::Agent (no
    # endpoint), seed = override start_chat (when staged) + scenario brief
    # + the target workflow's whole-workflow tooling. Serializes the
    # session with Chat#write. The generated file lives under var/ (see
    # SCRIPT_NAME), never inside lib/.
    def self.session_script
      dir = session_script_dir
      path = File.join(dir, SCRIPT_NAME)
      Open.rm(path)
      Open.write(path, SESSION_SCRIPT)
      path
    end

    # Deterministic writable home for the generated script: the workflow
    # root's var/ dir when the checkout is writable, otherwise the Scout
    # tmp store (foreign/sandboxed checkouts).
    def self.session_script_dir
      root = File.expand_path('../..', __dir__)
      var = File.join(root, 'var')
      return var if File.writable?(root) || File.writable?(var) || !File.exist?(var)
      d = Path.setup(Scout.var.tmp.find.to_s + '/fitagent')
      FileUtils.mkdir_p(d.to_s)
      d.to_s
    end

    SESSION_SCRIPT = <<~'RUBY'
      # FitAgent::LiveAgentChat child: one real agent session against a
      # scenario work tree. ARGV: scenario_dir work out chat_out target start_chat
      require 'json'
      require 'yaml'

      scenario_dir, work, out, chat_out, target, start_chat = ARGV

      # No endpoint staging: run with the REAL HOME so the configured default
      # endpoint resolves natively from the user store (default by omission;
      # this script never names or selects an endpoint). Blank the ASK/LLM/
      # ENDPOINT env vars only when they are EMPTY strings — a stray empty
      # value would otherwise be treated as a configured default.
      ENV['BWRAP_PATH'] = 'false'
      ENV['SCOUT_WORKFLOW_AUTOINSTALL'] = 'false'
      # LLM.ask persists every response under Scout.var.cache.ask, which a
      # foreign work-tree PWD resolves through the :user map — the read-only
      # user store inside this sandbox, and the session dies with Errno::EROFS.
      # A fit session measures fresh turns anyway, so the ask cache is
      # disabled rather than redirected (the agent option below is the lever
      # that reaches LLM.ask; the env var covers the Config fallback).
      ENV['PERSIST'] = 'false'
      %w[ASK LLM ENDPOINT ASK_ENDPOINT LLM_ENDPOINT].each do |k|
        ENV[k] = nil if ENV[k] && ENV[k].to_s.strip.empty?
      end

      Dir.chdir(work)
      require 'scout-ai'
      require 'tmpdir'
      # Foreign-PWD guard (see LiveAgentChat header): with the work tree as
      # PWD, Scout resolves workflow job paths and persistence caches against
      # the read-only user store and every tool job dies with Errno::EROFS.
      # Redirect BOTH into a per-session scratch dir before any workflow is
      # required, so job writes land somewhere writable that dies with the
      # session; PWD stays the staged work tree.
      scratch = Dir.mktmpdir('fitagent-session-scratch')
      Workflow.directory = Path.setup(scratch)
      Persist.cache_dir = File.join(scratch, 'cache/persistence')
      Persist.lock_dir = File.join(scratch, 'tmp/persist_locks')
      require File.join(target, 'workflow.rb')
      Workflow.require_workflow File.join(target, 'workflow.rb')

      patch_text = File.read(File.join(scenario_dir, 'patch.txt'))
      seed_text = +''
      if start_chat && !start_chat.to_s.strip.empty?
        seed_text << File.read(start_chat) << "\n\n"
      end
      seed_text << "user:\n\n" << <<~BRIEF
        Apply the following patch to the repo at hand using the `patch` tool:

        ```diff
        #{patch_text.chomp}
        ```
      BRIEF

      agent = LLM::Agent.new(persist: false)
      agent.workflow = Workflow.require_workflow File.join(target, 'workflow.rb')
      agent.start_chat.follow Chat.parse(seed_text)
      agent.chat

      begin
        agent.current_chat.write(chat_out, true)
      rescue StandardError
        Open.write(chat_out, agent.current_chat.to_s)
      end
      File.write(out, JSON.generate('ok' => true, 'chat' => chat_out))
    RUBY
  end
end
