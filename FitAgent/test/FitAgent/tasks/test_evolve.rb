require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'tmpdir'
require 'fileutils'
require 'json'
require 'stringio'

Workflow.require_workflow File.expand_path('../../../../workflow.rb', __FILE__)

# Tests for the deterministic evolution-loop core (research/07 §2 steps 4-7):
# stop rules, proposal validation with bounded repairs, and the generation
# loop with a stub proposer — no model anywhere.
class TestEvolve < Test::Unit::TestCase
  def setup
    @run = Time.now.to_f.to_s.delete('.') + "-#{rand(1e6).to_i}"
    @base = Path.setup(File.join(Dir.tmpdir, "fitagent-evolve-#{@run}"))
    FileUtils.mkdir_p @base.find
    FitAgent::Scenarios.materialize(@base['scenarios'].find, ids: %w[F01 F02])
    FitAgent::Runner.write_override(@base['arms']['baseline-arm'].find, 'FitMain',
                                    'seed instructions; unused arm to keep the arms dir non-baseline')
  end

  def teardown
    FileUtils.rm_rf @base.find if File.directory?(@base.find)
  end

  # ---- stop rules ------------------------------------------------------------

  # Unit B verdict-2: out_dir is required. The loop used to default to
  # Dir.pwd/results and silently write wherever the caller stood; passing no
  # out_dir (or a blank one) must now raise before any file is touched.
  def test_evolve_loop_requires_explicit_out_dir
    e = assert_raise(ArgumentError) do
      FitAgent::Evolve.evolve_loop('noout', @base['scenarios'].find, @base['arms'].find,
                                   'FitMain', FitAgent::Evolve::StubProposer.new)
    end
    assert_match(/out_dir is required/, e.message)

    e2 = assert_raise(ArgumentError) do
      FitAgent::Evolve.evolve_loop('blankout', @base['scenarios'].find, @base['arms'].find,
                                   'FitMain', FitAgent::Evolve::StubProposer.new,
                                   out_dir: '   ')
    end
    assert_match(/out_dir is required/, e2.message)

    # and nothing was written anywhere near the CWD
    refute File.exist?(File.join(Dir.pwd, 'results', 'noout'))
  end

  def test_stop_rules_table
    base = { 'generation' => 1, 'candidate' => 'candidates/1', 'digest' => 'd1',
             'score' => 0.5, 'pass_all' => false, 'verdicts' => {} }

    table = {
      # budget exhausted: last generation index == budget
      [[base.merge('generation' => 3)], { budget: 3 }] => 'budget_exhausted',
      [[base.merge('generation' => 2)], { budget: 3 }] => nil,
      # all pass
      [[base.merge('pass_all' => true)], {}] => 'all_pass',
      [[base.merge('pass_all' => false)], {}] => nil,
      # two consecutive no-op proposals (same digest)
      [[base, base.merge('generation' => 2, 'digest' => 'd1')], {}] => 'no_op_twice',
      [[base, base.merge('generation' => 2, 'digest' => 'd2')], {}] => nil,
      # regression vs best previous score
      [[base.merge('score' => 0.9),
        base.merge('generation' => 2, 'digest' => 'd2', 'score' => 0.4)], {}] => 'regression',
      [[base.merge('score' => 0.4),
        base.merge('generation' => 2, 'digest' => 'd2', 'score' => 0.9)], {}] => nil,
      # min_improve tolerance: a tiny drop below best is not a regression
      [[base.merge('score' => 0.9),
        base.merge('generation' => 2, 'digest' => 'd2', 'score' => 0.85)], { min_improve: 0.1 }] => nil,
      # empty history keeps going
      [[], {}] => nil
    }

    table.each do |(history, opts), expected|
      got = FitAgent::Evolve.stop?(history, **opts)
      assert_equal expected, got, "history=#{history.inspect} opts=#{opts.inspect}"
    end
  end

  # ---- proposal validation ---------------------------------------------------

  def test_validator_accepts_good_proposals
    good = [
      { 'instructions' => 'Be careful.', 'tools' => ['ComputerUse patch'] },
      { 'instructions' => 'No tools.', 'tools' => [] },
      { 'instructions' => 'Nested and scoped.',
        'tools' => ['ComputerUse patch dry_run=true', 'Baking', 'ScoutCoder help_workflow',
                    'Boolean trap_spaces cft=default', 'MiniTools sum noinputs'] }
    ]
    good.each { |p| assert_equal [], FitAgent::Evolve.validate_proposal(p), p.inspect }
  end

  def test_validator_rejects_bad_proposals
    bad = {
      'missing instructions' => { 'tools' => [] },
      'empty instructions' => { 'instructions' => '   ', 'tools' => [] },
      'tools not array' => { 'instructions' => 'x', 'tools' => 'ComputerUse' },
      'tool spec lowercase workflow' => { 'instructions' => 'x', 'tools' => ['computerUse patch'] },
      'tool spec stray token' => { 'instructions' => 'x', 'tools' => ['ComputerUse patch "quoted"'] },
      'endpoint smuggled' => { 'instructions' => 'x', 'tools' => [], 'endpoint' => 'qwen' }
    }
    bad.each do |label, p|
      errs = FitAgent::Evolve.validate_proposal(p)
      assert !errs.empty?, "#{label}: expected errors, got none"
    end
  end

  def test_validate_with_repairs_repairs_then_gives_up
    # first two proposals are broken, third is fine
    scripted = FitAgent::Evolve::ScriptedProposer.new([
      { 'tools' => [] },                                     # no instructions
      { 'instructions' => 'x', 'tools' => ['bad spec !!'] }, # bad tool grammar
      { 'instructions' => 'fixed', 'tools' => ['ComputerUse patch'] }
    ])
    proposal, attempts = FitAgent::Evolve.validate_with_repairs(scripted.call('e', 'p'), scripted)
    assert_equal 'fixed', proposal['instructions'], attempts.inspect
    assert_equal 3, attempts.length, attempts.inspect
    assert attempts[0]['errors'].any?
    assert attempts[2]['errors'].empty?

    # never repaired: nil + full attempt log
    hopeless = FitAgent::Evolve::ScriptedProposer.new([{ 'tools' => [] }])
    proposal2, attempts2 = FitAgent::Evolve.validate_with_repairs(hopeless.call('e', 'p'), hopeless)
    assert_nil proposal2
    assert_equal 3, attempts2.length, attempts2.inspect
  end

  # ---- prompt ----------------------------------------------------------------

  def test_propose_prompt_carries_rubric_and_scores
    prompt = FitAgent::Evolve.propose_prompt('exp', [
      { 'arm' => 'candidates/1', 'scenario' => 'F01', 'verdict' => 'PASS', 'score' => 1.0, 'failures' => [] },
      { 'arm' => 'candidates/1', 'scenario' => 'F02', 'verdict' => 'FAIL', 'score' => 0.0,
        'failures' => ['functional:notes.txt:match:mismatch'] }
    ], "F01: small one-line\nF02: another")
    assert prompt.include?('experiment exp'), prompt
    assert prompt.include?('F01: small one-line'), prompt
    assert prompt.include?('candidates/1 F01: PASS score=1.0'), prompt
    assert prompt.include?('Failing scenarios to fix'), prompt
    assert prompt.include?('F02 (functional:notes.txt:match:mismatch)'), prompt
    # all-pass shape has no failing section
    allpass = FitAgent::Evolve.propose_prompt('exp', [
      { 'arm' => 'a', 'scenario' => 'F01', 'verdict' => 'PASS', 'score' => 1.0, 'failures' => [] }
    ], 'r')
    assert allpass.include?('All scenarios PASS'), allpass
  end

  # The live run results/patch-mini-1 died at generation 1 because the model
  # emitted tool descriptions instead of spec lines; the prompt must now pin
  # the exact grammar with valid examples and the empty-array escape hatch.
  def test_propose_prompt_contains_tools_grammar_and_examples
    prompt = FitAgent::Evolve.propose_prompt('exp', [], 'r')
    grammar = 'Workflow [task [input|name=value|noinputs ...]]'
    assert prompt.include?(grammar), "prompt must quote the exact grammar:\n#{prompt}"
    assert prompt.include?('ComputerUse patch'), prompt
    assert prompt.include?('ScoutCoder help_workflow'), prompt
    assert prompt.include?('Baking cake name=chocolate'), prompt
    assert prompt.include?('MiniTools sum noinputs'), prompt
    # spec lines, not descriptions
    assert prompt.include?('never a description'), prompt
    # empty tools is valid and means keep defaults
    assert prompt.include?('tools: [] is valid and means: keep the default tooling.'), prompt
    # every example the prompt teaches must itself satisfy the validator
    %w[ComputerUse\ patch ScoutCoder\ help_workflow Baking\ cake\ name=chocolate
       MiniTools\ sum\ noinputs].each do |spec|
      assert_equal [], FitAgent::Evolve.tool_spec_errors(spec, 0),
                   "prompt example #{spec.inspect} must validate"
    end
    # grammar block is present in both the first-generation and the
    # failing-scenarios shapes (deterministic string building)
    failing = FitAgent::Evolve.propose_prompt('exp', [
      { 'arm' => 'a', 'scenario' => 'F01', 'verdict' => 'FAIL', 'score' => 0.0, 'failures' => ['x'] }
    ], 'r')
    assert failing.include?(grammar), failing
  end

  # ---- loop ------------------------------------------------------------------

  def test_loop_runs_generations_and_records_evolution_json
    # scripted: gen1 fails, gen2 passes everything => stop on all_pass
    failer = Object.new
    def failer.call(_arm) FitAgent::Runner::StubAgent.new(apply_expected: false,
                                                          force_payload: { 'exit_status' => 0, 'applied' => true,
                                                                           'used_strip' => 1, 'stdout' => '', 'stderr' => '' }); end
    passer = Object.new
    def passer.call(_arm) FitAgent::Runner::StubAgent.new(apply_expected: true); end

    proposer = FitAgent::Evolve::ScriptedProposer.new([
      { 'instructions' => 'gen1 instructions', 'tools' => ['ComputerUse patch'] },
      { 'instructions' => 'gen2 instructions', 'tools' => ['ComputerUse patch'] }
    ])

    history = FitAgent::Evolve.evolve_loop('evo', @base['scenarios'].find, @base['arms'].find,
                                           'FitMain', proposer,
                                           agent_factory: ->(arm) { arm == 'candidates/1' ? failer.call(arm) : passer.call(arm) },
                                           budget: 3, out_dir: @base['results'].find)
    assert_equal 2, history.length, history.inspect
    assert_equal 'candidates/1', history.first['candidate']
    assert_equal false, history.first['pass_all']
    assert_equal true, history.last['pass_all']
    assert_match(/gen[12] instructions/, history.first['instructions'])

    evo = JSON.parse(Open.read(@base['results']['evo']['evolution.json'].find))
    assert_equal 'evo', evo['experiment']
    assert_equal 2, evo['history'].length
    assert_equal 'all_pass', evo['stopped']
    # every generation ran baseline + best-so-far + new candidate
    assert_equal ['baseline', 'candidates/1'], history.first['arms_run']
    assert_equal ['baseline', 'candidates/1', 'candidates/2'], history.last['arms_run']
    assert_equal 1.0, history.last['comparison']['candidates/2']['score']
    assert_equal false, history.first['comparison']['candidates/1']['pass_all']
    # candidates staged under candidates/<gen>
    assert File.file?(@base['arms']['candidates']['1']['Agent']['FitMain']['start_chat'].find)
    assert File.file?(@base['arms']['candidates']['2']['Agent']['FitMain']['start_chat'].find)
    # per-gen run dirs exist with scores
    assert File.file?(File.join(history.first['dir'], 'scores.tsv'))
  end

  def test_loop_stops_on_no_op_twice_with_stub_proposer
    # StubProposer always returns the same proposal => identical digests; the
    # agent never reaches all-pass so only the no-op rule can stop the loop.
    failer = ->(_arm) { FitAgent::Runner::StubAgent.new(apply_expected: false,
                                                        force_payload: { 'exit_status' => 0, 'applied' => true,
                                                                         'used_strip' => 1, 'stdout' => '', 'stderr' => '' }) }
    history = FitAgent::Evolve.evolve_loop('noop', @base['scenarios'].find, @base['arms'].find,
                                           'FitMain', FitAgent::Evolve::StubProposer.new,
                                           agent_factory: failer,
                                           budget: 3, out_dir: @base['results'].find)
    assert_equal 2, history.length, history.inspect
    evo = JSON.parse(Open.read(@base['results']['noop']['evolution.json'].find))
    assert_equal 'no_op_twice', evo['stopped']
    assert_equal history[0]['digest'], history[1]['digest']
  end

  def test_loop_budget_exhausted_when_score_never_moves
    # every generation fails the same way but with different instructions =>
    # different digests, no all-pass, no regression (all scores equal)
    proposals = (1..3).map do |i|
      { 'instructions' => "instructions v#{i}", 'tools' => ['ComputerUse patch'] }
    end
    proposer = FitAgent::Evolve::ScriptedProposer.new(proposals)
    failer = ->(_arm) { FitAgent::Runner::StubAgent.new(apply_expected: false,
                                                        force_payload: { 'exit_status' => 0, 'applied' => true,
                                                                         'used_strip' => 1, 'stdout' => '', 'stderr' => '' }) }
    history = FitAgent::Evolve.evolve_loop('budget', @base['scenarios'].find, @base['arms'].find,
                                           'FitMain', proposer, agent_factory: failer,
                                           budget: 3, out_dir: @base['results'].find)
    assert_equal 3, history.length, history.inspect
    evo = JSON.parse(Open.read(@base['results']['budget']['evolution.json'].find))
    assert_equal 'budget_exhausted', evo['stopped']
  end

  def test_loop_dead_proposal_is_recorded_not_raised
    proposer = FitAgent::Evolve::ScriptedProposer.new([{ 'tools' => [] }]) # never valid
    history = FitAgent::Evolve.evolve_loop('dead', @base['scenarios'].find, @base['arms'].find,
                                           'FitMain', proposer,
                                           out_dir: @base['results'].find)
    assert_equal 1, history.length
    assert history.first['dead']
    evo = JSON.parse(Open.read(@base['results']['dead']['evolution.json'].find))
    assert history.first['attempts'].length == 3
    assert evo['stopped'].nil? || evo['stopped']
  end
end
