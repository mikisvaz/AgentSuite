module Workspace

  def self.get_allowed_paths(type)
    LLM::Sandbox.grant_paths(type, scope: 'Workspace')
  end

  @root = Dir.pwd
  singleton_class.attr_accessor :root

  def self.allowed_paths
    LLM::Sandbox.writable_grants(scope: 'Workspace')
  end

  def self.allowed_read_paths
    LLM::Sandbox.readable_grants(scope: 'Workspace')
  end

  # Authorization goes through the shared LLM::Sandbox containment policy.
  # The original path spelling is preserved for all filesystem operations;
  # Decision#canonical_path is an authorization/diagnostic value only.
  #
  # ScoutCoder: LLM::Sandbox.resolve_path treats '~...' as a relative path
  # (it does not expand the home directory), so '~' spellings must be
  # expanded by the caller before authorize_path to keep home grants working.
  helper :normalize do |path, type=:read|
    path = '.' if path == '' || TrueClass === path

    path = path.find(:current) if Path === path && ! path.located?
    path = File.expand_path(path) if path.start_with?('~')

    mode = type.to_s == 'read' ? :read : :write

    decision = LLM::Sandbox.authorize_path(path,
                                           root: Workspace.root.to_s,
                                           writable_paths: Workspace.allowed_paths.map(&:to_s),
                                           read_paths: Workspace.allowed_read_paths.map(&:to_s),
                                           mode: mode,
                                           base_path: Dir.pwd)

    unless decision.allowed
      if mode == :read
        raise SandboxAccessViolation, "Path #{path} not read allowed. Allowed paths:\n    #{describe_allowed_paths}"
      else
        raise SandboxAccessViolation, "Path #{path} not write allowed. Allowed paths:\n    #{describe_allowed_paths}"
      end
    end

    path
  end


  # -------------------------------------------------------------------------
  # Sandbox introspection. The helpers below describe the effective
  # filesystem permissions of the workflow: which paths the Ruby-level
  # tasks (read/write/delete/search/list_directory) accept, where those
  # paths come from, and how they are mounted inside the bwrap sandbox
  # used by the exec tasks (bash/ruby/python/r). They are strictly
  # read-only.
  # -------------------------------------------------------------------------

  helper :classify_path do |path|
    info = {path: path}
    begin
      info[:symlink] = File.symlink?(path)
    rescue
      info[:symlink] = false
    end
    begin
      info[:readlink] = File.readlink(path) if info[:symlink]
    rescue
      info[:readlink] = nil
    end
    begin
      info[:realpath] = File.realpath(path)
    rescue Errno::ENOENT, Errno::ENOTDIR, ArgumentError
      info[:realpath] = nil
    end
    info[:exists] = File.exist?(path)
    info[:type] = if info[:symlink]
                    'symlink'
                  elsif File.directory?(path)
                    'directory'
                  elsif File.file?(path)
                    'file'
                  else
                    'missing'
                  end
    info
  end

  # One line per allowlist entry, annotated with read/write semantics, so
  # denial messages are self-explanatory.
  helper :describe_allowed_paths do
    LLM::Sandbox.describe_grants(scope: 'Workspace',
                                 root: Workspace.root.to_s,
                                 hint: "Run task 'sandbox_paths' for details (file/dir, symlinks, mounts)")
  end

  # Which allowlist source granted a given expanded path.
  helper :path_origin do |path|
    LLM::Sandbox.grant_origin(path, scope: 'Workspace', root: Workspace.root.to_s)
  end

  # Reproduce, without executing anything, the mount plan that
  # sandbox_run builds for the exec tasks. Follows the same composition
  # order as sandbox_run: bwrap_* lists, allowed lists, and always root
  # as writable. Network and runtime additions are noted as limits.
  helper :sandbox_mount_plan do
    read_paths = Workspace.allowed_read_paths.dup
    bwrap_read = Workspace.get_allowed_paths(:bwrap_read_paths)
    read_paths += bwrap_read if bwrap_read && !bwrap_read.empty?

    writable_paths = Workspace.allowed_paths.dup
    bwrap_writable = Workspace.get_allowed_paths(:bwrap_paths)
    writable_paths += bwrap_writable if bwrap_writable && !bwrap_writable.empty?

    # The exec sandbox always grants write access to the workflow root.
    root = Workspace.root
    root = root.find if Path === root
    writable_paths << root.to_s if root && !root.to_s.empty?

    read_paths = read_paths.flatten.compact.uniq
    writable_paths = writable_paths.flatten.compact.uniq

    plan_mounts(read_paths, writable_paths)
  end

  helper :realized_mounts do
    return nil unless File.readable?('/proc/mounts')
    base = %w(/ /proc /dev /sys)
    File.readlines('/proc/mounts').collect do |line|
      parts = line.split(/\s+/)
      next if base.include?(parts[1])
      {device: parts[0], mountpoint: parts[1], filesystem: parts[2], options: parts[3]}
    end.compact
  end

  # =================================================================
  # Streaming text reading (plan step 5).
  #
  # Contract:
  # * `read` returns TEXT. Defaults: 100 lines / 16 KiB inline ceiling.
  # * `start` skips lines at the SELECTED end. With tail, `start` skips N
  #   lines back from the END of the file, so tail(limit=2, start=1) on
  #   lines A,B,C,D,E yields C,D (the window that ends one line before
  #   EOF). With head, `start` skips N lines from the front.
  # * Every negative or zero limit/chars value is rejected; zero is NOT
  #   an unlimited escape. `read_window` is the byte-offset pager over
  #   the original file: read_window(path, byte_offset, max_bytes)
  #   returns up to max_bytes (clamped to the 16 KiB inline ceiling)
  #   FILE bytes from that offset. It does NOT resume an arbitrary
  #   transformed selection (tail slices, line offsets, character
  #   counts); the envelope an oversized `read` returns reports the true
  #   file offset of the first byte of its selected content, and that is
  #   the offset to page from.
  # * Streams are read in fixed-size chunks. Skipped lines are counted,
  #   never retained; the retained buffer for tail is bounded by the
  #   requested window plus one chunk. Plain seekable files use a
  #   reverse block scan for tail selection. Compressed inputs use the
  #   decompressed stream from Open.open. UTF-8 character boundaries are
  #   preserved (no multibyte character is ever split).
  # =================================================================
  READ_CHUNK = 64 * 1024                      # bytes per streaming read
  READ_INLINE_BYTE_CEILING = 16 * 1024        # 16 KiB inline ceiling
  READ_DEFAULT_LINES = 100

  # Forward streaming line selector. Reads fixed-size chunks; while
  # skipping lines it counts delimiters and retains nothing. For tail it
  # keeps at most `need` [offset, line] pairs (bounded ring buffer).
  # Returns [selected, capped, offset]: the selected line strings WITH
  # their terminators in file order, whether a line too large to ever
  # return inline stopped the selection, and the byte offset (within the
  # stream) of the first byte of the selected window (nil when nothing
  # was selected). The ceiling is checked incrementally while lines are
  # read: an unterminated line is never accumulated past the line cap,
  # and a selection that already exceeds the inline ceiling stops early
  # instead of buffering text that can only become an envelope.
  helper :stream_select_lines do |io, limit, start, file_end|
    need = limit + start
    if file_end == 'tail'
      kept = []
      pos = 0
      total = 0
      res = each_line_chunked(io) do |line|
        kept.push([pos, line])
        pos += line.bytesize
        total += line.bytesize
        if kept.length > need
          total -= kept.first.last.bytesize
          kept.shift
        end
      end
      # The last `need` lines were not all seen (a line past the line cap
      # stopped the scan), or the ring already holds more than could ever
      # be returned inline: the tail window is unknown, so report the cap
      # at the true offset of the first complete line still held instead
      # of a guess.
      if res == :capped || total > READ_INLINE_BYTE_CEILING + READ_CHUNK
        return [[], true, kept.empty? ? pos : kept.first.first]
      end
      # `start` lines are skipped at the END: drop them from the back of
      # the last-`need` window, then keep the first `limit` lines.
      kept.pop(start) if start > 0
      window = kept[0, limit] || []
      [window.map(&:last), false, window.empty? ? nil : window.first.first]
    else
      kept = []
      idx = 0
      pos = 0
      total = 0
      off0 = nil
      res = each_line_chunked(io) do |line|
        if idx >= start
          off0 = pos if off0.nil?
          kept << line
          total += line.bytesize
        end
        pos += line.bytesize
        idx += 1
        break if kept.length >= limit || total > READ_INLINE_BYTE_CEILING
      end
      # A line grew past the line cap before a terminator: nothing from
      # this point on can be selected, so report the cap at the byte
      # offset where the oversized line starts.
      return [[], true, off0 || pos] if res == :capped
      [kept, false, off0]
    end
  end

  # Chunked each_line over any IO-like object (File, Zlib reader, etc.).
  # Retained memory is one chunk plus one line, and the line buffer
  # itself is capped: when `line_cap` bytes accumulate with no
  # terminator, the block is NOT called and :capped is returned so the
  # caller can stop instead of accumulating an entire unterminated
  # megabyte line in memory. `line_cap` defaults to the byte budget
  # after which no selected text could be returned inline anyway
  # (inline ceiling plus one chunk of slack). Gzip streams returned by
  # Open.open wrap a ConcurrentStream that only yields one #read, so
  # readpartial is used when available.
  helper :each_line_chunked do |io, sep = "\n", chunk_size = READ_CHUNK,
                               line_cap: nil, &blk|
    line_cap = READ_INLINE_BYTE_CEILING + READ_CHUNK if line_cap.nil?
    buf = +''.b
    res = nil
    loop do
      while (i = buf.index(sep))
        line = buf.slice!(0..i)
        line.force_encoding(Encoding::UTF_8)
        blk.call(line)
      end
      if buf.bytesize > line_cap
        # A single line longer than the cap: stop without delivering it.
        res = :capped
        break
      end
      data =
        if io.respond_to?(:readpartial)
          begin
            io.readpartial(chunk_size)
          rescue EOFError
            nil
          end
        else
          io.read(chunk_size)
        end
      break if data.nil? || data.empty?
      buf << data.b
    end
    unless res == :capped || buf.empty?
      line = buf.dup
      line.force_encoding(Encoding::UTF_8)
      blk.call(line)
    end
    res
  end

  # Backward "\n" search that retains nothing: returns the byte offset
  # of the `count`-th newline found scanning backward from `from`
  # (exclusive), or nil when fewer exist or the scan budget is
  # exhausted. Memory stays one chunk regardless of line length.
  helper :prev_newline_offset do |io, from, count, budget = 8388608|
    pos = from
    left = count
    scanned = 0
    while pos > 0 && scanned < budget && left > 0
      read_size = [pos, READ_CHUNK].min
      from_pos = pos - read_size
      io.seek(from_pos, IO::SEEK_SET)
      data = io.read(read_size).to_s.b
      scanned += data.bytesize
      idx = nil
      scan_from = data.bytesize - 1
      while left > 0 && !scan_from.negative?
        idx = data.rindex("\n", scan_from)
        break if idx.nil?
        left -= 1
        pos = from_pos + idx
        scan_from = idx - 1
      end
      pos = from_pos if left > 0
    end
    left == 0 ? pos : nil
  end

  # Reverse block scan for plain seekable files: collects the tail
  # region without a forward pass. Retained buffer bounded by the data
  # actually needed (at most `need` lines plus one chunk) AND by the
  # inline ceiling: a file whose final line alone exceeds the ceiling
  # cannot be returned inline anyway, so the scan stops and reports
  # `capped` instead of retaining megabytes. Returns [selected, capped,
  # offset] where `selected` has the `start` skip already applied and
  # `offset` is the file byte offset of the first byte of the selection
  # (nil when nothing was selected).
  helper :tail_lines_by_reverse_scan do |path, limit, start = 0|
    need = limit + start
    max_collect = READ_INLINE_BYTE_CEILING + READ_CHUNK
    File.open(path, 'rb') do |f|
      f.seek(0, IO::SEEK_END)
      pos = f.pos
      collected = +''.b
      capped = false
      while pos > 0
        read_size = [pos, READ_CHUNK].min
        pos -= read_size
        f.seek(pos, IO::SEEK_SET)
        data = f.read(read_size)
        break if data.nil?
        collected = data.b + collected
        break if collected.count("\n") >= need + 1
        if collected.bytesize > max_collect && pos > 0
          capped = true
          break
        end
      end
      parts = collected.split("\n", -1)
      parts.pop if parts.last == ''
      lines = parts.map { |p| p.force_encoding(Encoding::UTF_8) }
      # File byte offset of the first byte of `collected`.
      base = pos
      n = collected.count("\n")
      if capped
        # Enough trailing newlines were NOT seen: the collected suffix is
        # a strict suffix of the file, so its FIRST segment is partial.
        # A strict suffix therefore holds at most n - 1 complete lines,
        # and selecting `need` of them requires n >= need + 1. With
        # fewer, the window is unknown: report the cap at a truthful,
        # pageable offset — the first complete line still held, or the
        # first retained byte — never byte zero for a deep selection.
        if n < need + 1
          # Enough trailing newlines were NOT seen: the collected suffix
          # starts mid-line, so the last `need` complete lines cannot be
          # located exactly from what is held. Spend at most one extra
          # chunk finding the remaining newlines — their last hit is the
          # byte before the true start of the selection. If the budget is
          # exhausted, report the first byte still held. Both are
          # truthful, pageable offsets, and a deep selection is never
          # reported as byte zero.
          missing = need + 1 - n
          mark = prev_newline_offset(f, base, missing, READ_CHUNK)
          return [[], true, mark.nil? ? base : mark + 1]
        end
        capped = false
        window = (lines.last(need) || [])[0, limit] || []
      elsif pos == 0
        # The whole file was collected, so the total line count is exact:
        # skipping `start` lines back from the end of a file with
        # `total <= start` lines selects nothing.
        total = lines.length
        return [[], false, nil] if total <= start
        window = (lines[0, total - start] || []).last(limit)
      else
        # Early break on enough newlines: the last `need` complete lines
        # are all inside the collected window; `start` are skipped from
        # the END, so keep the first `limit` of them.
        window = (lines.last(need) || [])[0, limit] || []
      end
      # Offset of the first byte of the window inside the collected
      # suffix: sum the bytes of the segments before the first kept one.
      kept_count = window.length
      skip_in_collected = (parts.length - kept_count)
      skip_in_collected = 0 if skip_in_collected < 0
      offset = base + parts[0, skip_in_collected].map(&:bytesize).sum + skip_in_collected
      [window, capped, offset]
    end
  end

  # Strip line terminators and join as text lines.
  helper :lines_to_text do |lines|
    lines.map { |l| l.to_s.sub(/\r?\n\z/, '').sub(/\n\z/, '') }.join("\n")
  end

  input :path, :path, 'Writable destination path for the complete contents', nil, required: true
  input :content, :text, 'Content to write into the file', nil, required: true
  task :write => :string do |file,content|
    raise ParameterException, "File is nil or empty: #{file}" if file.nil? || file.to_s.empty?
    file = normalize file, :write
    raise ParameterException, "File is a directory: #{file}" if Open.directory?(file)
    Open.write file, content
    "success writing to #{file}"
  end

  # Trim an incomplete trailing UTF-8 character off a byte window so the
  # serialized text can never contain a partial character. UTF-8 lead
  # bytes declare their length, so this is decided from the last lead
  # byte and the continuation bytes that follow it; at most three bytes
  # are ever dropped.
  helper :utf8_align_end do |bytes|
    return bytes if bytes.empty? || bytes.ascii_only?
    b = bytes.bytes
    j = b.length - 1
    j -= 1 while j >= 0 && (b[j] & 0xC0) == 0x80
    return bytes if j < 0 # only continuation bytes: utf8_align_start's case
    expected =
      case b[j]
      when 0xC0..0xDF then 2
      when 0xE0..0xEF then 3
      when 0xF0..0xF7 then 4
      else 1 # ASCII or an invalid lead byte: nothing to complete
      end
    actual = b.length - j
    actual >= expected ? bytes : bytes.byteslice(0, j)
  end

  # Move a nonzero window start FORWARD to the first complete UTF-8
  # character at or after it. When the offset lands inside a multibyte
  # character the leading continuation bytes are skipped; a UTF-8 stream
  # never holds more than three of them in a row, so a bounded 4-byte
  # lookahead always reaches a boundary and forward progress is
  # guaranteed. Returns [byte_offset, bytes] with both aligned.
  helper :utf8_align_start do |offset, bytes|
    probe = bytes.to_s.dup.force_encoding(Encoding::UTF_8)
    return [offset, bytes] if probe.valid_encoding?
    lead = bytes.bytes.first(4)
    boundary = lead.index { |byte| (byte & 0xC0) != 0x80 }
    boundary = boundary.nil? ? [3, bytes.bytesize].min : [boundary, bytes.bytesize].min
    boundary = 1 if boundary < 1
    [(offset + boundary), bytes.byteslice(boundary, bytes.bytesize - boundary) || +''.b]
  end

  input :path, :path, 'Path to the file to read', nil, required: true
  input :limit, :integer, 'Maximum number of lines to return from chosen end of the file. Defaults to 100 lines; negative or zero values are rejected (zero is not an unlimited escape — use read_window or list fewer lines).'
  input :chars, :integer, 'Character window from the selected end, applied after line selection, also enforced under the 16 KiB inline byte ceiling.'
  input :file_end, :select, 'Side of file to read', :head, select_options: %w(head tail)
  input :start, :integer, 'Zero-based lines to skip at the selected end: tail skips N lines back from the END of the file (tail(limit=2,start=1) on A..E gives C,D); head skips N lines from the front.', 0
  task :read => :text do |file, limit, chars, file_end, start|
    # ---- validate everything BEFORE any I/O ---------------------------
    raise ParameterException, "Path is nil" if file.nil? || file.to_s.empty?

    file_end = (file_end || :head).to_s
    unless %w(head tail).include?(file_end)
      raise ParameterException, "Unknown file_end must be head or tail: #{Log.fingerprint file_end}"
    end

    limit = READ_DEFAULT_LINES if limit.nil? || limit.to_s.empty?
    limit = limit.to_i
    raise ParameterException, "Wrong limit: #{Log.fingerprint limit} — negative or zero limits are rejected; zero is not an unlimited escape" if limit <= 0

    chars = nil if !chars.nil? && chars.to_s.empty?
    if chars
      chars = chars.to_i
      raise ParameterException, "Wrong chars: #{Log.fingerprint chars}" if chars <= 0
    end

    start = (start || 0).to_i
    raise ParameterException, "Wrong start: #{Log.fingerprint start}" if start < 0

    file = normalize file
    raise ParameterException, "File not found #{file}" unless Open.exists?(file)
    raise ParameterException, 'File is really a directory, can not read' if Open.directory?(file)

    # ---- select lines -------------------------------------------------
    # `sel_offset` is the byte offset (in the file, or in the
    # decompressed stream for compressed inputs) of the first byte of
    # the selected window, so an oversized selection can point
    # read_window at the right place. A reverse scan that stopped on the
    # collection cap returns nil there and its own exact offset.
    selected, tail_capped, sel_offset =
      if file_end == 'tail' && !Open.compressed?(file) && File.file?(file)
        # `start` lines are skipped from the END: the helper returns the
        # window that ends `start` lines before EOF and holds `limit`
        # lines (equivalently the first `limit` of the last `need`).
        sel, capped, off = tail_lines_by_reverse_scan(file, limit, start)
        [sel, capped, off]
      else
        Open.open(file) do |io|
          stream_select_lines(io, limit, start, file_end)
        end
      end

    text = lines_to_text(selected)

    # Bytes by which the optional character window shifts the effective
    # start of the returned text (a head chars window never does).
    chars_skip = 0

    # ---- optional character window ------------------------------------
    if chars
      if file_end == 'tail'
        if text.length > chars
          skipped = text[0, text.length - chars]
          chars_skip = skipped.bytesize
          text = text[-chars, chars]
        end
      else
        text = text[0, chars]
      end
    end

    # True byte offset of the first byte of the selected content: never
    # byte zero for a selection that starts further into the file.
    sel_offset = (sel_offset || 0) + chars_skip if sel_offset

    # ---- inline ceiling -------------------------------------------------
    # Truncation metadata is never embedded in the returned text: read
    # stays a text result and points callers at read_window, the
    # byte-offset pager over the original file. A reverse scan that
    # stopped on the collection cap (an enormous final line) reports the
    # same structured envelope instead of an oversized text. byte_offset
    # is the TRUE offset of the first byte of the selected content —
    # never zero for a selection that starts further into the file.
    if tail_capped || text.bytesize > READ_INLINE_BYTE_CEILING
      next {
        path: file.to_s,
        truncated: true,
        reason: :inline_byte_ceiling,
        byte_size: tail_capped ? nil : text.bytesize,
        inline_byte_ceiling: READ_INLINE_BYTE_CEILING,
        byte_offset: sel_offset || 0,
        note: "Selected text exceeds the #{READ_INLINE_BYTE_CEILING}-byte inline ceiling. byte_offset is the true offset of the first byte of the selected content — a file byte offset (a decompressed-stream offset for compressed inputs); call read_window with it and max_bytes to page through the file from there."
      }.to_json
    end

    text
  rescue SystemCallError, Errno::ENOENT
    raise ParameterException, "Could not read file: #{$!.message}"
  end

  # Byte-offset pager over the ORIGINAL file bytes: returns up to
  # max_bytes file bytes starting at byte_offset. max_bytes is clamped
  # to READ_INLINE_BYTE_CEILING at this I/O boundary — a caller can
  # never smuggle a larger payload past the inline ceiling — and window
  # edges (the end and any nonzero start) are aligned to UTF-8 character
  # boundaries, so a window never splits a multibyte character and the
  # serialized text is always valid. Every accepted request makes
  # forward progress. This is a pager over the file itself, not a
  # continuation of an arbitrary transformed `read` selection (tail
  # slices, line offsets, character counts): those selections are byte
  # offsets too, but the window bytes are read straight from the file at
  # that offset. Distinct result shape (JSON object) so truncation
  # metadata never lives inside literal text.
  input :path, :path, 'Path to the file to read a byte window of', nil, required: true
  input :byte_offset, :integer, 'Byte offset to start the window at', 0
  input :max_bytes, :integer, 'Maximum bytes to return in this window (clamped to the 16 KiB inline ceiling)', READ_INLINE_BYTE_CEILING
  task :read_window => :json do |path, byte_offset, max_bytes|
    raise ParameterException, "Path is nil" if path.nil? || path.to_s.empty?
    byte_offset = (byte_offset || 0).to_i
    max_bytes = (max_bytes || READ_INLINE_BYTE_CEILING).to_i
    raise ParameterException, "Wrong byte_offset: #{Log.fingerprint byte_offset}" if byte_offset < 0
    raise ParameterException, "Wrong max_bytes: #{Log.fingerprint max_bytes}" if max_bytes <= 0
    # I/O boundary clamp: the ceiling is enforced here, not left to the caller.
    max_bytes = READ_INLINE_BYTE_CEILING if max_bytes > READ_INLINE_BYTE_CEILING

    path = normalize path
    raise ParameterException, "File not found #{path}" unless Open.exists?(path)
    raise ParameterException, 'File is really a directory, can not read' if Open.directory?(path)

    size = File.size(path)
    raise ParameterException, "byte_offset #{byte_offset} past end of file (size #{size})" if byte_offset >= size

    # Read one extra byte past the requested window so an edge that
    # lands mid-character can be aligned back to a boundary, and so
    # `truncated` can be decided from the data actually read.
    want = [max_bytes, size - byte_offset].min
    data = nil
    File.open(path, 'rb') do |f|
      f.seek(byte_offset)
      data = f.read(want + 1).to_s
    end
    more_after = data.bytesize > want
    data = data.byteslice(0, want)

    # UTF-8 alignment: the end edge moves back to the last complete
    # character, and a nonzero start moves FORWARD to the first one, so
    # both edges are always on character boundaries and forward progress
    # is preserved.
    data = utf8_align_end(data)
    byte_offset, data = utf8_align_start(byte_offset, data) if byte_offset > 0
    clipped = more_after && byte_offset + data.bytesize < size

    {
      path: path.to_s,
      byte_offset: byte_offset,
      bytes: data.bytesize,
      text: data.force_encoding(Encoding::UTF_8),
      truncated: clipped,
      next_byte_offset: clipped ? byte_offset + data.bytesize : nil,
    }
  rescue SystemCallError
    raise ParameterException, "Could not read file: #{$!.message}"
  end

  input :directory, :path, 'Readable directory path to enumerate', nil, required: true
  input :recursive, :boolean, 'List recursively', true
  input :stats, :boolean, 'Request size and modification time for listed files', false
  task :list_directory => :json do |directory,recursive,stats|
    raise ParameterException, "Directory is a regular expression" if Regexp === directory
    directory = normalize directory
    raise ParameterException, "Directory not found: #{directory}" unless Open.exists?(directory)
    raise ParameterException, "Not a directory: #{directory}" unless Open.directory?(directory)
    files = if recursive
              Path.setup(directory).glob('**/*')
            else
              Path.setup(directory).glob('*')
            end

    info = {files: [], directories: []}

    files.each do |entry|
      if entry.directory?
        info[:directories] << entry.find
      else
        info[:files] << entry.find
      end
    end

    if stats
      info[:stats] = {}
      info[:files].each do |sf|
        info[:stats][sf] = {
          size: Open.size(sf),
          mtime: Open.mtime(sf)
        }
      end
    end

    info
  end

  # Bounded page over the same enumeration, for callers that must not
  # load a whole tree. Returns the same files/directories/stats shape as
  # list_directory plus explicit paging fields.
  input :directory, :path, 'Readable directory path to enumerate', nil, required: true
  input :recursive, :boolean, 'List recursively', true
  input :stats, :boolean, 'Request size and modification time for listed entries on this page', false
  input :page, :integer, '1-based page number', 1
  input :page_size, :integer, 'Entries per page; 0 or empty means all entries (migration path to the full-array behavior of list_directory)'
  task :list_directory_page => :json do |directory, recursive, stats, page, page_size|
    raise ParameterException, "Directory is a regular expression" if Regexp === directory
    directory = normalize directory
    raise ParameterException, "Directory not found: #{directory}" unless Open.exists?(directory)
    raise ParameterException, "Not a directory: #{directory}" unless Open.directory?(directory)

    page = (page || 1).to_i
    raise ParameterException, "Wrong page: #{Log.fingerprint page}" if page < 1
    page_size = page_size.nil? || page_size.to_s.empty? ? nil : page_size.to_i
    raise ParameterException, "Wrong page_size: #{Log.fingerprint page_size}" if page_size && page_size < 0
    page_size = nil if page_size && page_size == 0

    # Bounded page over the same enumeration, for callers that must not
    # load a whole tree. When a page_size is given, the walk STOPS at the
    # page bound — one entry past the page proves `more == true` and the
    # rest of the tree is neither enumerated nor sorted. Order is
    # deterministic: children are visited sorted by name, depth-first.
    # (page_size 0/absent keeps the migration path: all entries, exact
    # total.) When the walk stopped early, total_entries is the lower
    # bound actually observed (page end + 1), not the tree total; `more`
    # carries the incompleteness.
    info = {files: [], directories: []}
    seen = 0
    kept = 0
    stopped = false
    first = page_size ? (page - 1) * page_size + 1 : 1
    last = page_size ? page * page_size : nil

    collect = lambda do |dir, depth|
      names = begin
                Dir.children(dir).sort
              rescue SystemCallError
                []
              end
      names.each do |name|
        full = File.join(dir, name)
        is_dir = File.directory?(full) && !File.symlink?(full)
        seen += 1
        if page_size && seen > last
          stopped = true
          break
        end
        if seen >= first
          if is_dir
            info[:directories] << full
          else
            info[:files] << full
          end
          kept += 1
        end
        collect.call(full, depth + 1) if is_dir && recursive && depth < 1_000
        break if stopped
      end
      nil
    end
    collect.call(directory, 0)

    info[:page] = page
    info[:page_size] = page_size
    info[:entries_on_page] = kept
    info[:total_entries] = seen
    info[:more] = page_size ? stopped : false

    if stats
      info[:stats] = {}
      (info[:files] + info[:directories]).each do |sf|
        info[:stats][sf] = {
          size: Open.size(sf),
          mtime: Open.mtime(sf)
        }
      end
    end

    info
  end

  input :file, :path, 'Readable file or directory path', nil, required: true
  input :count_lines, :boolean, 'Count lines exactly (a full-content pass); default false returns cheap metadata with binary sampling', false
  task :file_stats => :json do |file, count_lines|
    file = normalize file
    raise ParameterException, "File not found: #{file}" unless Open.exists?(file)
    stats = {}
    stats[:path] = file.to_s
    stats[:type] = Open.directory?(file) ? :directory : :file
    if ! Open.directory?(file)
      stats[:size] = Open.size(file)
      stats[:mtime] = Open.mtime(file)
      # Exact line counting is OPT-IN: the default returns cheap metadata
      # (size/mtime plus binary sampling) without a full-content pass.
      stats[:lines] = count_lines ? count_file_lines(file) : nil
      stats[:binary] = file_looks_binary?(file)
    end
    stats
  end

  # Binary heuristic on a bounded sample: NUL byte, or invalid UTF-8
  # after the first 4 KiB.
  helper :file_looks_binary? do |path|
    sample = begin
               File.open(path, 'rb') { |f| f.read(4096) } || ''
             rescue SystemCallError
               return false
             end
    return false if sample.empty?
    return true if sample.include?("\0")
    sample.force_encoding(Encoding::UTF_8).valid_encoding? ? false : true
  end

  helper :count_file_lines do |path|
    n = 0
    Open.open(path) { |io| io.each_line { n += 1 } }
    n
  end

  # ---------------------------------------------------------------------
  # sandbox_paths. realized_mounts is opt-in (verbose).
  # ---------------------------------------------------------------------
  input :verbose, :boolean, 'Include the verbose realized_mounts field (the mount table of the reporting process). Default false keeps the lean root/grants/mounts output.', false
  task :sandbox_paths => :json do |verbose|
    writable = [Workspace.root, Workspace.allowed_paths].flatten.compact.uniq
    readable = Workspace.allowed_read_paths.flatten.compact.uniq

    classify = lambda do |paths|
      paths.collect do |p|
        expanded = File.expand_path(p.to_s)
        classify_path(expanded).merge(origin: path_origin(expanded))
      end
    end

    bwrap = begin
              find_bwrap
            rescue
              nil
            end

    result = {
      root: Workspace.root.to_s,
      pwd: ENV['PWD'] || Dir.pwd,
      pwd_realpath: File.realpath(Dir.pwd),
      home: ENV['HOME'],
      bwrap: bwrap.nil? ? nil : bwrap.to_s,
      note: "File tasks check their input paths against Scout-AI grants. Reads accept writable and read grants. Writes require a writable location. For commands, mounts shows the base bwrap plan with host source, child destination and mode. Command-specific mounts are added at launch. Pass verbose=true to include realized_mounts, the mount table of the reporting process.",
      writable: classify.call(writable),
      readable: classify.call(readable),
      mounts: sandbox_mount_plan.collect do |m|
        {source: m.source, destination: m.destination, mode: m.mode.to_s,
         requested_path: m.requested_path, redirect: m.destination != m.requested_path}
      end,
    }

    result[:realized_mounts] = realized_mounts if verbose
    result
  end

  task :pwd => :string do
    ENV['PWD'] || Dir.pwd
  end

  # Delete task
  input :file, :path, 'File or directory to delete', nil, required: true
  task :delete => :string do |file|
    file = normalize file, :write
    raise ParameterException, "File not found: #{file}" unless Open.exists?(file)
    raise ParameterException, "Root path cannot be deleted" if File.expand_path(file) == File.expand_path(Workspace.root)

    if Open.directory?(file)
      Open.rm_rf(file)
      "deleted directory #{file}"
    else
      Open.rm(file)
      "deleted file #{file}"
    end
  end

  # Copy task
  input :source, :path, 'Readable source path', nil, required: true
  input :target, :path, 'Writable destination path', nil, required: true
  task :copy => :string do |source,target|
    source = normalize source, :read
    target = normalize target, :write
    raise ParameterException, "Source file not found: #{source}" unless Open.exists?(source)
    # Equivalent identities, not string spellings: same inode (samefile)
    # or a symlink to the same content counts as the same file.
    same = begin
             File.identical?(source, target)
           rescue StandardError
             source.to_s == target.to_s
           end
    raise ParameterException, "Source file same as target file #{source}" if same
    raise ParameterException, "Root path cannot be overwritten by copy" if File.expand_path(target) == File.expand_path(Workspace.root)

    Open.cp source, target
  end

  # ---------------------------------------------------------------------
  # search (plan step 6). `search` keeps the plain array of relative
  # paths for existing callers; `search_details` is the separate detailed
  # result with snippets, line numbers, scanned counts and truncation
  # reasons. Content search covers REGULAR FILES ONLY, authorization
  # always precedes any content access, and every skip (denied, oversize,
  # budget) is disclosed through `truncated_reasons`. Compressed contents
  # are NOT searched: gzip members look binary to `file_looks_binary?`
  # and are skipped (the read path's own decompressed-input handling is
  # a separate mechanism, untouched here).
  # ---------------------------------------------------------------------
  SEARCH_IGNORED_DIR_NAMES = %w(.git .hg .svn node_modules __pycache__).freeze
  SEARCH_DEFAULT_MAX_RESULTS = 10
  SEARCH_DEFAULT_MAX_FILES = 200
  SEARCH_MAX_BYTES_PER_FILE = 8 * 1024 * 1024
  SEARCH_MAX_SNIPPET_BYTES = 512
  SEARCH_CHUNK = 64 * 1024

  # LITERAL streaming matcher. `query` bytes are never interpreted as a
  # regular expression, and a match spanning a chunk boundary is still
  # found because up to query.bytesize - 1 bytes are carried between
  # chunks. The 1-based line number is counted DURING the scan itself,
  # so no second pass over the file is needed afterwards. Returns
  # [byte_offset, snippet, line_number] for the first match, nil for no
  # match, or the symbol :budget_exhausted when the per-file budget
  # is hit before a decision.
  helper :search_literal_match do |io, query, budget|
    q = query.to_s.b
    return nil if q.empty?
    carry = +''.b
    offset = 0
    total = 0
    newlines = 0
    keep = q.bytesize - 1
    loop do
      data =
        if io.respond_to?(:readpartial)
          begin
            io.readpartial(SEARCH_CHUNK)
          rescue EOFError
            nil
          end
        else
          io.read(SEARCH_CHUNK)
        end
      break if data.nil? || data.empty?
      data = data.b
      total += data.bytesize
      buf = carry + data
      if (i = buf.index(q))
        lo = buf.rindex("\n", i)
        lo = lo ? lo + 1 : 0
        hi = buf.index("\n", i) || buf.bytesize
        snippet = buf.byteslice(lo, [hi - lo, SEARCH_MAX_SNIPPET_BYTES].min)
        line = newlines + buf.byteslice(0, i).count("\n") + 1
        return [offset + i, snippet, line]
      end
      k = [keep, buf.bytesize].min
      dropped = buf.bytesize - k
      newlines += buf.byteslice(0, dropped).count("\n")
      carry = k > 0 ? buf.byteslice(buf.bytesize - k, k) : +''.b
      offset += dropped
      return :budget_exhausted if total > budget
    end
    nil
  end

  # Relative path of `full` under `base`, or the basename spelling when
  # they coincide.
  helper :search_relative do |full, base|
    rel = full.sub(%r{\A#{Regexp.escape(base)}/?}, '')
    rel.empty? ? File.basename(full) : rel
  end

  # A relative-path glob restricts candidates: File.fnmatch semantics
  # against the path RELATIVE to the search root.
  helper :search_glob_match? do |full, base, glob|
    rel = full.sub(%r{\A#{Regexp.escape(base)}/?}, '')
    File.fnmatch?(glob, rel, File::FNM_PATHNAME | File::FNM_EXTGLOB)
  end

  # 1-based line numbers now come out of the scan itself
  # (search_literal_match), so no reopen helper is needed.

  # Lazy depth-first walk that prunes ignored directories and never
  # materializes the whole tree. Yields absolute candidate paths only
  # (files, symlinks and other non-directory entries; directory entries
  # are recursed into, not yielded). The REGULAR-FILES-ONLY gate for
  # content search lives in the caller: opening a FIFO, socket or device
  # could block forever, so those are never content candidates.
  helper :search_walk do |base, stats, &blk|
    stack = [base]
    until stack.empty?
      current = stack.pop
      names = begin
                Dir.children(current).sort
              rescue SystemCallError
                stats[:skipped_directories] += 1
                next
              end
      names.each do |name|
        full = File.join(current, name)
        begin
          if File.directory?(full) && !File.symlink?(full)
            if SEARCH_IGNORED_DIR_NAMES.include?(name)
              stats[:skipped_directories] += 1
            else
              stack.push(full)
            end
          else
            blk.call(full)
          end
        rescue SystemCallError
          stats[:skipped_files] += 1
        end
      end
    end
  end

  helper :search_run do |path, query, max_results, max_files, glob: nil, filenames_only: false, detail: false|
    raise ParameterException, "Path is nil or empty" if path.nil? || path.to_s.empty?
    raise ParameterException, "Empty query string" if query.nil? || query.to_s.empty?
    path = normalize path
    raise ParameterException, "Directory not found: #{path}" unless Open.exists?(path)
    raise ParameterException, "Not a directory: #{path}" unless Open.directory?(path)

    max_results = max_results.nil? || max_results.to_s.empty? ? SEARCH_DEFAULT_MAX_RESULTS : max_results.to_i
    max_files = max_files.nil? || max_files.to_s.empty? ? SEARCH_DEFAULT_MAX_FILES : max_files.to_i
    raise ParameterException, "Wrong max_results: #{Log.fingerprint max_results}" if max_results < 0
    raise ParameterException, "Wrong max_files: #{Log.fingerprint max_files}" if max_files < 0

    q = query.to_s
    glob = glob.nil? || glob.to_s.empty? ? nil : glob.to_s

    matches = []
    stats = {scanned_files: 0, skipped_directories: 0, skipped_files: 0, examined: 0}
    truncated_reasons = []
    exhausted_files = false

    # AUTHORIZATION FIRST: normalize(full, :read) is called BEFORE any
    # content access. A denied candidate is never opened — not by
    # File.size, not by binary sampling, not by the scan itself. It is
    # counted in skipped_files and surfaced as a denial reason so a
    # permission skip is distinguishable from a budget skip. The root was
    # authorized above.
    authorize_candidate = lambda do |full|
      begin
        normalize full, :read
      rescue SandboxAccessViolation
        stats[:skipped_files] += 1
        truncated_reasons << :denied_read
        nil
      end
    end

    if filenames_only
      search_walk(path, stats) do |full|
        break if max_results > 0 && matches.length >= max_results
        # max_files applies to filename mode too: candidates examined
        # after filtering are capped, and the cap is disclosed.
        if max_files > 0 && stats[:examined] >= max_files
          truncated_reasons << :max_files
          exhausted_files = true
          break
        end
        next if glob && !search_glob_match?(full, path, glob)
        stats[:examined] += 1
        next unless File.basename(full).include?(q)
        matches << {path: search_relative(full, path), kind: :filename, line: nil, snippet: nil}
      end
    else
      search_walk(path, stats) do |full|
        break if max_results > 0 && matches.length >= max_results
        if max_files > 0 && stats[:examined] >= max_files
          truncated_reasons << :max_files
          exhausted_files = true
          break
        end
        next if glob && !search_glob_match?(full, path, glob)
        # Regular files only: a FIFO/socket/device would block (or lie)
        # on open. Not a skip worth reporting — it was never a candidate.
        next unless File.file?(full)
        # 1. Authorization BEFORE any size probe, binary sample or read.
        authorize = authorize_candidate.call(full)
        next unless authorize
        stats[:examined] += 1
        # 2. Oversized candidates are skipped WITH a disclosed reason.
        size = begin
                 File.size(authorize)
               rescue SystemCallError
                 stats[:skipped_files] += 1
                 next
               end
        if size > SEARCH_MAX_BYTES_PER_FILE
          stats[:skipped_files] += 1
          truncated_reasons << :oversize
          next
        end
        # 3. Binary-looking candidates are skipped (and counted) rather
        #    than producing spurious byte-level matches.
        begin
          if file_looks_binary?(authorize)
            stats[:skipped_files] += 1
            next
          end
        rescue SystemCallError
          stats[:skipped_files] += 1
          next
        end
        stats[:scanned_files] += 1
        found = nil
        begin
          Open.open(authorize) do |io|
            found = search_literal_match(io, q, SEARCH_MAX_BYTES_PER_FILE)
          end
        rescue SystemCallError, EOFError
          stats[:skipped_files] += 1
          next
        end
        if found == :budget_exhausted
          truncated_reasons << :max_bytes_per_file
          next
        end
        next unless found
        byte_offset, snippet, line = found
        matches << {
          path: search_relative(full, path),
          kind: :content,
          line: line,
          snippet: snippet.to_s.force_encoding(Encoding::UTF_8),
        }
      end
    end

    {
      path: path.to_s,
      query: q,
      matches: matches,
      match_count: matches.length,
      scanned_files: stats[:scanned_files],
      skipped_directories: stats[:skipped_directories],
      skipped_files: stats[:skipped_files],
      # Truthful truncation: never report an apparently complete negative
      # after hitting a budget.
      truncated: !truncated_reasons.empty? || exhausted_files || (max_results > 0 && matches.length >= max_results),
      truncated_reasons: truncated_reasons.uniq,
    }
  end

  # Array of relative paths — the shape existing callers already use.
  input :path, :path, 'Root directory to search', nil, required: true
  input :query, :string, 'Literal string to search for in file contents (never interpreted as a regular expression)', nil, required: true
  input :max_results, :integer, 'Maximum number of results to return', SEARCH_DEFAULT_MAX_RESULTS
  input :max_files, :integer, 'Maximum candidate files to examine AFTER filtering directories and ignored paths (default 200)', SEARCH_DEFAULT_MAX_FILES
  task :search => :array do |path, query, max_results, max_files|
    search_run(path, query, max_results, max_files)[:matches].collect { |m| m[:path] }
  end

  input :path, :path, 'Root directory to search', nil, required: true
  input :query, :string, 'Literal string to search for (never a regular expression)', nil, required: true
  input :glob, :string, 'Optional relative path glob (File.fnmatch semantics against paths relative to the search root) restricting candidates'
  input :filenames_only, :boolean, 'Match the query against file names instead of contents', false
  input :max_results, :integer, 'Maximum number of results to return', SEARCH_DEFAULT_MAX_RESULTS
  input :max_files, :integer, 'Maximum candidate files to examine AFTER filtering directories and ignored paths (default 200)', SEARCH_DEFAULT_MAX_FILES
  task :search_details => :json do |path, query, glob, filenames_only, max_results, max_files|
    search_run(path, query, max_results, max_files,
               glob: glob, filenames_only: filenames_only, detail: true)
  end

  # Step 8 export dedup: the full superset export only. The former
  # partial `export_exec :list_directory, :write, :read, :file_stats`
  # line was a duplicate declaration of a subset of this list.
  export_exec :list_directory, :write, :read, :file_stats, :pwd, :copy, :delete, :search, :search_details, :read_window, :list_directory_page, :sandbox_paths
end
