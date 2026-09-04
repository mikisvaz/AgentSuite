require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'tmpdir'
require 'fileutils'
require 'json'
require 'stringio'

Workflow.require_workflow File.expand_path('../../../../workflow.rb', __FILE__)

# Smoke tests for the deterministic FitAgent tasks `catalogue` and `score`
# (research/07 §2 steps 1-4, no inference anywhere in these paths).
class TestCatalogueScoreTasks < Test::Unit::TestCase
  def setup
    @run = Time.now.to_f.to_s.delete('.') + "-#{rand(1e6).to_i}"
    @base = Path.setup(File.join(Dir.tmpdir, "fitagent-tasks-#{@run}"))
    FileUtils.mkdir_p @base.find
  end

  def teardown
    FileUtils.rm_rf @base.find if File.directory?(@base.find)
  end

  def test_catalogue_job_produces_manifest_and_fixtures
    job = FitAgent.job(:catalogue, "smoke-#{@run}", scenario_set: @base['scenarios'].find)
    job.produce
    assert job.done?
    manifest = JSON.parse(Open.read(job.path))
    assert_equal 'patch-v1', manifest['version']
    assert manifest['set_digest']
    ids = manifest['scenarios'].map { |s| s['id'] }
    assert_equal %w[E01 E02 E03 E04 E05 E05b E06 F01 F02 F03 F04 F05 F06 F07 F08], ids.sort
    ids.each do |id|
      sc = @base['scenarios'][id]
      assert sc['rubric.yaml'].exists?, "no rubric for #{id}"
      assert sc['scenario.yaml'].exists?, "no scenario.yaml for #{id}"
      assert sc['patch.txt'].exists?, "no patch.txt for #{id}"
      assert sc['work'].directory?, "no work tree for #{id}"
      assert sc['expected'].directory?, "no expected tree for #{id}"
    end
    assert @base['scenarios']['manifest.json'].exists?
  end

  def test_catalogue_is_deterministic
    j1 = FitAgent.job(:catalogue, "det-#{@run}-1", scenario_set: @base['a'].find)
    j2 = FitAgent.job(:catalogue, "det-#{@run}-2", scenario_set: @base['b'].find)
    j1.produce; j2.produce
    d1 = JSON.parse(Open.read(j1.path))['set_digest']
    d2 = JSON.parse(Open.read(j2.path))['set_digest']
    assert_equal d1, d2
  end

  # Build a fake "run" sandbox: scenarios materialized, work trees already in
  # the expected after-state (as if the agent had applied every patch
  # perfectly), and a main.chat containing one successful patch call per
  # scenario (counts stay within the 1..2 rubric bound).
  def perfect_run_sandbox
    box = @base['sandbox']
    FileUtils.mkdir_p box.find
    FitAgent::Scenarios.materialize(@base['scenarios'].find)
    FileUtils.cp_r(@base['scenarios'].find, box['scenarios'].find)
    Dir.glob(File.join(box['scenarios'].find, '*')).select { |d| File.directory?(d) }.each do |sc|
      id = File.basename(sc)
      exp = File.join(sc, 'expected')
      work = File.join(sc, 'work')
      if id == 'E06'
        # E06 rubric expects the pristine file REMOVED (expected dir is empty)
        FileUtils.rm_rf(work)
        FileUtils.mkdir_p(work)
      else
        Dir.glob(File.join(exp, '**', '*')).select { |f| File.file?(f) }.each do |f|
          rel = f.sub(%r{^#{Regexp.escape(exp)}/}, '')
          dst = File.join(work, rel)
          FileUtils.mkdir_p(File.dirname(dst))
          FileUtils.cp(f, dst)
        end
      end
    end
    write_chat(box['main.chat'].find, 1)
    box
  end

  def write_chat(path, n_patch_calls)
    payload = { 'exit_status' => 0, 'applied' => true, 'used_strip' => 1,
                'stdout' => 'patching file', 'stderr' => '' }
    lines = ['user:', '', 'Apply the patches.', '']
    n_patch_calls.times do |i|
      id = "c#{i}"
      lines << "function_call: #{JSON.generate('name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => id)}"
      lines << ''
      lines << "function_call_output: #{JSON.generate('name' => 'patch', 'content' => JSON.generate(payload), 'id' => id)}"
      lines << ''
    end
    lines += ['assistant:', '', 'done', '']
    File.open(path, 'wb') { |f| f.write(lines.join("\n")) }
  end

  def test_score_job_green_on_perfect_run
    box = perfect_run_sandbox
    job = FitAgent.job(:score, "smoke-#{@run}", scenarios: @base['scenarios'].find,
                                                      sandbox: box.find)
    job.produce
    assert job.done?
    tsv = TSV_setup_from(job)
    # E05 (add-file) and E05b (add-overwrites) expect file CREATION; the fake
    # run creates them from expected/, so all functional rows should match.
    assert_equal [], tsv.keys - %w[E01 E02 E03 E04 E05 E05b E06 F01 F02 F03 F04 F05 F06 F07 F08]
    # E01/E02 rubrics expect a CONTROLLED FAILURE (applied=false / Ambiguous
    # output); the synthetic chat here is success-shaped, so only the
    # success-shaped scenarios must PASS.
    success_ids = %w[E03 E04 E05 E05b E06 F01 F02 F03 F04 F05 F06 F07 F08]
    fail_ids = %w[E01 E02]
    success_ids.each do |id|
      assert_equal ['PASS'], tsv[id].first(1), "scenario #{id}: #{tsv[id].inspect}"
    end
    fail_ids.each { |id| assert_equal ['FAIL'], tsv[id].first(1) }
    assert job.files.any? { |f| f.include?('scores.json') }
  end

  # TSV.parse (not TSV.open) — the latter would try to persist through the
  # job path and confuse job-cache lookups in tests.
  def TSV_setup_from(job)
    TSV.parse(StringIO.new(Open.read(job.path)), type: :list)
  end

  def test_score_job_fails_on_broken_run
    box = perfect_run_sandbox
    # vandalize one work tree: F01 back to pristine content (inside the
    # sandbox copy that `score` actually reads)
    sc = box['scenarios']['F01']
    FileUtils.mkdir_p File.dirname(sc['work']['notes.txt'].find)
    File.open(sc['work']['notes.txt'].find, 'wb') { |f| f.write "note-1\nnote-2\n" }
    job = FitAgent.job(:score, "broken-#{@run}", scenarios: @base['scenarios'].find,
                                                        sandbox: @base['sandbox'].find)
    job.produce
    tsv = TSV_setup_from(job)
    row = tsv['F01']
    assert_equal 'FAIL', row.first
    assert row[4].include?('functional:notes.txt:match')
  end
end
