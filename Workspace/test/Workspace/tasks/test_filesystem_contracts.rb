require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path('../../../workflow', __dir__)
require 'tmpdir'
require 'fileutils'
require 'json'
require 'timeout'

# Integration tests for the Wave 2B filesystem contracts (plan steps 5,
# 6 and the filesystem items of step 8):
#
#   read        — text result, streaming selection, validated inputs,
#                 start = lines skipped at the selected end, chars window,
#                 16 KiB inline ceiling, read_window continuation.
#   search      — array shape preserved, literal matching, glob,
#                 filename-only, truthful truncation, search_details.
#   list_directory / list_directory_page — leaked-variable fix, paging.
#   file_stats  — bounded sample binary detection, streaming line count.
#   write/copy  — write validates its own file argument; copy guards
#                 equivalent identities (samefile), normal copy first.
#   sandbox_paths — realized_mounts opt-in.
#
# Everything is exercised through the REAL exported tool surface
# (Workspace.job(:read, ...).run and friends), not only helper-level
# constructed inputs.
class TestWorkspaceFilesystemContracts < Test::Unit::TestCase
  FIXTURES = File.expand_path('../../../tmp/impl-fixtures/fs', __dir__)
  LINES_FILE = File.join(FIXTURES, 'lines_a_to_e.txt')

  def run_task(name, inputs)
    inputs = inputs.transform_keys(&:to_s)
    job = Workspace.job(name, inputs)
    job.run
    job.load
  end

  # `read` is a text task whose oversized branch returns a JSON envelope;
  # job.load hands that back as the literal STRING. Parse it here. Real
  # json tasks (read_window, list_directory, ...) decode to a Hash with
  # SYMBOL keys.
  def run_task_json(name, inputs)
    res = run_task(name, inputs)
    res = JSON.parse(res) if res.is_a?(String)
    res = res.transform_keys(&:to_sym) if res.is_a?(Hash)
    res
  end

  def run_task_raw(name, inputs)
    run_task(name, inputs)
  end

  # ---------------- read (plan step 5) ----------------

  def test_read_returns_text_by_type
    r = run_task(:read, {path: LINES_FILE, limit: 5})
    assert_equal "A\nB\nC\nD\nE", r
    assert_equal String, r.class
  end

  def test_read_tail_start_skips_lines_back_from_the_end
    # A,B,C,D,E — tail(limit=2, start=1) must yield C,D
    r = run_task(:read, {path: LINES_FILE, limit: 2, start: 1, file_end: 'tail'})
    assert_equal "C\nD", r
  end

  def test_read_tail_plain
    r = run_task(:read, {path: LINES_FILE, limit: 2, file_end: 'tail'})
    assert_equal "D\nE", r
  end

  def test_read_tail_start_at_or_past_line_count_selects_nothing
    # 5 lines: skipping 5 lines back from the end selects nothing.
    assert_equal '', run_task(:read, {path: LINES_FILE, limit: 2, start: 5, file_end: 'tail'})
    assert_equal '', run_task(:read, {path: LINES_FILE, limit: 2, start: 10, file_end: 'tail'})
    # exactly at the boundary still yields the first line
    assert_equal 'A', run_task(:read, {path: LINES_FILE, limit: 1, start: 4, file_end: 'tail'})
  end

  def test_read_head_start_skips_from_the_front
    r = run_task(:read, {path: LINES_FILE, limit: 2, start: 1, file_end: 'head'})
    assert_equal "B\nC", r
  end

  def test_read_one_char_tail_on_abc
    abc = File.join(FIXTURES, 'abc.txt')
    # "one-character tail" — the character window taken from the tail
    r = run_task(:read, {path: abc, chars: 1, file_end: 'tail'})
    assert_equal 'c', r
    # a one-character HEAD window is the first character
    r2 = run_task(:read, {path: abc, chars: 1, file_end: 'head'})
    assert_equal 'a', r2
  end

  def test_read_larger_request_returns_everything
    abc = File.join(FIXTURES, 'abc.txt')
    r = run_task(:read, {path: abc, limit: 10, file_end: 'tail'})
    assert_equal 'abc', r
  end

  def test_read_empty_input
    empty = File.join(FIXTURES, 'empty.txt')
    r = run_task(:read, {path: empty, limit: 5})
    assert_equal '', r
  end

  def test_read_crlf_and_no_final_newline
    crlf = File.join(FIXTURES, 'crlf.txt')
    # CRLF terminators are preserved inside the returned lines
    r = run_task(:read, {path: crlf, limit: 2, file_end: 'tail'})
    assert_equal "two\r\nthree", r
  end

  def test_read_final_blank_lines
    blanks = File.join(FIXTURES, 'blanks.txt')
    r = run_task(:read, {path: blanks, limit: 3, file_end: 'tail'})
    assert_equal "x\n\n", r
  end

  def test_read_multibyte_characters_are_not_split
    multi = File.join(FIXTURES, 'multibyte.txt')
    r = run_task(:read, {path: multi, limit: 3, file_end: 'tail'})
    assert_equal "é\n日\n漢", r
    assert r.valid_encoding?
  end

  def test_read_chars_window_is_a_character_limit
    multi = File.join(FIXTURES, 'multibyte.txt')
    # head: the character window is a prefix of the selected text
    r = run_task(:read, {path: multi, limit: 4, chars: 3, file_end: 'head'})
    assert_equal "ä\né", r
    # tail: the character window ends at the selected end
    r2 = run_task(:read, {path: multi, limit: 4, chars: 3, file_end: 'tail'})
    assert_equal "日\n漢", r2
    # a one-character tail of a one-line file
    r3 = run_task(:read, {path: File.join(FIXTURES, 'abc.txt'), chars: 1, file_end: 'tail'})
    assert_equal 'c', r3
  end

  def test_read_oversized_chars_is_clipped_not_failed
    multi = File.join(FIXTURES, 'multibyte.txt')
    r = run_task(:read, {path: multi, limit: 4, chars: 100})
    assert_equal "ä\né\n日\n漢", r
  end

  def test_read_rejects_negative_limit_chars_start
    assert_raise(ParameterException) { run_task(:read, {path: LINES_FILE, limit: -1}) }
    assert_raise(ParameterException) { run_task(:read, {path: LINES_FILE, chars: -3}) }
    assert_raise(ParameterException) { run_task(:read, {path: LINES_FILE, start: -1}) }
  end

  def test_read_rejects_zero_limit_as_unlimited_escape
    assert_raise(ParameterException) { run_task(:read, {path: LINES_FILE, limit: 0}) }
    assert_raise(ParameterException) { run_task(:read, {path: LINES_FILE, chars: 0}) }
  end

  def test_read_rejects_zero_and_negative_limit_before_any_io
    assert_raise(ParameterException) { run_task(:read, {path: '/nonexistent/no-such-file.txt', limit: 0}) }
  end

  def test_read_compressed_input_uses_decompressed_stream
    gz = File.join(FIXTURES, 'lines.gz')
    r = run_task(:read, {path: gz, limit: 2, file_end: 'tail'})
    assert_equal "D\nE", r
    r = run_task(:read, {path: gz, limit: 2, start: 1, file_end: 'tail'})
    assert_equal "C\nD", r
  end

  def test_read_oversized_selection_reports_structured_continuation
    big = File.join(FIXTURES, 'over-ceiling.txt')
    # 100 lines of ~300 bytes each -> over the 16 KiB ceiling
    r = run_task_json(:read, {path: big, limit: 100})
    assert r[:truncated]
    assert_equal 'inline_byte_ceiling', r[:reason]
    assert r.key?(:byte_offset)
    assert r.key?(:inline_byte_ceiling)
    # No truncation marker inside the literal text channel
    refute_includes r.keys, 'text'
  end

  def test_read_window_paging_round_trip
    big = File.join(FIXTURES, 'over-ceiling.txt')
    w1 = run_task_json(:read_window, {path: big, byte_offset: 0, max_bytes: 1024})
    assert_equal 1024, w1[:bytes]
    assert w1[:truncated]
    assert_equal 1024, w1[:next_byte_offset]
    w2 = run_task_json(:read_window, {path: big, byte_offset: w1[:next_byte_offset], max_bytes: 1024})
    assert_equal 1024, w2[:bytes]
    assert_equal w1[:text].bytesize + w2[:text].bytesize, 2048
  end

  def test_read_window_rejects_invalid_inputs
    assert_raise(ParameterException) { run_task(:read_window, {path: LINES_FILE, byte_offset: -1}) }
    assert_raise(ParameterException) { run_task(:read_window, {path: LINES_FILE, max_bytes: 0}) }
    assert_raise(ParameterException) { run_task(:read_window, {path: LINES_FILE, byte_offset: 10_000}) }
  end

  def test_read_works_under_root_grant_and_separate_read_grant
    # Root grant (workflow root)
    r = run_task(:read, {path: 'tmp/impl-fixtures/fs/abc.txt'})
    assert_equal 'abc', r
    # Separately granted directory
    isolated = File.expand_path('~/.rbbt/tmp/workspace-fs-contracts-grant')
    FileUtils.mkdir_p(isolated)
    out = File.join(isolated, 'granted.txt')
    Open.write(out, "granted\n")
    before_w = (Thread.current['allowed_paths'] || []).dup
    before_r = (Thread.current['allowed_read_paths'] || []).dup
    LLM::Sandbox.allow_read_path(isolated)
    begin
      r = run_task(:read, {path: out, limit: 5})
      assert_equal 'granted', r
    ensure
      Thread.current['allowed_paths'] = before_w
      Thread.current['allowed_read_paths'] = before_r
      FileUtils.rm_rf(isolated)
    end
  end

  def test_read_bounded_sizes_on_8mib_newline_free_file
    big = File.join(FIXTURES, 'newline-free-8mib.bin')
    unless File.exist?(big)
      File.open(big, 'wb') do |f|
        chunk = ('x' * 64 * 1024).b
        (8 * 1024 * 1024 / chunk.bytesize).times { f.write(chunk) }
      end
    end
    sizes = []
    spy = Module.new do
      define_method(:open) do |*args, &blk|
        super(*args) do |io|
          io.define_singleton_method(:read) do |n = nil, *rest|
            sizes << n if n
            super(n, *rest)
          end
          blk.call(io)
        end
      end
    end
    receiver = Object.new.extend(Workspace.step_module)
    begin
      File.singleton_class.prepend(spy)
      lines, capped = receiver.tail_lines_by_reverse_scan(big, 1)
    ensure
      File.singleton_class.ancestors[0].__send__(:remove_method, :open) rescue nil
    end
    # A newline-free 8 MiB file cannot produce a full line: the helper
    # reports the collection cap instead of silently returning a whole
    # bogus line, and it NEVER reads more than a handful of chunks.
    assert_equal true, capped
    assert lines.empty?
    assert sizes.size <= 3, "expected at most a few chunk reads, got #{sizes.size}"
    assert sizes.all? { |s| s == 64 * 1024 }, "reads must be fixed-size chunks: #{sizes.inspect}"
    assert sizes.sum < 8 * 1024 * 1024, 'the whole 8 MiB file must not be read'
  end

  # ---- WP-C reads (plan step 1b): one decisive test per defect ----------

  def wp_c_fixture(name, &blk)
    path = File.join(FIXTURES, name)
    File.delete(path) if File.exist?(path)
    File.open(path, 'wb', &blk)
    path
  end

  def test_read_window_clamps_max_bytes_to_the_inline_ceiling
    # defect (a): caller max_bytes must never flow straight into File#read
    big = wp_c_fixture('wp-c-three-blocks.txt') { |f| f.write('x' * (Workspace::READ_INLINE_BYTE_CEILING * 3)) }
    res = run_task_json(:read_window, {path: big, byte_offset: 0, max_bytes: Workspace::READ_INLINE_BYTE_CEILING * 2})
    assert res[:bytes] <= Workspace::READ_INLINE_BYTE_CEILING,
           "window must never exceed the inline ceiling, got #{res[:bytes]}"
    assert_equal Workspace::READ_INLINE_BYTE_CEILING, res[:text].bytesize
    assert res[:truncated]
    assert_equal Workspace::READ_INLINE_BYTE_CEILING, res[:next_byte_offset]
  end

  def test_read_window_never_splits_a_multibyte_character
    # defect (b): both window edges stay on UTF-8 character boundaries
    # (é = C3 A9 placed so both an end edge and a nonzero start edge cut it)
    multi = wp_c_fixture('wp-c-multibyte.txt') do |f|
      f.write((('a' * 10) + [0xC3, 0xA9].pack('C*') + ('b' * 10)).b)
      f.write("ç".b + ('c' * 10).b)
    end
    res = run_task_json(:read_window, {path: multi, byte_offset: 0, max_bytes: 11})
    assert res[:text].valid_encoding?, 'window end edge split a multibyte character'
    assert_equal 10, res[:bytes] # the trailing C3 was trimmed, never delivered
    res = run_task_json(:read_window, {path: multi, byte_offset: 11, max_bytes: 8})
    assert res[:text].valid_encoding?, 'window start edge split a multibyte character'
    assert_operator res[:byte_offset], :>, 11, 'start must move FORWARD to a boundary'
    assert res[:text].bytes.first != 0xA9
    # Serializing every window of the fixture must never see a partial char.
    off = 0
    loop do
      w = run_task_json(:read_window, {path: multi, byte_offset: off, max_bytes: 3})
      assert w[:text].valid_encoding?
      break unless w[:truncated]
      off = w[:next_byte_offset]
    end
  end

  def test_read_envelope_reports_the_true_selection_offset
    # defect (c): oversized envelope must never point a tail selection at
    # byte zero when it starts further into the file
    fat = wp_c_fixture('wp-c-fat-tail.txt') do |f|
      (1..30).each { |i| f.write(format("%04d\n", i)) }
      f.write('y' * (2 * (Workspace::READ_INLINE_BYTE_CEILING + 64 * 1024)) + "\n")
    end
    res = run_task_json(:read, {path: fat, limit: 1, file_end: 'tail'})
    assert_equal 'inline_byte_ceiling', res[:reason]
    expected = 30 * 5 # first byte of the fat line, after the 30 header lines
    assert_equal expected, res[:byte_offset],
                 "envelope byte_offset must be the true start of the selected line, got #{res[:byte_offset]}"
    # Paging from that offset lands exactly on the fat line.
    w = run_task_json(:read_window, {path: fat, byte_offset: res[:byte_offset], max_bytes: 8})
    assert_equal 'y', w[:text][0]
  end

  def test_read_forward_path_is_bounded_on_a_multi_mib_unterminated_line
    # defect (d): the forward path must check the ceiling incrementally
    # while reading chunks, never accumulating an unterminated line
    big = wp_c_fixture('wp-c-fat-line.txt') do |f|
      f.write('z' * (4 * 1024 * 1024)) # 4 MiB unterminated
      f.write("\nsecond line\n")
    end
    receiver = Object.new.extend(Workspace.step_module)
    selected, capped, offset = nil
    assert_nothing_raised do
      GC.start
      before = GC.stat(:total_allocated_objects)
      selected, capped, offset = Open.open(big) { |io| receiver.stream_select_lines(io, 1, 0, 'head') }
      @allocations = GC.stat(:total_allocated_objects) - before
    end
    assert capped
    assert selected.empty?
    assert_equal 0, offset
    assert_operator selected.join.bytesize, :<, 4 * 1024 * 1024,
                    'the whole 4 MiB line must never be accumulated'
    assert_operator @allocations, :<, 5_000,
                    "allocation during selection must stay bounded, got #{@allocations}"
    # The read task surfaces the same bound through the envelope.
    env = run_task_json(:read, {path: big, limit: 1})
    assert_equal 'inline_byte_ceiling', env[:reason]
    assert_equal 0, env[:byte_offset]
  end

  # ---------------- search (plan step 6) ----------------

  TREE = File.join(FIXTURES, 'tree')

  # WP-C search+dir fixtures ------------------------------------------------
  DENIED_SECRET = 'DENIED-CANDIDATE-NEEDLE'
  DENIAL_TREE = File.join(FIXTURES, 'denial_tree')
  OVERSIZE_TREE = File.join(FIXTURES, 'oversize_tree')
  FIFO_TREE = File.join(FIXTURES, 'fifo_tree')
  NAMES_TREE = File.join(FIXTURES, 'names_tree')
  BIG_TREE = File.join(FIXTURES, 'big_tree')

  def ensure_search_dir_fixtures!
    # Denied candidate: a symlink pointing OUTSIDE every grant, so
    # normalize(…, :read) refuses it while the walk still visits it.
    unless File.exist?(File.join(DENIAL_TREE, '.built'))
      FileUtils.mkpath(DENIAL_TREE)
      File.write(File.join(DENIAL_TREE, 'visible.txt'), "plain filler\n")
      FileUtils.ln_s('/proc/self/environ', File.join(DENIAL_TREE, 'denied-link.txt'))
      File.write(File.join(DENIAL_TREE, '.built'), "1\n")
    end
    # Oversize candidate: over the 8 MiB per-file content budget, with
    # the needle ABSENT so the skip is the only reason there are no hits.
    unless File.exist?(File.join(OVERSIZE_TREE, '.built'))
      FileUtils.mkpath(OVERSIZE_TREE)
      File.binwrite(File.join(OVERSIZE_TREE, 'huge.txt'), (("x" * 1000 + "\n") * 8_500))
      File.write(File.join(OVERSIZE_TREE, '.built'), "1\n")
    end
    # FIFO candidate: opening it for reading would block forever.
    # 11+ filler entries also push the directory past scout-essentials'
    # Path#digest_str threshold (>10 entries => names-only digest), so
    # Workspace.job's input digesting never opens the FIFO either. The
    # scanner itself gates FIFOs on File.file? before any open.
    unless File.exist?(File.join(FIFO_TREE, '.built'))
      FileUtils.mkpath(FIFO_TREE)
      File.write(File.join(FIFO_TREE, 'real.txt'), "NEEDLE-IN-REAL-FILE\n")
      12.times { |i| File.write(File.join(FIFO_TREE, format('filler_%02d.txt', i)), "filler\n") }
      FileUtils.rm_f(File.join(FIFO_TREE, 'pipe.fifo'))
      system('mkfifo', File.join(FIFO_TREE, 'pipe.fifo'))
      File.write(File.join(FIFO_TREE, '.built'), "1\n")
    end
    # Filename-cap candidates.
    unless File.exist?(File.join(NAMES_TREE, '.built'))
      FileUtils.mkpath(NAMES_TREE)
      12.times { |i| File.write(File.join(NAMES_TREE, format('needle-name-%02d.txt', i)), "filler\n") }
      File.write(File.join(NAMES_TREE, '.built'), "1\n")
    end
    # Chunk-boundary content fixture: 98 single-byte-long lines whose
    # cumulative size crosses several 64 KiB chunk boundaries, with the
    # needle on line 99.
    unless File.exist?(File.join(BIG_TREE, '.built'))
      FileUtils.mkpath(BIG_TREE)
      File.open(File.join(BIG_TREE, 'boundary.txt'), 'w') do |f|
        98.times { f.write(("y" * 997) + "\n") }
        f.write("the BOUNDARY-NEEDLE sits on line 99\n")
      end
      File.write(File.join(BIG_TREE, '.built'), "1\n")
    end
  end

  # Acceptance fixture: a 300-file tree containing a nested filename hit,
  # two content hits, a compressed file and a binary file, plus filler
  # files that match nothing.
  def ensure_tree!
    return if File.exist?(File.join(TREE, '.built'))
    FileUtils.mkpath(TREE)
    File.write(File.join(TREE, 'needle-name.txt'), "no content needle here\n")
    FileUtils.mkpath(File.join(TREE, 'nested', 'deep'))
    File.write(File.join(TREE, 'nested', 'deep', 'needle-file.txt'),
               "line one\ncontains NEEDLE-CONTENT-1 inside\nline three\n")
    FileUtils.mkpath(File.join(TREE, 'top'))
    File.write(File.join(TREE, 'top', 'other.txt'),
               "unrelated\nmore NEEDLE-CONTENT-2 here\nend\n")
    File.write(File.join(TREE, 'punct.txt'), "contains a.b*c[1] literally\n")
    FileUtils.mkpath(File.join(TREE, 'compressed'))
    Zlib::GzipWriter.open(File.join(TREE, 'compressed', 'needle.gz')) do |gz|
      gz.write("NEEDLE-CONTENT-1 inside compressed\n")
    end
    FileUtils.mkpath(File.join(TREE, 'binary'))
    File.binwrite(File.join(TREE, 'binary', 'blob.bin'),
                  [0x00, 0x01, 0x02, 0x00, 0x7f, 0xfe].pack('C*') * 4)
    # The ignored-directory fixture: content is under .git and must never
    # be reached by a filtered traversal.
    FileUtils.mkpath(File.join(TREE, '.git'))
    File.write(File.join(TREE, '.git', 'config-needle'), 'NEEDLE-CONTENT-1 under git\n')
    300.times do |i|
      dir = File.join(TREE, 'filler', format('%03d', i / 50))
      FileUtils.mkpath(dir)
      File.write(File.join(dir, format('filler_%03d.txt', i)),
                 "filler line #{i}\nnothing to see\n")
    end
    File.write(File.join(TREE, '.built'), "1\n")
  end

  def setup
    ensure_tree!
    ensure_search_dir_fixtures!
  end

  def test_search_array_shape_preserved
    r = run_task_raw(:search, {path: TREE, query: 'NEEDLE-CONTENT-1'})
    assert_equal Array, r.class
    assert r.all? { |x| String === x }
    assert_include r, 'nested/deep/needle-file.txt'
  end

  def test_search_content_hits_across_files
    r = run_task_raw(:search, {path: TREE, query: 'NEEDLE-CONTENT-1'})
    assert_include r, 'nested/deep/needle-file.txt'
    r2 = run_task_raw(:search, {path: TREE, query: 'NEEDLE-CONTENT-2'})
    assert_include r2, 'top/other.txt'
  end

  def test_search_literal_with_regexp_punctuation
    r = run_task_raw(:search, {path: TREE, query: 'a.b*c[1]'})
    assert_include r, 'punct.txt'
  end

  def test_search_no_match_is_empty_array
    r = run_task_raw(:search, {path: TREE, query: 'NO-SUCH-NEEDLE-ANYWHERE'})
    assert_equal [], r
  end

  def test_search_ignores_compressed_and_binary_files_by_default
    r = run_task_raw(:search, {path: TREE, query: 'NEEDLE-CONTENT-1'})
    refute_includes r, 'compressed/needle.gz'
    refute_includes r, 'binary/blob.bin'
  end

  def test_search_glob_restricts_candidates
    d = run_task_raw(:search_details, {path: TREE, query: 'NEEDLE', glob: 'top/*'})
    assert d[:matches].all? { |m| m[:path].start_with?('top/') }
    assert_equal 1, d[:matches].length
  end

  def test_search_details_reports_line_numbers_and_snippet
    d = run_task_raw(:search_details, {path: TREE, query: 'NEEDLE-CONTENT-2'})
    m = d[:matches].find { |x| x[:path] == 'top/other.txt' }
    assert_equal 2, m[:line]
    assert_include m[:snippet], 'NEEDLE-CONTENT-2'
    assert d[:scanned_files] > 0
  end

  def test_search_details_filename_only
    d = run_task_raw(:search_details, {path: TREE, query: 'needle-name', filenames_only: true})
    assert_include d[:matches].collect { |m| m[:path] }, 'needle-name.txt'
  end

  def test_search_details_truncation_is_truthful
    # max_results=1 with several possible matches: truncated must be true
    d = run_task_raw(:search_details, {path: TREE, query: 'NEEDLE', max_results: 1})
    assert d[:truncated], d.inspect
    assert d[:match_count] >= 1
    # No-match under a tiny file budget is never a complete negative
    d2 = run_task_raw(:search_details, {path: TREE, query: 'NO-SUCH-NEEDLE-ANYWHERE', max_files: 1})
    assert d2[:truncated], 'a budget-exhausted scan must not look complete'
    assert_equal [], d2[:matches]
  end

  def test_search_details_reports_skipped_and_pruned_directories
    d = run_task_raw(:search_details, {path: TREE, query: 'NEEDLE'})
    assert d[:skipped_directories] >= 1, 'the .git fixture must be pruned'
  end

  # ---------- WP-C search+dir: authorization, oversize, filename cap ----------

  def test_search_never_opens_a_denied_candidate
    # A file the sandbox has not granted is inside the search root. Its
    # contents must never be opened (no hit may surface from them) and
    # the denial must be disclosed as a truncation reason.
    d = run_task_raw(:search_details, {path: DENIAL_TREE, query: DENIED_SECRET})
    assert_equal [], d[:matches], 'no hit may surface from a denied candidate'
    assert_include d[:truncated_reasons], :denied_read, d.inspect
    assert d[:truncated]
    assert_operator d[:skipped_files], :>=, 1
    r = run_task_raw(:search, {path: DENIAL_TREE, query: DENIED_SECRET})
    assert_equal [], r
  end

  def test_search_oversize_skip_is_disclosed_never_a_complete_negative
    d = run_task_raw(:search_details, {path: OVERSIZE_TREE, query: 'NEEDLE-NEVER-IN-FILE'})
    assert_equal 0, d[:match_count]
    assert_equal true, d[:truncated], 'an oversize skip must never look complete'
    assert_include d[:truncated_reasons], :oversize, d.inspect
    assert_operator d[:skipped_files], :>=, 1
  end

  def test_search_skips_fifo_without_blocking
    # A FIFO in the search root must be skipped as a non-regular file
    # without blocking the scan. The scan completes and reports the
    # regular files around it.
    d = nil
    Timeout.timeout(30) do
      d = run_task_raw(:search_details, {path: FIFO_TREE, query: 'NEEDLE-IN-REAL-FILE'})
    end
    assert_include d[:matches].collect { |m| m[:path] }, 'real.txt'
    refute_includes d[:matches].collect { |m| m[:path] }, 'pipe.fifo'
  end

  def test_search_filenames_only_enforces_max_files
    d = run_task_raw(:search_details, {path: NAMES_TREE, query: 'needle-name',
                                       filenames_only: true, max_files: 5, max_results: 0})
    assert_operator d[:match_count], :<=, 5, 'the file cap must bind in filename mode'
    assert_operator d[:match_count], :>=, 4, 'sorting places .built first, so 4 of the first 5 examined files match'
    assert d[:truncated]
    assert_include d[:truncated_reasons], :max_files, d.inspect
    # Uncapped the same tree yields all of them.
    d2 = run_task_raw(:search_details, {path: NAMES_TREE, query: 'needle-name',
                                        filenames_only: true, max_results: 0})
    assert_equal 12, d2[:match_count]
  end

  def test_search_details_line_numbers_are_exact_after_a_boundary_match
    # The match sits late in the file so it spans at least one chunk
    # boundary; the line count must still come out exact from the scan.
    d = run_task_raw(:search_details, {path: BIG_TREE, query: 'BOUNDARY-NEEDLE'})
    m = d[:matches].find { |x| x[:path] == 'boundary.txt' }
    assert_equal 99, m[:line]
  end

  # ---------------- list_directory / paging ----------------

  # A bounded page can observe at most page_size + 1 entries (the extra
  # one decides `more`); it never enumerates the whole tree.
  PAGE_SIZE_BOUND = 3

  def test_list_directory_keeps_full_array_and_stats_shape
    d = run_task_raw(:list_directory, {directory: TREE, recursive: true})
    assert_equal Array, d[:files].class
    assert d[:files].length > 5
    d2 = run_task_raw(:list_directory, {directory: TREE, recursive: true, stats: true})
    assert d2[:stats].length > 5
    assert d2[:stats].values.first.key?(:size)
    assert d2[:stats].values.first.key?(:mtime)
  end

  def test_list_directory_page_is_bounded_and_deterministic
    p1 = run_task_raw(:list_directory_page, {directory: TREE, recursive: true, page: 1, page_size: 3})
    p2 = run_task_raw(:list_directory_page, {directory: TREE, recursive: true, page: 2, page_size: 3})
    assert_equal 3, p1[:entries_on_page]
    assert_equal 3, p2[:entries_on_page]
    refute_equal p1[:files] + p1[:directories], p2[:files] + p2[:directories]
    # Bounded enumeration: the walk stops one entry past the page, so
    # total_entries is the OBSERVED lower bound (page end + 1), never a
    # whole-tree count, and `more` carries the incompleteness.
    assert p1[:more]
    assert_equal PAGE_SIZE_BOUND + 1, p1[:total_entries]
    assert p1[:total_entries] < 100, 'paging must not enumerate the whole 300-file tree'
    # page_size 0/absent keeps the migration path: all entries
    all = run_task_raw(:list_directory_page, {directory: TREE, recursive: true, page: 1, page_size: 0})
    assert_equal all[:total_entries], all[:entries_on_page]
    refute all[:more]
    # A page far past the end can only prove `more=false` by exhausting
    # the walk, so its total is exact there.
    last_page = run_task_raw(:list_directory_page, {directory: TREE, recursive: true, page: 200, page_size: 3})
    assert_equal 0, last_page[:entries_on_page]
    refute last_page[:more]
    assert_equal all[:total_entries], last_page[:total_entries]
  end

  def test_list_directory_stats_no_longer_uses_leaked_variable
    # With stats, every listed file must carry its own size, not the last
    # entry's. Sizes are distinct in the fixture tree, so a leak shows.
    d = run_task_raw(:list_directory, {directory: TREE, recursive: true, stats: true})
    sizes = d[:stats].values.collect { |v| v[:size] }
    assert sizes.uniq.length > 1, 'stats must not be one repeated (leaked) value'
  end

  # ---------------- file_stats ----------------

  def test_file_stats_binary_detection_by_sample
    d = run_task_raw(:file_stats, {file: File.join(TREE, 'binary/blob.bin')})
    assert_equal true, d[:binary]
    assert d.key?(:lines)
    assert_nil d[:lines], 'exact line counting must be opt-in (cheap metadata by default)'
    d2 = run_task_raw(:file_stats, {file: LINES_FILE})
    assert_equal false, d2[:binary]
    assert_nil d2[:lines]
    # Opt-in exact counting: the count is the true line count.
    d3 = run_task_raw(:file_stats, {file: LINES_FILE, count_lines: true})
    assert_equal 5, d3[:lines]
  end

  # ---------------- write / copy (plan step 8) ----------------

  def test_write_normal_copy_of_a_new_file
    target = File.join(FIXTURES, 'write-out', 'written.txt')
    r = run_task(:write, {path: target, content: "written\n"})
    assert_include r, 'success writing to'
    assert_equal "written\n", File.read(target)
  end

  def test_write_validates_its_own_file_argument
    # The step-level path input name differs from the task's `file`
    # argument: a nil task argument must be rejected before normalize.
    job = Workspace.job(:write, {'path' => '', 'content' => 'x'})
    assert_raise(ParameterException) { job.run }
  end

  def test_copy_normal_copy_happens_before_error_cases
    src = File.join(FIXTURES, 'copy-src.txt')
    File.write(src, "copied\n") if File.read(src) != "copied\n"
    tgt = File.join(FIXTURES, 'copy-out', 'copied.txt')
    FileUtils.rm_f(tgt)
    r = run_task(:copy, {source: src, target: tgt})
    assert_equal "copied\n", File.read(tgt)
  end

  def test_copy_refuses_equivalent_identities
    # Scout keys :path inputs by content MD5, so a refusal job can collide
    # with an earlier normal copy whose target holds the same bytes. Give
    # this test its own source content so the digest is unique.
    src = File.join(FIXTURES, "copy-refusal-src-#{$$}.txt")
    File.write(src, "refusal-source-#{$$}\n")
    link = File.join(FIXTURES, "copy-refusal-link-#{$$}.txt")
    FileUtils.rm_f(link)
    begin
      File.symlink(src, link)
      job = Workspace.job(:copy, {'source' => src, 'target' => link})
      job.clean if job.respond_to?(:clean)
      e = assert_raise(ParameterException) { run_task(:copy, {source: src, target: link}) }
      assert_include e.message, 'same as target'
    ensure
      FileUtils.rm_f(link)
      FileUtils.rm_f(src)
    end
  end

  # ---------------- sandbox_paths ----------------

  def test_sandbox_paths_lean_by_default_and_verbose_opt_in
    lean = run_task_raw(:sandbox_paths, {})
    assert lean.key?(:root)
    refute lean.key?(:realized_mounts), 'verbose field must be opt-in'
    verbose = run_task_raw(:sandbox_paths, {verbose: true})
    assert verbose.key?(:realized_mounts)
  end
end
