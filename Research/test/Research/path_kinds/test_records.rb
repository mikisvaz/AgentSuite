require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/lib/Research/path_kinds/records.rb')

require 'fileutils'
require 'tmpdir'
require 'scout'

class TestRecordsSpec < Test::Unit::TestCase
  def setup
    @tmpdir = File.join(Scout.tmp.test_records_spec.find.to_s, "rec-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @roots = Research::PathKinds.kind_roots(@tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  def stub_agent
    # The :full edit override asks the engine for path_apply_selector; a
    # minimal fake answers with a whole-body transform: the replacement IS
    # the edited record, which is exactly the semantics the step-3 edit
    # override expects (a whole-record rewrite).
    Struct.new(:name).new('test-agent').tap do |agent|
      agent.define_singleton_method(:path_apply_selector) do |_content, _selector, replacement|
        replacement.to_s
      end
    end
  end

  def register(kind, args)
    Research::PathKinds.register_record(kind, @roots, args)
  end

  def test_register_allocates_sequential_unique_ids_and_stores_records
    first = register('observation', base_observation_args)
    second = register('observation', base_observation_args)

    assert_equal 'OBS-001', first['id']
    assert_equal 'OBS-002', second['id']
    assert File.file?(first['file'])
    assert_equal ['OBS-001', 'OBS-002'], Dir.glob(File.join(@roots['observation'], '*.yaml')).map { |f| File.basename(f, '.yaml') }.sort

    record = Research::PathKinds.parse_record(File.read(first['file']))
    assert_equal 1, record['version']
    assert_equal 'current', record['status']
    assert_equal 'log2 fold-change of gene X in condition A vs control', record['statement']
    assert first['warnings'].is_a?(Array)

    sidecar = Research::PathKinds.load_sidecar(@roots['observation'], 'OBS-001')
    assert_equal 1, sidecar['version']
    assert sidecar.key?('created_at')
    assert sidecar.key?('updated_at')
  end

  def test_register_validates_and_rejects_bad_input_without_allocating
    assert_raise(ParameterException) { register('claim', {}) }
    assert_raise(ParameterException) { register('claim', 'statement' => 's', 'value' => {}) }
    assert_raise(ParameterException) { register('observation', 'statement' => 'no sources') }
    assert_raise(ParameterException) { register('claim', 'statement' => 's', 'status' => 'supported', 'version' => 5) }
    assert_raise(ParameterException) { register('claim', 'statement' => 's', 'links' => [{'type' => 'explains', 'target' => 'OBS-001'}]) }
    assert_raise(ParameterException) { register('claim', 'statement' => 's', 'links' => [{'type' => 'supersedes', 'target' => 'OBS-999'}]) }
    assert_raise(ParameterException) { register('claim', 'statement' => 's', 'sources' => [{'type' => 'file', 'ref' => 'no/such/file.tsv'}]) }

    assert_equal [], Dir.glob(File.join(@roots['claim'], '*.yaml'))
    assert_equal [], Dir.glob(File.join(@roots['observation'], '*.yaml'))
    assert !File.file?(File.join(@roots['claim'], 'counter'))
  end

  def test_register_validates_valid_input_and_reports_warnings
    file = File.join(@tmpdir, 'gene_x.tsv')
    FileUtils.touch(file)

    result = register('hypothesis',
                      'statement' => 'condition A acts through pathway P',
                      'predictions' => ['knockout of P abolishes the effect'])

    assert_equal 'H-001', result['id']
    assert_equal [], result['warnings']

    record = Research::PathKinds.parse_record(File.read(result['file']))
    assert_equal 'proposed', record['status']
    assert_equal ['knockout of P abolishes the effect'], record['predictions']
  end

  def test_edit_with_correct_version_applies_changes_and_snapshots_history
    obs = register('observation', base_observation_args)
    file = obs['file']

    agent = stub_agent
    new_statement = 'revised statement with a second confirmatory source'
    candidate = Research::PathKinds.parse_record(File.read(file))
    candidate['statement'] = new_statement
    candidate_text = Research::PathKinds.serialize('observation', candidate)

    result = Research::PathKinds.edit_record(
      'observation', @roots, file,
      { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
        'replacement' => candidate_text },
      agent
    )

    assert result['changed']
    assert_equal 1, result['previous_version']
    assert_equal 2, result['version']

    record = Research::PathKinds.parse_record(File.read(file))
    assert_equal 2, record['version']
    assert_equal new_statement, record['statement']

    snapshot = File.join(@roots['observation'], 'history', 'OBS-001.v1.yaml')
    assert File.file?(snapshot)
    old = Research::PathKinds.parse_record(File.read(snapshot))
    assert_equal 1, old['version']
    assert_equal 'current', old['status']

    sidecar = Research::PathKinds.load_sidecar(@roots['observation'], 'OBS-001')
    assert_equal 2, sidecar['version']
  end

  def test_edit_with_stale_version_fails_cleanly_and_changes_nothing
    obs = register('observation', base_observation_args)
    file = obs['file']

    # First edit lands version 2.
    agent = stub_agent
    candidate = Research::PathKinds.parse_record(File.read(file))
    candidate['title'] = 'second title'
    Research::PathKinds.edit_record(
      'observation', @roots, file,
      { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
        'replacement' => Research::PathKinds.serialize('observation', candidate) },
      agent
    )

    # Stale edit: still declares version 1.
    stale = candidate
    stale_text = Research::PathKinds.serialize('observation', stale)
    error = assert_raise(ParameterException) do
      Research::PathKinds.edit_record(
        'observation', @roots, file,
        { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
          'replacement' => stale_text },
        agent
      )
    end
    assert_match(/stale edit of OBS-001/, error.message)

    record = Research::PathKinds.parse_record(File.read(file))
    assert_equal 2, record['version']
    assert_equal 'second title', record['title']
    assert_equal 1, Dir.glob(File.join(@roots['observation'], 'history', '*.yaml')).length
  end

  def test_edit_enforces_status_transition_rules
    obs = register('observation', base_observation_args)
    file = obs['file']
    agent = stub_agent

    candidate = Research::PathKinds.parse_record(File.read(file))
    candidate['status'] = 'current'  # same status: allowed
    assert_nothing_raised do
      Research::PathKinds.edit_record(
        'observation', @roots, file,
        { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
          'replacement' => Research::PathKinds.serialize('observation', candidate) },
        agent
      )
    end

    candidate = Research::PathKinds.parse_record(File.read(file))
    candidate['status'] = 'superseded'  # current -> superseded: allowed
    assert_nothing_raised do
      Research::PathKinds.edit_record(
        'observation', @roots, file,
        { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
          'replacement' => Research::PathKinds.serialize('observation', candidate) },
        agent
      )
    end

    candidate = Research::PathKinds.parse_record(File.read(file))
    candidate['status'] = 'current'  # superseded -> current: not allowed
    error = assert_raise(ParameterException) do
      Research::PathKinds.edit_record(
        'observation', @roots, file,
        { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
          'replacement' => Research::PathKinds.serialize('observation', candidate) },
        agent
      )
    end
    assert_match(/invalid status transition/, error.message)
  end

  def test_validate_path_reports_errors_and_warnings_without_rejecting
    obs = register('observation', base_observation_args)

    result = Research::PathKinds.validate_path('observation', @roots, obs['id'])
    assert result['ok']
    assert result['warnings'].is_a?(Array)
    assert result['links'].is_a?(Array)
    assert result['backlinks'].is_a?(Array)

    claim = register('claim', 'statement' => 'gene X is upregulated',
                                   'links' => [{ 'type' => 'supported_by', 'target' => obs['id'] }])
    result = Research::PathKinds.validate_path('claim', @roots, claim['id'])
    assert result['ok']
    assert result['warnings'].any? { |w| w.include?('counterevidence') }

    obs_result = Research::PathKinds.validate_path('observation', @roots, obs['id'])
    assert obs_result['backlinks'].any? { |bl| bl['source'] == claim['id'] }

    bad = Research::PathKinds.validate_path('observation', @roots, 'OBS-999')
    assert !bad['ok']
    assert bad['reasons'].is_a?(Array)
  end

  def test_validate_record_splits_errors_from_warnings
    spec_error_only = { 'version' => 1, 'status' => 'proposed',
                        'statement' => 'x', 'predictions' => [] }
    errors, warnings = Research::PathKinds.validate_record(
      'hypothesis', spec_error_only.merge('predictions' => 'not-a-list'), roots: @roots
    )
    assert errors.any? { |e| e.include?("field 'predictions'") }
    assert_equal [], warnings

    good = { 'version' => 1, 'status' => 'proposed',
             'statement' => 'x', 'predictions' => ['p'] }
    errors, warnings = Research::PathKinds.validate_record('hypothesis', good, roots: @roots)
    assert_equal [], errors
    assert_equal [], warnings
  end

  def test_relationships_table_matches_spec_sections_2_to_5
    assert_equal %w[observation claim], Research::PathKinds::RELATIONSHIPS['claim']['supported_by']
    assert_equal %w[claim], Research::PathKinds::RELATIONSHIPS['claim']['supersedes']
    assert_equal %w[observation claim], Research::PathKinds::RELATIONSHIPS['hypothesis']['motivated_by']
    assert_equal %w[observation claim hypothesis], Research::PathKinds::RELATIONSHIPS['hypothesis']['related_to']
    assert_equal %w[observation claim hypothesis], Research::PathKinds::RELATIONSHIPS['observation']['related_to']
  end

  def test_list_records_lists_only_matching_ids_in_order
    register('observation', base_observation_args)
    register('claim', 'statement' => 'one')
    register('claim', 'statement' => 'two')

    listed = Research::PathKinds.list_records('claim', @roots, '')
    assert_equal 2, listed['count']
    assert_equal %w[C-001 C-002], listed['records'].map { |r| r['id'] }
  end

  def base_observation_args
    { 'statement' => 'log2 fold-change of gene X in condition A vs control',
      'title' => 'Gene X differential expression',
      'scope' => { 'condition' => ['condition A', 'control'] },
      'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb',
                      'digest' => 'workflow.rb sha256' }] }
  end
end
