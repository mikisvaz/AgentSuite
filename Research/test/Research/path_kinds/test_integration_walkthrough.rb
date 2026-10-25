require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/workflow.rb')

require 'fileutils'

# Step 5 integration dry run: ONE coherent walked-through scenario that
# exercises the record surface the way an incorporated agent would --
# through the real engine dispatch (LLM::Agent#path_dispatch, the same
# entry scout-ai uses for the installed tools), against a temporary
# per-test checkout root, with synthetic DOMAIN-NEUTRAL fixtures written
# by the test itself.  Not a re-test of the step-4 matrix: the stages
# follow one story in order.
#
# Fixtures (deliberately non-AGS, domain-neutral):
#   - a small plain-text measurement file written by the test
#   - a fabricated-but-well-formed task-receipt directory
#     (var/jobs/<Workflow>/<task>/<id>/ with a job.info file)
class TestIntegrationWalkthrough < Test::Unit::TestCase
  def setup
    @tmpdir = File.join(Scout.tmp.test_integration_walkthrough.find.to_s,
                        "walk-#{Process.pid}")
    FileUtils.mkdir_p(@tmpdir)
    @base = File.join(@tmpdir, 'checkout')
    FileUtils.mkdir_p(@base)

    # Domain-neutral synthetic fixtures.  Source refs are ABSOLUTE: the
    # validator anchors relative refs against the Research checkout by
    # design, so an out-of-checkout caller (like this test, or an agent
    # working elsewhere) must cite its fixtures absolutely.
    @data_file = File.join(@base, 'measurements', 'ambient_levels.txt')
    FileUtils.mkdir_p(File.dirname(@data_file))
    @readings = [12.4, 11.8, 13.1].freeze
    File.write(@data_file, @readings.join("\n") + "\n")

    # Fabricated task receipt: well-formed in shape, synthetic in content.
    @receipt = File.join(@base, 'var', 'jobs', 'Survey', 'mean_level', 'unit_a1')
    FileUtils.mkdir_p(@receipt)
    File.write(File.join(@receipt, 'job.info'), "task: mean_level\n")

    @roots = Research::PathKinds.kind_roots(@base)
    @definitions = Research::PathKinds.definitions(base_dir: @base)
    @agent = LLM.agent
    @definitions.each { |kind, definition| @agent.register_path_kind(kind, definition) }
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  # The engine dispatch funnel: keyword kind/operation plus the rest as
  # the agent-facing tool would send them.
  def dispatch(kind:, operation:, **args)
    stringified = {}
    args.each { |key, value| stringified[key.to_s] = value }
    @agent.path_dispatch(kind: kind, operation: operation, **stringified)
  end

  def test_full_agent_walkthrough_register_validate_fail_then_supersede
    # ------------------------------------------------------------------
    # Stage 1: register an Observation citing a file source (with digest)
    # and a receipt source (with locator).
    # ------------------------------------------------------------------
    observation = dispatch(kind: 'observation', operation: 'register', path: '.',
      'statement' => 'mean ambient level of unit a is 12.4 over 3 readings',
      'title' => 'Unit A ambient level',
      'scope' => { 'unit' => ['a'], 'readings' => 3 },
      'sources' => [
        { 'type' => 'file', 'ref' => @data_file,
          'digest' => 'digest-of-ambient-levels' },
        { 'type' => 'task', 'ref' => @receipt,
          'locator' => 'mean step', 'digest' => 'digest-of-mean-step' }
      ])

    assert_equal 'OBS-001', observation['id']
    assert_equal 1, observation['version']
    assert_equal 'current', observation['status']
    assert File.file?(observation['file'])
    assert File.file?(File.join(@roots['observation'], 'OBS-001.info.json'))

    # ------------------------------------------------------------------
    # Stage 2: register a Claim supported_by that Observation.
    # ------------------------------------------------------------------
    claim = dispatch(kind: 'claim', operation: 'register', path: '.',
      'statement' => 'unit a runs at a mean ambient level near 12',
      'title' => 'Unit A operating level',
      'links' => [{ 'type' => 'supported_by', 'target' => observation['id'] }])

    assert_equal 'C-001', claim['id']
    assert_equal 'proposed', claim['status']
    # An unchallenged proposed claim warns but never blocks.
    assert claim['warnings'].any? { |w| w.include?('counterevidence') }

    # ------------------------------------------------------------------
    # Stage 3: register a Hypothesis motivated_by the Observation and
    # explains the Claim, with predictions and a test_idea.
    # ------------------------------------------------------------------
    hypothesis = dispatch(kind: 'hypothesis', operation: 'register', path: '.',
      'statement' => 'unit a calibration drift raises its ambient readings by about 1',
      'title' => 'Calibration drift explanation',
      'links' => [
        { 'type' => 'motivated_by', 'target' => observation['id'] },
        { 'type' => 'explains', 'target' => claim['id'] }
      ],
      'predictions' => [
        'recalibrating unit a drops its mean ambient level to about 11',
        'uncalibrated sister unit b shows no drift over the same window'
      ],
      'test_ideas' => ['repeat the 3-reading window after recalibration'])

    assert_equal 'H-001', hypothesis['id']
    assert_equal 'proposed', hypothesis['status']
    assert_equal [], hypothesis['warnings']

    # ------------------------------------------------------------------
    # Stage 4: validate all three clean (errors empty; only the expected
    # advisory warnings) and confirm link resolution both ways.
    # ------------------------------------------------------------------
    obs_check = dispatch(kind: 'observation', operation: 'validate',
                         path: observation['id'])
    assert obs_check['ok']
    assert_equal [], obs_check['reasons']
    assert_equal [], obs_check['warnings']

    claim_check = dispatch(kind: 'claim', operation: 'validate',
                           path: claim['id'])
    assert claim_check['ok']
    assert_equal [], claim_check['reasons']
    supported = claim_check['links'].find { |l| l['type'] == 'supported_by' }
    assert supported['resolved']
    assert_equal observation['id'], supported['target']
    assert_equal 'current', supported['target_status']

    hyp_check = dispatch(kind: 'hypothesis', operation: 'validate',
                         path: hypothesis['id'])
    assert hyp_check['ok']
    assert_equal [], hyp_check['reasons']
    assert_equal [], hyp_check['warnings']
    assert_equal 2, hyp_check['links'].length
    assert hyp_check['links'].all? { |l| l['resolved'] }

    # Backlinks are derived at validate time.
    assert obs_check['backlinks'].any? { |bl| bl['source'] == claim['id'] }
    assert obs_check['backlinks'].any? { |bl| bl['source'] == hypothesis['id'] }

    # ------------------------------------------------------------------
    # Stage 5: failure modes in turn, each with an actionable error.
    # ------------------------------------------------------------------
    broken = dispatch(kind: 'observation', operation: 'register', path: '.',
      'statement' => 'cite a missing artifact',
      'sources' => [{ 'type' => 'file', 'ref' => File.join(@base, 'measurements', 'absent.txt') }]) rescue nil
    assert_nil broken, 'a broken reference must raise, not return'
    error = assert_raise(ParameterException) do
      dispatch(kind: 'observation', operation: 'register', path: '.',
               'statement' => 'cite a missing artifact',
               'sources' => [{ 'type' => 'file', 'ref' => File.join(@base, 'measurements', 'absent.txt') }])
    end
    assert_match(/measurements\/absent\.txt/, error.message)
    assert_match(/not (?:found|exist)/i, error.message)

    error = assert_raise(ParameterException) do
      dispatch(kind: 'observation', operation: 'register', path: '.',
               'statement' => 'no provenance at all')
    end
    assert_match(/without at least one source/, error.message)

    error = assert_raise(ParameterException) do
      dispatch(kind: 'observation', operation: 'register', path: '.',
               'statement' => 'observation cannot motivate',
               'sources' => [{ 'type' => 'file', 'ref' => @data_file }],
               'links' => [{ 'type' => 'motivated_by', 'target' => hypothesis['id'] }])
    end
    assert_match(/motivated_by/, error.message)
    assert_match(/not valid from a observation/i, error.message)

    # Invalid status transition, through edit: current -> proposed is not
    # in the observation transition graph.
    body = Research::PathKinds.parse_record(
      dispatch(kind: 'observation', operation: 'read', path: observation['id'])['content']
    )
    body['status'] = 'proposed'
    error = assert_raise(ParameterException) do
      current = dispatch(kind: 'observation', operation: 'read',
                         path: observation['id'])['content']
      dispatch(kind: 'observation', operation: 'edit', path: observation['id'],
               'selector' => { 'type' => 'chars', 'start' => 0, 'end' => current.length },
               'replacement' => Research::PathKinds.serialize('observation', body))
    end
    assert_match(/invalid status transition/i, error.message)
    assert_match(/current.*proposed|proposed.*current/, error.message)
    # The record is untouched by the failed edit.
    still = dispatch(kind: 'observation', operation: 'validate',
                     path: observation['id'])
    assert_equal 'current', still['status']
    assert_equal 1, still['version']

    error = assert_raise(ParameterException) do
      dispatch(kind: 'claim', operation: 'register', path: '.',
               'statement' => 'misspelled field',
               'confidence' => 0.8)
    end
    assert_match(/unknown/i, error.message)
    assert_match(/confidence/, error.message)

    # ------------------------------------------------------------------
    # Stage 6: invalidate the Observation; history is preserved and the
    # Claim now surfaces the stale-evidence warning naming the
    # Observation, while the Claim body itself is untouched.
    # ------------------------------------------------------------------
    latest = Research::PathKinds.parse_record(
      dispatch(kind: 'observation', operation: 'read', path: observation['id'])['content']
    )
    latest['status'] = 'invalidated'
    current = dispatch(kind: 'observation', operation: 'read',
                       path: observation['id'])['content']
    invalidated = dispatch(kind: 'observation', operation: 'edit',
                           path: observation['id'],
                           'selector' => { 'type' => 'chars', 'start' => 0, 'end' => current.length },
                           'replacement' => Research::PathKinds.serialize('observation', latest))
    assert invalidated['changed']
    assert_equal 2, invalidated['version']
    assert_equal 'invalidated', invalidated['status']

    # Prior version snapshotted and readable, with the pre-edit status.
    snapshot = File.join(@roots['observation'], 'history', 'OBS-001.v1.yaml')
    assert File.file?(snapshot)
    prior = Research::PathKinds.parse_record(File.read(snapshot))
    assert_equal 1, prior['version']
    assert_equal 'current', prior['status']
    assert_equal 'mean ambient level of unit a is 12.4 over 3 readings',
                 prior['statement']

    # The invalidated observation itself remains readable and valid.
    after_obs = dispatch(kind: 'observation', operation: 'validate',
                         path: observation['id'])
    assert after_obs['ok']
    assert_equal 'invalidated', after_obs['status']

    # The Claim: still valid, stale evidence now WARNED and visible in
    # the resolved links, body untouched.
    after_claim = dispatch(kind: 'claim', operation: 'validate',
                           path: claim['id'])
    assert after_claim['ok'], 'stale evidence must warn, not invalidate'
    stale_id = observation['id']
    stale_hit = after_claim['warnings'].detect do |w|
      String === w && w.include?(stale_id) && w.include?('invalidated')
    end
    assert stale_hit,
           "expected a stale-evidence warning naming #{stale_id} " \
           "in #{after_claim['warnings'].inspect}"
    stale_link = after_claim['links'].find { |l| l['type'] == 'supported_by' }
    assert stale_link['resolved']
    assert_equal 'invalidated', stale_link['target_status']

    claim_body = Research::PathKinds.parse_record(
      dispatch(kind: 'claim', operation: 'read', path: claim['id'])['content']
    )
    assert_equal 1, claim_body['version'], 'the claim must not be silently rewritten'
    assert_equal 'proposed', claim_body['status']
    assert_equal 'unit a runs at a mean ambient level near 12',
                 claim_body['statement']

    # And the hypothesis sees the same stale evidence through its
    # motivated_by link (informational for the author, never a failure).
    after_hyp = dispatch(kind: 'hypothesis', operation: 'validate',
                         path: hypothesis['id'])
    assert after_hyp['ok']
    assert after_hyp['warnings'].any? { |w| String === w && w.include?(stale_id) }

    # ------------------------------------------------------------------
    # Stage 7: listing still shows everything, statuses intact.
    # ------------------------------------------------------------------
    obs_list = dispatch(kind: 'observation', operation: 'list', path: '.')
    assert_equal 1, obs_list['count']
    assert_equal 'invalidated', obs_list['records'].first['status']

    %w[claim hypothesis].each do |kind|
      listed = dispatch(kind: kind, operation: 'list', path: '.')
      assert_equal 1, listed['count']
      assert_equal 'proposed', listed['records'].first['status']
    end
  end
end
