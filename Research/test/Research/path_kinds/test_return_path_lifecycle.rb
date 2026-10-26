# Cross-session lifecycle test for the return_path citation contract.
#
# Process A runs a REAL tool invocation and registers an Observation citing
# the returned durable path; process B (a genuinely fresh Ruby process)
# resolves and reads the cited source through ordinary means and, where a
# digest was pinned, matches it. The temporary-result case is its own test.
#
# The two real-tool invocations are:
#   - entity case: Semantics.entity_property, now NON-exec exported (the
#     export flip of the previous bout), returning value + durable
#     receipt.job.path in ONE execution;
#   - generality case: a non-entity task result (ScoutCoder task or any
#     installed non-exec workflow task) cited as tool_result.
#
# Run from the Research checkout root:
#   ruby -Itest -Ilib test/Research/path_kinds/test_return_path_lifecycle.rb
require 'fileutils'
require 'json'
require 'digest'
require 'open3'
require 'test/unit'

RESEARCH_ROOT = File.expand_path('../../../', __dir__)

def research_module_source
  File.join(RESEARCH_ROOT, 'lib', 'Research', 'path_kinds', 'records.rb')
end

# One shared scratch root per test-run: the two processes must see the same
# record store for the cross-session handoff.
SCRATCH = File.join(RESEARCH_ROOT, 'tmp', "rp-lifecycle-#{Process.pid}")
REF_POINTER = File.join(SCRATCH, 'last-ref.txt')

# ---- helper: run a snippet in a fresh process ---------------------------
def fresh_process(code)
  Open3.capture2e({ 'RUBYOPT' => nil },
                  RbConfig.ruby, '-I', File.join(RESEARCH_ROOT, 'lib'),
                  '-I', File.join(RESEARCH_ROOT, 'test'),
                  '-e', "require 'scout'\nrequire 'scout-ai'\n#{code}")
end

