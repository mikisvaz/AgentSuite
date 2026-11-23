module Workspace
  # ---------------------------------------------------------------------------
  # Unified-diff repair.  Kept from the original: stale hunk counts are
  # recomputed, content lines are copied VERBATIM (a body line that begins
  # with '-' or '+' is content after its marker, never re-stripped).
  # ---------------------------------------------------------------------------
  # Canonical header name for a diff header (plan item 5: headers resolve
  # CONSISTENTLY across probe, conversion and apply).  Every target under
  # the workflow root is rewritten to the `a/<root-relative>` form so the
  # probe and the apply can always run `-p1 -d <root>`; `/dev/null` and
  # paths outside the root are left untouched (the latter are refused by
  # authorization).
  def self.patch_header_name(name, root)
    n = name.to_s
    return n if n == '/dev/null'

    if n.start_with?('/')
      return "a/#{n[(root.length + 1)..]}" if root && n.start_with?(root + '/')
      return n
    end

    parts = n.split('/')
    if parts.length > 1
      prefix = parts.first # `a/...` / `b/...`
      candidate = parts[1..].join('/') # `a//abs/...` → `/abs/...`
      if candidate.start_with?('/') && root && candidate.start_with?(root + '/')
        return "#{prefix}/#{candidate[(root.length + 1)..]}"
      end
    end
    n
  end

  def self.normalize_unified_diff(diff_text)
    root = Workspace.root.to_s
    lines = diff_text.to_s.lines.map(&:chomp)
    output = []
    index = 0

    while index < lines.length
      line = lines[index]
      if line =~ /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$/
        old_start = $1
        new_start = $3
        suffix = $5
        index += 1
        hunk = []
        while index < lines.length && !lines[index].start_with?('@@')
          # A hunk line can itself begin with `--- ` or `+++ ` when its
          # content starts with dashes/pluses. Only treat the pair as a file
          # header when both header lines occur together.
          file_header = lines[index].start_with?('--- ') &&
            index + 1 < lines.length && lines[index + 1].start_with?('+++ ')
          break if file_header

          hunk << lines[index]
          index += 1
        end

        old_count = hunk.count { |entry| entry.start_with?(' ', '-') && entry !~ /\A\\ No newline/ }
        new_count = hunk.count { |entry| entry.start_with?(' ', '+') && entry !~ /\A\\ No newline/ }
        output << "@@ -#{old_start},#{old_count} +#{new_start},#{new_count} @@#{suffix}"
        output.concat(hunk)
      else
        if line =~ %r{^(---|\+\+\+) (\S+)(.*)$}
          name = $2
          output << "#{$1} #{patch_header_name(name, root)}#{$3}"
        else
          output << line
        end
        index += 1
      end
    end

    output.join("\n") + "\n"
  end

  # Shared safety check for a patch-target path.  Confinement to the workflow
  # root (no `..`, no absolute escape) is the pre-existing policy and stays;
  # AUTHORIZATION is delegated to the workflow grant mechanism via the task's
  # `normalize` helper, so this file carries no private policy (plan item 4).
  def self.patch_rel_path(path)
    p = path.to_s.strip
    raise ScoutException, 'Empty patch target path' if p.empty?
    p
  end

  # ---------------------------------------------------------------------------
  # THE block parser (the only one — plan item 3: parse once, share).
  #
  # Returns nil when the text carries no `*** ... File:` directive at all (a
  # raw unified diff, or plain content without structure).
  #
  # Body entries keep their ORIGINAL content byte-for-byte: each entry is
  # `{ t: <chomped line>, f: <fenced?> }`.  `f` marks lines captured inside a
  # ``` fence: they are opaque PAYLOAD — a fence containing `--- a/x` or
  # `@@ ... @@` lines must never be interpreted as patch structure.  The
  # fence lines themselves are structure and are dropped.
  #
  # `final_newline` records whether the block body's last content line ended
  # with a newline in the source text, so content round-trips byte-exactly
  # (plan item 6, files without a final newline).
  # ---------------------------------------------------------------------------
  def self.parse_patch_blocks(patch_text)
    return nil if patch_text.nil?

    blocks = []
    current = nil
    in_code_fence = false

    close_block = lambda do |blk, last_raw|
      return if blk.nil?
      blk[:final_newline] = blk[:body].empty? ? true : last_raw.to_s.end_with?("\n")
    end

    last_raw_for_current = nil
    patch_text.each_line do |raw|
      line = raw.chomp

      if line.start_with?('```')
        # A fence marker INSIDE a block body is part of the content being
        # written (Markdown files legitimately contain ``` lines), so it is
        # recorded and the payload between markers is opaque.  Outside any
        # block it is patch-level formatting and is ignored without
        # toggling, so a patch wrapped in ``` fences still works.
        if current
          current[:body] << { t: line, f: :fence }
          last_raw_for_current = raw
          in_code_fence = !in_code_fence
        end
        next
      end

      directive = case line
                  when /\A\*\*\*\s*Begin Patch/i then :begin
                  when /\A\*\*\*\s*End Patch/i then :end
                  when /\A\*\*\*\s*Update File:\s*(.+)/i then [:update, $1]
                  when /\A\*\*\*\s*Add File:\s*(.+)/i then [:add, $1]
                  when /\A\*\*\*\s*Delete File:\s*(.+)/i then [:delete, $1]
                  end

      if directive && !in_code_fence
        close_block.call(current, last_raw_for_current)
        case directive
        when :begin
          current = nil
        when :end
          current = nil
        else
          action, path = directive
          current = { action: action, path: path.strip, body: [], final_newline: true }
          blocks << current
          last_raw_for_current = nil
        end
        next
      end

      next if current.nil?

      current[:body] << { t: line, f: in_code_fence ? :fenced : false }
      last_raw_for_current = raw
    end
    close_block.call(current, last_raw_for_current)

    blocks.empty? ? nil : blocks
  end

  # Content lines of a block, in order.
  def self.patch_block_lines(blk)
    blk[:body].map { |e| e[:t] }
  end

  # Add File body lines with their marker consumed: a body line that starts
  # with exactly one `+` contributes the REST of the line (the ChatGPT
  # `+content` Add convention, kept from the original implementation); any
  # other line contributes itself verbatim.  Applies to ADD blocks only, so
  # plain Update bodies keep their verbatim semantics.
  def self.patch_add_body_lines(blk)
    patch_block_lines(blk).map { |l| l.start_with?('+') ? l[1..] : l }
  end

  # True when the block body is a sequence of whole-file payload lines, with
  # no unified-diff markers to interpret: either explicit fenced payload, or
  # lines that carry no marker prefix.  A lone leading bare `@@` opener is
  # structure, not payload (the ChatGPT plain-body convention).  An ADD body
  # that USES the `+` prefix (any line starts with `+`) is plain in the
  # step-8 sense: the `+` is the content prefix, not a diff marker, so the
  # whole body is marker-style payload and one leading `+` per line is
  # consumed.  An ADD body with no `+` at all stays verbatim plain payload.
  def self.patch_block_plain?(blk)
    entries = blk[:body].dup
    entries.shift if entries.first && entries.first[:t] == '@@' && !entries.first[:f]
    if blk[:action] == :add && !entries.empty? &&
       entries.any? { |e| !e[:f] && e[:t].start_with?('+') } &&
       entries.none? { |e| !e[:f] && e[:t].start_with?('-') }
      return true
    end
    entries.empty? ||
      entries.all? do |e|
        e[:f] == :fence || e[:f] == :fenced || !e[:t].start_with?('@@', '+', '-', '--- ', '+++ ')
      end
  end

  # The exact file content a plain block stands for, honoring the presence or
  # absence of a final newline.  A lone leading bare `@@` opener is structure,
  # not payload.  An ADD block consumes exactly one leading `+` per body line
  # (the two writers — diff emission and direct write — must agree).
  def self.patch_block_content(blk)
    lines = patch_block_lines(blk)
    # ADD: a plain body consumes exactly one leading `+` per line (the step-8
    # convention, kept identical in the diff-emission path); a marker-style
    # Add body stays verbatim.  Other actions keep their lines verbatim here.
    if blk[:action] == :add && patch_block_plain?(blk)
      lines = patch_add_body_lines(blk)
    end
    lines.shift if lines.first == '@@' && !blk[:body].first[:f]
    return '' if lines.empty?
    joined = lines.join("\n")
    joined += "\n" if blk[:final_newline]
    joined
  end

  # Serialize a diff body line with the marker prefix and the content
  # verbatim — no `sub` on the content, so "-literal"/"+literal" file content
  # round-trips byte-exactly (plan item 6).
  def self.diff_body_line(prefix, content)
    "#{prefix}#{content}\n"
  end

  def self.no_newline_marker
    "\\ No newline at end of file\n"
  end

  # Read (path-authorized by the caller BEFORE this runs — plan item 4) the
  # current state of a target: [lines, final_newline, exists].
  def self.patch_read_state(root, rel)
    path = File.join(root, rel)
    return [[], true, false] unless File.exist?(path)
    content = File.open(path, 'rb') { |f| f.read }
    return [[], true, true] if content.empty?
    parts = content.split("\n", -1)
    if parts.last == ''
      [parts[0, parts.length - 1], true, true]
    else
      [parts, false, true]
    end
  end

  # ---------------------------------------------------------------------------
  # Conversion.  Returns a hash:
  #   text        — the unified diff handed to the system `patch` tool
  #   expressible — false when the blocks cannot be represented as a unified
  #                 diff at all (creating an EMPTY file, deleting an EMPTY or
  #                 MISSING file): the probe loop must be skipped and the
  #                 direct fallback (or an explicit refusal) used instead.
  #   blocks      — the shared parse (nil for raw unified diffs)
  # ---------------------------------------------------------------------------
  def self.convert_chatgpt_patch_with_meta(patch_text)
    return { text: '', expressible: true, blocks: nil } if patch_text.nil?

    # Header resolution is consistent across the probe, conversion and apply
    # paths (plan item 5): a text that contains *** Update/Add/Delete File
    # directives is ALWAYS a ChatGPT block patch — never a raw unified diff —
    # even when its payload contains lines that look like `--- a/…` headers.
    # The raw-diff branch is only reachable when no block directive exists.
    blocks = parse_patch_blocks(patch_text)
    if blocks.nil?
      if patch_text =~ /^--- \S/ && patch_text =~ /^\+\+\+ \S/
        return { text: normalize_unified_diff(patch_text), expressible: true, blocks: nil }
      end
      return { text: patch_text + "\n", expressible: true, blocks: nil }
    end

    root = Workspace.root.to_s

    ensure_rel = lambda do |p|
      p = patch_rel_path(p)
      if p.start_with?('/')
        if p.start_with?(root + '/') || p == root
          p = p.sub(/^#{Regexp.escape(root)}\/?/, '')
        else
          p = p.sub(%r{^/+}, '')
        end
      end
      p = p.sub(%r{^\./+}, '')
      raise ScoutException, "Unsafe path: #{p}" if p.include?('..')
      raise ScoutException, 'Empty patch target path' if p.empty?
      p
    end

    find_match = lambda do |file_lines, target_lines|
      return nil if target_lines.empty?
      raise ScoutException, 'Could not locate hunk context in file' if target_lines.length > file_lines.length

      matches = []
      (0..file_lines.length - target_lines.length).each do |i|
        matches << i if file_lines[i, target_lines.length] == target_lines
      end

      if matches.empty?
        raise ScoutException, 'Could not locate hunk context in file'
      elsif matches.length > 1
        raise ScoutException, 'Ambiguous hunk: multiple matches found'
      end

      matches.first
    end

    # Whole-content replacement section.  Returns false when the change
    # cannot be expressed (empty target content on the new side with an
    # empty/absent old side).
    emit_replacement = lambda do |a_name, b_name, old_lines, old_nl, new_lines, new_nl, out|
      if old_lines.empty? && new_lines.empty?
        out << "--- #{a_name}\n"
        out << "+++ #{b_name}\n"
        out << "@@ -0,0 +0,0 @@\n"
        false
      elsif old_lines.empty?
        out << "--- /dev/null\n"
        out << "+++ #{b_name}\n"
        out << "@@ -0,0 +1,#{new_lines.length} @@\n"
        new_lines.each_with_index do |l, i|
          out << diff_body_line('+', l)
          out << no_newline_marker if i == new_lines.length - 1 && !new_nl
        end
        true
      elsif new_lines.empty?
        # Empty new side.  With a `/dev/null` b-side this is a REAL DELETION
        # (`@@ -1,N +0,0 @@`).  With a real b-name it is an update-to-empty:
        # the file EXISTS with zero bytes after apply, so the new range is
        # `+1,0`, not `+0,0`.
        deletion = b_name == '/dev/null'
        out << "--- #{a_name}\n"
        out << "+++ #{b_name}\n"
        out << "@@ -1,#{old_lines.length} #{deletion ? '+0,0' : '+1,0'} @@\n"
        old_lines.each_with_index do |l, i|
          out << diff_body_line('-', l)
          out << no_newline_marker if i == old_lines.length - 1 && !old_nl
        end
        true
      else
        out << "--- #{a_name}\n"
        out << "+++ #{b_name}\n"
        out << "@@ -1,#{old_lines.length} +1,#{new_lines.length} @@\n"
        old_lines.each_with_index do |l, i|
          out << diff_body_line('-', l)
          out << no_newline_marker if i == old_lines.length - 1 && !old_nl
        end
        new_lines.each_with_index do |l, i|
          out << diff_body_line('+', l)
          out << no_newline_marker if i == new_lines.length - 1 && !new_nl
        end
        true
      end
    end

    out = []
    expressible = true

    blocks.each do |blk|
      rel = ensure_rel.call(blk[:path])
      a_name = Workspace.patch_header_name("a/#{blk[:path]}", root)
      b_name = Workspace.patch_header_name("b/#{blk[:path]}", root)
      body = blk[:body]

      case blk[:action]
      # ------------------------------------------------------------------
      # ADD FILE — plain content by definition; a non-empty add is a
      # replacement against /dev/null.  An EMPTY add is not expressible.
      # ------------------------------------------------------------------
      when :add
        # An Add body that is "plain" (fenced or marker-free) carries literal
        # file content prefixed with a single `+` per line (the step-8
        # convention): exactly one leading `+` is consumed.  A marker-style
        # Add body is a literal payload and stays verbatim.
        new_lines = patch_block_plain?(blk) ? patch_add_body_lines(blk) : patch_block_lines(blk)
        ok = emit_replacement.call(a_name, b_name, [], true, new_lines, blk[:final_newline], out)
        expressible &&= ok

      # ------------------------------------------------------------------
      # DELETE FILE — old content verbatim after '-'.  Deleting an empty or
      # missing file is not expressible.
      # ------------------------------------------------------------------
      when :delete
        old_lines, old_nl, exists = patch_read_state(root, rel)
        if !exists || old_lines.empty?
          out << "--- #{a_name}\n"
          out << "+++ /dev/null\n"
          out << "@@ -0,0 +0,0 @@\n"
          expressible = false
        else
          emit_replacement.call(a_name, '/dev/null', old_lines, old_nl, [], true, out)
        end

      # ------------------------------------------------------------------
      # UPDATE FILE
      # ------------------------------------------------------------------
      when :update
        # A lone leading bare `@@` opener is structure, not payload; it is
        # excluded from the fenced/marker mixing check.
        body_entries = body.dup
        body_entries.shift if body_entries.first && body_entries.first[:t] == '@@' && !body_entries.first[:f]
        fenced = body_entries.any? { |e| e[:f] == :fenced }
        unfenced_markers = body_entries.any? do |e|
          !e[:f] && e[:t].start_with?('@@', '+', '-', '--- ', '+++ ')
        end

        if fenced && unfenced_markers
          raise ScoutException,
                'Mixed fenced payload and diff markers in one update block; ' \
                'put the whole replacement inside a single fence or use markers only'
        end

        if patch_block_plain?(blk)
          # Whole-content replacement (the ChatGPT plain-body convention).
          old_lines, old_nl, exists = patch_read_state(root, rel)
          old_for_diff = exists ? old_lines : []
          body_lines = patch_block_lines(blk)
          body_lines.shift if body_lines.first == '@@' && !blk[:body].first[:f]
          new_lines = body_lines
          ok = emit_replacement.call(a_name, b_name, old_for_diff, old_nl, new_lines, blk[:final_newline], out)
          expressible &&= ok
          next
        end

        # Marker-style body: hunks resolved against the current file.
        old_lines, _old_nl, _exists = patch_read_state(root, rel)
        file_lines = old_lines

        out << "--- #{a_name}\n"
        out << "+++ #{b_name}\n"

        hunks = []
        current_hunk = []
        marker_lines = patch_block_lines(blk)
        marker_lines.shift if marker_lines.first == '@@' && !blk[:body].first[:f]
        marker_lines.each do |line|
          if line.start_with?('@') && line =~ /\A@@/
            hunks << current_hunk unless current_hunk.empty?
            current_hunk = [line]
          else
            current_hunk << line
          end
        end
        hunks << current_hunk unless current_hunk.empty?

        # No @@ at all → the whole body is one contextual hunk.
        if hunks.length == 1 && !hunks.first.first.start_with?('@@')
          hunks = [['@@'] + hunks.first]
        end

        hunks.each do |hunk|
          header = hunk.first
          lines = hunk[1..] || []

          if header =~ /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/
            old_start = $1.to_i
            new_start = $3.to_i
            computed_old = lines.count { |l| !l.start_with?('+') }
            computed_new = lines.count { |l| !l.start_with?('-') }
            out << "@@ -#{old_start},#{computed_old} +#{new_start},#{computed_new} @@\n"
            lines.each do |l|
              out << (l.start_with?(' ', '+', '-') ? "#{l}\n" : " #{l}\n")
            end
          else
            # Contextual (bare `@@`) hunk.  PLAIN lines and ' ' lines are
            # CONTEXT, '-' deletions, '+' additions.  The old side (context +
            # deletions, in order) must appear CONTIGUOUSLY in the file; the
            # hunk starts at that position.  A pure-context body (`alpha`,
            # `BETA`) is the ChatGPT "replace this region with these lines"
            # shape: its old side is the context sequence alone.
            old_side = lines.reject { |l| l.start_with?('+') }
                            .map { |l| l.start_with?(' ', '-') ? l[1..] : l }

            raise ScoutException, 'Cannot resolve hunk without context or deletions' if old_side.empty?

            index = find_match.call(file_lines, old_side)

            old_start = index + 1
            old_count = lines.count { |l| !l.start_with?('+') }
            new_count = lines.count { |l| !l.start_with?('-') }
            out << "@@ -#{old_start},#{old_count} +#{old_start},#{new_count} @@\n"
            lines.each do |l|
              out << (l.start_with?(' ', '+', '-') ? "#{l}\n" : " #{l}\n")
            end
          end
        end
      end
    end

    text = out.join
    text = text + "\n" unless text.end_with?("\n")
    { text: text, expressible: expressible, blocks: blocks }
  end

  # Public entry kept for compatibility: returns the converted diff text.
  def self.convert_chatgpt_patch(patch_text)
    convert_chatgpt_patch_with_meta(patch_text)[:text]
  end


  # ---------------------------------------------------------------------------
  # THE operation-aware target plan (the one list every later step consumes:
  # authorization, strip selection, conversion, dry-run preview, apply and
  # changed_files reporting).  Each record is
  #   { action: :write | :delete, rel: <root-relative>, abs: <absolute> }
  # Built from BOTH target sources — `*** ... File:` block directives (when
  # present) and raw `---`/`+++` header pairs otherwise — resolved for the
  # given strip with the same `parts.drop(strip)` rule the probe's `-pN`
  # applies, plus the root-prefix / `./` normalization the direct writer uses.
  # ---------------------------------------------------------------------------
  # Resolve ONE `*** ... File:` directive path to `[rel, abs]` with exactly
  # the normalization the target plan uses (root-prefix stripping, `./`
  # removal, unsafe-path refusal).  Shared by the plan builder and the task's
  # block preconditions (WP-B'), so the two can never disagree.
  def self.patch_block_target(path, root)
    root = root.to_s
    raw = path.to_s.strip
    if raw.start_with?('/')
      if raw == root || raw.start_with?(root + '/')
        rel = raw == root ? '' : raw[(root.length + 1)..]
        abs = raw
      else
        # Outside-root absolute: authorize the LITERAL path so the grant
        # mechanism (not this file) is what refuses it — the legacy step-2 rule.
        rel = raw
        abs = raw
      end
    else
      rel = raw.sub(%r{^\./+}, '')
      abs = File.join(root, rel)
    end
    raise ScoutException, "Unsafe patch target: #{raw}" if rel.empty? || rel.include?('..')
    [rel, abs]
  end

  def self.patch_target_plan(patch_text, root, strips)
    root = root.to_s
    blocks = parse_patch_blocks(patch_text)
    strips = [strips].flatten.compact.map(&:to_i).uniq

    # Resolve one header name for one strip.  Returns [rel, abs]: a rel that
    # still starts with `/` names an ABSOLUTE target outside the root grant,
    # and its abs is the literal path (not root-joined) so the grant check —
    # not this file — is what refuses it.
    to_target = lambda do |name, strip|
      p = name.to_s.strip
      next nil if p.empty? || p == '/dev/null'
      p = patch_header_name(p, root) if p.start_with?('/')
      parts = p.split('/')
      parts = parts.drop(strip) if strip.to_i > 0
      rel = parts.join('/')
      rel = rel.sub(%r{^\./+}, '')
      next nil if rel.empty? || rel.include?('..')
      abs = rel.start_with?('/') ? rel : File.join(root, rel)
      [rel, abs]
    end

    plan = []
    if blocks
      blocks.each do |blk|
        raw = blk[:path].to_s.strip
        next if raw.empty? || raw == '/dev/null'
        rel, abs = patch_block_target(raw, root)
        plan << { action: blk[:action] == :delete ? :delete : :write,
                  rel: rel, abs: abs }
      end
    else
      text = patch_text.to_s
      lines = text.lines.map(&:chomp)
      a_name = nil
      lines.each_with_index do |line, i|
        if line =~ /^--- (\S+)/
          a_name = $1
          next
        end
        next unless line =~ /^\+\+\+ (\S+)/
        b_name = $1
        strips.each do |strip|
          if b_name == '/dev/null'
            t = to_target.call(a_name, strip)
            plan << { action: :delete, rel: t[0], abs: t[1] } if t
          else
            t = to_target.call(b_name, strip)
            plan << { action: :write, rel: t[0], abs: t[1] } if t
          end
        end
        a_name = nil
      end
    end

    plan.uniq { |t| [t[:action], t[:rel]] }
  end

  # Raw-diff (and generated-diff) plan for a single strip — the shape the
  # apply/report steps need once the probe has selected `-pN`.
  def self.patch_raw_target_plan(diff_text, strip, root = nil)
    root ||= Workspace.root.to_s
    lines = diff_text.to_s.lines.map(&:chomp)
    a_name = nil
    plan = []
    lines.each do |line|
      if line =~ /^--- (\S+)/
        a_name = $1
        next
      end
      next unless line =~ /^\+\+\+ (\S+)/
      b_name = $1
      next if b_name == '/dev/null' && (a_name.nil? || a_name.empty? || a_name == '/dev/null')
      p = b_name == '/dev/null' ? a_name : b_name
      next if p.nil? || p.to_s.empty? || p == '/dev/null'
      p = patch_header_name(p, root) if p.start_with?('/')
      parts = p.split('/')
      # `a/` and `b/` are diff MARKERS, not path components: a strip count
      # that removes exactly the marker (or, for a header that carries no
      # marker, a strip count of 0) is the CANONICAL placement of that
      # header.  Anything else only "places" when the file happens to be
      # there, which is what the ambiguity check below is about.
      canonical = (strip.to_i == 1 && %w[a b].include?(parts.first)) ||
                  (strip.to_i.zero? && !%w[a b].include?(parts.first))
      parts = parts.drop(strip.to_i) if strip.to_i > 0
      rel = parts.join('/')
      rel = rel.sub(%r{^\./+}, '')
      next if rel.empty? || rel.include?('..')
      abs = rel.start_with?('/') ? rel : File.join(root, rel)
      # :source_exists records that the plan is a genuine create (b-side
      # present and a-side /dev/null), so placement does not require the
      # target to exist yet.  Everything else must already be on disk.
      source_exists = !(b_name != '/dev/null' && a_name == '/dev/null')
      plan << { action: b_name == '/dev/null' ? :delete : :write,
                rel: rel, abs: abs,
                source_exists: source_exists, canonical: canonical }
    end
    plan.uniq { |t| [t[:action], t[:rel]] }
  end

  input :patch, :text, 'Patch content', nil, required: true
  input :strip, :integer, 'Number for patch -pN (strip count). Required (no auto-detect) when more than one candidate strip count would place the patch; otherwise nil auto-detects.', nil
  input :dry_run, :boolean, 'Preview the system patch command. Read-only: never applies, never writes targets, even when apply_direct is true.', false
  input :apply_direct, :boolean, 'Allow eligible plain-content blocks (*** ... File:) to write directly when no strip count succeeds or the change is not diff-expressible. Raw unified diffs are never applied directly. Ignored during dry_run.', false
  extension :json
  task :patch => :text do |patch_text, strip, dry_run, apply_direct|
    patch_text ||= ''
    dry_run = !!dry_run
    apply_direct = !!apply_direct && !dry_run

    file('original.patch').write patch_text

    tried = []
    final = nil
    used_strip = nil

    root = Workspace.root.to_s

    # -----------------------------------------------------------------------
    # 1. PARSE ONCE (plan items 3, 5).  The same block plan feeds
    #    authorization, conversion, the block preconditions and the direct
    #    writer (blocks only — a raw diff is never applied by hand).
    # -----------------------------------------------------------------------
    blocks = Workspace.parse_patch_blocks(patch_text)

    # -----------------------------------------------------------------------
    # 2. AUTHORIZATION BEFORE ANY CONVERSION READ OR PROBE (plan item 4).
    #    The ONE target plan covers BOTH sources — block directives AND raw
    #    `---`/`+++` header pairs — resolved for every candidate strip, so a
    #    raw deletion (`+++ /dev/null`) is authorized exactly like a block
    #    delete, and an ungranted target is refused before a single byte of
    #    it is read or patched.
    # -----------------------------------------------------------------------
    candidate_strips = strip.nil? ? [1, 0, 2, 3, 4] : [strip.to_i]
    target_plan = Workspace.patch_target_plan(patch_text, root, candidate_strips)
    target_plan.each { |t| normalize(t[:abs], :write) }

    meta = Workspace.convert_chatgpt_patch_with_meta(patch_text)
    generated = meta[:text]
    expressible = meta[:expressible]
    tmp_patch = file('patch.diff')
    tmp_patch.write generated

    # Full diff artifact (plan item 8): every result points at it; the inline
    # diagnostics stay bounded.
    full_diff_path = begin
      persist_full_stream(generated, 'patch_full')
    rescue StandardError
      nil
    end

    build_base = lambda do |extra = {}|
      base = {
        generated_patch: bound_head_tail(generated, 4000),
        tried_strips: tried,
        used_strip: used_strip,
        applied: false,
        applied_directly: false
      }
      base[:patch_full] = full_diff_path if full_diff_path
      base.merge(extra)
    end

    # -----------------------------------------------------------------------
    # 3. STRIP PROBE (plan item 5).  One candidate list, one header
    #    expectation, `-d root` on BOTH the probe and the apply so the two
    #    resolve header names identically without any process chdir (item 7).
    #    A "malformed"/garbage probe is TERMINAL (item 2): the real child
    #    output is reported and nothing else runs.
    # -----------------------------------------------------------------------
    probe_args = lambda do |p, extra = []|
      ['--batch', "-p#{p}", '-d', root, *extra, '-i', tmp_patch.to_s]
    end

    probe = lambda do |p|
      res = cmd_json(:patch, probe_args.call(p, ['--dry-run']))
      tried << { strip: p,
                 stdout: bound_head_tail(res[:stdout].to_s, 2000),
                 stderr: bound_head_tail(res[:stderr].to_s, 2000),
                 exit_status: res[:exit_status] }
      final = res
      res
    end

    # A candidate strip count PLACES the patch when (a) the dry-run child
    # exited 0, (b) the strip resolves to a non-empty target set, and (c)
    # every target the plan means to REPLACE or DELETE already exists.  GNU
    # patch exits 0 for "which does not exist!  Assuming -R" — a silent
    # re-interpretation, not a placement — and exits 0 for EVERY -pN on a
    # create diff, so the plan (not the exit code) decides placement.  A
    # genuine create (b-side present, a-side /dev/null, target absent) is a
    # placement with no existence requirement.
    placed = lambda do |p|
      plan = Workspace.patch_raw_target_plan(generated, p, root)
      return false if plan.empty?
      plan.all? do |t|
        # A genuine create places only at its CANONICAL strip (GNU patch
        # exits 0 for every -pN on a create, so the exit code says nothing).
        next t[:canonical] if t[:action] == :write && t[:source_exists] == false
        # A replace or delete must find the file on disk: exit 0 with
        # "which does not exist!  Assuming -R" is a silent re-interpretation.
        File.exist?(t[:abs])
      end
    end

    malformed_result = nil
    working_strips = []
    if expressible
      candidate_strips.each do |p|
        res = probe.call(p)

        if res[:exit_status].to_i == 0 && placed.call(p)
          working_strips << p
          next
        end

        combined = [res[:stdout], res[:stderr]].join("\n")
        if working_strips.empty? &&
           (combined.include?('malformed') || combined.include?('Only garbage'))
          malformed_result = build_base.call(
            exit_status: res[:exit_status].to_i,
            stdout: res[:stdout].to_s,
            stderr: res[:stderr].to_s,
            failure_kind: :malformed_patch,
            changed_files: [],
            suggestion: 'Patch text is malformed. Inspect stdout/stderr and the patch_full artifact; fix the patch and retry.'
          ).to_json
          break
        end
      end
    end

    next malformed_result if malformed_result

    # -----------------------------------------------------------------------
    # 3a. BLOCK PRECONDITIONS (WP-B' item d).  An Update File block naming a
    #     MISSING target must NOT create it (round-1 decision D6 reversed):
    #     refuse with a bounded diagnostic that names the absent target,
    #     before any probe has had a chance to apply anything.  Nothing has
    #     been written at this point, so every candidate file keeps its
    #     bytes.
    # -----------------------------------------------------------------------
    if blocks
      absent_rel = nil
      blocks.each do |blk|
        next unless blk[:action] == :update
        rel, abs = Workspace.patch_block_target(blk[:path], root)
        unless File.exist?(abs)
          absent_rel = rel
          break
        end
      end
      if absent_rel
        next build_base.call(
          exit_status: 1,
          stdout: '',
          stderr: "Update target does not exist: #{absent_rel}",
          failure_kind: :absent_target,
          changed_files: [],
          suggestion: "Update File names #{absent_rel}, which does not exist; patch does not " \
                      'create files. Use the write task to create it (or delete to remove it), ' \
                      'or an Add File block to add it through a patch.'
        ).to_json
      end
    end

    # -----------------------------------------------------------------------
    # 3b. STRIP PLACEMENT MUST BE UNIQUE (WP-B' item c).  GNU patch exits 0
    #     for MANY -pN values on the same diff (it silently re-interprets or
    #     reverses at odd strips), so "exit 0" alone cannot pick one.  The
    #     placement is what matters: two candidate strips are the same
    #     placement only when they resolve to the same (action, rel) target
    #     set.  When more than one DISTINCT placement exists and no explicit
    #     `strip` was given, refuse to guess — an explicit strip is required.
    #     Every probe so far was a --dry-run, so nothing has been written.
    # -----------------------------------------------------------------------
    if working_strips.length > 1 && strip.nil?
      placement_by_strip = {}
      working_strips.each do |p|
        placement_by_strip[p] =
          Workspace.patch_raw_target_plan(generated, p, root)
                    .map { |t| [t[:action], t[:rel]] }.uniq.sort
      end
      distinct = placement_by_strip.values.uniq
      if distinct.length > 1
        placements = placement_by_strip.map do |p, set|
          rels = set.map { |_a, rel| rel }
          "-p#{p} → #{rels.empty? ? '(no target resolved)' : rels.join(', ')}"
        end
        placement_text = placements.join(' ; ')
        placement_text = placement_text[0, 400] + '...' if placement_text.length > 400
        next build_base.call(
          exit_status: 2,
          stdout: '',
          stderr: "Ambiguous strip placement: #{working_strips.inspect} resolve to different " \
                  "targets (#{placement_text}); refusing to guess",
          failure_kind: :ambiguous_strip,
          changed_files: [],
          suggestion: 'More than one strip count places this patch, so no placement was chosen ' \
                      'and nothing was written. Re-run with an explicit strip input (patch -pN) ' \
                      'naming the placement you mean; inspect tried_strips and the patch_full artifact.'
        ).to_json
      end
    end
    used_strip = working_strips.first

    # -----------------------------------------------------------------------
    # 4. NO WORKING STRIP → plain-block direct writer (blocks only); a raw
    #    unified diff is NEVER applied by hand (WP-B' item a: the raw-diff
    #    direct fallback is gone).  dry_run NEVER reaches the writer:
    #    apply_direct was forced false for dry runs at the top of the task.
    # -----------------------------------------------------------------------
    if used_strip.nil?
      plain_plan = blocks && blocks.all? { |blk| Workspace.patch_block_plain?(blk) }

      if apply_direct && plain_plan
        # -- 4a. VALIDATE THE COMPLETE PLAN BEFORE ANY WRITE ----------------
        # All targets were authorized in step 2.  Re-check the local
        # conditions that can fail mid-commit; only when EVERY block
        # validates does the commit loop start, and the loop records exactly
        # which files changed (truthful report when commit is not atomic).
        plan = blocks.map do |blk|
          rel, abs = Workspace.patch_block_target(blk[:path], root)
          raise ScoutException, "Patch target is a directory: #{abs}" if File.directory?(abs)
          if blk[:action] == :update && !File.exist?(abs)
            raise ScoutException,
                  "Update target does not exist: #{rel} (patch does not create files; use write)"
          end
          { action: blk[:action], rel: rel, abs: abs, content: Workspace.patch_block_content(blk) }
        end

        changed = []
        begin
          plan.each do |op|
            case op[:action]
            when :add, :update
              FileUtils.mkdir_p(File.dirname(op[:abs]))
              tmp = "#{op[:abs]}.tmp.#{Process.pid}"
              File.open(tmp, 'wb') { |f| f.write(op[:content]) }
              FileUtils.mv(tmp, op[:abs])
            when :delete
              FileUtils.rm_f(op[:abs])
            end
            changed << op[:rel]
          end
          next build_base.call(
            exit_status: 0,
            stdout: '',
            stderr: '',
            applied: true,
            applied_directly: true,
            changed_files: changed,
            suggestion: 'Applied directly.'
          ).to_json
        rescue StandardError => e
          tried << { strip: 'apply_direct', stdout: '', stderr: e.message, exit_status: 1 }
          next build_base.call(
            exit_status: 1,
            stdout: '',
            stderr: e.message,
            applied: false,
            applied_directly: false,
            changed_files: changed,
            failure_kind: :partial_commit,
            suggestion: 'Direct apply failed part-way. changed_files lists every file already written; inspect and reconcile manually.'
          ).to_json
        end
      end

      if blocks.nil?
        # -- 4b. (REMOVED, WP-B' item a) RAW-DIFF DIRECT FALLBACK -------------
        # A raw unified diff is never applied by hand anymore.  When no
        # candidate strip worked, the result below reports the bounded
        # child output and points at the patch_full artifact; every
        # candidate file keeps its bytes.
        # The refusal must not inherit a 0 exit status from a child that
        # merely exited 0 while silently re-interpreting the diff
        # ("Assuming -R"): nothing was applied, so the task result cannot
        # look successful.
        child_status = final ? final[:exit_status].to_i : 1
        child_status = 1 if child_status.zero?
        next build_base.call(
          exit_status: child_status,
          stdout: (final ? final[:stdout].to_s : ''),
          stderr: (final ? final[:stderr].to_s : 'Patch did not apply: no strip count placed it.'),
          changed_files: [],
          failure_kind: :patch_not_applied,
          suggestion: 'Patch did not apply. Inspect tried_strips and the patch_full artifact ' \
                      '(the full diff text is saved there); fix the patch and retry, or pass an ' \
                      'explicit strip. Raw diffs are never applied directly.'
        ).to_json
      end
      if expressible
        suggestion = 'Could not auto-detect -p. Review tried_strips, verify paths in generated_patch, or specify strip explicitly.'
        if dry_run
          suggestion = 'Dry run found no working strip count; nothing was written. Review tried_strips and patch_full.'
        elsif !expressible && blocks
          suggestion = 'Not expressible as a unified diff (empty file add/delete). Re-run with apply_direct: true to write directly.'
        end
        next build_base.call(
          exit_status: (final ? final[:exit_status].to_i : 1),
          stdout: (final ? final[:stdout].to_s : ''),
          stderr: (final ? final[:stderr].to_s : ''),
          suggestion: suggestion
        ).to_json
      else
        suggestion = if blocks
                       'Patch is not expressible as a unified diff (empty file add/delete).' +
                         (dry_run ? ' dry_run is read-only; re-run with dry_run: false and apply_direct: true to write directly.' : ' Re-run with apply_direct: true to write directly, or make the change expressible.')
                     else
                       'Could not process the patch. Review generated_patch and patch_full.'
                     end
        next build_base.call(
          exit_status: 1,
          stdout: '',
          stderr: (final ? final[:stderr].to_s : ''),
          failure_kind: :not_expressible,
          suggestion: suggestion
        ).to_json
      end
    end

    # -----------------------------------------------------------------------
    # 5. DRY RUN (plan item 1).  Read-only by construction: apply_direct was
    #    forced false for a dry call, and execution stops here.
    # -----------------------------------------------------------------------
    if dry_run
      next build_base.call(
        exit_status: final[:exit_status].to_i,
        stdout: final[:stdout].to_s,
        stderr: final[:stderr].to_s,
        applied: false,
        changed_files: target_plan.map { |t| t[:rel] },
        suggestion: 'Dry run OK. Re-run with dry_run: false to apply.'
      ).to_json
    end

    # -----------------------------------------------------------------------
    # 6. APPLY with the SAME strip the probe selected (plan item 5) and the
    #    same `-d root` header resolution.  Every plan target (both sources,
    #    every candidate strip) was already authorized at step 2, BEFORE the
    #    probe ran.
    # -----------------------------------------------------------------------
    apply_res = cmd_json(:patch, probe_args.call(used_strip))
    ok = apply_res[:exit_status].to_i == 0
    result = build_base.call(
      exit_status: apply_res[:exit_status],
      stdout: apply_res[:stdout].to_s,
      stderr: apply_res[:stderr].to_s,
      applied: ok,
      suggestion: ok ? 'Applied successfully.' : 'Patch failed on apply. Inspect stderr and the patch_full artifact.'
    )
    if ok
      result[:changed_files] = Workspace
                               .patch_raw_target_plan(generated, used_strip, root)
                               .map { |t| t[:rel] }
    end
    next result.to_json
  end

  export_exec :patch
end
