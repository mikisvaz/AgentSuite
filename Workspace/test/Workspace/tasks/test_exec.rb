require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path('../../../workflow', __dir__)
require 'tmpdir'

# Wave 2A (plan steps 2, 4, 8-exec) — shell failure path for
# lib/Workspace/tasks/exec.rb.  Cases drive the EXPORTED bash tool through
# LLM.call_workflow (real schema, real result decoding), not only helper
# internals.  bwrap cases probe capability at test time: NESTED bwrap is
# refused inside this sandbox (baseline finding: "No permissions to create
# new namespace"), so the bwrap-capable tests SKIP with a recorded reason
# and the host-fallback path is ALWAYS exercised as an independent case.

class TestExec < Test::Unit::TestCase
  FIXTURE_BIN = File.expand_path('../../../tmp/impl-fixtures/bin', __dir__)
  MISSING_EXE = 'definitely-not-a-real-executable-xyz'

  def call_bash(cmd, extra = {})
    LLM.call_workflow(Workspace, :bash, { 'cmd' => cmd, 'timeout' => 20 }.merge(extra))
  end

  def in_host_fallback
    previous = ENV['BWRAP_PATH']
    ENV['BWRAP_PATH'] = 'none'
    yield
  ensure
    previous.nil? ? ENV.delete('BWRAP_PATH') : ENV['BWRAP_PATH'] = previous
  end

  def nested_bwrap_possible?
    # Capability probe (baseline: nested bwrap refused inside the sandbox).
    system('bwrap', '--ro-bind', '/', '/', '--dev', '/dev', '--', '/bin/true',
           out: File::NULL, err: File::NULL)
  end

  # --- Acceptance matrix -------------------------------------------------

  def test_ordinary_nonzero_exit_returns_real_status_and_verbatim_streams
    in_host_fallback do
      r = call_bash(%(printf 'before\n'; printf 'bad row 9\n' >&2; exit 7))
      assert_equal 7, r[:exit_status]
      assert_equal "before\n", r[:stdout]
      assert_equal "bad row 9\n", r[:stderr]
      assert_equal 'host_fallback', r[:execution_mode]
    end
  end

  def test_silent_nonzero_exit_returns_empty_streams
    in_host_fallback do
      r = call_bash('exit 7')
      assert_equal 7, r[:exit_status]
      assert_equal '', r[:stdout]
      assert_equal '', r[:stderr]
      assert_nil r[:failure_kind]
    end
  end

  def test_stdout_flood_is_bounded_head_tail_and_spooled_readable
    in_host_fallback do
      # 1200 lines * ~10 B = ~12 KB total: far above the 4000-char inline
      # bound (so bounding/spooling kick in) yet below the read tool's
      # 16 KiB inline ceiling (so a single read returns every line).
      r = call_bash("ruby -e '1200.times{|i| puts \"line-\" + i.to_s }'")
      assert_equal 0, r[:exit_status]
      assert_operator r[:stdout].length, :<=, 4000
      assert_operator r[:stdout].lines.size, :<, 1200, 'inline copy must be bounded'
      refute_nil r[:stdout_full], 'spool path must be advertised'
      # Complete stream readable via the exported read tool, same context.
      # (read defaults to 100 lines and has a 16 KiB inline ceiling, so ask
      # for all lines; the spool is ~12 KiB, below the ceiling.)
      content = LLM.call_workflow(Workspace, :read,
                                  { 'path' => r[:stdout_full], 'limit' => 4000 })
      lines = content.to_s.lines
      assert_equal 1200, lines.size, 'spooled stream must be COMPLETE'
      assert_equal 'line-0', lines.first.chomp
      assert_equal 'line-1199', lines.last.chomp
      # In-order head+tail: the head of the stream survives inline.
      assert_equal 'line-0', r[:stdout].lines.first.chomp
      assert r[:stdout].include?('line-1199'), 'tail of the stream must survive inline'
    end
  end

  def test_stderr_flood_is_bounded_inclusive_of_markers_and_spooled
    in_host_fallback do
      r = call_bash("bash -c 'for i in $(seq 1 1200); do echo \"errline-$i\" >&2; done; exit 1'")
      assert_equal 1, r[:exit_status]
      assert_operator r[:stderr].length, :<=, 4000,
                      'marker/elision text must be INSIDE the budget'
      refute_nil r[:stderr_full]
      content = LLM.call_workflow(Workspace, :read,
                                  { 'path' => r[:stderr_full], 'limit' => 2000 })
      assert_equal 1200, content.to_s.lines.size, 'spooled stderr must be COMPLETE'
      # First actionable child message survives inline.
      assert r[:stderr].include?('errline-1'), 'first actionable message must survive'
      # Tail also survives.
      assert r[:stderr].include?('errline-1200'), 'tail must survive'
    end
  end

  def test_timeout_reports_kind_without_fabricated_exit_code
    in_host_fallback do
      r = call_bash('sleep 30', 'timeout' => 3)
      assert_equal :timeout, r[:failure_kind]
      assert_equal(-1, r[:exit_status], 'sentinel only: no exit code exists')
    end
  end

  def test_unavailable_executable_is_launch_failure_not_exit_one
    in_host_fallback do
      # WP-E, plan step 2b: exit 127 with "not found" words in child output
      # is an ORDINARY exit — the word inference is gone.  bash itself exits
      # 127 (a real exit code, reported as-is) and the shared stream rule
      # returns the shell's own message verbatim (small stream → no bound,
      # no spool).  A GENUINE launch failure is covered separately below.
      r = call_bash(MISSING_EXE, 'env' => { 'PATH' => FIXTURE_BIN })
      assert_nil r[:failure_kind], 'exit 127 must NOT be reclassified as launch'
      assert_equal 127, r[:exit_status], 'real exit code stays 127'
      assert_match /not found/i, r[:stderr], 'shell message must survive under the shared rule'
      refute_match /\A\W*exit status 1\W*\z/, r[:stderr].to_s
    end
  end

  def test_genuine_spawn_failure_is_launch_with_minus_one
    in_host_fallback do
      # WP-E, plan step 2b: :launch comes ONLY from a runner fact — popen3
      # could not start the executable (CMD returns nil), never from exit
      # codes or output words.  Driven at the runner boundary because the
      # exported bash tool deliberately starts /bin/bash itself.
      step = Object.new.extend Workspace.step_module
      r = step.run_child(['/nonexistent/exe-genuine-xyz', '--flag'],
                         cwd: Dir.pwd, timeout: 10, execution_mode: 'host_fallback')
      assert_equal :launch, r[:failure_kind]
      assert_equal(-1, r[:exit_status], 'no exit code exists — sentinel only')
      assert_equal '', r[:stdout], 'stdout text, never nil'
      assert_match /nonexistent\/exe-genuine-xyz/, r[:stderr]
      assert_instance_of String, r[:stderr], 'stderr text, never nil'
    end
  end

  # --- Serialized tool-result shape -------------------------------------

  def test_result_shape_fields_and_types
    in_host_fallback do
      r = call_bash('printf hi')
      assert_instance_of Hash, r
      %w[exit_status stdout stderr execution_mode].each do |f|
        assert r.key?(f.to_sym) || r.key?(f), "missing field #{f}"
      end
      assert_equal true, Integer === r[:exit_status] || Integer === r['exit_status']
      assert_equal true, String === r[:stdout] || String === r['stdout']
      assert_equal true, String === r[:stderr] || String === r['stderr']
    end
  end

  # --- bwrap / host-fallback modes ---------------------------------------

  def test_bwrap_mode_when_capability_allows
    omit_if(!nested_bwrap_possible?,
            'nested bwrap refused in this environment: bwrap case skipped, host-fallback covered independently')
    r = call_bash('echo in-bwrap')
    assert_equal 0, r[:exit_status]
    assert_equal 'bwrap', r[:execution_mode]
  end

  def test_host_fallback_mode_is_always_tested_and_reported
    in_host_fallback do
      r = call_bash('echo host')
      assert_equal 0, r[:exit_status]
      assert_equal 'host_fallback', r[:execution_mode],
                   'actual execution mode must be machine-readable, not just a Log.warn'
    end
  end

  # --- plan step 8: exec items --------------------------------------------

  def test_cmd_json_preserves_writable_paths_extras
    # plan step 8: cmd_json must compose writable paths into a FRESH array;
    # overwriting the parameter loses extras.  Exercised through the
    # exported ruby script task, which routes through cmd_json.
    in_host_fallback do
      r = LLM.call_workflow(Workspace, :ruby,
                            { 'jobname' => 'cmd_json_extras',
                              'code' => "puts 'cmd-json-ok'" })
      assert_equal 0, r[:exit_status], "stdout=#{r[:stdout].inspect} stderr=#{r[:stderr].to_s[0,200].inspect}"
      assert_match /cmd-json-ok/, r[:stdout].to_s
      assert_equal 'host_fallback', r[:execution_mode]
    end
  end

  def step_object
    o = Object.new
    o.extend Workspace.step_module
    o
  end

  def test_mount_dedup_three_alternating_permission_levels
    # ro->rw->ro chain: ro over a, rw over a/b, ro over a/b/c.  The final
    # read-only re-restriction must SURVIVE dedup — it is not shadowed by
    # the shallow ro ancestor, and it must not inherit rw from its parent.
    # Decisive planner-pure test: assert the EXACT emitted mount triples.
    tmp = Dir.mktmpdir('mount-dedup')
    %w[a a/b a/b/c].each { |d| FileUtils.mkdir_p(File.join(tmp, d)) }
    a, ab, abc = [tmp, File.join(tmp, 'a/b'), File.join(tmp, 'a/b/c')]
    mounts = step_object.plan_mounts([a, abc], [ab])
    expected = [[a, a, :ro], [ab, ab, :rw], [abc, abc, :ro]]
    assert_equal expected, mounts.map { |m| [m.source, m.destination, m.mode] },
                 'ro->rw->ro chain must emit all three mounts, parent-before-child'
  ensure
    FileUtils.remove_entry(tmp) if tmp
  end

  def test_mount_dedup_keeps_same_mode_descendant_with_different_relative_mapping
    # Same mode and same host subtree still does NOT prune when the
    # namespace-side relative position differs from the host-side one:
    # dd/D mounts host s at 'D', while dd/D/x mounts host s/z at 'D/x'
    # (x on the namespace side, z on the host side).  Pruning the child
    # would silently drop host s/z from the sandbox.
    s = Dir.mktmpdir('wp-a-c2src')
    dd = Dir.mktmpdir('wp-a-c2dst')
    begin
      FileUtils.mkdir_p(File.join(s, 'z'))
      FileUtils.ln_s(File.join(s, 'z'), File.join(s, 'x'))   # s/x -> s/z
      FileUtils.ln_s(s, File.join(dd, 'D'))                  # dd/D -> s
      dd_d = File.join(dd, 'D')
      dd_dx = File.join(dd, 'D', 'x')
      mounts = step_object.plan_mounts([dd_d, dd_dx], [])
      expected = [[s, dd_d, :ro], [File.join(s, 'z'), dd_dx, :ro]]
      assert_equal expected, mounts.map { |m| [m.source, m.destination, m.mode] },
                   'same-mode descendant with a different relative source mapping must survive'
    ensure
      FileUtils.remove_entry(s) if s
      FileUtils.remove_entry(dd) if dd
    end
  end

  def test_same_destination_ro_rw_resolved_to_rw_before_pruning
    # ro at d, ro AND rw both requested at d/c: the same-destination
    # resolution must run BEFORE pruning, so d/c is :rw (not a surviving
    # :ro child under the ro parent d) and d stays :ro.
    tmp = Dir.mktmpdir('same-dest-first')
    d = File.join(tmp, 'd'); dc = File.join(tmp, 'd', 'c')
    FileUtils.mkdir_p(dc)
    mounts = step_object.plan_mounts([d, dc], [dc])
    expected = [[d, d, :ro], [dc, dc, :rw]]
    assert_equal expected, mounts.map { |m| [m.source, m.destination, m.mode] },
                 'same-destination ro/rw must resolve to :rw before pruning'
  ensure
    FileUtils.remove_entry(tmp) if tmp
  end

  def test_same_mode_same_mapping_descendant_is_still_pruned
    # Guard against over-correction: a genuine same-mode descendant at the
    # same relative position is redundant and MUST still be pruned.
    tmp = Dir.mktmpdir('mount-dedup3')
    a = File.join(tmp, 'a'); ab = File.join(tmp, 'a', 'b')
    FileUtils.mkdir_p(ab)
    mounts = step_object.plan_mounts([a, ab], [])
    assert_equal [[a, a, :ro]], mounts.map { |m| [m.source, m.destination, m.mode] },
                 'same-mode same-mapping descendant is redundant and must be pruned'
  ensure
    FileUtils.remove_entry(tmp) if tmp
  end

  def test_mount_dedup_ro_child_under_rw_parent_stays_ro
    # The inverse alternation: a ro child under a rw parent of the same
    # source subtree is NOT redundant — its ro mode is stricter than the
    # parent's rw, so it must survive dedup.
    tmp = Dir.mktmpdir('mount-dedup2')
    %w[a a/b a/b/c].each { |d| FileUtils.mkdir_p(File.join(tmp, d)) }
    a, abc = [tmp, File.join(tmp, 'a/b/c')]
    mounts = step_object.plan_mounts([abc], [a])
    modes = Hash[mounts.collect { |m| [m.destination, m.mode.to_sym] }]
    assert_equal :rw, modes[a]
    assert_equal :ro, modes[abc], 'stricter ro child under rw parent must survive'
  ensure
    FileUtils.remove_entry(tmp) if tmp
  end

  def test_symlink_dependency_mount_is_limited_to_target_subtree
    tmp = Dir.mktmpdir('symlink-mount')
    target = File.join(tmp, 'target'); FileUtils.mkdir_p(target)
    link_dir = File.join(tmp, 'links'); FileUtils.mkdir_p(link_dir)
    dep = File.join(link_dir, 'dep')
    FileUtils.ln_s(target, dep)
    # Parent of the symlink is mounted (ro) so Phase 3 redirects the
    # dependent mount and Phase 4 must add the symlink's OWN target.
    mounts = step_object.plan_mounts([dep, link_dir], [])
    sources = mounts.collect(&:source)
    assert sources.any? { |s| s == target },
           "the symlink's own target (#{target}) must be mounted; got #{sources.inspect}"
    # The DEPENDENCY mounts added for symlinks must not be broader than the
    # target they exist to resolve: only the exact target subtree.
    dep_sources = sources - [link_dir, dep]
    dep_sources.each do |src|
      assert src == target, "dependency mount source #{src} is broader than the target subtree #{target}"
    end
  ensure
    FileUtils.remove_entry(tmp) if tmp
  end

  def test_execution_mode_present_in_every_result
    in_host_fallback do
      r1 = call_bash('true')
      r2 = call_bash('false')
      [r1, r2].each { |r| assert_equal 'host_fallback', r[:execution_mode] }
    end
  end

  # --- WP-E, plan step 2b: correction 1 (working directory) --------------

  def test_host_child_pwd_equals_working_root_when_root_differs_from_dir_pwd
    # Decisive cwd test: assert the CHILD'S OWN `pwd` OUTPUT, not the
    # reported cwd field.  Workspace.root is pointed at a temporary
    # directory that is deliberately NOT Dir.pwd; in host fallback the
    # spawned child must actually be there.
    require 'tmpdir'
    in_host_fallback do
      tmp = Dir.mktmpdir('wp-e-cwd')
      previous_root = Workspace.root
      begin
        refute_equal tmp, Dir.pwd, 'fixture must differ from Dir.pwd for the test to be decisive'
        Workspace.root = tmp
        r = call_bash("pwd # wp-e-cwd-#{Process.pid}")
        assert_equal 'host_fallback', r[:execution_mode]
        assert_equal tmp, r[:stdout].strip,
                     'the child process itself must report the working root as its pwd'
        assert_equal tmp, r[:cwd], 'the result must keep reporting cwd truthfully'
      ensure
        Workspace.root = previous_root
        FileUtils.remove_entry(tmp)
      end
    end
  end

  def test_host_and_bwrap_branch_share_one_cwd_computation
    # Host fallback and (when bwrap is live) the sandbox branch must land on
    # the SAME directory: one cwd computed above the mode branch, so the
    # two modes cannot drift.  With root set outside Dir.pwd the host child
    # already proves it; under live bwrap the --chdir flag uses the value.
    require 'tmpdir'
    tmp = Dir.mktmpdir('wp-e-shared-cwd')
    previous_root = Workspace.root
    begin
      refute_equal tmp, Dir.pwd
      Workspace.root = tmp
      # Host branch: the child itself must be standing in the working root.
      in_host_fallback do
        r = call_bash("pwd # wp-e-share-host-#{Process.pid}")
        assert_equal 'host_fallback', r[:execution_mode]
        assert_equal tmp, r[:stdout].strip
        assert_equal tmp, r[:cwd]
      end
      # bwrap branch: only meaningful where a nested bwrap can run.  Where
      # it cannot, the shared-cwd property is covered by the host branch
      # above plus the mount-planner tests; a refused nested bwrap would
      # only test the sandbox error path.
      if nested_bwrap_possible?
        r = call_bash("pwd # wp-e-share-bwrap-#{Process.pid}")
        assert_equal 'bwrap', r[:execution_mode]
        assert_equal tmp, r[:stdout].strip
        assert_equal tmp, r[:cwd]
      end
    ensure
      Workspace.root = previous_root
      FileUtils.remove_entry(tmp)
    end
  end

  # --- WP-E, plan step 2b: correction 2 (one stream rule) -----------------

  def test_both_streams_byte_bounded_on_ordinary_exit
    in_host_fallback do
      # Oversized stdout AND oversized stderr on an ordinary exit: both go
      # through the one byte-bounded head+tail rule, markers inside the
      # budget, complete streams spooled and re-openable.
      r = call_bash("for i in $(seq 1 1200); do echo \"out-$i\"; echo \"err-$i\" >&2; done; exit 0")
      assert_equal 0, r[:exit_status]
      assert_nil r[:failure_kind]
      assert_operator r[:stdout].bytesize, :<=, 4000, 'stdout byte budget'
      assert_operator r[:stderr].bytesize, :<=, 4000, 'stderr byte budget'
      assert_match(/\[\s*bytes elided\s*\]/, r[:stdout], 'marker must sit inside the stdout budget')
      assert_match(/\[\s*bytes elided\s*\]/, r[:stderr], 'marker must sit inside the stderr budget')
      assert r[:stdout].include?('out-1'), 'stream head survives inline'
      assert r[:stdout].include?('out-1200'), 'stream tail survives inline'
      assert r[:stderr].include?('err-1')
      assert r[:stderr].include?('err-1200')
      %w[stdout_full stderr_full].each do |key|
        refute_nil r[key.to_sym], "#{key} must be advertised when truncation happened"
        content = LLM.call_workflow(Workspace, :read, { 'path' => r[key.to_sym], 'limit' => 2000 })
        assert_equal 1200, content.to_s.lines.size, "#{key} spool must be COMPLETE"
      end
    end
  end

  def test_both_streams_byte_bounded_on_signaled_path
    in_host_fallback do
      # Non-ordinary path (SIGKILL): same single rule, text (not nil),
      # head+tail preserved, spool advertised for the truncated stream.
      r = call_bash("for i in $(seq 1 1200); do echo \"sig-out-$i\"; done; kill -9 $$")
      assert_equal(-1, r[:exit_status], 'signal death — no exit code exists')
      assert_equal :signal, r[:failure_kind]
      assert_instance_of String, r[:stdout], 'stdout must be text, never nil'
      assert_instance_of String, r[:stderr], 'stderr must be text, never nil'
      assert_operator r[:stdout].bytesize, :<=, 4000
      assert r[:stdout].include?('sig-out-1'), 'head survives'
      assert r[:stdout].include?('sig-out-1200'), 'tail survives'
      refute_nil r[:stdout_full], 'truncated stream must be spooled'
      content = LLM.call_workflow(Workspace, :read, { 'path' => r[:stdout_full], 'limit' => 2000 })
      assert_equal 1200, content.to_s.lines.size, 'signaled stream spool must be COMPLETE'
    end
  end

  def test_timeout_streams_are_text_and_spooled_when_oversized
    in_host_fallback do
      # Timeout labeled from the runner fact (CMD::Timeout class), not from
      # output words.  Streams are text; when CMD's exception carries no io
      # the honest text is the runner's own report, still never nil.
      r = call_bash('sleep 30', 'timeout' => 2)
      assert_equal :timeout, r[:failure_kind]
      assert_equal(-1, r[:exit_status], 'no exit code exists — sentinel only')
      assert_instance_of String, r[:stdout], 'stdout must be text, never nil'
      assert_instance_of String, r[:stderr], 'stderr must be text, never nil'
      assert_operator r[:stdout].bytesize, :<=, 4000
      assert_operator r[:stderr].bytesize, :<=, 4000
    end
  end

  def test_exit_127_with_not_found_words_is_ordinary_exit_127
    in_host_fallback do
      r = call_bash(MISSING_EXE, 'env' => { 'PATH' => FIXTURE_BIN })
      assert_equal 127, r[:exit_status], '127 stays 127'
      assert_nil r[:failure_kind], 'no word-based launch inference'
      assert_match(/not found/i, r[:stderr], 'stream reported under the shared rule')
    end
  end

  def test_small_stderr_with_process_words_is_not_special_cased
    in_host_fallback do
      # The removed "small stderr containing 'Process '" special case: a
      # small stderr that happens to contain those words is returned
      # verbatim by the shared rule — no condensed rewrite, no fabricated
      # failure classification from the words.
      r = call_bash(%(printf 'Process 123 failed - not found\n' >&2; exit 3))
      assert_equal 3, r[:exit_status]
      assert_nil r[:failure_kind]
      assert_equal "Process 123 failed - not found\n", r[:stderr],
                   'small stderr must come back verbatim under the shared rule'
    end
  end
end