class TestReturnPathLifecycle < Test::Unit::TestCase
  def setup
    FileUtils.mkdir_p(SCRATCH)
  end

  def teardown
    FileUtils.rm_rf(SCRATCH) if File.directory?(SCRATCH)
    cleanup_scratch_jobs
  end

  # Jobs this test creates under the user-global jobs root are named with a
  # recognizable prefix so teardown can remove exactly them.
  LIFECYCLE_TAG = 'rp_lifecycle_'

  def cleanup_scratch_jobs
    root = File.join(ENV['HOME'], '.scout', 'var', 'jobs')
    %w[Semantics].each do |wf|
      dir = File.join(root, wf)
      next unless File.directory?(dir)
      Dir.glob(File.join(dir, '**', "*#{LIFECYCLE_TAG}*")).each do |p|
        FileUtils.rm_rf(p)
      end
    end
  end

  # ---- process A: one real entity_property execution --------------------

  def test_entity_case_cross_session
    omit 'Semantics checkout not present' unless semantics_present?

    out, status = fresh_process(<<~RUBY)
      require '#{research_module_source}'
      # Semantics carries no entity drafts; register the same benign probe
      # module its own tests use, then run the real task job against it.
      module ProbeWidget
        extend EntityWorkflow
        property :value => :single do |factor = 2|
          self.to_s.to_i * factor
        end
      end
      wf = Workflow.require_workflow 'Semantics'
      job = wf.job(:entity_property, '#{LIFECYCLE_TAG}entity',
                   'entity_type' => 'ProbeWidget',
                   'entity' => '7',
                   'property' => 'value')
      record = job.run
      require 'json'
      raise 'execution failed: ' + record[:error].inspect if record[:status] == 'error'
      File.write('#{REF_POINTER}',
                 JSON.generate({ 'path' => record[:receipt][:job][:path],
                                 'value' => record[:result] }))
      puts JSON.generate({ 'path' => record[:receipt][:job][:path],
                           'value' => record[:result] })
    RUBY

    assert_equal 0, status.exitstatus, out
    a = JSON.parse(File.read(REF_POINTER))
    assert_not_nil a['path'], 'execution must return a durable job path'
    assert File.file?(a['path']),
           "receipt.job.path #{a['path'].inspect} must exist on disk"

    # Register the Observation in another fresh process citing that path.
    reg_out, reg_status = fresh_process(<<~RUBY)
      require '#{research_module_source}'
      roots = Research::PathKinds.kind_roots('#{SCRATCH}')
      result = Research::PathKinds.register_record('observation', roots, {
        'statement' => 'entity_property cross-session demo',
        'sources' => [{ 'type' => 'entity_property',
                        'ref' => #{a['path'].to_json},
                        'locator' => 'row:lc-a' }] })
      puts result['id']
    RUBY
    assert_equal 0, reg_status.exitstatus, reg_out
    obs_id = reg_out.strip

    # ---- process B: fresh process resolves and reads ------------------
    out_b, status_b = fresh_process(<<~RUBY)
      require '#{research_module_source}'
      require 'json'
      require 'digest'
      roots = Research::PathKinds.kind_roots('#{SCRATCH}')
      record = YAML.load_file(File.join(roots['observation'], '#{obs_id}.yaml'))
      ref = record['sources'][0]['ref']
      puts JSON.generate({
        'exists' => File.file?(ref),
        'bytes' => File.file?(ref) ? File.size(ref) : nil,
        'digest' => File.file?(ref) ? Digest::SHA256.file(ref).hexdigest : nil
      })
    RUBY
    assert_equal 0, status_b.exitstatus, out_b
    b = JSON.parse(out_b.strip.split("\n").last)
    assert b['exists'], 'process B must resolve the cited ref'
    assert b['bytes'].positive?, 'process B must read real bytes'
  end

  # ---- generality case: a non-entity task result -----------------------

  def test_tool_result_generality_cross_session
    omit 'ScoutCoder checkout not present' unless scoutcoder_present?

    out, status = fresh_process(<<~RUBY)
      wf = Workflow.require_workflow 'ScoutCoder'
      job = wf.job(:help_list_workflows, '#{LIFECYCLE_TAG}gen')
      value = job.run
      require 'json'
      puts JSON.generate({ 'path' => job.path.to_s,
                           'value_kind' => value.class.to_s })
    RUBY
    assert_equal 0, status.exitstatus, out
    a = JSON.parse(out.strip.split("\n").last)
    assert File.file?(a['path'] + '.info') || File.file?(a['path']),
           'the non-exec task job must persist'

    reg_out, reg_status = fresh_process(<<~RUBY)
      require '#{research_module_source}'
      roots = Research::PathKinds.kind_roots('#{SCRATCH}')
      require 'digest'
      ref = #{a['path'].to_json}
      result = Research::PathKinds.register_record('observation', roots, {
        'statement' => 'tool_result generality demo',
        'sources' => [{ 'type' => 'tool_result', 'ref' => ref,
                        'digest' => Digest::SHA256.file(ref).hexdigest }] })
      puts result['id']
    RUBY
    assert_equal 0, reg_status.exitstatus, reg_out
    obs_id = reg_out.strip

    out_b, status_b = fresh_process(<<~RUBY)
      require '#{research_module_source}'
      require 'json'
      require 'digest'
      require 'yaml'
      roots = Research::PathKinds.kind_roots('#{SCRATCH}')
      record = YAML.load_file(File.join(roots['observation'], '#{obs_id}.yaml'))
      src = record['sources'][0]
      ref = src['ref']
      puts JSON.generate({
        'exists' => File.file?(ref),
        'match' => src['digest'] == Digest::SHA256.file(ref).hexdigest })
    RUBY
    assert_equal 0, status_b.exitstatus, out_b
    b = JSON.parse(out_b.strip.split("\n").last)
    assert b['exists']
    assert b['match'], 'pinned digest must match in process B'
  end

  # ---- temporary-result case --------------------------------------------

  def test_temporary_result_is_rejected_not_silently_registered
    out, status = fresh_process(<<~RUBY)
      require '#{research_module_source}'
      roots = Research::PathKinds.kind_roots('#{SCRATCH}')
      tmp = TmpFile.tmp_file
      File.write(tmp, 'exec-mode scratch')
      begin
        Research::PathKinds.register_record('observation', roots, {
          'statement' => 'should never register',
          'sources' => [{ 'type' => 'tool_result', 'ref' => tmp }] })
        puts 'REGISTERED'
      rescue ParameterException => e
        puts JSON.generate({ 'rejected' => true, 'message' => e.message })
      ensure
        File.delete(tmp) if File.exist?(tmp)
      end
    RUBY
    assert_equal 0, status.exitstatus, out
    payload = out.strip.split("\n").last
    assert_not_equal 'REGISTERED', payload, 'ephemeral ref must not register'
    assert payload.include?('ephemeral reference')
    assert payload.include?('promote the artifact into the durable store')
    assert payload.include?('re-run the tool in non-exec mode')
  end

  private

  def semantics_present?
    File.directory?(File.join(ENV['HOME'], 'git', 'AgentSuite', 'Semantics')) ||
      File.directory?('/bulk/mvazque2/git/AgentSuite/Semantics')
  end

  def scoutcoder_present?
    File.directory?(File.join(ENV['HOME'], 'git', 'AgentSuite', 'ScoutCoder')) ||
      File.directory?('/bulk/mvazque2/git/AgentSuite/ScoutCoder')
  end
end
