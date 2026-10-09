require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path('../../../workflow', __dir__)
require 'tmpdir'
require 'fileutils'

# Integration tests for the LLM::Sandbox-backed `normalize` authorization
# helper in lib/Workspace/tasks/filesystem.rb.
#
# The tests exercise normalize through a helper-level receiver object (the
# workflow step module), and register isolated thread-local grants with the
# public LLM::Sandbox registrar API (allow_path / allow_read_path), restoring
# the exact prior Thread.current keys afterwards so no thread state leaks.
#
# Isolated grant fixtures are created under ~/.rbbt/tmp (see ISOLATED_TMP
# below): outside every grant this workflow configures, yet creatable by
# the process at the OS level.
class TestWorkspaceFilesystem < Test::Unit::TestCase
  # Isolated grant fixtures live under ~/.rbbt/tmp: the process can create
  # directories there at the OS level, but it sits outside every grant this
  # workflow configures (writable /tmp-style grants cover /tmp and
  # ~/tmp, not ~/.rbbt/tmp), so containment denials and read-only grants are
  # meaningful and not shadowed.
  ISOLATED_TMP = File.expand_path('~/.rbbt/tmp')

  def normalize(path, type=:read)
    receiver = Object.new
    receiver.extend(Workspace.step_module)
    receiver.normalize(path, type)
  end

  def assert_denied(path, type=:read)
    verb = type.to_s == 'read' ? 'read' : 'write'
    e = assert_raise(SandboxAccessViolation) { normalize(path, type) }
    first = "Path #{path} not #{verb} allowed. Allowed paths:"
    assert_equal first, e.message.lines.first.chomp, e.message
    assert_include e.message, path.to_s
    e
  end

  # Register one or more thread-local grants (writable or read-only) for the
  # duration of the block, restoring exactly the prior Thread.current keys.
  def with_grants(writable: [], readable: [])
    writable = [writable] unless Array === writable
    readable = [readable] unless Array === readable
    w_before = (Thread.current['allowed_paths'] || []).dup
    r_before = (Thread.current['allowed_read_paths'] || []).dup
    writable.each { |p| LLM::Sandbox.allow_path(p) }
    readable.each { |p| LLM::Sandbox.allow_read_path(p) }
    begin
      yield
    ensure
      Thread.current['allowed_paths'] = w_before
      Thread.current['allowed_read_paths'] = r_before
    end
  end

  # A grant directory outside every configured grant.
  def isolated_grant_dir(prefix='workspace-fs-grant')
    FileUtils.mkdir_p(ISOLATED_TMP)
    Dir.mktmpdir(prefix, ISOLATED_TMP) { |d| yield d }
  end

  # 1. Basic containment: inside root allowed, sibling prefix and unrelated
  #    outside paths denied with the original spelling in the message.
  def test_root_containment_read_and_write
    inside = File.join(Workspace.root, 'workflow.rb')
    assert_equal inside, normalize(inside, :read)
    assert_equal inside, normalize(inside, :write)
  end

  def test_sibling_prefix_directory_is_not_inside_root
    sibling = Workspace.root.to_s + '2'
    assert_denied(sibling, :read)
    assert_denied(sibling, :write)
  end

  def test_unrelated_path_outside_all_grants_denied
    isolated_grant_dir('workspace-fs-outside') do |outside_dir|
      outside = File.join(outside_dir, 'some_file.txt')
      Open.write(outside, "x\n")
      assert_denied(outside, :read)
      assert_denied(outside, :write)
    end
  end

  # 2. Symlink target containment: the grant must contain the resolved
  #    target, not just the lexical spelling of the link.
  def test_symlink_pointing_outside_grant_is_denied
    isolated_grant_dir do |grant|
      isolated_grant_dir('workspace-fs-outside-target') do |outside_target|
        # outside_target is a real existing directory, granted to no one.
        link = File.join(grant, 'outside_link')
        File.symlink(outside_target, link)
        with_grants(writable: [grant]) do
          # The link is lexically inside the grant, but its target is
          # outside every grant: denied.
          assert_denied(link, :read)
          assert_denied(link, :write)
          # The grant directory itself still works.
          assert_equal grant, normalize(grant, :write)
        end
      end
    end
  end

  def test_symlink_inside_grant_allowed_and_spelling_preserved
    isolated_grant_dir do |grant|
      target = File.join(grant, 'target.txt')
      Open.write(target, "content\n")
      link = File.join(grant, 'inner_link')
      File.symlink(target, link)
      with_grants(writable: [grant]) do
        result = normalize(link, :read)
        assert_equal link, result
        assert !result.end_with?('target.txt'), 'must not resolve to canonical target'
        assert_equal link, normalize(link, :write)
      end
    end
  end

  # 3. Missing descendants under a writable grant authorize for write.
  def test_missing_descendant_under_writable_grant_allowed
    isolated_grant_dir do |grant|
      missing = File.join(grant, 'new_dir', 'new_file.txt')
      assert !File.exist?(missing)
      with_grants(writable: [grant]) do
        assert_equal missing, normalize(missing, :write)
        assert_equal missing, normalize(missing, :read)
      end
    end
  end

  # 4. Traversal: existing components collapse; a missing component makes
  #    the spelling unresolvable and it is NOT lexically collapsed.
  def test_traversal_with_existing_component_allowed
    isolated_grant_dir do |grant|
      Dir.mkdir(File.join(grant, 'a'))
      Open.write(File.join(grant, 'file'), "x\n")
      traversed = File.join(grant, 'a', '..', 'file')
      assert File.exist?(traversed)
      with_grants(writable: [grant]) do
        assert_equal traversed, normalize(traversed, :write)
      end
    end
  end

  def test_traversal_after_missing_component_not_collapsed
    isolated_grant_dir do |grant|
      assert !File.exist?(File.join(grant, 'a'))
      missing_component = File.join(grant, 'a', 'missing', '..', 'file')
      with_grants(writable: [grant]) do
        assert_denied(missing_component, :write)
      end
    end
  end

  # 5. A read-only grant permits read but not write at the same path.
  def test_read_only_grant_permits_read_but_not_write
    isolated_grant_dir do |dir|
      file = File.join(dir, 'ro.txt')
      Open.write(file, "x\n")
      with_grants(readable: [dir]) do
        assert_equal file, normalize(file, :read)
        assert_denied(file, :write)
      end
    end
  end

  # 6. Relative spellings resolve against the process PWD (the base_path
  #    Workspace passes to authorize_path).
  def test_relative_path_resolved_against_process_pwd
    Dir.chdir(Workspace.root.to_s) do
      assert_equal 'workflow.rb', normalize('workflow.rb', :read)
      assert_equal './workflow.rb', normalize('./workflow.rb', :read)
    end

    sub = File.join(Workspace.root, 'tmp')
    Dir.chdir(sub) do
      assert_denied('../../etc/passwd', :read)
    end
  end
end
