require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'scout-ai'
require 'tmpdir'
require 'fileutils'

Workflow.require_workflow File.expand_path('../../../../workflow.rb', __FILE__)

class TestScenarios < Test::Unit::TestCase
  def setup
    @set = Path.setup(File.join(Dir.tmpdir, "fitagent-scenarios-test-#{Process.pid}"))
    FileUtils.mkdir_p @set.find
  end

  def teardown
    FileUtils.rm_rf @set.find if File.directory?(@set.find)
  end

  def test_materialize_all_scenarios
    manifest = FitAgent::Scenarios.materialize(@set)
    ids = manifest['scenarios'].map { |s| s['id'] }
    assert_equal %w[C01 C02 E01 E02 E03 E04 E05 E05b E06 F01 F02 F03 F04 F05 F06 F07 F08], ids
    assert manifest['set_digest'].is_a?(String) && manifest['set_digest'].length == 32
    assert File.file?(@set['manifest.json'].find)
    ids.each do |id|
      assert File.file?(@set[id]['rubric.yaml'].find), "#{id} rubric.yaml"
      assert File.file?(@set[id]['patch.txt'].find), "#{id} patch.txt"
      assert File.directory?(@set[id]['work'].find), "#{id} work/"
      assert File.directory?(@set[id]['expected'].find), "#{id} expected/"
      assert File.file?(@set[id]['scenario.yaml'].find), "#{id} scenario.yaml"
    end
  end

  def test_determinism_same_seed_same_digests
    a = FitAgent::Scenarios.materialize(@set)
    other = Path.setup(File.join(Dir.tmpdir, "fitagent-scenarios-other-#{Process.pid}"))
    begin
      b = FitAgent::Scenarios.materialize(other)
      assert_equal a['set_digest'], b['set_digest']
      assert_equal a['scenarios'].map { |s| s['digest'] }, b['scenarios'].map { |s| s['digest'] }
    ensure
      FileUtils.rm_rf other.find if File.directory?(other.find)
    end
  end

  def test_unknown_scenario_rejected
    assert_raise ArgumentError do
      FitAgent::Scenarios.materialize(@set, ids: ['NOPE'])
    end
  end

  def test_subset_selection
    FitAgent::Scenarios.materialize(@set, ids: ['F01', 'E02'])
    assert File.file?(@set['F01']['rubric.yaml'].find)
    assert File.file?(@set['E02']['rubric.yaml'].find)
    refute File.exist?(@set['F02'].find)
  end

  def test_fixture_content_f01
    FitAgent::Scenarios.materialize(@set, ids: ['F01'])
    notes = File.read(@set['F01']['notes.txt'].find)
    assert_equal (1..10).map { |n| "note-#{n}" }.join("\n") + "\n", notes
    assert_equal notes, File.read(@set['F01']['work']['notes.txt'].find)
    assert_match(/^note-seven$/, File.read(@set['F01']['expected']['notes.txt'].find))
    assert_match(/^-note-7$/, File.read(@set['F01']['patch.txt'].find))
    assert_match(/^\+note-seven$/, File.read(@set['F01']['patch.txt'].find))
  end

  def test_scenario_yaml_fields
    FitAgent::Scenarios.materialize(@set, ids: ['E06'])
    info = YAML.load_file(@set['E06']['scenario.yaml'].find)
    assert_equal 'E06', info['id']
    assert_equal 'error', info['class']
    assert_equal ['old_file.txt'], info['files']
  end

  def test_rubric_yaml_fields
    FitAgent::Scenarios.materialize(@set, ids: ['E02'])
    rubric = YAML.load_file(@set['E02']['rubric.yaml'].find)
    assert_equal 'E02', rubric['scenario']
    assert_equal 'patch', rubric['message_rules']['tool']
    assert_equal ['Ambiguous'], rubric['message_rules']['expect']['output_contains']
    assert_equal 'match', rubric['functional']['expect_files']['dup.txt']
  end

  def test_empty_files_scenario_has_no_stray_fixtures
    FitAgent::Scenarios.materialize(@set, ids: ['E05'])
    work = Dir.glob(File.join(@set['E05']['work'].find, '**', '*')).select { |f| File.file?(f) }
    assert_equal [], work
    assert File.file?(@set['E05']['expected']['created.txt'].find)
  end

  def test_scenario_ids_listing
    FitAgent::Scenarios.materialize(@set, ids: ['F01', 'E03'])
    assert_equal %w[E03 F01], FitAgent::Scenarios.scenario_ids(@set.find)
  end
end
