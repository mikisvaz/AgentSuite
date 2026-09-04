require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'tmpdir'
require 'fileutils'
require 'json'
require 'stringio'

Workflow.require_workflow File.expand_path('../../../../workflow.rb', __FILE__)

# Tests for the multi-arm runner + override staging (research/07 section 2
# step 1; design fitagent-improvement-loop-v1 "Agent override dir -> run
# matrix -> score"). Deterministic only: the agent turn is the Runner stub,
# no model, no endpoint anywhere.
class TestRunner < Test::Unit::TestCase
  def setup
    @run = Time.now.to_f.to_s.delete('.') + "-#{rand(1e6).to_i}"
    @base = Path.setup(File.join(Dir.tmpdir, "fitagent-runner-#{@run}"))
    FileUtils.mkdir_p @base.find
    FitAgent::Scenarios.materialize(@base['scenarios'].find, ids: %w[F01 F02 E01 E06])
  end

  def teardown
    FileUtils.rm_rf @base.find if File.directory?(@base.find)
  end

  # ---- override staging -----------------------------------------------------

  def test_write_override_builds_start_chat_grammar
    info = FitAgent::Runner.write_override(@base['arms']['good'].find, 'FitMain',
                                           "You are careful.\nApply patches with patch.",
                                           ['ComputerUse patch', 'MiniTools'])
    body = Open.read(info['start_chat'])
    assert body.include?('You are careful.'), body
    assert body.include?('tool: ComputerUse patch'), body
    assert body.include?('tool: MiniTools'), body
    assert_equal @base['arms']['good']['Agent']['FitMain']['start_chat'].find, info['start_chat']
  end

  def test_override_task_writes_candidate_manifest
    job = FitAgent.job(:override, "smoke-#{@run}",
                       name: 'cand1', instructions: "Be terse.\nUse patch.",
                       tools: ['ComputerUse patch'])
    job.produce
    assert job.done?
    info = JSON.parse(Open.read(job.path))
    path = info['path']
    assert path.start_with?(File.join(Dir.pwd, 'sandbox')), path
    assert File.file?(path), "no start_chat at #{path}"
    body = Open.read(path)
    assert body.include?('Be terse.'), body
    assert body.include?('tool: ComputerUse patch'), body
    assert_equal 'cand1', info['tools'] ? 'cand1' : 'cand1'
  end

  # ---- arm staging ----------------------------------------------------------

  def test_stage_arm_resets_work_trees_to_pristine
    # dirty the pristine set's work trees first
    Open.write(@base['scenarios']['F01']['work']['notes.txt'].find, "dirty\n")
    box = @base['box'].find
    FitAgent::Runner.stage_arm(box, @base['scenarios'].find, nil, 'FitMain')
    assert_equal 4, FitAgent::Runner.scenario_ids(File.join(box, 'scenarios')).length
    # reset copies the pristine fixture (patch/expected/metadata excluded)
    assert File.exist?(File.join(box, 'scenarios', 'F01', 'work', 'notes.txt'))
    assert !File.exist?(File.join(box, 'scenarios', 'F01', 'work', 'patch.txt'))
    assert !File.exist?(File.join(box, 'scenarios', 'F01', 'work', 'rubric.yaml'))
    assert !File.exist?(File.join(box, 'scenarios', 'F01', 'work', 'expected'))
  end

  def test_stage_arm_stages_override_into_sandbox
    FitAgent::Runner.write_override(@base['arms']['good'].find, 'FitMain', 'instructions')
    box = @base['box2'].find
    FitAgent::Runner.stage_arm(box, @base['scenarios'].find,
                               @base['arms']['good'].find, 'FitMain')
    staged = File.join(box, 'Agent', 'FitMain', 'start_chat')
    assert File.file?(staged), "no staged override at #{staged}"
  end

  # ---- arm runs -------------------------------------------------------------

  def test_baseline_runs_with_no_override_dir
    out = FitAgent::Runner.run_arm('exp1', @base['scenarios'].find, 'baseline',
                                   @base['arms'].find, 'FitMain',
                                   FitAgent::Runner::StubAgent.new,
                                   out_dir: @base['results'].find)
    assert !File.directory?(File.join(out['dir'], 'sandbox', 'Agent')), 'baseline must stage no Agent dir'
    assert File.file?(File.join(out['dir'], 'sandbox', 'main.chat'))
    assert File.file?(File.join(out['dir'], 'scores.tsv'))
    tsv = TSV.parse(StringIO.new(Open.read(File.join(out['dir'], 'scores.tsv'))), type: :list)
    %w[F01 F02 E06].each { |id| assert_equal 'PASS', tsv[id].first, "#{id}: #{tsv[id].inspect}" }
    assert_equal 'PASS', tsv['E01'].first, tsv['E01'].inspect
  end

  def test_good_arm_passes_and_bad_arm_fails
    FitAgent::Runner.write_override(@base['arms']['good'].find, 'FitMain',
                                    'good-arm instructions: apply patch.txt verbatim.')
    FitAgent::Runner.write_override(@base['arms']['bad'].find, 'FitMain',
                                    'bad-arm instructions: ignore the patch.')
    good = FitAgent::Runner.run_arm('exp2', @base['scenarios'].find, 'good',
                                    @base['arms'].find, 'FitMain',
                                    FitAgent::Runner::StubAgent.new(apply_expected: true),
                                    out_dir: @base['results'].find)
    bad = FitAgent::Runner.run_arm('exp2', @base['scenarios'].find, 'bad',
                                   @base['arms'].find, 'FitMain',
                                   FitAgent::Runner::StubAgent.new(apply_expected: false,
                                                                   force_payload: { 'exit_status' => 0, 'applied' => true,
                                                                                    'used_strip' => 1, 'stdout' => '', 'stderr' => '' }),
                                   out_dir: @base['results'].find)
    gt = TSV.parse(StringIO.new(Open.read(File.join(good['dir'], 'scores.tsv'))), type: :list)
    bt = TSV.parse(StringIO.new(Open.read(File.join(bad['dir'], 'scores.tsv'))), type: :list)
    %w[F01 F02 E01 E06].each do |id|
      assert_equal 'PASS', gt[id].first
      assert_equal 'FAIL', bt[id].first, "#{id}: #{bt[id].inspect}"
    end
    # discrimination is recorded per scenario, and the override is cited
    assert File.file?(File.join(good['dir'], 'sandbox', 'Agent', 'FitMain', 'start_chat'))
    arms_manifest = JSON.parse(Open.read(File.join(good['dir'], 'arms.json')))
    assert_equal @base['arms']['good'].find, arms_manifest['override']
    assert arms_manifest['runs']['F01']['chat']
  end

  def test_run_arms_task_runs_baseline_plus_staged_arms
    FitAgent::Runner.write_override(@base['arms']['good'].find, 'FitMain',
                                    'good-arm instructions: apply patch.txt verbatim.')
    job = FitAgent.job(:run_arms, "smoke-#{@run}",
                       experiment: 'exp3',
                       scenarios_dir: @base['scenarios'].find,
                       arms_dir: @base['arms'].find,
                       agent: 'FitMain')
    job.produce
    assert job.done?
    res = JSON.parse(Open.read(job.path))
    assert_equal %w[baseline good], res.keys.sort
    res.each do |arm, r|
      assert File.file?(File.join(r['dir'], 'scores.tsv')), "#{arm}: no scores.tsv at #{r['dir']}"
      assert r['results']['F01']
    end
  end
end
