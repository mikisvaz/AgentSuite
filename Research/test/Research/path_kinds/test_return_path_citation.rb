require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/lib/Research/path_kinds/records.rb')

require 'fileutils'
require 'digest'

# Unit coverage for the return_path citation contract rules R6-R12, R14 as
# implemented in lib/Research/path_kinds/records.rb:
#
#   R6  tool_result is a first-class local source type
#   R7  ref grammar: existing file, absolute or Research-root-relative; a
#       directory is not a valid ref
#   R8  locator grammar: one string 'kind:value', kind in
#       {row, range, line, section}; malformed is a hard error
#   R10 durability: durable job tree / durable named store / ephemeral
#   R11 ephemeral -> promote-or-reject with the contract's verbatim
#       rejection message; promote copies bytes into
#       var/records-attachments/<destination>/ and the record cites the copy
#   R12 digest: absent = warning; recorded and mismatched at edit/validate
#       = hard error; recorded at registration without recomputation
#   R14 compatibility: existing types still validate; unknown types stay
#       warning-opaque
#
# Everything runs against a per-test temporary root; the real var/records is
# never touched.  Durable-job-tree fixtures are synthesized under the
# temporary root with the var/jobs/<Workflow>/<task>/<name>.json(+.info)
# shape the probes documented on disk.
class TestReturnPathCitation < Test::Unit::TestCase
  def setup
    @tmpdir = File.join(Scout.tmp.test_return_path_citation.find.to_s,
                        "m-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @roots = Research::PathKinds.kind_roots(@tmpdir)

    # A synthetic persisted job tree INSIDE the test root follows the
    # var/jobs/<Workflow>/<task>/<name>.json + <name>.info layout, so the
    # durability classifier exercises its real condition.
    @job_name = 'probe_job_a1b2c3d4'
    @job_dir = File.join(@tmpdir, 'var', 'jobs', 'Semantics',
                         'entity_property')
    FileUtils.mkdir_p(@job_dir)
    @job_result = File.join(@job_dir, "#{@job_name}.json")
    File.write(@job_result, %({"status":"done","result":"demo-x3"}))
    File.write("#{@job_result}.info", %({"done":true}))

    @wf_digest = nil
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
    # The named-store test touches the REAL durable store (promote_tool_result
    # is pinned to the checkout root by design); remove exactly its artifact.
    att = File.join(Research::PathKinds::RECORDS_ATTACHMENTS_DIR,
                    'citation', 'demo.json')
    FileUtils.rm_f(att)
    FileUtils.rm_rf(File.dirname(att)) if File.directory?(File.dirname(att)) &&
                                          Dir.empty?(File.dirname(att))
  end

  # ---- helpers -----------------------------------------------------------

  def register(kind, args)
    args = args.reject { |k, _| %w[version status].include?(k) }
    Research::PathKinds.register_record(kind, @roots, args)
  end

  def validate(record)
    Research::PathKinds.validate_record('observation', record,
                                        roots: @roots)
  end

  def observation_with(source)
    { 'version' => 1, 'status' => 'current', 'statement' => 'demo-x3 measured',
      'sources' => [source] }
  end

  def synth_job_json(dir, name, body)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "#{name}.json"), body)
    File.write(File.join(dir, "#{name}.info"), %({"done":true}))
    File.join(dir, "#{name}.json")
  end

  # ---- R6: tool_result is first-class ------------------------------------

  def test_tool_result_durable_job_tree_is_accepted
    record = observation_with('type' => 'tool_result',
                              'ref' => @job_result,
                              'locator' => 'row:demo-x3')
    result = register('observation', record)
    assert_equal 'OBS-001', result['id']
    assert_not_include result['warnings'].join, 'ephemeral'
  end

  def test_tool_result_named_store_attachment_is_accepted
    att = File.join(Research::PathKinds::RECORDS_ATTACHMENTS_DIR,
                    'citation', 'demo.json')
    FileUtils.mkdir_p(File.dirname(att))
    File.write(att, 'attached')
    record = observation_with('type' => 'tool_result', 'ref' => att)
    result = register('observation', record)
    assert result['warnings'].all? { |w| !w.include?('ephemeral') }
  end

  # ---- R7: ref grammar ----------------------------------------------------

  def test_ref_pointing_at_directory_is_rejected
    record = observation_with('type' => 'tool_result',
                              'ref' => @job_dir)
    e = assert_raise(ParameterException) { register('observation', record) }
    assert_include e.message, 'must name a FILE'
  end

  def test_broken_reference_is_hard_error_for_tool_result
    record = observation_with('type' => 'tool_result',
                              'ref' => File.join(@tmpdir, 'nope.json'))
    e = assert_raise(ParameterException) { register('observation', record) }
    assert_include e.message, 'broken reference'
  end

  # ---- R8: locator grammar ------------------------------------------------

  def test_locator_malformed_is_hard_error
    record = observation_with('type' => 'tool_result',
                              'ref' => @job_result,
                              'locator' => 'cell A1')
    e = assert_raise(ParameterException) { register('observation', record) }
    assert_include e.message, "locator must be one form 'kind:value'"
  end

  def test_locator_unknown_kind_is_hard_error
    record = observation_with('type' => 'tool_result',
                              'ref' => @job_result,
                              'locator' => 'page:3')
    e = assert_raise(ParameterException) { register('observation', record) }
    assert_include e.message, "kind in {row, range, line, section}"
  end

  def test_locator_each_kind_accepted
    %w[row:TP53 range:1-10 line:42 section:Results].each do |loc|
      record = observation_with('type' => 'tool_result',
                                'ref' => @job_result, 'locator' => loc)
      assert_nothing_raised { validate(record) }
    end
  end

  def test_locator_grammar_not_enforced_on_legacy_types
    record = observation_with('type' => 'entity_property',
                              'ref' => @job_result,
                              'locator' => 'step 2')
    errors, = validate(record)
    assert errors.empty?, errors.join('; ')
  end

  # ---- R10: durability classification ------------------------------------

  def test_checkout_relative_var_jobs_ref_under_research_root_is_durable
    # Same relative spelling the Research checkout itself would host.
    rel = File.join('var', 'jobs', 'Semantics', 'entity_property',
                    "#{@job_name}.json")
    abs = File.join(@tmpdir, rel)
    # The classifier resolves relative refs against PATH_KIND_ROOT, not the
    # test root; use the absolute spelling here (R7 absolute arm).
    record = observation_with('type' => 'tool_result', 'ref' => abs)
    result = register('observation', record)
    assert result['warnings'].none? { |w| w.include?('ephemeral') }
  end

  def test_plain_file_outside_durable_stores_warns_unverified_durability
    # Contract gap (R10): a plain file that is neither a job tree nor a
    # named store nor temp-rooted cannot be classified as ephemeral by
    # shape alone; the closest enforceable rule accepts it with an
    # explicit unverified-durability warning (reported in the report).
    stray = File.join(@tmpdir, 'scratch', 'out.tsv')
    FileUtils.mkdir_p(File.dirname(stray))
    File.write(stray, "x\n")
    record = observation_with('type' => 'tool_result', 'ref' => stray)
    result = register('observation', record)
    assert result['warnings'].any? { |w| w.include?('unverified durability') }
  end

  def test_tmpfile_scratch_path_is_rejected_with_verbatim_message
    tmp = File.join(TmpFile.tmpdir, 'tmp-123456789')
    File.write(tmp, 'exec-mode return_path output')
    record = observation_with('type' => 'tool_result', 'ref' => tmp)
    e = assert_raise(ParameterException) { register('observation', record) }
    assert_include e.message, 'promote the artifact into the durable store'
    assert_include e.message, 're-run the tool in non-exec mode'
  ensure
    File.delete(tmp) if File.exist?(tmp)
  end

  # ---- R11: promote end-to-end -------------------------------------------

  def test_promote_tool_result_copies_bytes_and_yields_durable_citation
    tmp = File.join(TmpFile.tmpdir, "tmp-#{rand(10**9)}")
    File.write(tmp, 'temporary exec-mode artifact bytes')
    source = { 'type' => 'tool_result', 'ref' => tmp }

    e = assert_raise(ParameterException) do
      register('observation', observation_with(source))
    end
    assert_include e.message, 'promote'

    promoted = Research::PathKinds.promote_record_artifact(
      'observation', @roots, 'ref' => tmp, 'destination' => 'rp-tests'
    )
    assert File.file?(promoted['promoted'])
    assert_equal File.read(tmp), File.read(promoted['promoted'])
    assert promoted['promoted'].start_with?(
      Research::PathKinds::RECORDS_ATTACHMENTS_DIR
    )

    record = observation_with('type' => 'tool_result',
                              'ref' => promoted['promoted'])
    result = register('observation', record)
    assert result['warnings'].none? { |w| w.include?('ephemeral') }
  ensure
    File.delete(tmp) if tmp && File.exist?(tmp)
    if promoted
      FileUtils.rm_f(promoted['promoted'])
      FileUtils.rmdir(File.dirname(promoted['promoted'])) rescue nil
    end
  end

  def test_promote_rejects_directory
    e = assert_raise(ParameterException) do
      Research::PathKinds.promote_record_artifact(
        'observation', @roots, 'ref' => @job_dir, 'destination' => 'rp-tests'
      )
    end
    assert_include e.message, 'is not a file'
  end

  def test_promote_rejects_missing_source
    e = assert_raise(ParameterException) do
      Research::PathKinds.promote_record_artifact(
        'observation', @roots,
        'ref' => File.join(@tmpdir, 'gone.bin'), 'destination' => 'rp-tests'
      )
    end
    assert_include e.message, 'does not resolve'
  end

  # ---- R12: digest semantics ---------------------------------------------

  def test_missing_digest_on_tool_result_is_warning_not_error
    errors, warnings = validate(observation_with('type' => 'tool_result',
                                                 'ref' => @job_result))
    assert errors.empty?, errors.join('; ')
    assert warnings.any? { |w| w.include?('no recorded digest') }
  end

  def test_recorded_digest_is_not_recomputed_at_registration
    # R12: registration RECORDS the caller-asserted digest without
    # recomputing; the recomputation locus is edit/validate.
    record = observation_with('type' => 'tool_result',
                              'ref' => @job_result,
                              'digest' => 'caller-asserted-sha256')
    assert_nothing_raised { register('observation', record) }
  end

  def test_digest_mismatch_at_validate_is_hard_error
    record = register(
      'observation',
      observation_with('type' => 'tool_result', 'ref' => @job_result,
                       'digest' => Digest::SHA256.file(@job_result).hexdigest)
    )
    # Content drifts after registration.
    File.write(@job_result, %({"status":"done","result":"drifted"}))

    result = Research::PathKinds.validate_path('observation', @roots,
                                               record['id'])
    assert_not_nil result['reasons'].find { |r| r.include?('does not match') },
                   result['reasons'].inspect
  end

  # ---- R14: compatibility -------------------------------------------------

  def test_existing_entity_property_source_still_validates
    record = observation_with('type' => 'entity_property',
                              'ref' => @job_result, 'locator' => 'step 2')
    result = register('observation', record)
    assert_equal 'OBS-001', result['id']
  end

  def test_unknown_type_stays_warning_opaque
    record = observation_with('type' => 'federation_query',
                              'ref' => 'https://example.org/q/1')
    result = register('observation', record)
    assert result['warnings'].any? { |w| w.include?('opaque') }
  end

  def test_file_task_workflow_types_still_resolve
    %w[file task workflow].each do |type|
      record = observation_with('type' => type, 'ref' => @job_result)
      assert_nothing_raised("type #{type}") do
        Research::PathKinds.validate_record('observation', record,
                                            roots: @roots)
      end
    end
  end
end
