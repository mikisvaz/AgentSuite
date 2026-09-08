# End-to-end gated live smoke: catalogue -> mini scenario set -> arms
# staged via the override task -> run_arms with FitAgent::LiveAgentChat (a
# REAL model session through the configured default endpoint; never named)
# -> deterministic scoring.
#
# The legacy scripted single-turn path (LiveAgentTurn, one ComputerUse
# patch job, no model) was deleted in the Unit A execution-layer
# unification; both smoke scenarios below now run the same adapter.
#
# Asserts the frozen rubric expectations from
# var/cortex/artifacts/verifications/patch-probe-matrix-v1.md:
#   F01 PASS, E01 FAIL (patch refuses stale context), E06 PASS.
require File.expand_path('../../test_helper', __dir__)
require 'tmpdir'
require 'FitAgent/agent_chat'

class TestE2ELiveSmoke < Test::Unit::TestCase
  LIVE = -> { ENV['FITAGENT_LIVE_MODEL'].to_s == '1' }

  # The shipped example target (repo-level default; selecting it here keeps
  # this smoke example-specific, which is allowed outside lib/).
  TARGET = FitAgent::Scenarios.loaded_target ||
           FitAgent::TargetSpec.load(File.expand_path('../../../../examples/computeruse-patch/target.yaml', __dir__))

  def setup
    @tmp = Path.setup(File.join(Dir.mktmpdir('fitagent-e2e')))
    @scenarios_dir = File.join(@tmp, 'set')
    FitAgent::Scenarios.materialize(@scenarios_dir, ids: %w[F01 E01 E06])
  end

  # The live session is a real model turn: endpoint resolution, tool loop
  # and transcript are only exercised with FITAGENT_LIVE_MODEL=1. Without
  # the gate the child cannot reach a model and every arm would score as a
  # dead session, which is not what this smoke asserts.
  def test_baseline_arm_scores_match_frozen_expectations
    omit('live-model smoke; set FITAGENT_LIVE_MODEL=1') unless LIVE.call

    out_dir = File.join(@tmp, 'results')

    chat = FitAgent::LiveAgentChat.new(target: TARGET, agent_dir: nil, timeout: 600)
    res = FitAgent::Runner.run_arm('e2e', @scenarios_dir, FitAgent::Runner::BASELINE,
                                   File.join(@tmp, 'arms'), 'FitMain', chat,
                                   out_dir: out_dir)
    results = res['results']
    assert results.key?('F01')
    assert results.key?('E01')
    assert results.key?('E06')

    assert File.file?(File.join(out_dir, 'e2e', FitAgent::Runner::BASELINE, 'scores.json'))
    refute File.directory?(File.join(out_dir, 'e2e', FitAgent::Runner::BASELINE, 'sandbox', 'Agent')),
           'baseline arm must stage NO Agent override'
    # the real session must have run real tool calls (not a failure chat)
    sandbox = File.join(out_dir, 'e2e', FitAgent::Runner::BASELINE, 'sandbox')
    calls = FitAgent::Scoring.tool_calls(File.join(sandbox, 'main.chat'))
    assert calls.any? { |c| c['tool'] == 'patch' },
           "expected at least one real patch call, saw #{calls.map { |c| c['tool'] }.inspect}"
    # well-formed score rows for every scenario
    results.each do |id, r|
      assert_equal id, r['scenario']
      assert %w[PASS FAIL].include?(r['verdict']), "#{id}: bad verdict #{r['verdict'].inspect}"
      assert [0.0, 1.0].include?(r['score']), "#{id}: bad score #{r['score'].inspect}"
    end
    # frozen expectation: the patch tool refuses the stale-context hunk
    assert_equal false, results['E01']['message']['expect']['applied']['got'],
                 'E01 patch must not be applied'
  end

  def test_candidate_arm_stages_override_and_runs
    omit('live-model smoke; set FITAGENT_LIVE_MODEL=1') unless LIVE.call

    arms = File.join(@tmp, 'arms')
    FitAgent::Runner.write_override(File.join(arms, 'cand1'), 'FitMain',
                                    'Try patch first; verify with read.',
                                    ['ComputerUse patch'])
    out_dir = File.join(@tmp, 'results')
    chat = FitAgent::LiveAgentChat.new(target: TARGET, agent_dir: File.join(arms, 'cand1'), timeout: 600)
    res = FitAgent::Runner.run_arm('e2e', @scenarios_dir, 'cand1', arms, 'FitMain', chat,
                                   out_dir: out_dir)
    sandbox = File.join(out_dir, 'e2e', 'cand1', 'sandbox')
    assert File.file?(File.join(sandbox, 'Agent', 'FitMain', 'start_chat')),
           'candidate override must be staged into the arm sandbox'
    assert res['results'].length == 3
    # chat transcript records the staged agent provenance
    chat_text = File.read(File.join(sandbox, 'main.chat'))
    assert chat_text.include?('meta: staged_agent='), 'chat must record staged agent'
  end

  # Deterministic regression (no model): the execution adapter's contract
  # independent of inference — script materialization from the single
  # SESSION_SCRIPT source, and the failure-chat fallback shape.
  def test_session_script_is_materialized_from_single_source
    path = FitAgent::LiveAgentChat.session_script
    assert File.file?(path), "child script not materialized at #{path}"
    assert_equal FitAgent::LiveAgentChat::SESSION_SCRIPT, File.read(path),
                 'materialized child script must match SESSION_SCRIPT byte-for-byte'
  end

  def test_failure_chat_fallback_when_child_dies
    # point the adapter at a work dir that cannot exist: the child fails
    # fast and the adapter must still emit a minimal parseable chat so
    # scoring reports the failure instead of raising.
    set = File.join(@tmp, 'broken-set')
    FitAgent::Scenarios.materialize(set, ids: %w[F01])
    FileUtils.rm_rf(File.join(set, 'F01', 'work'))
    arm_box = File.join(@tmp, 'arm_box')
    adapter = FitAgent::LiveAgentChat.new(target: TARGET, agent_dir: nil, timeout: 60)
    chat = adapter.call(File.join(set, 'F01'), arm_box)
    assert File.file?(chat)
    calls = FitAgent::Scoring.tool_calls(chat)
    assert_equal [], calls, 'failure chat must have zero tool calls'
    verdict = FitAgent::Scoring.score_scenario(File.join(set, 'F01', 'work'),
                                               YAML.load_file(File.join(set, 'F01', 'rubric.yaml')),
                                               chat)
    assert_equal 'FAIL', verdict['verdict']
    assert_equal 0, verdict['message']['count']
  end
end
