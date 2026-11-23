module Workspace
  require 'open3'
  require 'tmpdir'

  # ===========================================================================
  # Mount struct — explicit representation of a single bind mount.
  #
  # +source+        Canonical host path (File.realpath of the requested path).
  # +destination+   Path visible inside the sandbox namespace.
  # +mode+          :ro (read-only) or :rw (read-write).
  # +requested_path+ The original expanded path requested by the caller.
  #
  # The critical invariant: destination is NOT derived from source via
  # realpath().  It is the path the application expects to use.
  # ===========================================================================
  Mount = Struct.new(:source, :destination, :mode, :requested_path, keyword_init: true)

  # ===========================================================================
  # Utility helpers
  # ===========================================================================

  # Compute the canonical realpath of a path, returning nil if the path
  # does not exist or cannot be resolved.
  helper :safe_realpath do |path|
    return nil if path.nil?
    File.realpath(path.to_s)
  rescue Errno::ENOENT, Errno::ENOTDIR, ArgumentError
    nil
  end

  # Lexical path-containment test: true if +child+ is the same as +parent+
  # or is a subdirectory of +parent+.  Uses "/" boundary to avoid false
  # positives like /foo matching /foobar.
  helper :path_under? do |child, parent|
    child == parent || child.start_with?(parent + "/")
  end

  # Map a mode symbol to the bwrap flag string.
  helper :mount_mode_flag do |mode|
    mode == :rw ? '--bind' : '--ro-bind'
  end

  # Walk every component of an expanded path from root downward and return
  # the first component that is a symlink on the host, or nil if none.
  #
  # Example: for /home/user/.rbbt/var/jobs where .rbbt/var is a symlink,
  # returns /home/user/.rbbt/var.
  helper :first_symlink_component do |path|
    path = File.expand_path(path.to_s)
    current = "/"
    path.split("/").reject(&:empty?).each do |part|
      current = File.join(current, part)
      return current if File.symlink?(current)
    end
    nil
  end

  # ===========================================================================
  # Mount planner — the core of the sandbox construction.
  #
  # Transforms requested read/write paths into a complete, validated,
  # ordered list of Mount objects.  The planner preserves both the
  # requested namespace (the path the application uses) and the canonical
  # namespace (File.realpath) so that symlinked paths resolve correctly
  # inside the sandbox.
  #
  # Pipeline stages:
  #   1. Create initial Mount objects from requested paths.
  #   2. Compute which destinations will be mounted.
  #   3. Adjust destinations that traverse symlinks whose parent is mounted.
  #   4. Add symlink dependency mounts (parent dirs + symlink targets).
  #   5. Resolve read/write conflicts at the same destination (keep :rw),
  #      BEFORE dedup so pruning only ever sees effective modes.
  #   6. Semantic deduplication (same source+dest+mode = duplicate; a child
  #      is pruned only when its DEEPEST mounted ancestor has the same mode
  #      AND maps the source subtree at the same relative position).
  #   7. Sort by destination depth (parents before children).
  # ===========================================================================
  helper :plan_mounts do |read_paths, writable_paths|
    mounts = []

    # --- Phase 1: Create initial mount objects ---
    read_paths.each do |p|
      expanded = File.expand_path(p.to_s)
      next unless File.exist?(expanded)
      src = safe_realpath(expanded)
      next unless src
      mounts << Mount.new(source: src, destination: expanded, mode: :ro, requested_path: expanded)
    end

    writable_paths.each do |p|
      expanded = File.expand_path(p.to_s)
      #next unless File.exist?(expanded)
      src = safe_realpath(expanded)
      next unless src
      mounts << Mount.new(source: src, destination: expanded, mode: :rw, requested_path: expanded)
    end

    # --- Phase 2: Compute which destinations will be mounted ---
    # This is used to determine if a symlink's parent directory will be
    # present in the sandbox (which affects whether we can mount onto a
    # symlinked destination).
    all_destinations = mounts.map(&:destination)

    # --- Phase 3: Adjust destinations that traverse symlinks ---
    #
    # Key rule (experimentally verified):
    #   bwrap CANNOT mount onto a destination that is (or traverses) a
    #   symlink IF the symlink's parent is already mounted in the sandbox.
    #   When the parent IS mounted, the host symlink is visible in the
    #   namespace and bwrap's mount() call fails with ENOENT.
    #
    #   When the parent is NOT mounted, bwrap creates fresh directories
    #   at the destination, so mounting onto a symlinked path works fine.
    #
    # Therefore: if a mount's destination traverses a symlink AND the
    # symlink's parent is in the mount set, redirect the destination to
    # the canonical (realpath) location.
    mounts.each do |m|
      sym = first_symlink_component(m.destination)
      next unless sym

      parent_of_sym = File.dirname(sym)

      # Check if the symlink's parent (or an ancestor) is in the mount set.
      parent_mounted = all_destinations.any? do |d|
        path_under?(parent_of_sym, d)
      end

      if parent_mounted
        # Cannot mount onto the symlinked destination because the parent
        # is mounted, making the symlink visible.  Redirect to canonical.
        m.destination = m.source
      end
      # If parent is NOT mounted, keep the original destination — bwrap
      # will create fresh directories and there's no symlink conflict.
    end

    # --- Phase 4: Add symlink dependency mounts ---
    #
    # For mounts whose destinations were redirected (Phase 3), the
    # symlink from the parent mount needs its target to exist at the
    # canonical path so the symlink resolves inside the sandbox.
    #
    # Pattern (experimentally verified):
    #   --ro-bind /home/user/.rbbt     /home/user/.rbbt
    #   --ro-bind /bulk/user/rbbt/var  /bulk/user/rbbt/var
    #   → ls /home/user/.rbbt/var/jobs works because the symlink resolves.
    additional = []
    mounts.each do |m|
      sym = first_symlink_component(m.requested_path)
      next unless sym

      parent_of_sym = File.dirname(sym)
      target_of_sym = safe_realpath(sym)

      parent_mounted = all_destinations.any? do |d|
        path_under?(parent_of_sym, d)
      end

      if parent_mounted && target_of_sym
        # The symlink target must exist at its canonical path so the
        # symlink resolves.  Add a read-only mount for the target.
        #
        # Breadth note (plan step 8): the dependency mount is the symlink's
        # OWN target (target_of_sym), never an ancestor of it.  Mounting a
        # broader ancestor (e.g. /bulk/user/rbbt when only /bulk/user/rbbt/var
        # is the target) would expose host data the caller never asked for;
        # bwrap will create any missing intermediate directories inside the
        # sandbox, so the exact target is always sufficient.  The two
        # `already_*` guards below prevent both re-adding a subtree another
        # mount already covers and duplicating within `additional`.
        already_covered = mounts.any? { |om| path_under?(target_of_sym, om.destination) }
        already_in_additional = additional.any? { |am| path_under?(target_of_sym, am.destination) }

        unless already_covered || already_in_additional
          additional << Mount.new(
            source: target_of_sym,
            destination: target_of_sym,
            mode: :ro,
            requested_path: target_of_sym
          )
        end
      end
    end
    mounts.concat(additional)

    # --- Phase 5: Resolve read/write conflicts at same destination ---
    #
    # Runs BEFORE dedup pruning so pruning only ever sees the EFFECTIVE
    # mode of each destination.  If the same destination has both :ro and
    # :rw mounts, keep only :rw.
    mounts = mounts.uniq { |m| [m.source, m.destination, m.mode] }

    dest_modes = mounts.group_by(&:destination)
    mounts = mounts.reject do |m|
      siblings = dest_modes[m.destination]
      siblings.any? { |s| s.mode == :rw && m.mode == :ro }
    end

    # --- Phase 6: Semantic deduplication ---
    #
    # Two mounts are exact duplicates only if ALL of (source, destination,
    # mode) are identical.  Canonical source equality alone is NOT
    # sufficient — two paths resolving to the same host object but at
    # different sandbox destinations are NOT duplicates.
    #
    # A child mount is redundant (can be removed) ONLY when its DEEPEST
    # mounted ancestor (after same-destination resolution above) has the
    # SAME access mode AND mounts the same host source subtree at the SAME
    # relative position.  Comparing against the deepest — not the
    # shallowest — ancestor matches what the kernel resolves for paths
    # under the child; the old shallowest-ancestor comparison let a
    # distant ro ancestor prune a same-mode ro child that had a different
    # mode (or different relative mapping) on every intermediate mount.
    mounts = mounts.reject do |candidate|
      # Consider every OTHER mount that is an ancestor of the candidate's
      # destination, and keep only the DEEPEST one (the mount the kernel
      # actually resolves first for paths under the candidate).
      ancestors = mounts.select do |other|
        ! other.equal?(candidate) &&
          candidate.destination != other.destination &&
          path_under?(candidate.destination, other.destination)
      end
      next false if ancestors.empty?

      nearest = ancestors.max_by { |a| a.destination.count('/') }

      # Only redundant when the deepest ancestor mounts the same host
      # subtree (or an ancestor of it), the child's source sits at the
      # SAME relative position inside it as the destination sits inside
      # the ancestor's destination, AND the modes match:
      #   ro parent + rw child            → child KEPT (widens, by design)
      #   rw parent + ro child            → child KEPT (re-restricts)
      #   same mode + same mapping        → child redundant
      #   same mode + different mapping   → child KEPT (different host data
      #                                   →  mapped to a different position)
      same_subtree = path_under?(candidate.source, nearest.source)
      same_mapping = candidate.source.delete_prefix(nearest.source) ==
                     candidate.destination.delete_prefix(nearest.destination)
      same_subtree && same_mapping && nearest.mode == candidate.mode
    end

    # --- Phase 7: Sort by destination depth (parents before children) ---
    mounts.sort_by! { |m| [m.destination.count("/"), m.destination] }

    mounts
  end

  # ===========================================================================
  # Diagnostic logging — structured mount plan before bwrap execution.
  # ===========================================================================
  helper :log_mount_plan do |mounts|
    lines = ["SANDBOX MOUNT PLAN (#{mounts.length} mounts)"]
    mounts.each do |m|
      flag = mount_mode_flag(m.mode)
      tag = m.mode == :rw ? 'RW' : 'RO'
      if m.source == m.destination
        lines << "  #{tag}  #{m.destination}"
      else
        lines << "  #{tag}  #{m.source} -> #{m.destination}"
      end

      # Log symlink dependency info if the requested path differs from destination
      if m.requested_path != m.destination
        lines << "       (requested: #{m.requested_path})"
      end
    end
    Log.debug lines.join("\n")
  end

  # ===========================================================================
  # Validation — check the mount plan before bwrap execution.
  # ===========================================================================
  helper :validate_mount_plan do |mounts|
    mounts.each do |m|
      unless File.exist?(m.source)
        Log.warn "Workspace sandbox: mount source does not exist: #{m.source}"
      end
      unless m.source.to_s.start_with?("/")
        Log.warn "Workspace sandbox: mount source is not absolute: #{m.source}"
      end
      unless m.destination.to_s.start_with?("/")
        Log.warn "Workspace sandbox: mount destination is not absolute: #{m.destination}"
      end
    end

    # Check for destination conflicts (same dest, conflicting modes not resolved)
    dest_groups = mounts.group_by(&:destination)
    dest_groups.each do |dest, group|
      if group.length > 1
        Log.warn "Workspace sandbox: multiple mounts at #{dest}: #{group.map(&:mode).inspect}"
      end
    end
  end

  # ===========================================================================
  # bwrap executable discovery (no shell-out to `which`).
  # ===========================================================================
  helper :find_bwrap do
    # 1. Explicit config/env override.
    bwrap = config(:path, :bwrap, :sandbox, :sandbox_run, env: 'BWRAP_PATH')
    return bwrap unless bwrap.nil? || bwrap.to_s.empty?

    # 2. Search PATH manually.
    ENV['PATH'].to_s.split(File::PATH_SEPARATOR).each do |dir|
      candidate = File.join(dir, 'bwrap')
      return candidate if File.executable?(candidate) && File.file?(candidate)
    end

    nil
  end

  # ===========================================================================
  # Error-stream condensing — keep failures succinct and root-cause first.
  #
  # Three noise sources historically drowned the real mistake in `stderr`:
  #
  #   1. CMD.cmd's ProcessFailed message re-serializes the ENTIRE bwrap argv
  #      (mount list + PATH), which alone runs to several KB.
  #   2. The Ruby-side rescue appended e.backtrace — the HOST stack
  #      (scout-ai tool loop, persist/lock frames), not the sandbox's.
  #   3. The program's own stderr was returned verbatim; a 5000-line flood
  #      exceeded scout-ai's 100,000-char tool-result cap, so the WHOLE
  #      result was dropped and the caller saw only a fingerprint.
  #
  # condense_stderr() rebuilds a failure stream as
  #   <root-cause lines first> + <bounded tail> + <elision markers>
  # collapsing repeats and dropping host framework frames.  The full,
  # uncondensed stream is persisted and returned as `stderr_full` so no
  # information is lost.
  # ===========================================================================

  # Does +line+ look like it carries error information?
  helper :error_line_match? do |line|
    return false if line.nil? || line.strip.empty?
    return false if line =~ /\A[\t ]/ && line !~ /error|exception|fatal|fail/i
    line =~ /
      \berror\b|\berror:|\Aerror|
      \bexception\b|\btraceback\b|
      \bfatal\b|\bfailed\b|\bfailure\b|\bcannot\b|\bcan't\b|
      \bno such file\b|\bpermission denied\b|\bnot found\b|\bexpected\b|
      \benoent\b|\beacces\b|\besrch\b|\baborted\b|
      \bkilled\b|\bterminated\b|\bsyntaxerror\b|\bnameerror\b|\btypeerror\b|
      \bvalueerror\b|\bkeyerror\b|\bindexerror\b|\bsegmentation fault\b|
      \bnot a git repository\b|\bundefined\b
    /ix
  end

  # Strip the giant flattened bwrap argv dump from a CMD.cmd ProcessFailed
  # message, leaving a short, useful summary instead of thousands of chars
  # of mount flags and PATH entries.
  helper :summarize_process_failed do |message|
    return message unless message =~ /\AProcess \d+ failed - /
    if (m = message.match(/\AProcess \d+ failed - (.+?) -- (.+?)( failed with error status \d+\.?)\z/m))
      argv = m[1]
      return message if argv.length <= 120
      payload_summary = m[2].strip.split(/\s+/).first(14).join(' ')
      return "Process failed - bwrap #{argv.split(/\s+/).first(2).join(' ')} ... -- #{payload_summary}#{m[3]} [full argv elided]"
    end
    if (m = message.match(/\AProcess \d+ failed - (.+)/m))
      argv = m[1]
      return message if argv.length <= 120
      words = argv.split(/\s+/)
      return "Process failed - bwrap #{words.first(6).join(' ')} ... #{words.last(3).join(' ')} [full argv elided]"
    end
    head = message[0, 120]
    rest = message.length > 240 ? " ... [elided #{message.length - 240} chars] ... " : ''
    tail = message[-120, 120].to_s
    head + rest + tail
  end

  # Condense a raw stderr stream into <= max_chars chars, root cause first.
  # The limit is applied INCLUSIVE of markers/elision text (plan step 4.4):
  # `fit_to_budget` below appends the framework-frame marker and performs
  # the final hard cap accounting for the marker bytes themselves, so the
  # returned string never exceeds max_chars.
  # WP-E, plan step 2b: the 127-plus-"not found" launch inference and its
  # `executable_missing?` helper are REMOVED.  Exit 127 keeps its real
  # status and its streams follow the shared byte-bounded rule like every
  # other ordinary exit (see run_child); words in child output are never
  # evidence of a launch failure.
  #
  # condense_stderr is no longer on the runner path (the runner now uses
  # the single bound_stream rule below); it stays defined for its unit
  # tests in test_exec_helpers.rb.  WP-F should decide whether to retire it
  # together with those tests.
  helper :condense_stderr do |raw, max_chars: nil|
    max_chars ||= 4000
    max_chars = max_chars.to_i
    return raw.to_s if max_chars <= 0 || raw.nil?
    raw = raw.to_s

    return raw.chomp + "\n" if raw.length <= max_chars && !raw.include?('Process ')

    lines = raw.lines.map(&:chomp)

    # 1. Replace any giant ProcessFailed argv dump with its summary.
    lines = lines.map do |l|
      l =~ /\AProcess \d+ failed - / ? summarize_process_failed(l) : l
    end

    # 2. Drop host Ruby framework frames (gem internals, persist/lock,
    #    workflow step machinery).  They describe the CALLER's stack, not
    #    the sandbox failure.
    framework = %r{
      /gems/|/scout-essentials/lib|/scout-gear/lib|/scout-ai/lib|
      /rbbt-util/lib|/scout/persist|/open/lock|/workflow/step|
      chain_tools|process_calls|bin/scout:|`exec'\z|`cmd'\z
    }x
    dropped_frames = 0
    lines = lines.reject do |l|
      if l =~ framework && l !~ /error|failed|cannot|No such/i
        dropped_frames += 1
        true
      else
        false
      end
    end

    # 3. Collapse runs of identical lines into "line  [x N]".
    collapsed = []
    lines.each do |l|
      if collapsed.any? && collapsed.last[0] == l
        collapsed.last[1] += 1
      else
        collapsed << [l, 1]
      end
    end
    lines = collapsed.map { |l, n| n > 1 ? "#{l}  [x #{n}]" : l }

    # 4. Over budget: head = root-cause lines, tail = last lines.
    # Scan ALL error lines but keep at most 5 DISTINCT ones, so a real
    # error buried mid-stream (after thousands of repeated error-shaped
    # noise lines) still surfaces.  IN-ORDER: head keeps the first distinct
    # error lines (in stream order), tail keeps the final lines, and the
    # elision marker between them records what was dropped.
    error_idx = lines.each_index.select { |i| error_line_match?(lines[i]) }
    head_lines = []
    error_idx.each do |i|
      l = lines[i]
      next if head_lines.include?(l)
      head_lines << l
      break if head_lines.length >= 5
    end
    head = head_lines.empty? ? lines.first(3) : head_lines
    tail_keep = [(max_chars / 3) / 20, 5].max
    tail_lines = lines.last(tail_keep)
    omitted = lines.length - head.length - tail_lines.length

    parts = []
    parts.concat(head)
    parts << "... [#{omitted} lines omitted]" if omitted > 0
    parts.concat(tail_lines)
    text = parts.join("\n")

    # 5. Final hard cap on pathological single-line monsters.  The cap is
    # INCLUSIVE of the elision marker (plan step 4.4): the marker text is
    # part of the budget, so the result never exceeds max_chars.
    if text.length > max_chars
      marker = "\n... [chars elided] ...\n"
      keep = max_chars - marker.length - 60
      keep = max_chars / 2 if keep < 0
      head_txt = text[0, keep]
      tail_txt = text[-60, 60].to_s
      text = head_txt + marker + tail_txt
    end

    # 6. Framework-frame marker (also inside the budget).
    frame_marker = dropped_frames > 0 ? "\n[#{dropped_frames} framework backtrace frames elided]" : ''
    if text.length + frame_marker.length > max_chars
      room = max_chars - frame_marker.length
      if room > 0
        text = text[0, room]
      else
        text = frame_marker.sub(/\A\n/, '')
      end
    end
    text + frame_marker
  end

  # Persist +text+ for post-hoc debugging and return its path (nil on
  # failure).  Written under the step files_dir when available, else /tmp.
  # Return an in-order bounded head+tail view of +text+ whose length is
  # bound_head_tail is the LEGACY character-based bounding helper, kept
  # only for patch.rb's inline diagnostics (generated_patch / tried_strips),
  # whose tests pin its "chars elided" marker.  The exec runner does NOT
  # use it any more: runner streams go through `bound_stream` below, whose
  # budget is BYTES (WP-E, plan step 2b).  WP-F should migrate patch.rb
  # onto bound_stream and retire this helper.
  helper :bound_head_tail do |text, max_chars = 4000|
    text = text.to_s
    return text if text.length <= max_chars
    marker = "\n... [chars elided] ...\n"
    head_room = (max_chars - marker.length) * 2 / 3
    tail_room = (max_chars - marker.length) / 3
    head_txt = text[0, head_room]
    tail_txt = text[-tail_room, tail_room].to_s
    head_txt + marker + tail_txt
  end

  # The ONE stream-truncation rule for exec results (WP-E, plan step 2b):
  # a byte-bounded, in-order head+tail view of +text+ whose size is
  # <= max_bytes BYTES with the elision marker INSIDE that budget.  It is
  # applied to BOTH stdout and stderr on EVERY outcome path (ordinary
  # exit, signal, timeout, launch failure).  Byte slicing can split a
  # multibyte character; `scrub` drops the orphaned bytes so the result
  # stays valid UTF-8, and scrubbing only ever shrinks, so the byte budget
  # still holds.
  helper :bound_stream do |text, max_bytes = 4000|
    text = text.to_s
    return text if text.bytesize <= max_bytes
    marker = "\n... [bytes elided] ...\n"
    budget = max_bytes - marker.bytesize
    return marker if budget <= 0
    head_room = budget * 2 / 3
    tail_room = budget - head_room
    enc = text.encoding
    head = text.byteslice(0, head_room).to_s.force_encoding(enc).scrub('')
    tail = text.byteslice(-tail_room, tail_room).to_s.force_encoding(enc).scrub('')
    head + marker + tail
  end

  # Persist +text+ for post-hoc debugging and return its path (nil on
  # failure).  The artifact lives under the STEP's files_dir (plan step
  # 4.4): the caller context can open it (files_dir paths are bwrap-granted
  # to the reporting process), whereas the old `Dir.mktmpdir` fallback
  # produced a host temp path that `Workspace.read` could NOT open from the
  # same caller — advertising an unreadable path was the bug.  If no
  # files_dir exists or the write fails we return nil rather than a path
  # we cannot stand behind.
  helper :persist_full_stream do |text, label = 'stderr_full'|
    begin
      dir = respond_to?(:files_dir) ? files_dir : nil
      return nil unless dir
      dir = dir.to_s
      FileUtils.mkdir_p(dir) unless Open.exists?(dir)
      return nil unless Open.exists?(dir)
      path = File.join(dir, "#{label}.log")
      Open.write(path, text.to_s)

      # The spool path is returned to the CALLER, so the caller's own
      # thread must be able to read it back (plan step 4.4: `Workspace.read`
      # must be able to open every returned path from the same caller
      # context).  Register a READ grant on the current thread; the file
      # task's authorization composes thread read grants into its policy.
      begin
        LLM::Sandbox.allow_read_path(dir)
        LLM::Sandbox.allow_read_path(path)
      rescue
        # Grant registration is best-effort: without it the artifact still
        # exists on disk; the caller simply sees a read violation.
      end
      path
    rescue
      nil
    end
  end

  # Build the standard exec result shape (WP-E, plan step 2b): ONE stream
  # rule applied to BOTH streams on EVERY path.  `bound_stream` returns a
  # byte-bounded in-order head+tail copy whose elision marker counts inside
  # the byte budget; whenever the inline copy is truncated, the COMPLETE
  # stream is spooled under the step files_dir and advertised as
  # `stdout_full` / `stderr_full`, re-openable by the exported read tool in
  # the same caller context.  `base` carries the per-run context fields
  # (execution_mode, cwd, launcher diagnostics); `failure_kind` classifies
  # non-ordinary outcomes for machine consumers and stays ABSENT for plain
  # exits that carry a real exit code.
  helper :failure_result do |exit_status, stdout, stderr, prefix: nil, base: {}, failure_kind: nil|
    raw_out = stdout.to_s
    raw_err = [prefix.to_s.empty? ? nil : prefix,
               stderr.to_s.empty? ? nil : stderr.to_s].compact.join("\n")
    bounded_out = bound_stream(raw_out)
    bounded_err = bound_stream(raw_err)
    result = base.merge({ exit_status: exit_status, stdout: bounded_out, stderr: bounded_err })
    result[:failure_kind] = failure_kind if failure_kind
    if bounded_out != raw_out
      path = persist_full_stream(raw_out, 'stdout_full')
      result[:stdout_full] = path if path
    end
    if bounded_err != raw_err
      path = persist_full_stream(raw_err)
      result[:stderr_full] = path if path
    end
    result
  end

  # ===========================================================================
  # Executable resolution — resolve bare names via $PATH, then realpath.
  # ===========================================================================
  helper :resolve_executable do |exe|
    return exe.to_s if exe.nil? || exe.to_s.empty?
    resolved = safe_realpath(exe.to_s)
    return resolved if resolved
    # Bare name: search PATH for the real location.
    found = ENV['PATH'].to_s.split(File::PATH_SEPARATOR).find do |dir|
      candidate = File.join(dir, exe.to_s)
      File.executable?(candidate) && File.file?(candidate)
    end
    found ? safe_realpath(File.join(found, exe.to_s)) || exe.to_s : exe.to_s
  end

  # ===========================================================================
  # Runtime directory discovery for relocatable runtimes.
  # ===========================================================================

  # Compute the minimal set of directories needed to run +exe+ inside a
  # bwrap sandbox.  For relocatable runtime environments (RVM, rbenv,
  # Conda, pyenv, Homebrew, ...) the entire installation tree must be
  # mounted so that relative references resolve correctly.
  helper :runtime_dirs do |exe|
    resolved = safe_realpath(exe.to_s)
    return [] unless resolved

    dirs = []
    dirs << File.dirname(resolved)

    case resolved
    when %r{/\.rvm/rubies/},     # RVM Ruby
         %r{/\.rvm/gems/},       # RVM gems
         %r{/\.rbenv/versions/}, # rbenv
         %r{/\.pyenv/versions/}, # pyenv
         %r{/envs/},             # Conda/virtualenv
         %r{/Cellar/}            # Homebrew
      dirs << resolved.sub(%r{/bin/.*$}, '')
    end

    dirs.uniq
  end

  # Scan $PATH entries for known relocatable runtime layouts and return
  # their installation roots.  Needed for shell-based tasks where the
  # script may invoke interpreters that differ from the tool itself.
  helper :path_runtime_dirs do
    dirs = []
    ENV['PATH'].to_s.split(File::PATH_SEPARATOR).each do |entry|
      next if entry.nil? || entry.empty?
      expanded = File.expand_path(entry)
      next unless File.directory?(expanded)

      case expanded
      when %r{/\.rvm/}, %r{/\.rbenv/}, %r{/\.pyenv/},
           %r{/envs/[^/]+/bin$}, %r{/Cellar/}
        dirs << expanded
        root = expanded.sub(%r{/bin/?$}, '')
        dirs << root unless root == expanded
      end
    end
    dirs.uniq
  end

  # ===========================================================================
  # Base sandbox path composition (plan step 8) — the ONE definition of the
  # canonical grant lists shared by `sandbox_paths` reporting (in
  # filesystem.rb, via its `sandbox_mount_plan`) and by execution here.
  # Both compose: bwrap_* config lists, the workflow allowed lists, and the
  # workflow root always writable.  Per-call additions (runtime dirs,
  # PATH-scanned runtime roots, resolv.conf, step files_dir, caller extras)
  # are applied by each caller on top of this base and stay explicit.
  # ===========================================================================
  helper :base_sandbox_paths do
    read_paths = Workspace.allowed_read_paths.dup
    bwrap_read = Workspace.get_allowed_paths(:bwrap_read_paths)
    read_paths += bwrap_read if bwrap_read && !bwrap_read.empty?

    writable_paths = Workspace.allowed_paths.dup
    bwrap_writable = Workspace.get_allowed_paths(:bwrap_paths)
    writable_paths += bwrap_writable if bwrap_writable && ! bwrap_writable.empty?

    # The exec sandbox always grants write access to the workflow root.
    begin
      root = Workspace.root
      root = root.find if Path === root
      writable_paths << root.to_s if root && ! root.to_s.empty?
    rescue
    end

    {
      read_paths:     read_paths.flatten.compact.uniq,
      writable_paths: writable_paths.flatten.compact.uniq
    }
  end

  # ===========================================================================
  # sandbox_run — execute +executable+ with +argv+ inside a bwrap sandbox.
  #
  # Uses the mount planner to construct a principled, namespace-preserving
  # set of bind mounts.  Falls back to unsandboxed execution with a warning
  # when bwrap is not available.
  # ===========================================================================
  helper :sandbox_run do |executable, argv, options = {}, writable_paths_extra = []|
    bwrap = find_bwrap

    timeout = options[:timeout]
    timeout = config(:timeout, :sandbox, :Workspace, :workspace, env: 'SANDBOX_TIMEOUT,TIMEOUT', default: 3600 ) if timeout.nil?
    timeout = case timeout
              when 'false', 'FALSE', 'False', 'no', 'none', 'nil', '0'
                nil
              when String
                timeout.to_i
              else
                timeout
              end

    # Base path composition is SHARED (plan step 8) with the mount plan
    # that `sandbox_paths` reports: one helper, `base_sandbox_paths`,
    # defines the canonical grant composition (bwrap_* lists + allowed
    # lists + always-root-writable).  Per-call additions below are
    # explicit and separate so reporting and execution cannot drift.
    base = base_sandbox_paths
    read_paths      = base[:read_paths]
    writable_paths  = base[:writable_paths]

    # Per-call writable extras (e.g. the step files_dir) passed by the
    # caller via the writable_paths argument:
    writable_paths += Array(writable_paths_extra).flatten.compact.uniq

    # Root is already in the base plan; keep resolving root_dir for cwd.
    root_dir = begin
                 r = Workspace.root
                 r = r.find if Path === r
                 r.to_s
               rescue
                 nil
               end
    writable_paths << root_dir if root_dir && !root_dir.to_s.empty?

    writable_paths.uniq!
    read_paths.uniq!

    use_bwrap = bwrap && !bwrap.to_s.empty? && bwrap.to_s != 'false' && bwrap.to_s != 'none'

    use_network = config(:use_network, :sandbox, :bwrap, default: 'true') == 'true'
    
    read_paths << '/etc/resolv.conf' if use_network

    # WP-E, plan step 2b — the working directory is computed ONCE, before
    # the mode branch, so the bwrap branch (--chdir) and the HOST branch
    # (chdir spawn option) land on the SAME directory: the working root
    # whenever one exists, otherwise the child inherits Dir.pwd.
    cwd = root_dir && !root_dir.to_s.empty? ? root_dir.to_s : nil

    if use_bwrap
      Log.debug "Workspace sandbox_run read_paths: #{read_paths.inspect}, writable_paths: #{writable_paths.inspect}"

      # --- Resolve the executable's real path ---
      resolved_exec = resolve_executable(executable)

      # --- Add runtime directories needed by the resolved executable ---
      read_paths.concat(runtime_dirs(resolved_exec))

      # --- Scan $PATH for known relocatable runtime layouts ---
      read_paths.concat(path_runtime_dirs)

      # --- Plan all mounts using the mount planner ---
      mounts = plan_mounts(read_paths, writable_paths)

      log_mount_plan(mounts)
      validate_mount_plan(mounts)

      # --- Build bwrap argument list (as an argv array, never a string) ---
      bwrap_args = ['--unshare-all', '--die-with-parent']

      # Bind /tmp writable so temp files survive across subprocesses.
      bwrap_args.concat(['--bind', '/tmp', '/tmp'])

      bwrap_args.concat(['--proc', '/proc'])
      bwrap_args.concat(['--dev', '/dev'])

      # Set HOME and PATH explicitly for deterministic execution.
      home = ENV['HOME']
      if home && !home.empty?
        bwrap_args.concat(['--setenv', 'HOME', home])
      end

      path_env = ENV['PATH']
      if path_env && !path_env.empty?
        bwrap_args.concat(['--setenv', 'PATH', path_env])
      end

      # --- Emit application/user mounts from the planned mount list ---
      # Mounts are already sorted parents-before-children by plan_mounts.
      mounts.each do |m|
        flag = mount_mode_flag(m.mode)
        bwrap_args.concat([flag, m.source, m.destination])
      end

      if use_network
        bwrap_args << '--share-net'
      end

      # Working directory: computed ONCE above the mode branch (WP-E, plan
      # step 2b) so bwrap (--chdir) and the host fallback (chdir spawn
      # option) use the SAME value — the working root when one exists.
      bwrap_args.concat(['--chdir', cwd]) if cwd

      # End of bwrap args marker.
      bwrap_args << '--'

      # --- Build the full command as an argv array ---
      full_argv = [bwrap.to_s] + bwrap_args + [resolved_exec] + Array(argv).map(&:to_s)

      run_child(full_argv, cwd: cwd, timeout: timeout, options: options,
                execution_mode: 'bwrap', bwrap_argv: [bwrap.to_s] + bwrap_args)
    else
      # Fallback: run unsandboxed.  The POLICY is unchanged (host fallback
      # still happens); the only new behavior is TRUTHFUL REPORTING of the
      # mode in the result so callers can distinguish it from a sandboxed
      # run (plan step 8: execution_mode reporting).
      if defined?(Log)
        Log.warn 'bwrap not found — running unsandboxed'
      else
        warn 'bwrap not found — running unsandboxed'
      end

      full_argv = [executable.to_s] + Array(argv).map(&:to_s)

      # Same cwd policy as the bwrap branch (plan step 4.1; WP-E, plan
      # step 2b): when a working root exists the child runs there in BOTH
      # modes.  `run_child` now hands that directory to the HOST child
      # itself (a trailing chdir spawn option on the argv), so the child's
      # actual pwd equals the working root even when it differs from
      # Dir.pwd; the bwrap branch reaches the same directory via --chdir.
      # Without a root the child inherits Dir.pwd and the result's `cwd`
      # field reports nothing while `execution_mode` says `host_fallback`,
      # so any real difference stays explicit.
      host_cwd = cwd || Dir.pwd
      run_child(full_argv, cwd: host_cwd, timeout: timeout, options: options,
                execution_mode: 'host_fallback', bwrap_argv: nil)
    end
  end

  # ===========================================================================
  # run_child — the single shared child-execution runner (plan step 4.1).
  #
  # Both the bwrap branch and the host-fallback branch previously carried
  # VERBATIM-DUPLICATE copies of this logic (CMD.cmd call, io.read /
  # io.std_err / io.exit_status, the status/err-size test and the rescue
  # clause).  They are now ONE runner, parameterized by:
  #   full_argv      — the complete launcher argv (bwrap prefix + exec +
  #                    args, or bare executable + args)
  #   cwd            — the working directory for the child.  The HOST
  #                    branch runs the child THERE (WP-E, plan step 2b: a
  #                    trailing chdir spawn option is appended to the argv
  #                    so the child's actual pwd equals this value even
  #                    when it differs from Dir.pwd); when the bwrap branch
  #                    passes an explicit --chdir, that SAME value is given
  #                    here so both modes use the SAME effective cwd
  #                    (plan step 4.1), and the result reports it via
  #                    `cwd`.
  #   execution_mode — 'bwrap' or 'host_fallback', reported in the result.
  #   bwrap_argv     — launcher argv diagnostics (plan step 4.5): the full
  #                    bwrap prefix is preserved for debugging.
  #
  # Contract (plan step 4.2; WP-E, plan step 2b):
  #   * The outcome is classified FIRST and only from reliable runner
  #     information: ordinary exit (real exit status from CMD's io),
  #     signal death (io.exit_status nil — no exit code exists),
  #     timeout / launch failure (runner exception classes / CMD returning
  #     nil).  Words in the child's output are NEVER evidence of anything.
  #   * ONE stream rule then applies to BOTH stdout and stderr on EVERY
  #     path: byte-bounded in-order head+tail inline (`bound_stream`,
  #     marker inside the byte budget), complete stream spooled under the
  #     step files_dir whenever truncation happened.
  #   * Ordinary nonzero exits return the REAL exit code and, when small,
  #     the child's streams VERBATIM (nothing truncated → nothing spooled);
  #     stdout is preserved independently of stderr.
  #   * -1 remains ONLY the sentinel for "no exit code exists" (signal
  #     death, timeout, launch failure) and is NEVER used to mean "exit
  #     code 1" or inferred from status 1 alone.
  #   * failure_kind classifies the failure for machine consumers:
  #     :timeout, :signal, :launch, :runner_exception, or nil for a plain
  #     nonzero exit that carries a real exit code.
  # ===========================================================================
  helper :run_child do |full_argv, cwd: nil, timeout: nil, options: {}, execution_mode: nil, bwrap_argv: nil|
    cmd_options = options.merge(save_stderr: true, pipe: false, log: true)
    cmd_options[:timeout] = timeout unless timeout.nil?

    base = { execution_mode: execution_mode }
    base[:cwd] = cwd if cwd
    base[:launcher] = bwrap_argv if bwrap_argv && Log.severity <= Log::LOW

    # WP-E, plan step 2b — correction 1: pass the REAL working directory to
    # the HOST child.  In CMD's array mode a trailing spawn-options hash
    # inside the argv is consumed by Open3.popen3, so `chdir:` moves the
    # child itself instead of leaving it in Dir.pwd.  The bwrap branch
    # (bwrap_argv present) already chdirs via --chdir and is left untouched,
    # so both modes end up with the SAME effective cwd.  The hash must stay
    # the LAST argv element; every option key run_child passes to CMD.cmd
    # is consumed there (save_stderr/pipe/log/no_fail/timeout/in), so CMD
    # appends nothing after it.
    spawn_argv = full_argv
    if cwd && !cwd.to_s.empty? && bwrap_argv.nil?
      spawn_argv = full_argv + [{ chdir: cwd.to_s }]
    end

    begin
      # no_fail: true — CMD returns the io instead of raising, so BOTH
      # streams and the REAL exit status are available to handlers even on
      # nonzero exit (plan step 2 design decision; see
      # reports/impl/02-cmd-probe.md).
      io = CMD.cmd(spawn_argv, cmd_options.merge(no_fail: true))

      # LAUNCH failure, from the runner fact alone (plan step 4.3): CMD
      # returns nil when popen3 could not start the executable at all, so
      # no exit code exists and -1 is the sentinel — never conflated with
      # a plain exit-1 of some successfully started process.  The streams
      # follow the same shared rule as every other path (here: plain text,
      # nothing to truncate).
      return base.merge(exit_status: -1, stdout: '',
                        stderr: "Launch failed: no such executable — #{full_argv.first}",
                        failure_kind: :launch) if io.nil?

      # The CMD io object is a StringIO and `io.read` DRAINS it, so keep the
      # raw text before any bounding.
      raw_out = io.read.to_s
      raw_err = io.std_err.to_s
      status = io.exit_status

      # Classify the outcome FIRST, from runner facts only (WP-E, plan step
      # 2b — correction 2).  CMD's io exposes exit_status, which is NIL
      # exactly when the process died by signal: no exit code exists, so
      # the -1 sentinel and :signal are justified by a runner fact.  Every
      # other status — INCLUDING exit 127 whose output happens to contain
      # "not found" words — is an ORDINARY exit that keeps its real code;
      # words in child output are never evidence.
      signal_death = status.nil?
      exit_code = signal_death ? -1 : status
      kind = signal_death ? :signal : nil

      # ONE stream rule on EVERY path (WP-E, plan step 2b): byte-bounded
      # head+tail for BOTH streams, complete stream spooled under the step
      # files_dir whenever the inline copy was truncated.
      failure_result(exit_code, raw_out, raw_err, base: base, failure_kind: kind)
    rescue => e
      kind = classify_runner_exception(e)
      build_exception_result(e, base: base, kind: kind)
    end
  end

  # Classify a raised runner exception from the exception CLASS alone
  # (WP-E, plan step 2b): message text is never trusted as evidence,
  # because a ProcessFailed message embeds the CHILD'S OUTPUT — the exact
  # channel the old word-matching inferences used.  The installed
  # scout-essentials 1.9.3 classes are top-level `ProcessFailed` and
  # `CMD::Timeout < ProcessFailed` (matched FIRST), plus Errno launch
  # failures raised by the spawn itself.  A plain ProcessFailed arriving
  # here carries no reliable signal information, so it stays
  # :runner_exception rather than being guessed at.
  helper :classify_runner_exception do |e|
    case
    when defined?(CMD::Timeout) && CMD::Timeout === e then :timeout
    when Errno::ENOENT === e, Errno::EACCES === e, Errno::ENOEXEC === e then :launch
    else :runner_exception
    end
  end

  # Build a result from a raised runner exception, recovering whatever the
  # underlying API exposes (io streams, exit status); -1 is the sentinel
  # ONLY when no real exit code is available.  WP-E, plan step 2b: both
  # streams go through the SAME shared rule as every other path, and stream
  # text is never nil — when the exception carries no io (the CMD::Timeout
  # of scout-essentials 1.9.3 does not) the streams are honest empty
  # strings plus the runner's own report as the stderr prefix.
  helper :build_exception_result do |e, base: {}, kind: nil|
    program_out = ''
    program_err = ''
    status = -1
    begin
      io = e.io if e.respond_to?(:io)
      if io
        program_out = io.read.to_s if io.respond_to?(:read)
        program_err = io.std_err.to_s if io.respond_to?(:std_err)
        status = io.exit_status if io.respond_to?(:exit_status)
      end
    rescue
      program_out = ''
      program_err = ''
    end
    status = -1 if status.nil?

    prefix = [e.message || e.class.to_s]
    prefix.unshift("failure_kind: #{kind}") if kind

    failure_result(status, program_out, program_err || '', base: base,
                   prefix: prefix.join("\n"), failure_kind: kind)
  end

  # ===========================================================================
  # cmd_json — build interpreter args and delegate to sandbox_run.
  # ===========================================================================
  helper :cmd_json do |tool, cmd, options = {}, writable_paths = []|
    # Normalize command and stdin
    stdin_data = options[:in]

    # Determine interpreter name (tool can be symbol or string)
    interpreter = tool.to_s

    # Build args array based on tool type and provided cmd
    args_array = if Array === cmd
                   cmd
                 elsif interpreter == 'bash'
                   if stdin_data && (cmd.nil? || cmd.to_s.empty?)
                     ['-s']
                   else
                     ['-c', cmd.to_s]
                   end
                 elsif interpreter.start_with?('python') || interpreter == 'ruby' || interpreter == 'Rscript' || interpreter == 'R'
                   # For python, ruby and R-like interpreters prefer running files when a path is given.
                   if cmd && File.exist?(cmd.to_s)
                     if interpreter == 'R'
                       ['--slave', '-f', cmd.to_s]
                     else
                       [cmd.to_s]
                     end
                   else
                     if interpreter == 'R' && stdin_data
                       ['-']
                     else
                       stdin_data ? ['-'] : [cmd.to_s]
                     end
                   end
                 else
                   cmd ? [cmd.to_s] : []
                 end

    # Ensure args are strings
    args_array = Array(args_array).collect(&:to_s)

    # Collect writable dirs to expose inside the sandbox.
    # Build a FRESH array (plan step 8): the call below used to assign the
    # grant list itself and then mutate it with <<, so any caller-supplied
    # `writable_paths` extras were overwritten and only survived by
    # accident.  Keep the parameter intact and union it with the grants.
    writable_paths = (Workspace.get_allowed_paths(:allowed_paths) + Array(writable_paths)).compact.uniq
    begin
      writable_paths << self.files_dir if respond_to?(:files_dir) && self.files_dir && Open.exists?(self.files_dir)
    rescue => _e
    end

    # Run inside sandbox (bwrap) when available, fallback to unsandboxed
    sandbox_run(tool, args_array, options, writable_paths)
  end

  # ===========================================================================
  # Task definitions
  # ===========================================================================

  input :cmd, :string, 'Bash command to run', nil, required: true
  input :timeout, :integer, 'Timeout in seconds', nil
  extension :json
  task 'bash' => :text do |cmd,timeout|
    Log.medium "Bash\n" + cmd
    cmd_json :bash, cmd, timeout: timeout
  end

  input :code, :text, 'Python code to run (ignored if file provided)'
  input :file, :path, 'File to run'
  input :timeout, :integer, 'Timeout in seconds', nil
  extension :json
  task :python => :text do |code, file,timeout|
    if file && !file.to_s.empty?
      file = normalize file
      target = file
    elsif code && !code.to_s.empty?
      tmp = file('script.py')
      tmp.write code
      target = tmp
    else
      raise ParameterException, 'Provide either a file or code to run'
    end

    cmd_name = nil
    ['python3', 'python'].each do |p|
      begin
        io_test = CMD.cmd(p.to_sym, '--version', save_stderr: true, pipe: true, no_fail: true)
        io_test.join
        if io_test.exit_status == 0 || io_test.read.to_s.length > 0
          cmd_name = p
          break
        end
      rescue
        next
      end
    end
    cmd_name ||= 'python'

    begin
      cmd_json cmd_name, target, timeout: timeout
    rescue => e
      raise ScoutException, e.message
    end
  end

  input :code, :text, 'Ruby code to run (ignored if file provided)'
  input :file, :path, 'File to run'
  input :timeout, :integer, 'Timeout in seconds', nil
  extension :json
  task :ruby => :text do |code, file,timeout|
    if file && !file.to_s.empty?
      file = normalize file
      target = file
    elsif code && !code.to_s.empty?
      tmp = file('script.rb')
      tmp.write code
      target = tmp
    else
      raise ParameterException, 'Provide either a file or code to run'
    end

    begin
      cmd_json :ruby, target, timeout: timeout
    rescue => e
      raise ScoutException, e.message
    end
  end

  input :code, :text, 'R code to run (ignored if file provided)'
  input :file, :path, 'File to run'
  input :timeout, :integer, 'Timeout in seconds', nil
  extension :json
  task :r => :text do |code, file,timeout|
    if file && !file.to_s.empty?
      file = normalize file
      target = file
    elsif code && !code.to_s.empty?
      tmp = file('script.R')
      tmp.write code
      target = tmp
    else
      raise ParameterException, 'Provide either a file or code to run'
    end

    cmd_name = nil
    ['Rscript', 'R'].each do |p|
      begin
        io_test = CMD.cmd(p.to_sym, '--version', save_stderr: true, pipe: true, no_fail: true)
        io_test.join
        if io_test.exit_status == 0 || io_test.read.to_s.length > 0
          cmd_name = p
          break
        end
      rescue
        next
      end
    end
    cmd_name ||= 'Rscript'

    begin
      cmd_json cmd_name, target, timeout: timeout
    rescue => e
      raise ScoutException, e.message
    end
  end

  export_exec :bash
  export_exec :python
  export_exec :ruby
  export_exec :r
end
