require 'test/unit'
require 'fileutils'
require_relative '../../test_helper'
require 'FitAgent/agent_chat'

# Live-agent-chat tests: a REAL model call through the configured default
# endpoint (never named; the child resolves the ambient default). Guarded by
# FITAGENT_LIVE_MODEL=1 so CI-style runs skip them; a network/endpoint
# failure fails the test with a clear message rather than hanging.
class TestLiveAgentChat < Test::Unit::TestCase
  # The shipped example target (repo-level default), mirroring the e2e
  # smoke: LiveAgentChat needs a TargetSpec since the decoupling round.
  TARGET = FitAgent::Scenarios.loaded_target ||
           FitAgent::TargetSpec.load(File.expand_path('../../../../examples/computeruse-patch/target.yaml', __dir__))

  def live_model?
    ENV['FITAGENT_LIVE_MODEL'].to_s == '1'
  end

  def endpoint_ready?
    return @endpoint_ready if instance_variable_defined?(:@endpoint_ready)
    src_ai = File.join(Dir.pwd, 'etc/AI')
    @endpoint_ready = File.directory?(src_ai) && !Dir.glob(File.join(src_ai, '*')).empty?
  end

  def test_session_script_shape
    # No endpoint selection anywhere in the child: grep-level guarantee the
    # constraint holds by construction, not just by convention.
    src = FitAgent::LiveAgentChat::SESSION_SCRIPT.to_s
    assert src.include?('LLM::Agent.new'), 'child must build a plain agent'
    refute src.match?(/endpoint\s*[:=]/), 'child must never set an endpoint'
    refute src.include?('Scout.etc.AI['), 'child must never select an endpoint table entry'
    assert src.include?("ENV['BWRAP_PATH'] = 'false'"), 'child must disable nested bwrap'
    assert src.include?('patch.txt'), 'child must seed the scenario brief'
    assert src.include?('current_chat.write'), 'child must serialize the session transcript' # heredoc squiggly may re-indent; content check below is semantic
  end

  def test_live_model_f01
    omit('live-model test; set FITAGENT_LIVE_MODEL=1') unless live_model?
    omit('no endpoint configuration found in etc/AI') unless endpoint_ready?

    exp = 'fitagent_livechat_f01'
    root = File.join(Dir.pwd, 'tmp', 'live_model_f01')
    FileUtils.rm_rf root
    FileUtils.mkdir_p root
    set = File.join(root, 'scenarios')
    FitAgent::Scenarios.materialize(set, ids: ['F01'])
    arm_box = File.join(root, 'arm_box')
    scenario = File.join(set, 'F01')

    turn = FitAgent::LiveAgentChat.new(target: TARGET, timeout: 600)
    chat = turn.call(scenario, arm_box)

    assert File.file?(chat), 'session transcript main.chat must exist'
    calls = FitAgent::Scoring.tool_calls(chat)
    assert calls.any? { |c| c['tool'] == 'patch' }, "expected a real patch call, saw #{calls.map { |c| c['tool'] }.inspect}"
    exp_dir = File.join(root, 'exp_only', 'F01', 'expected')
    work = File.join(scenario, 'work')
    Dir.glob(File.join(exp_dir, '*')).each do |ef|
      rel = ef.sub("#{exp_dir}/", '')
      af = File.join(work, rel)
      assert File.file?(af), "work/#{rel} missing after live session"
      assert_equal File.read(ef), File.read(af), "work/#{rel} differs from expected"
    end
  ensure
    FileUtils.rm_rf root if root && File.directory?(root) && !ENV['FITAGENT_LIVE_KEEP']
  end
end
