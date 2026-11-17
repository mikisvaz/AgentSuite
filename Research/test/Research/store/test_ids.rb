# Unit tests for ID allocation (Research::Ids) and the fixed
# project-relative store-root resolution that replaced Research::Roots.
#
# The concurrency test uses REAL SEPARATE PROCESSES (fork + waitall),
# exercising the root-level Open.lock serialization required by the
# acceptance criteria ("concurrent ID allocation test exercises separate
# processes; IDs never reused").
#
# The root-resolution tests pin the Bout A contract: the store root is
# ALWAYS File.expand_path('research', Dir.pwd) computed at execution
# time, with no input, config, env or Scout.var fallback.

require 'tmpdir'
require 'scout'
require 'json'
require 'open3'
require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')

require_relative '../../../lib/Research/layout'
require_relative '../../../lib/Research/ids'
require_relative '../../../lib/Research/tasks/common'
require_relative '../../support/dossier_fixtures'

Ids = Research::Ids unless defined?(Ids)
Tasks = Research::Tasks unless defined?(Tasks)
Layout = Research::Layout unless defined?(Layout)

class TestIdsAllocation < Test::Unit::TestCase
  include DossierFixtureTeardown

  def setup
    @tmp = Dir.mktmpdir('research-ids-test')
    @root = File.join(@tmp, 'root')
    Research::Layout.ensure_root!(@root)
  end

  def teardown
    FileUtils.remove_entry(@tmp) if @tmp && File.exist?(@tmp)
    super
  end

  def test_types_and_formatting
    assert_equal 'Q-001', Ids.format_id('question', 1)
    assert_equal 'C-001', Ids.format_id('claim', 1)
    assert_equal 'H-001', Ids.format_id('hypothesis', 1)
    assert_equal 'Q-1000', Ids.format_id('question', 1000)
    assert_equal 'Q-042', Ids.format_id('question', 42)
    assert Ids.valid_type?('question')
    refute Ids.valid_type?('pub')
  end

  def test_sequential_allocation_within_type
    a = Ids.allocate(@root, 'question')
    b = Ids.allocate(@root, 'question')
    assert_equal 'Q-001', a
    assert_equal 'Q-002', b
    # counters are per type
    c = Ids.allocate(@root, 'claim')
    assert_equal 'C-001', c
  end

  def test_concurrent_allocation_across_processes_never_reuses
    # 6 processes x 5 allocations each, interleaved by the OS, must produce
    # exactly 30 distinct Q IDs 1..30 with zero reuse and zero gaps.
    procs = 6
    per = 5
    here = File.dirname(__FILE__)
    lib_layout = File.expand_path('../../../lib/Research/layout', here)
    lib_ids = File.expand_path('../../../lib/Research/ids', here)
    script = <<~RUBY
      require 'scout'
      require_relative #{lib_layout.inspect}
      require_relative #{lib_ids.inspect}
      ids = #{per}.times.map { Research::Ids.allocate(#{@root.inspect}, 'question') }
      puts ids.join("\n")
    RUBY
    outs = procs.times.map do
      Open3.popen3(RbConfig.ruby, '-e', script) do |_i, o, e, t|
        out = o.read
        err = e.read
        st = t.value
        raise "child failed: #{err}" unless st.success?
        out
      end
    end
    all = outs.flat_map { |x| x.split("\n").reject(&:empty?) }
    assert_equal procs * per, all.size
    assert_equal all.size, all.uniq.size, 'an ID was reused across processes'
    numbers = all.map { |x| Integer(x.delete_prefix('Q-'), 10) }.sort
    assert_equal (1..(procs * per)).to_a, numbers
  end

  def test_unknown_type_rejected
    assert_raise(Ids::Error) { Ids.allocate(@root, 'paper') }
  end
end

class TestProjectRootResolution < Test::Unit::TestCase
  include DossierFixtureTeardown

  def test_store_root_is_cwd_research_computed_at_call_time
    DossierFixtures.in_project(DossierFixtures.scaffold_project('rootres')) do |project|
      expected = File.expand_path('research', project)
      assert_equal expected, Tasks.store_root
      # recomputed on every call, following the current cwd
      Dir.chdir(project) do
        assert_equal File.expand_path('research', Dir.pwd),
                     Tasks.store_root
      end
    end
  end

  def test_store_root_follows_cwd_between_calls
    a = DossierFixtures.scaffold_project('rootres-a')
    b = DossierFixtures.scaffold_project('rootres-b')
    Dir.chdir(a) do
      assert_equal File.expand_path('research', a),
                   Tasks.store_root
    end
    Dir.chdir(b) do
      assert_equal File.expand_path('research', b),
                   Tasks.store_root
    end
    refute_equal File.expand_path('research', a),
                 File.expand_path('research', b)
  end
end
