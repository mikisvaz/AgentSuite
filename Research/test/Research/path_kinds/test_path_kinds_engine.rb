require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/workflow.rb')

require 'fileutils'

# Engine-level contract of the three record kinds: registration shape on
# whole-workflow incorporation, the shared `register` tool, the edit
# override and the validate hook through the REAL engine dispatch
# (LLM::Agent#path_dispatch), which is what scout-ai invokes for the
# installed tools.
class TestRecordsKinds < Test::Unit::TestCase
  def setup
    @tmpdir = File.join(Scout.tmp.test_records_kinds.find.to_s, "kinds-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @base = File.join(@tmpdir, 'checkout')
    FileUtils.mkdir_p(@base)
    @roots = Research::PathKinds.kind_roots(@base)
    @definitions = Research::PathKinds.definitions(base_dir: @base)
    @agent = LLM.agent
    @definitions.each { |kind, definition| @agent.register_path_kind(kind, definition) }
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  def dispatch(kind:, operation:, **args)
    stringified = {}
    args.each { |key, value| stringified[key.to_s] = value }
    @agent.path_dispatch(kind: kind, operation: operation, **stringified)
  end

  def test_definitions_shape_for_engine_consumption
    %w[observation claim hypothesis].each do |kind|
      definition = @definitions[kind]
      assert_equal ['project'], definition['locations']
      assert_equal 'project', definition['default_location']
      assert_equal @roots[kind], definition['roots']['project']
      assert definition['roots']['project'].start_with?('/'), 'root must be absolute'

      capabilities = definition['capabilities']
      %w[read edit list validate].each { |op| assert capabilities[op], "#{kind} #{op} should be on" }
      %w[write move rename delete promote smoke patch].each do |op|
        assert !capabilities[op], "#{kind} #{op} should be off"
      end
    end
  end

  def test_whole_workflow_path_kinds_constant_registers_all_three_kinds
    assert Research::PATH_KINDS.is_a?(Hash)
    assert_equal %w[claim hypothesis observation], Research::PATH_KINDS.keys.sort

    agent = LLM.agent
    definitions = Research::PATH_KINDS
    definitions.each { |kind, definition| agent.register_path_kind(kind, definition) }

    assert_equal %w[claim hypothesis observation], agent.path_kind_registry.keys.sort
  end

  def test_shared_register_installs_one_tool_with_one_parameter_contract
    tools = @agent.other_options[:tools]
    assert tools.key?('register'), 'the shared custom operation must install ONE tool'
    assert_equal 1, tools.keys.count { |name| name == 'register' }

    expected_required = Research::PathKinds::REGISTER_PARAMETERS['required']
    schema = tools['register'].last['function']['parameters']
    assert_equal (%w[kind path] + expected_required).sort, schema['required'].sort
    assert_includes schema['properties'].keys, 'statement'
    assert_includes schema['properties'].keys, 'sources'
    assert_includes schema['properties'].keys, 'links'
  end

  def test_register_through_engine_dispatch_allocates_ids
    FileUtils.touch(File.join(@base, 'results', 'example.tsv')) rescue nil
    args_for = lambda do |kind|
      base = { 'statement' => "#{kind} statement" }
      base['sources'] = [{ 'type' => 'file', 'ref' => 'workflow.rb',
                           'digest' => 'workflow.rb sha256' }] if kind == 'observation'
      base
    end
    results = %w[observation claim hypothesis].map do |kind|
      dispatch(kind: kind, operation: 'register', path: '.',
               'statement' => args_for.call(kind)['statement'],
               'sources' => args_for.call(kind)['sources'])
    end

    assert_equal ['OBS-001', 'C-001', 'H-001'], results.map { |r| r['id'] }
    assert_equal 'current', results[0]['status']
    assert_equal 'proposed', results[1]['status']
    assert_equal 'proposed', results[2]['status']
    results.each do |result|
      assert File.file?(result['file'])
      # claims/hypotheses carry expected non-blocking WARNINGS here (no
      # counterevidence links, no predictions); the observation with a
      # digested source is clean. Warnings never block registration.
      assert result['warnings'].all? { |w| String === w }
    end
  end

  def test_edit_through_engine_dispatch_applies_versioned_change
    result = dispatch(kind: 'claim', operation: 'register', path: '.',
                      'statement' => 'original claim')
    id = result['id']

    text = dispatch(kind: 'claim', operation: 'read', path: id)['content']
    candidate = Research::PathKinds.parse_record(text)
    assert_equal 1, candidate['version']
    candidate['title'] = 'titled'
    candidate['status'] = 'supported'

    edited = dispatch(kind: 'claim', operation: 'edit', path: id,
                      'selector' => { 'type' => 'chars', 'start' => 0,
                                      'end' => text.length },
                      'replacement' => Research::PathKinds.serialize('claim', candidate))

    assert edited['changed']
    assert_equal 2, edited['version']

    after = Research::PathKinds.parse_record(
      dispatch(kind: 'claim', operation: 'read', path: id)['content']
    )
    assert_equal 2, after['version']
    assert_equal 'supported', after['status']
    assert_equal 'titled', after['title']
  end

  def test_edit_with_stale_version_through_engine_fails_cleanly
    result = dispatch(kind: 'claim', operation: 'register', path: '.',
                      'statement' => 'original claim')
    id = result['id']

    text = dispatch(kind: 'claim', operation: 'read', path: id)['content']
    candidate = Research::PathKinds.parse_record(text)
    candidate['title'] = 'stale-test title'

    edited = dispatch(kind: 'claim', operation: 'edit', path: id,
                      'selector' => { 'type' => 'chars', 'start' => 0,
                                      'end' => text.length },
                      'replacement' => Research::PathKinds.serialize('claim', candidate))
    assert_equal 2, edited['version']

    # STALE body: the ORIGINAL text still declares version 1 while the
    # record has advanced to version 2; the edit must fail cleanly and
    # leave the record untouched.
    assert_raise(ParameterException, 'stale version must fail cleanly') do
      dispatch(kind: 'claim', operation: 'edit', path: id,
               'selector' => { 'type' => 'chars', 'start' => 0,
                               'end' => text.length },
               'replacement' => text)
    end

    after = Research::PathKinds.parse_record(
      dispatch(kind: 'claim', operation: 'read', path: id)['content']
    )
    assert_equal 2, after['version'], 'stale edit must not advance the version'
  end

  def test_disabled_capabilities_reject_cleanly
    %w[write move rename delete].each do |operation|
      assert_raise(ParameterException, "#{operation} should be disabled") do
        dispatch(kind: 'observation', operation: operation, path: 'OBS-001',
                 'content' => 'x', 'destination' => 'd', 'name' => 'n')
      end
    end
  end

  def test_validate_hook_reports_through_engine_dispatch
    result = dispatch(kind: 'hypothesis', operation: 'register', path: '.',
                      'statement' => 'h', 'predictions' => ['p'])
    id = result['id']

    verdict = dispatch(kind: 'hypothesis', operation: 'validate', path: id)
    assert verdict['ok']
    assert_equal [], verdict['warnings']
  end

  def test_list_hook_reports_through_engine_dispatch
    dispatch(kind: 'claim', operation: 'register', path: '.', 'statement' => 'a')
    dispatch(kind: 'claim', operation: 'register', path: '.', 'statement' => 'b')

    listing = dispatch(kind: 'claim', operation: 'list', path: '.')
    assert_equal 2, listing['count']
    assert_equal %w[C-001 C-002], listing['records'].map { |r| r['id'] }
  end
end
