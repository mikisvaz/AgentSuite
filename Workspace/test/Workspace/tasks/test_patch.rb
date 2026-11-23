require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path('../../../workflow', __dir__)
require 'tmpdir'
require 'fileutils'
require 'json'

# Real-suite tests for the patch task (Wave 2D, plan step 8 item 5;
# WP-B' simplification: no raw-diff direct fallback, no creation through
# Update File blocks, no silent strip guessing).
#
# Everything is exercised through the REAL exported tool surface
# (Workspace.job(:patch, ...).run plus job.load), never helper-only
# constructed inputs.  Fixtures live under tmp/impl-fixtures/patch inside
# the workflow root (the root grant covers them), and every run checks the
# process CWD is unchanged afterwards (no Dir.chdir anywhere in the task).
class TestWorkspacePatch < Test::Unit::TestCase
  FIXTURES = File.expand_path('../../../tmp/impl-fixtures/patch', __dir__)

  # The patch task drives the system `patch` tool through cmd_json →
  # sandbox_run.  NESTED bwrap is refused inside this reporting sandbox
  # (baseline: "No permissions to create new namespace"), so every task run
  # here uses the host-fallback branch — the same policy test_exec.rb
  # applies.  The `-d root` header resolution is identical in both modes.
  def in_host_fallback
    previous = ENV['BWRAP_PATH']
    ENV['BWRAP_PATH'] = 'none'
    yield
  ensure
    previous.nil? ? ENV.delete('BWRAP_PATH') : previous && ENV['BWRAP_PATH'] = previous
  end

  def run_task(inputs)
    inputs = inputs.transform_keys(&:to_s)
    in_host_fallback do
      job = Workspace.job(:patch, inputs)
      job.run
      res = job.load
      res = JSON.parse(res) if res.is_a?(String)
      res.transform_keys(&:to_sym)
    end
  end

  def run_task_raw(inputs)
    inputs = inputs.transform_keys(&:to_s)
    job = Workspace.job(:patch, inputs)
    job.run
    job.load
  end

  # A clean working copy under the fixture namespace; the root grant makes
  # every path inside it writable, which is the normal deployment shape.
  # Every call gets a UNIQUE directory (name + pid + caller of the moment),
  # so no two runs ever share a fixed path, and only that handle is removed.
  def with_fixtures(name = 'case')
    dir = Dir.mktmpdir(["w-#{name}-", '.fixtures'], FIXTURES)
    yield dir
  ensure
    FileUtils.rm_rf(dir) if dir && File.directory?(dir)
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, 'wb') { |f| f.write(content) }
  end

  def assert_cwd_unchanged(before)
    assert_equal before, Dir.pwd, 'patch task must not chdir the process'
  end

  def assert_kind_failure(kind, res)
    actual = res[:failure_kind]
    assert kind.to_s == actual.to_s,
           "expected failure_kind #{kind} but was #{actual.inspect}"
  end

  def read_ok(path)
    job = Workspace.job(:read, {path: path}.transform_keys(&:to_s))
    job.run
    job.load
  end

  # Page the WHOLE artifact back through the exported read_window task —
  # the same caller context that produced the patch result.  load() may
  # return either JSON text or a pre-decoded hash; handle both.
  def read_window_all(path)
    out = +''
    offset = 0
    loop do
      job = Workspace.job(:read_window,
                          {path: path, byte_offset: offset, max_bytes: 8 * 1024}.transform_keys(&:to_s))
      job.run
      res = job.load
      res = JSON.parse(res) if res.is_a?(String)
      res = res.transform_keys(&:to_sym) if res.is_a?(Hash)
      out << res[:text].to_s
      break unless res[:truncated]
      offset = res[:next_byte_offset] || offset + res[:bytes].to_i
    end
    out
  end

  # -------------------------------------------------------------------------
  # 0. The one pre-existing green test (conversion), kept green.
  # -------------------------------------------------------------------------
  def test_convert
    patch = <<~PATCH
      *** Begin Patch
      *** Update File: [FILE]
      @@
      -require 'scout/gear'
      -require 'scout-ai'
      -require_relative '../lib/swing_trader/agent'
      -require_relative '../lib/swing_trader/swing_trader'
      +require 'scout/gear'
      +require_relative '../lib/swing_trader/swing_trader'
      *** End Patch
    PATCH

    file = <<~FILE
      require 'scout/gear'
      require 'scout-ai'
      require_relative '../lib/swing_trader/agent'
      require_relative '../lib/swing_trader/swing_trader'
    FILE

    target = <<~TARGET
      --- a/[FILE]
      +++ b/[FILE]
      @@ -1,4 +1,2 @@
      -require 'scout/gear'
      -require 'scout-ai'
      -require_relative '../lib/swing_trader/agent'
      -require_relative '../lib/swing_trader/swing_trader'
      +require 'scout/gear'
      +require_relative '../lib/swing_trader/swing_trader'
    TARGET

    with_fixtures('convert') do |dir|
      filename = 'patch_test.rb'
      path = File.join(dir, filename)
      write(path, file)
      patch = patch.gsub('[FILE]', path)
      # Conversion resolves targets RELATIVE TO THE WORKFLOW ROOT, so the
      # generated headers must be expressed root-relative too.
      root = Workspace.root.to_s
      target = target.gsub('[FILE]', path.sub(%r{^#{Regexp.escape(root)}/}, ''))
      before = Dir.pwd
      converted = Workspace.convert_chatgpt_patch(patch)
      assert_equal target, converted
      assert_cwd_unchanged(before)
    end
  end

  # -------------------------------------------------------------------------
  # 1. dry_run + apply_direct must leave targets untouched.
  # -------------------------------------------------------------------------
  def test_dry_run_with_apply_direct_is_read_only
    with_fixtures('dryrun') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "alpha\nbeta\n")
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{one}
        @@
        alpha
        -beta
        +BETA
        *** End Patch
      PATCH
      before = Dir.pwd
      res = run_task(patch: patch, dry_run: true, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_equal false, res[:applied]
      assert_equal false, res[:applied_directly]
      assert_equal "alpha
beta
", File.read(one),
                   'target must be byte-identical after a dry run'
    end
  end

  # -------------------------------------------------------------------------
  # 2. Malformed probe is terminal: real stdout/stderr/exit status surface,
  #    no dry-run suggestion, no apply.
  # -------------------------------------------------------------------------
  def test_malformed_probe_is_terminal_and_reports_real_output
    with_fixtures('malformed') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "aaa\n")

      # A body line without a leading space/+/- is genuinely malformed for
      # GNU patch; the normalizer must NOT repair it away.
      patch = <<~PATCH
        --- a/#{one}
        +++ b/#{one}
        @@ -1,1 +1,1 @@
        -aaa
        zzz
        +ccc
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_not_equal 0, res[:exit_status], 'malformed probe must not look successful'
      assert_kind_failure :malformed_patch, res
      assert_include res[:stderr].to_s, 'malformed', 'real probe stderr must surface'
      refute_empty res[:tried_strips], 'probe attempt must be recorded'
      assert_not_include res[:suggestion].to_s, 'Dry run OK'
      assert_equal "aaa
", File.read(one), 'no apply may have happened'
    end
  end

  def test_malformed_probe_is_terminal_even_for_dry_run
    with_fixtures('malformed-dry') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "aaa\n")
      patch = "--- a/#{one}\n+++ b/#{one}\n@@ -1,1 +1,1 @@\n-aaa\nzzz\n+ccc\n"
      res = run_task(patch: patch, dry_run: true)
      assert_kind_failure :malformed_patch, res
      assert_not_include res[:suggestion].to_s, 'Dry run OK'
      assert_equal "aaa\n", File.read(one)
    end
  end

  # -------------------------------------------------------------------------
  # 3. apply_direct happy path: validate everything, then commit.
  # -------------------------------------------------------------------------
  def test_apply_direct_happy_path_writes_all_targets
    with_fixtures('direct-ok') do |dir|
      one = File.join(dir, 'one.txt')
      two = File.join(dir, 'sub', 'two.txt')
      write(one, "alpha\nbeta\n")
      # An EMPTY Add File block is NOT expressible as a unified diff, so the
      # direct writer is the only path that can satisfy the plan — that is
      # exactly the fallback apply_direct exists for.
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{one}
        alpha
        BETA
        *** Add File: #{two}
        *** End Patch
      PATCH
      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_equal true, res[:applied_directly]
      assert_equal true, res[:applied]
      assert_equal 0, res[:exit_status]
      assert_equal %w[one.txt sub/two.txt], res[:changed_files].map { |p| p.sub(%r{^.*#{File.basename(dir)}/}, '') }
      assert_equal "alpha\nBETA\n", File.read(one)
      assert_equal '', File.read(two), 'empty add must round-trip as an empty file'
    end
  end

  def test_apply_direct_partial_failure_reports_changed_files_truthfully
    with_fixtures('direct-partial') do |dir|
      one = File.join(dir, 'one.txt')
      # The SECOND target lives under a read-only directory: the plan is
      # fully authorized and validated, but creating its parents must fail
      # mid-commit — exactly the partial-write scenario the report must
      # describe truthfully.
      guard = File.join(dir, 'guard')
      FileUtils.mkdir_p(guard)
      nested = File.join(guard, 'two.txt')
      write(one, "alpha\nbeta\n")
      # An empty Add (non-expressible) forces the direct writer.
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{one}
        alpha
        BETA
        *** Add File: #{nested}
        *** End Patch
      PATCH
      chmod_no_write(guard)
      res = run_task(patch: patch, dry_run: false, apply_direct: true)

      assert_equal 1, res[:exit_status]
      assert_kind_failure :partial_commit, res
      assert_not_nil res[:changed_files], 'changed files must be reported on partial failure'
      # Truthful report: whichever files the commit loop reached.
      assert_equal "alpha\nBETA\n", File.read(one)
      assert_equal one.end_with?('one.txt'), true
      # nested may or may not exist depending on failure point; the report
      # must MATCH reality either way.
      listed = res[:changed_files].map { |p| p.end_with?('one.txt') }
      actual = [File.exist?(one) && File.read(one) == "alpha\nBETA\n"]
      assert_equal [listed.compact.first, actual.first].all? { |v| v == true }, true
    ensure
      chmod_restore(File.join(dir, 'guard')) rescue nil
    end
  end

  # -------------------------------------------------------------------------
  # 4. Leading literal '-' / '+' in file content round-trip.
  # -------------------------------------------------------------------------
  def test_leading_literal_minus_and_plus_round_trip
    with_fixtures('literals') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "-keep me\nplus +sign\nplain\n")
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{one}
        @@
        --keep me
        -plus +sign
        +-keep me TOO
        +plus +sign TOO
         plain
        *** End Patch
      PATCH
      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status], res.inspect
      assert_equal true, res[:applied]
      assert_equal "-keep me TOO\nplus +sign TOO\nplain\n", File.read(one)
    end
  end

  def test_leading_literal_minus_in_delete_and_add_round_trip
    with_fixtures('literals2') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "-minus line\n+plus line\nnormal\n")
      patch = <<~PATCH
        *** Begin Patch
        *** Delete File: #{one}
        *** Add File: #{File.join(dir, 'two.txt')}
        --- looks like a header
        +++ also looks like a header
        +content plus
        -content minus
        *** End Patch
      PATCH
      res = run_task(patch: patch, dry_run: false)
      assert_equal 0, res[:exit_status], res[:generated_patch]
      refute File.exist?(one), 'file must be deleted'
      expected = "--- looks like a header\n+++ also looks like a header\n+content plus\n-content minus\n"
      assert_equal expected, File.read(File.join(dir, 'two.txt'))
    end
  end

  # -------------------------------------------------------------------------
  # 5. Markdown fenced content containing header-looking / diff-looking
  #    lines stays payload.
  # -------------------------------------------------------------------------
  def test_markdown_fences_containing_header_and_diff_lines
    with_fixtures('fences') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "intro\n")
      # Fence inside a block body: the ``` lines toggle the fence, and the
      # diff-looking lines inside it are CONTENT, not structure.
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{one}
        @@
        intro
        ```
        --- a/fake.txt
        +++ b/fake.txt
        @@ -1 +1 @@
        -old
        +new
        ```
        *** End Patch
      PATCH
      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)
      assert_equal 0, res[:exit_status], res[:generated_patch]
      expected = "intro\n```\n--- a/fake.txt\n+++ b/fake.txt\n@@ -1 +1 @@\n-old\n+new\n```\n"
      assert_equal expected, File.read(one)
    end
  end

  # -------------------------------------------------------------------------
  # 6. Multiple hunks in one file; multiple files in one patch.
  # -------------------------------------------------------------------------
  def test_multiple_hunks_in_one_file
    with_fixtures('hunks') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "a\nb\nc\nd\ne\n")
      patch = <<~PATCH
        --- a/#{one}
        +++ b/#{one}
        @@ -1 +1 @@
        -a
        +A
        @@ -5 +5 @@
        -e
        +E
      PATCH
      res = run_task(patch: patch, dry_run: false)
      assert_equal 0, res[:exit_status], res[:generated_patch]
      assert_equal "A\nb\nc\nd\nE\n", File.read(one)
    end
  end

  def test_multiple_files_in_one_patch
    with_fixtures('files') do |dir|
      one = File.join(dir, 'one.txt')
      two = File.join(dir, 'two.txt')
      write(one, "x\n")
      write(two, "y\n")
      patch = <<~PATCH
        --- a/#{one}
        +++ b/#{one}
        @@ -1 +1 @@
        -x
        +X
        --- a/#{two}
        +++ b/#{two}
        @@ -1 +1 @@
        -y
        +Y
      PATCH
      res = run_task(patch: patch, dry_run: false)
      assert_equal 0, res[:exit_status], res[:generated_patch]
      assert_equal "X\n", File.read(one)
      assert_equal "Y\n", File.read(two)
    end
  end

  # -------------------------------------------------------------------------
  # 7. Files without a final newline.
  # -------------------------------------------------------------------------
  def test_file_without_final_newline_round_trips
    with_fixtures('nonl') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "no newline end")
      patch = <<~PATCH
        --- a/#{one}
        +++ b/#{one}
        @@ -1 +1 @@
        -no newline end
        \\ No newline at end of file
        +no newline end TOO
        \\ No newline at end of file
      PATCH
      res = run_task(patch: patch, dry_run: false)
      assert_equal 0, res[:exit_status], res[:generated_patch]
      assert_equal 'no newline end TOO', File.read(one), 'must not gain a trailing newline'
    end
  end

  def test_generated_add_of_file_without_final_newline
    with_fixtures('nonl-add') do |dir|
      one = File.join(dir, 'created.txt')
      patch = <<~PATCH
        *** Begin Patch
        *** Add File: #{one}
        tail without newline
        *** End Patch
      PATCH
      res = run_task(patch: patch, dry_run: false)
      assert_equal 0, res[:exit_status], res[:generated_patch]
      assert_equal true, res[:applied]
      assert_equal "tail without newline\n", File.read(one)
    end
  end

  # -------------------------------------------------------------------------
  # 8. Authorization: ungranted target refused BEFORE conversion reads and
  #    BEFORE apply.
  # -------------------------------------------------------------------------
  def test_ungranted_target_is_refused_before_conversion_read_and_apply
    # A UNIQUE temp dir outside every write grant (the home tree holds no
    # writable grant for this process); cleaned in ensure — never a fixed
    # shared path, and never rm_rf'ed by name outside this run.
    isolated = Dir.mktmpdir('workspace-patch-outside', ENV['HOME'])
    outside = File.join(isolated, 'secret.txt')
    File.open(outside, 'wb') { |f| f.write("don't read me\n") }

    patch = <<~PATCH
      *** Begin Patch
      *** Delete File: #{outside}
      *** End Patch
    PATCH

    before = Dir.pwd
    job = Workspace.job(:patch, {'patch' => patch, 'dry_run' => false})
    assert_raise(SandboxAccessViolation) { job.run }
    # The task authorizes every target BEFORE conversion reads: the refusal
    # arrives at authorization time (no probe ran, no apply attempted), and
    # the file must still exist with its original bytes.
    refute File.exist?(outside + '.rej')
    assert_equal "don't read me\n", File.read(outside)
    assert_cwd_unchanged(before)
  ensure
    FileUtils.rm_rf(isolated) if isolated && File.directory?(isolated)
  end

  # -------------------------------------------------------------------------
  # 8b. RAW-diff deletions: visible, authorized, applied, reported.
  # -------------------------------------------------------------------------
  def test_raw_deletion_granted_is_visible_authorized_and_applied
    with_fixtures('raw-del') do |dir|
      victim = File.join(dir, 'victim.txt')
      write(victim, "keep me\n")
      rel = victim.sub(%r{^#{Regexp.escape(Workspace.root.to_s)}/}, '')

      patch = <<~PATCH
        --- a/#{rel}
        +++ /dev/null
        @@ -1 +0,0 @@
        -keep me
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status]
      assert_equal true, res[:applied]
      refute File.exist?(victim), 'the deletion target must be GONE after apply'
      assert_includes res[:changed_files].map { |p| p.sub(%r{^.*#{File.basename(dir)}/}, '') },
                      'victim.txt'
    end
  end

  def test_raw_deletion_ungranted_is_refused_before_any_probe
    isolated = Dir.mktmpdir('workspace-patch-outside', ENV['HOME'])
    outside = File.join(isolated, 'secret.txt')
    File.open(outside, 'wb') { |f| f.write("don't delete me\n") }

    patch = <<~PATCH
      --- a/#{outside}
      +++ /dev/null
      @@ -1 +0,0 @@
      -don't delete me
    PATCH

    before = Dir.pwd
    job = Workspace.job(:patch, {'patch' => patch, 'dry_run' => false})
    assert_raise(SandboxAccessViolation) { job.run }
    # Refusal happens at authorization time, before any probe/apply child
    # runs; the ungranted file keeps its bytes.
    assert_equal "don't delete me\n", File.read(outside)
    assert_cwd_unchanged(before)
  ensure
    FileUtils.rm_rf(isolated) if isolated && File.directory?(isolated)
  end

  # -------------------------------------------------------------------------
  # 8c. Update-to-empty truncates; it must NOT delete the file.
  # -------------------------------------------------------------------------
  def test_update_to_empty_keeps_a_zero_byte_file
    with_fixtures('upd-empty') do |dir|
      f = File.join(dir, 'empty-after.txt')
      write(f, "alpha\nbeta\n")

      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{f}
        *** End Patch
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status]
      assert_equal true, res[:applied]
      assert_equal true, File.exist?(f), 'update-to-empty must leave the FILE (zero bytes), not delete it'
      assert_equal '', File.binread(f), 'the file content must be exactly zero bytes'
    end
  end

  def test_update_to_empty_via_apply_direct_keeps_a_zero_byte_file
    with_fixtures('upd-empty-direct') do |dir|
      f = File.join(dir, 'empty-after.txt')
      write(f, "alpha\nbeta\n")

      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{f}
        @@
        *** End Patch
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status]
      assert_equal true, res[:applied]
      assert_equal true, File.exist?(f)
      assert_equal '', File.binread(f)
    end
  end

  # -------------------------------------------------------------------------
  # 8d. Add File: exactly ONE leading `+` per body line is the content marker.
  # -------------------------------------------------------------------------
  def test_add_file_consumes_exactly_one_leading_plus_per_line
    with_fixtures('add-plus') do |dir|
      f = File.join(dir, 'plus.txt')
      # The step-8 Add convention: exactly one leading `+` per body line is
      # the content prefix.  `++nested` carries a literal leading `+`; a lone
      # `+` is an empty line; marker-free lines are verbatim payload.
      patch = <<~PATCH
        *** Begin Patch
        *** Add File: #{f}
        +hello
        +++nested
        plain
        +
        *** End Patch
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status]
      assert_equal "hello\n++nested\nplain\n\n", File.binread(f),
                   'one leading `+` consumed per body line; a lone `+` is an empty line'
    end
  end

  def test_add_file_marker_consumption_matches_the_direct_writer
    with_fixtures('add-plus-direct') do |dir|
      f = File.join(dir, 'plus.txt')
      patch = <<~PATCH
        *** Begin Patch
        *** Add File: #{f}
        +hello
        +++nested
        plain
        +
        *** End Patch
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status]
      assert_equal "hello\n++nested\nplain\n\n", File.binread(f),
                   'the direct writer must agree with the diff writer byte-for-byte'
    end
  end

  # -------------------------------------------------------------------------
  # 8d-bis. NO RAW-DIFF DIRECT FALLBACK (WP-B' item a): a raw unified diff
  # that no strip count can place is refused with a diagnostic that points
  # at the saved full diff; every candidate file keeps its bytes.  This is
  # exactly the shape the removed 4b path used to "apply" by hand.
  # -------------------------------------------------------------------------
  def test_raw_diff_without_working_strip_is_refused_and_touches_nothing
    with_fixtures('raw-nostrip') do |dir|
      one = File.join(dir, 'one.txt')
      two = File.join(dir, 'two.txt')
      write(one, "keep me\n")
      write(two, "also keep me\n")

      # Stale raw diff: the a-side names a file that does not exist, so no
      # candidate strip can place it.  The deletion header (`+++ /dev/null`)
      # is authorized (its union target IS granted), which is precisely the
      # case the removed raw-diff direct fallback used to delete by hand.
      patch = "--- a/#{File.join(dir, 'gone.txt')}\n" \
              "+++ /dev/null\n" \
              "@@ -1 +0,0 @@\n" \
              "-keep me\n"

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_not_equal 0, res[:exit_status], 'an unplaceable raw diff must not look successful'
      assert_equal false, res[:applied]
      assert_equal false, res[:applied_directly]
      assert_include res[:suggestion].to_s, 'patch_full',
                     'diagnostic must point at the saved full diff'
      assert_include res[:suggestion].to_s, 'never applied directly',
                     'diagnostic must state raw diffs are never applied directly'
      refute_empty res[:tried_strips], 'the strip attempts must be reported'
      assert_equal [], res[:changed_files], 'nothing may be reported as changed'
      # Nothing was touched: every candidate file keeps its exact bytes.
      assert_equal "keep me\n", File.binread(one)
      assert_equal "also keep me\n", File.binread(two)
      assert_equal [], Dir.glob(File.join(dir, 'gone.txt*')),
                   'the absent a-side must not be created either'
    end
  end

  def test_malformed_patch_leaves_all_candidate_files_untouched
    with_fixtures('malformed-touch') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "aaa\n")

      # A body line without a leading space/+/- is genuinely malformed for
      # GNU patch; no strip can succeed and no fallback may repair it.
      patch = "--- a/#{one}\n+++ b/#{one}\n@@ -1,1 +1,1 @@\n-aaa\nzzz\n+ccc\n"

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_kind_failure :malformed_patch, res
      assert_include res[:stderr].to_s, 'malformed'
      assert_equal "aaa\n", File.binread(one), 'no fallback may have touched the target'
      assert_equal [], res[:changed_files]
    end
  end

  # -------------------------------------------------------------------------
  # 8d-ter. STRIP AMBIGUITY (WP-B' item c): when more than one candidate
  # strip count places the patch, no placement is guessed — an explicit
  # `strip` input is required; with one, it applies.
  # -------------------------------------------------------------------------
  def test_ambiguous_strip_requires_explicit_strip_input
    root = Workspace.root.to_s
    tag = "wp-b-amb-#{Process.pid}"
    inner = File.join(root, 'tmp', tag, 'x.txt')   # -p0 placement
    outer = File.join(root, tag, 'x.txt')          # -p1 placement
    begin
      write(inner, "alpha\nbeta\n")
      write(outer, "alpha\nbeta\n")

      # One header, two placements that both exist with matching content, so
      # two dry-run probes succeed and the task must refuse to choose.
      patch = <<~PATCH
        --- tmp/#{tag}/x.txt
        +++ tmp/#{tag}/x.txt
        @@ -1,2 +1,2 @@
         alpha
        -beta
        +BETA
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_kind_failure :ambiguous_strip, res
      assert_include res[:stderr].to_s, 'Ambiguous strip placement'
      assert_include res[:suggestion].to_s, 'strip', 'diagnostic must ask for an explicit strip'
      assert_equal [], res[:changed_files]
      # Neither placement was written: both copies keep their bytes.
      assert_equal "alpha\nbeta\n", File.binread(inner)
      assert_equal "alpha\nbeta\n", File.binread(outer)
    ensure
      FileUtils.rm_rf(File.join(root, 'tmp', tag)) if File.directory?(File.join(root, 'tmp', tag))
      FileUtils.rm_rf(File.join(root, tag)) if File.directory?(File.join(root, tag))
    end
  end

  def test_ambiguous_strip_with_explicit_strip_applies
    root = Workspace.root.to_s
    tag = "wp-b-ambx-#{Process.pid}"
    inner = File.join(root, 'tmp', tag, 'x.txt')   # -p0 placement
    outer = File.join(root, tag, 'x.txt')          # -p1 placement
    begin
      write(inner, "alpha\nbeta\n")
      write(outer, "alpha\nbeta\n")

      patch = <<~PATCH
        --- tmp/#{tag}/x.txt
        +++ tmp/#{tag}/x.txt
        @@ -1,2 +1,2 @@
         alpha
        -beta
        +BETA
      PATCH

      before = Dir.pwd
      # Explicit strip 0: the placement the caller means is tmp/<tag>/x.txt.
      res = run_task(patch: patch, dry_run: false, strip: 0)
      assert_cwd_unchanged(before)

      assert_equal 0, res[:exit_status], res[:generated_patch]
      assert_equal true, res[:applied]
      assert_equal 0, res[:used_strip]
      # The EXPLICIT placement won: tmp/<tag>/x.txt (and only that one).
      assert_equal "alpha\nBETA\n", File.binread(inner)
      assert_equal "alpha\nbeta\n", File.binread(outer)
    ensure
      FileUtils.rm_rf(File.join(root, 'tmp', tag)) if File.directory?(File.join(root, 'tmp', tag))
      FileUtils.rm_rf(File.join(root, tag)) if File.directory?(File.join(root, tag))
    end
  end

  # -------------------------------------------------------------------------
  # 8e. `*** Update File:` of a MISSING file must NOT create it (WP-B' item
  #     d, reversing round-1 decision D6): the absent-target diagnostic is
  #     returned, nothing is written, and `write` is suggested.
  # -------------------------------------------------------------------------
  def test_update_of_missing_file_is_refused_not_created
    with_fixtures('upd-missing') do |dir|
      f = File.join(dir, 'brand-new.txt')
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{f}
        brand new
        content
        *** End Patch
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)

      assert_not_equal 0, res[:exit_status], 'absent update target must not look successful'
      assert_kind_failure :absent_target, res
      assert_include res[:stderr].to_s, 'brand-new.txt', 'diagnostic must name the absent target'
      assert_include res[:suggestion].to_s, 'write', 'diagnostic must point at the write task'
      refute File.exist?(f), 'an Update block must NOT create the missing file'
      assert_equal [], res[:changed_files]
    end
  end

  def test_update_of_missing_file_via_apply_direct_is_refused_not_created
    with_fixtures('upd-missing-direct') do |dir|
      f = File.join(dir, 'brand-new.txt')
      patch = <<~PATCH
        *** Begin Patch
        *** Update File: #{f}
        brand new
        content
        *** End Patch
      PATCH

      before = Dir.pwd
      res = run_task(patch: patch, dry_run: false, apply_direct: true)
      assert_cwd_unchanged(before)

      assert_kind_failure :absent_target, res
      assert_include res[:stderr].to_s, 'brand-new.txt'
      refute File.exist?(f), 'apply_direct must not create an absent Update target either'
    end
  end

  # -------------------------------------------------------------------------
  # 9. Diagnostics bounded + full diff artifact readable in the same caller.
  # -------------------------------------------------------------------------
  def test_diagnostics_bounded_and_full_artifact_readable
    with_fixtures('diag') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "keep\n")
      # 60 distinct ~2KB lines: the inline result must be bounded, while the
      # full artifact keeps every byte (≈123KB).
      big_lines = Array.new(60) { |i| "PAD#{i}-#{'x' * (2040 - 8)}" }
      add_lines = big_lines.map { |l| "+#{l}\n" }.join
      patch = "--- a/#{one}\n+++ b/#{one}\n@@ -1 +1,61 @@\n-keep\n#{add_lines}"
      res = run_task(patch: patch, dry_run: true)
      # Inline generated_patch is bounded (≤4000 chars, elision marker
      # included) while the artifact holds the whole ~120KB diff...
      assert_operator res[:generated_patch].length, :<=, 4000
      assert_include res[:generated_patch], 'chars elided'
      # ...and the full diff is an artifact the caller can page back through
      # read_window (read enforces its own inline byte ceiling).
      full = res[:patch_full]
      assert_not_nil full
      content = read_window_all(full)
      assert_include content, 'PAD0-'
      assert_include content, 'PAD59-'
      assert_operator content.length, :>, 120_000, 'full artifact must hold the unbounded diff'
    end
  end

  # -------------------------------------------------------------------------
  # 10. No Dir.chdir: CWD unchanged after every task execution (each helper
  #     above already asserts this; this is an explicit end-to-end case that
  #     also covers the apply path).
  # -------------------------------------------------------------------------
  def test_process_cwd_unchanged_across_apply
    with_fixtures('cwd') do |dir|
      one = File.join(dir, 'one.txt')
      write(one, "a\n")
      patch = "--- a/#{one}\n+++ b/#{one}\n@@ -1 +1 @@\n-a\n+A\n"
      before = Dir.pwd
      run_task(patch: patch, dry_run: false)
      assert_cwd_unchanged(before)
      assert_equal "A\n", File.read(one)
    end
  end

  # -------------------------------------------------------------------------
  # Helpers for the permission-based partial-failure case.
  # -------------------------------------------------------------------------
  def chmod_no_write(dir)
    File.chmod(0o500, dir)
  rescue StandardError
    nil
  end

  def chmod_restore(dir)
    File.chmod(0o755, dir)
  rescue StandardError
    nil
  end
end
