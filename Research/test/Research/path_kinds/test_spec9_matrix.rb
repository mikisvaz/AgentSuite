require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/lib/Research/path_kinds/records.rb')

require 'fileutils'
require 'timeout'

# Spec section 9 test matrix (the items step 3 left open): serialization
# round-trips, the systematic relationship matrix across all three kinds,
# source-reference variants (files, entity_property/task/workflow
# receipts, locators, digests, external), historical inspectability after
# invalidation/supersession, the full claims-on-stale-evidence scenario,
# and concurrency stress for creation and edits.  Everything runs against
# a per-test temporary root; the real var/records is never touched.
class TestSpec9Matrix < Test::Unit::TestCase
  CHILD_TIMEOUT = 30

  def setup
    @tmpdir = File.join(Scout.tmp.test_spec9_matrix.find.to_s, "m-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @roots = Research::PathKinds.kind_roots(@tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  def stub_agent
    Struct.new(:name).new('test-agent').tap do |agent|
      agent.define_singleton_method(:path_apply_selector) do |_content, _selector, replacement|
        replacement.to_s
      end
    end
  end

  def register(kind, args)
    args = args.merge('sources' => default_sources) if kind == 'observation' && !args.key?('sources')
    Research::PathKinds.register_record(kind, @roots, args)
  end

  def default_sources
    [{ 'type' => 'file', 'ref' => 'workflow.rb', 'digest' => 'fixed' }]
  end

  # ------------------------------------------------------------------
  # Serialization round-trip preservation (spec section 9)
  # ------------------------------------------------------------------

  def test_round_trip_preserves_every_field_type_and_is_idempotent
    record = {
      'version' => 1,
      'statement' => "multiline and quoted: 'single', \"double\",\ttab",
      'title' => 'Round trip title',
      'scope' => { 'condition' => ['condition A', 'control'],
                   'organism' => 'human', 'n' => 3 },
      'status' => 'current',
      'sources' => [
        { 'type' => 'file', 'ref' => 'workflow.rb',
          'digest' => 'abc123' },
        { 'type' => 'external', 'ref' => 'https://example.org/p',
          'locator' => 'table 2' }
      ],
      'value' => { 'log2fc' => 2.1, 'p' => 0.003,
                   'significant' => true, 'genes' => %w[X Y] },
      'links' => [{ 'type' => 'related_to', 'target' => 'C-001',
                    'note' => 'note with: colon' }],
      'limitations' => ['single cohort']
    }

    first = Research::PathKinds.serialize('observation', record)
    parsed = Research::PathKinds.parse_record(first)
    second = Research::PathKinds.serialize('observation', parsed)

    assert_equal record, parsed, 'parse must preserve every field and type'
    assert_equal first, second, 'serialize/parse/serialize must be idempotent'

    %w[claim hypothesis].each do |kind|
      body = Research::PathKinds.serialize(kind, parsed)
      again = Research::PathKinds.parse_record(body)
      assert_equal parsed, again, "#{kind} round trip must be lossless"
    end
  end

  def test_round_trip_through_disk_preserves_content
    result = register('observation',
                      'statement' => 'disk round trip',
                      'scope' => { 'a' => [1, 2], 'b' => 'x' },
                      'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb' }])
    on_disk = Research::PathKinds.parse_record(File.read(result['file']))
    rewritten = Research::PathKinds.serialize('observation', on_disk)
    assert_equal File.read(result['file']), rewritten
  end

  # ------------------------------------------------------------------
  # Systematic relationship matrix (spec sections 2-5, section 9)
  # ------------------------------------------------------------------

  def test_relationship_matrix_accepts_exactly_the_tabulated_combinations
    targets = {
      'observation' => register('observation',
                                'statement' => 'target obs',
                                'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb' }])['id'],
      'claim' => register('claim', 'statement' => 'target claim')['id'],
      'hypothesis' => register('hypothesis', 'statement' => 'target hyp',
                                                 'predictions' => ['p'])['id']
    }

    vocabulary = Research::PathKinds::RELATIONSHIPS.values
                                                  .flat_map(&:keys).uniq.sort
    assert_equal %w[contradicted_by explains motivated_by qualified_by
                    related_to supersedes supported_by], vocabulary

    checked = 0
    Research::PathKinds::RELATIONSHIPS.each_key do |source_kind|
      vocabulary.each do |relationship|
        targets.each do |target_kind, target_id|
          allowed = Research::PathKinds::RELATIONSHIPS
                                   .fetch(source_kind, {})
                                   .fetch(relationship, []).include?(target_kind)

          label = "#{source_kind} #{relationship} -> #{target_kind}"
          accepted =
            begin
              register(source_kind,
                       'statement' => "#{source_kind} #{relationship} #{target_kind}",
                       'links' => [{ 'type' => relationship, 'target' => target_id }])
              true
            rescue ParameterException
              false
            end
          assert_equal allowed, accepted,
                       "#{label} should be #{allowed ? 'accepted' : 'rejected'}"
          checked += 1
        end
      end
    end
    assert checked >= 60, 'the matrix must be systematic, not a spot check'
  end

  def test_relationship_matrix_prohibited_combinations_error_message_names_both_sides
    obs = register('observation', 'statement' => 'obs',
                                  'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb' }])['id']
    error = assert_raise(ParameterException) do
      register('claim', 'statement' => 'claim cannot explain',
               'links' => [{ 'type' => 'explains', 'target' => obs }])
    end
    assert_match(/explains.*not valid from a claim/, error.message)
    assert_match(/supported_by, contradicted_by/, error.message)
  end

  # ------------------------------------------------------------------
  # Source-reference variants (spec sections 3 and 9)
  # ------------------------------------------------------------------

  def make_receipt(*segments)
    dir = File.join(@tmpdir, 'var', 'jobs', *segments)
    FileUtils.mkdir_p(dir)
    FileUtils.touch(File.join(dir, 'job.info'))
    dir
  end

  def test_source_variants_task_workflow_and_entity_property_receipts
    entity = make_receipt('Gene', 'activity_in_treatment', 'TP53_ab12'.split('_'))
    task = make_receipt('Workspace', 'bash', 'Default_job1')
    workflow = make_receipt('Planned', 'ask', 'Default_job2')

    complete = register('observation', 'statement' => 'receipts with digest',
      'sources' => [
        { 'type' => 'entity_property', 'ref' => entity, 'digest' => 'd1' },
        { 'type' => 'task', 'ref' => task, 'digest' => 'd2' },
        { 'type' => 'workflow', 'ref' => workflow, 'digest' => 'd3' }
      ])
    assert_equal [], complete['warnings']

    # Receipt with a locator but no digest: resolves, warns about digest.
    located = register('observation', 'statement' => 'locator no digest',
      'sources' => [{ 'type' => 'task', 'ref' => task, 'locator' => 'step 2' }])
    assert located['warnings'].any? { |w| w.include?('no recorded digest') }

    # Receipt with neither locator nor digest: two warnings (digest,
    # re-executability) and still accepted.
    bare = register('observation', 'statement' => 'bare receipt',
      'sources' => [{ 'type' => 'workflow', 'ref' => workflow }])
    assert bare['warnings'].any? { |w| w.include?('re-executable') }
  end

  def test_source_variants_external_sources_warn_but_never_fail
    result = register('observation', 'statement' => 'external evidence',
      'sources' => [{ 'type' => 'external', 'ref' => 'https://example.org/does-not-resolve',
                      'digest' => 'd' }])
    assert_equal 'OBS-001', result['id']
    assert result['warnings'].any? { |w| w.include?('reachability not verified') }

    validated = Research::PathKinds.validate_path('observation', @roots, result['id'])
    assert validated['ok'], 'an unreachable URL must never be a validation failure'
  end

  def test_source_variants_broken_local_reference_is_a_hard_error
    assert_raise(ParameterException) do
      register('observation', 'statement' => 'broken',
               'sources' => [{ 'type' => 'file', 'ref' => 'no/such/path.tsv' }])
    end
    assert_raise(ParameterException) do
      register('observation', 'statement' => 'broken receipt',
               'sources' => [{ 'type' => 'task', 'ref' => File.join(@tmpdir, 'missing-job') }])
    end
  end

  def test_source_variants_unknown_source_type_is_treated_as_opaque
    result = register('observation', 'statement' => 'opaque source',
      'sources' => [{ 'type' => 'database', 'ref' => 'postgres://host/db/table' }])
    assert result['warnings'].any? { |w| w.include?('not in the built-in vocabulary') }
    validated = Research::PathKinds.validate_path('observation', @roots, result['id'])
    assert validated['ok'], 'unknown-but-well-formed source kinds warn, not fail'
  end

  def test_source_entries_reject_malformed_shapes
    base = lambda do |sources|
      lambda do
        register('observation', 'statement' => 'malformed', 'sources' => sources)
      end
    end
    assert_raise(ParameterException, 'missing type') { base.call([{ 'ref' => 'workflow.rb' }]).call }
    assert_raise(ParameterException, 'missing ref') { base.call([{ 'type' => 'file' }]).call }
    assert_raise(ParameterException, 'unknown key') do
      base.call([{ 'type' => 'file', 'ref' => 'workflow.rb', 'bogus' => 'x' }]).call
    end
    assert_raise(ParameterException, 'not a list') { base.call('workflow.rb').call }
    assert_raise(ParameterException, 'not a mapping') { base.call(['workflow.rb']).call }
  end

  # ------------------------------------------------------------------
  # Historical inspectability after invalidation / supersession
  # ------------------------------------------------------------------

  def test_invalidated_observation_remains_readable_listed_and_snapshotted
    obs = register('observation', 'statement' => 'will be invalidated',
                                  'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb', 'digest' => 'd' }])
    agent = stub_agent

    candidate = Research::PathKinds.parse_record(File.read(obs['file']))
    candidate['status'] = 'invalidated'
    Research::PathKinds.edit_record(
      'observation', @roots, obs['file'],
      { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
        'replacement' => Research::PathKinds.serialize('observation', candidate) },
      agent
    )

    # Still readable and validated
    validated = Research::PathKinds.validate_path('observation', @roots, obs['id'])
    assert validated['ok']
    assert_equal 'invalidated', validated['status']

    # Still listed
    listed = Research::PathKinds.list_records('observation', @roots, '')
    assert listed['records'].any? { |r| r['id'] == obs['id'] && r['status'] == 'invalidated' }

    # History snapshot holds the pre-invalidation body
    snapshot = File.join(@roots['observation'], 'history', "#{obs['id']}.v1.yaml")
    assert File.file?(snapshot)
    old = Research::PathKinds.parse_record(File.read(snapshot))
    assert_equal 'current', old['status']
    assert_equal 1, old['version']
  end

  def test_superseded_claim_remains_historically_inspectable_with_replacement_link
    old = register('claim', 'statement' => 'original formulation')
    replacement = register('claim', 'statement' => 'sharper formulation',
                                       'links' => [{ 'type' => 'supersedes', 'target' => old['id'] }])
    agent = stub_agent

    candidate = Research::PathKinds.parse_record(File.read(old['file']))
    candidate['status'] = 'superseded'
    Research::PathKinds.edit_record(
      'claim', @roots, old['file'],
      { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
        'replacement' => Research::PathKinds.serialize('claim', candidate) },
      agent
    )

    # Superseded claim: readable, listed, versioned, and its replacement
    # resolves through the stored supersedes link.
    validated = Research::PathKinds.validate_path('claim', @roots, old['id'])
    assert validated['ok']
    assert_equal 'superseded', validated['status']

    back = Research::PathKinds.validate_path('claim', @roots, replacement['id'])
    assert back['links'].any? { |l| l['type'] == 'supersedes' && l['target'] == old['id'] && l['resolved'] }

    # A claim pointing at the superseded record reports stale evidence as
    # a WARNING, not an error.
    dependent = register('claim', 'statement' => 'depends on old',
                                  'links' => [{ 'type' => 'supported_by', 'target' => old['id'] }])
    dep_validated = Research::PathKinds.validate_path('claim', @roots, dependent['id'])
    assert dep_validated['ok']
    assert dep_validated['warnings'].any? { |w| w.include?(old['id']) && w.include?('superseded') }
  end

  # ------------------------------------------------------------------
  # Claims depending on stale evidence: full scenario (spec section 8)
  # ------------------------------------------------------------------

  def test_claim_depending_on_stale_evidence_is_detected_not_rewritten
    obs = register('observation', 'statement' => 'gene X effect',
                                  'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb', 'digest' => 'd' }])
    claim = register('claim', 'statement' => 'gene X is a marker',
                             'links' => [{ 'type' => 'supported_by', 'target' => obs['id'] }])
    agent = stub_agent

    # Before: the claim validates with warnings only (counterevidence).
    before = Research::PathKinds.validate_path('claim', @roots, claim['id'])
    assert before['ok']
    assert !before['warnings'].any? { |w| w.include?('invalidated') }

    # The observation is invalidated after the claim was registered.
    candidate = Research::PathKinds.parse_record(File.read(obs['file']))
    candidate['status'] = 'invalidated'
    Research::PathKinds.edit_record(
      'observation', @roots, obs['file'],
      { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
        'replacement' => Research::PathKinds.serialize('observation', candidate) },
      agent
    )

    # After: the dependency is DETECTED (warning naming the stale
    # observation) and the claim was NOT silently rewritten.
    after = Research::PathKinds.validate_path('claim', @roots, claim['id'])
    assert after['ok'], 'a stale dependency must not make the claim invalid'
    assert after['warnings'].any? { |w| w.include?(obs['id']) && w.include?('invalidated') }
    assert after['links'].any? { |l| l['type'] == 'supported_by' && l['resolved'] &&
                                    l['target_status'] == 'invalidated' }

    claim_body = Research::PathKinds.parse_record(File.read(claim['file']))
    assert_equal 1, claim_body['version'], 'the claim must not be silently rewritten'
    assert_equal 'gene X is a marker', claim_body['statement']
  end

  # ------------------------------------------------------------------
  # Concurrency: creation and edits (spec section 8)
  # ------------------------------------------------------------------

  def run_children(count, result_name)
    pids = []
    count.times do |i|
      pids << Process.fork do
        out = File.join(@tmpdir, "#{result_name}-#{i}.json")
        yield i
        File.write(out, 'ok')
        exit!(true)
      end
    end
    pids.each do |pid|
      Timeout.timeout(CHILD_TIMEOUT) do
        _pid, status = Process.wait2(pid)
        flunk("child #{pid} failed: #{status.exitstatus}") unless status.success?
      end
    rescue Timeout::Error
      Process.kill('KILL', pid)
      Process.waitpid(pid)
      flunk("child #{pid} timed out after #{CHILD_TIMEOUT}s (deadlock?)")
    end
  end

  def test_concurrent_creation_allocates_unique_sequential_ids
    children = 4
    per_child = 5

    run_children(children, 'create') do |i|
      per_child.times do |j|
        args = { 'statement' => "child #{i} record #{j}",
                 'sources' => [{ 'type' => 'file', 'ref' => 'workflow.rb' }] }
        Research::PathKinds.register_record('observation', @roots, args)
      end
    end

    ids = Dir.glob(File.join(@roots['observation'], '*.yaml'))
             .map { |f| File.basename(f, '.yaml') }.sort
    expected = (1..(children * per_child)).map { |n| format('OBS-%03d', n) }
    assert_equal expected, ids, 'concurrent registration must produce exactly the sequential id set'
  end

  def test_concurrent_edits_from_the_same_base_version_one_wins_one_stales
    claim = register('claim', 'statement' => 'contended claim')
    base_text = File.read(claim['file'])

    run_children(2, 'edit') do |i|
      agent = Struct.new(:name).new("child-#{i}").tap do |a|
        a.define_singleton_method(:path_apply_selector) do |_c, _s, replacement|
          replacement.to_s
        end
      end
      candidate = Research::PathKinds.parse_record(base_text)
      candidate['title'] = "title from child #{i}"
      # Serialize the conflict deterministically: child 0 sits between its
      # read and its edit while child 1 completes a full edit cycle first,
      # so child 0 edits against a base the record has moved past.
      sleep(0.3) if i == 0
      edit_args = { 'selector' => { 'type' => 'regexp', 'pattern' => 'statement' },
                    'replacement' => Research::PathKinds.serialize('claim', candidate) }
      begin
        Research::PathKinds.edit_record('claim', @roots, claim['file'], edit_args, agent)
        File.write(File.join(@tmpdir, "edit-#{i}.status"), 'won')
      rescue ParameterException
        File.write(File.join(@tmpdir, "edit-#{i}.status"), 'stale')
      end
    end

    outcomes = Dir.glob(File.join(@tmpdir, 'edit-*.status')).map { |f| File.read(f) }.sort
    assert_equal %w[stale won], outcomes, 'exactly one edit must win and the other must stale'

    body = Research::PathKinds.parse_record(File.read(claim['file']))
    sidecar = Research::PathKinds.load_sidecar(@roots['claim'], claim['id'])
    assert_equal 2, body['version']
    assert_equal 2, sidecar['version'], 'body and sidecar must agree after the race'
    assert File.file?(File.join(@roots['claim'], 'history', 'C-001.v1.yaml'))
  end
end
