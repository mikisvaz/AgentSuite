# FitAgent v1 unit test: the `fit` task — live loop entry point.
# Deterministic here: the default stub proposer/agent (no model, no network).
require 'test/unit'
require 'fileutils'
require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
Workflow.require_workflow File.expand_path('../../../../workflow.rb', __FILE__)
require 'FitAgent/runner'
require 'FitAgent/evolve'
require 'FitAgent/agent_chat'
require 'FitAgent/proposer'

class TestFitTask < Test::Unit::TestCase
  def setup
    @root = File.join(Dir.pwd, 'tmp', "fit_task_#{$$}")
    FileUtils.rm_rf @root
    FileUtils.mkdir_p @root
    @set = File.join(@root, 'scenarios')
    FitAgent::Scenarios.materialize(@set, ids: %w[F01 F02])
    @arms = File.join(@root, 'arms')
  end

  def teardown
    FileUtils.rm_rf @root if @root
    # the `fit` task stages candidate overrides + results under PWD by default
    FileUtils.rm_rf File.join(Dir.pwd, 'sandbox') rescue nil
    FileUtils.rm_rf File.join(Dir.pwd, 'results') rescue nil
    FileUtils.rm_rf File.join(Dir.pwd, 'var/jobs/FitAgent/fit') rescue nil
  end

  def test_fit_task_runs_two_generations_and_writes_winner
    job = FitAgent.job(:fit,
                       experiment: 'e2e',
                       scenarios_dir: @set,
                       arms_dir: @arms,
                       agent: 'FitMain',
                       generations: 2,
                       proposer: 'stub')
    job.recursive_clean if job.done?
    out = JSON.parse(Open.read(job.produce.path))

    results = File.join(Dir.pwd, 'results', 'e2e')
    assert File.file?(File.join(results, 'evolution.json')), 'evolution.json must exist'
    evo = JSON.parse(Open.read(File.join(results, 'evolution.json')))
    assert evo['history'].any?, 'history must not be empty'
    assert_equal 1, evo['history'].first['generation']
    assert File.file?(File.join(results, 'winner.json')), 'winner.json must exist'
    winner = JSON.parse(Open.read(File.join(results, 'winner.json')))
    assert winner['stop_reason'], 'winner must record the stop reason'
    assert winner['digest'], 'winner must record the candidate digest'
    assert out['generations'] >= 1, 'task result must report generation count'
  end

  def test_fit_task_raises_for_zero_generations
    # clean error, not a silent no-op, when the loop cannot run
    job = FitAgent.job(:fit,
                       experiment: 'dead',
                       scenarios_dir: @set,
                       arms_dir: @arms,
                       agent: 'FitMain',
                       generations: 0)
    job.recursive_clean if job.done?
    assert_raise(ScoutException, ArgumentError) { job.produce }
  end
end
