# Pure line-editing helper for authored documents.
#
# Isolated from storage and task code on purpose: this module knows
# nothing about dossiers, revisions or the store; it is the seam where a
# shared Scout-AI document library can later replace it.
#
# CONTRACT (pinned by test/Research/line_edit/test_line_edit.rb, which
# covers every clause):
#
# - Positions are ONE-BASED; the edited interval is half-open
#   [start_line, end_line). For a document of N lines the valid request
#   range is 1 <= start_line <= end_line <= N+1. Out-of-range or inverted
#   requests RAISE (LineEdit::RangeError); nothing is clamped.
# - Lines are text segments INCLUDING their existing terminators (\n,
#   \r\n, or none at the final line). The replacement is literal text:
#   it is inserted exactly as given, with no terminator added, removed or
#   normalized. Every byte outside the selected span is preserved
#   byte-for-byte; there is no global newline or format normalization of
#   any kind.
# - start_line == end_line inserts immediately BEFORE that line;
#   (N+1, N+1) appends after the last line. An empty replacement string
#   deletes exactly the selected range. An empty document (N = 0) admits
#   only the request (1, 1).
# - CALLER RULE (must be documented at every call site): the caller
#   includes the desired line breaks. In particular, appending after a
#   final line that lacks its terminator requires a LEADING newline in
#   the replacement ("#{new_line}\n" or "\n#{new_line}" depending on
#   which side supplies the break) — otherwise the new text joins the
#   last line.
# - Encoding: valid UTF-8 strings pass through untouched; invalid UTF-8
#   or non-UTF-8-encoded input RAISES (LineEdit::EncodingError) — bytes
#   are never transcoded. (ASCII-8BIT binary input is rejected too: the
#   authored-document surface is UTF-8 text.)
# - span(text, start_line, end_line) returns the current text of the
#   one-based half-open span [start_line, end_line) with exactly edit's
#   positioning, validation and encoding discipline, and with NO
#   normalization of any kind: the returned String compares
#   byte-identical with the substring the caller last read (terminators
#   included), so a caller can verify what a span currently holds before
#   replacing it. It is the pure substrate of content anchoring; this
#   module stays dossier-agnostic and never learns who calls it.
#
# Counting rule: a line is a maximal segment terminated by "\n" (the
# terminator may be preceded by "\r"); a final segment with no terminator
# is its own line. "" therefore has 0 lines; "a\n" has 1; "a" has 1;
# "a\r\nb" has 2. CRLF terminators belong to their line's bytes and move
# with them.

module Research
  module LineEdit
    class Error < StandardError; end
    class RangeError < Error; end
    class EncodingError < Error; end

    class << self
      # edit(text, start_line, end_line, replacement) -> new String
      def edit(text, start_line, end_line, replacement)
        check_input!(text, 'document')
        check_input!(replacement, 'replacement')

        head, _selected, tail = split_span(text, start_line, end_line)
        # join of empty arrays yields a US-ASCII "" — tag the result UTF-8
        # so callers always receive the document encoding (no byte is
        # transcoded; inputs are strictly validated UTF-8).
        (head + replacement + tail).force_encoding(Encoding::UTF_8)
      end

      # span(text, start_line, end_line) -> current text of the span.
      # One-based half-open [start_line, end_line): exactly the segment
      # edit removes, terminators included, so "anchor == span(...)" means
      # the edit will replace exactly the anchored text. Empty span
      # returns "" (pure insertion point). Same RangeError/EncodingError
      # discipline as edit; byte-faithful, no normalization. Pure.
      def span(text, start_line, end_line)
        check_input!(text, 'document')

        _head, selected, = split_span(text, start_line, end_line)
        # join of an empty span would tag "" US-ASCII; keep UTF-8 (no byte
        # is transcoded).
        selected.dup.force_encoding(Encoding::UTF_8)
      end

      # lines(text) -> Array of line segments including terminators.
      # Zero lines for the empty string. Pure: no mutation, no copy of
      # the input beyond segmentation.
      def lines(text)
        check_input!(text, 'document')
        split_lines(text)
      end

      # diff(old, new, max_lines: 2000) -> Array of hunks between two
      # UTF-8 documents. Pure: no dossier/store knowledge. Hunk shape:
      #   { 'start' => one-based line in NEW text where the hunk begins,
      #     'end'   => line AFTER the last new-text line of the hunk
      #               (half-open [start, end); end < start means a pure
      #               deletion with no new-text lines),
      #     'old_start' => one-based line in OLD text,
      #     'old_end'   => half-open end in OLD text,
      #     'removed' => [old lines], 'added' => [new lines] }
      # A single shared suffix/prefix commonality keeps hunks minimal for
      # the intended use (adjacent revisions of one document); it is a
      # longest-common-subsequence line diff, not a minimal-diff engine.
      # Raises RangeError-equivalent nothing; returns [] for equal texts.
      def diff(old_text, new_text, max_lines: 2000)
        check_input!(old_text, 'old document')
        check_input!(new_text, 'new document')
        old_lines = split_lines(old_text)
        new_lines = split_lines(new_text)

        # LCS over indices (documents here are small; cap protects size)
        total = old_lines.length + new_lines.length
        if total > max_lines
          return [{ 'start' => 1, 'end' => new_lines.length + 1,
                    'old_start' => 1,
                    'old_end' => old_lines.length + 1,
                    'removed' => old_lines.first(max_lines),
                    'added' => new_lines.first(max_lines),
                    'truncated' => true }]
        end

        lcs = lcs_table(old_lines, new_lines)
        hunks = []
        oi = 0
        ni = 0
        while oi < old_lines.length || ni < new_lines.length
          if oi < old_lines.length && ni < new_lines.length &&
             old_lines[oi] == new_lines[ni]
            oi += 1
            ni += 1
            next
          end

          # Extend the mismatch: find the next aligned point using the LCS
          # table, then emit one hunk covering everything between.
          del_start, del_end, add_start, add_end =
            next_aligned(old_lines, new_lines, lcs, oi, ni)

          hunks << { 'start' => add_start + 1,
                     'end' => add_end + 1,
                     'old_start' => del_start + 1,
                     'old_end' => del_end + 1,
                     'removed' => old_lines[del_start...del_end],
                     'added' => new_lines[add_start...add_end] }
          oi = del_end
          ni = add_end
        end
        hunks
      end

      def lcs_table(old_lines, new_lines)
        n = old_lines.length
        m = new_lines.length
        table = Array.new(n + 1) { Array.new(m + 1, 0) }
        (n - 1).downto(0) do |i|
          (m - 1).downto(0) do |j|
            table[i][j] = if old_lines[i] == new_lines[j]
                            table[i + 1][j + 1] + 1
                          else
                            [table[i + 1][j], table[i][j + 1]].max
                          end
          end
        end
        table
      end

      def next_aligned(old_lines, new_lines, table, oi, ni)
        del_start = oi
        add_start = ni
        n = old_lines.length
        m = new_lines.length
        # Walk to the next (oi2, ni2) both < bounds with equal lines that
        # lies on an LCS path.
        oi2 = oi
        ni2 = ni
        until (oi2 >= n && ni2 >= m) ||
              (oi2 < n && ni2 < m && old_lines[oi2] == new_lines[ni2])
          if oi2 >= n
            ni2 = m
          elsif ni2 >= m
            oi2 = n
          elsif table[oi2 + 1][ni2] >= table[oi2][ni2 + 1]
            oi2 += 1
          else
            ni2 += 1
          end
        end
        [del_start, oi2, add_start, ni2]
      end

      # count(text) -> Integer number of lines. Pure.
      def count(text)
        check_input!(text, 'document')
        split_lines(text).length
      end

      # split_span(text, start_line, end_line) -> [head, selected, tail]
      #
      # THE single positioning helper: splits the text into lines ONCE and
      # returns the three parts around the one-based half-open span
      # [start_line, end_line) — head (lines before the span), selected
      # (the span itself) and tail (lines after the span). It performs the
      # whole validation the pinned contract states (no clamping;
      # RangeError on out-of-range, inverted or non-Integer positions), so
      # edit and span share one validation and one split of the text.
      # Public: the contract tests pin the edit/span/split_span agreement.
      def split_span(text, start_line, end_line)
        lines = split_lines(text)
        n = lines.length

        unless Integer === start_line && Integer === end_line
          raise RangeError,
                "line positions must be Integers (got " \
                "#{start_line.inspect}, #{end_line.inspect})"
        end
        unless start_line >= 1 && start_line <= n + 1
          raise RangeError,
                "start_line #{start_line} out of range: with #{n} line(s), " \
                "valid start_line is 1..#{n + 1}"
        end
        unless end_line >= start_line && end_line <= n + 1
          raise RangeError,
                "end_line #{end_line} out of range for start_line " \
                "#{start_line}: valid end_line is #{start_line}..#{n + 1} " \
                '(half-open [start_line, end_line), 1-based)'
        end

        # One-based half-open [start_line, end_line): the span covers
        # zero-based indices start_line - 1 ... end_line - 1, the head is
        # zero-based 0 ... start_line - 1, and the tail begins at
        # one-based line end_line (zero-based end_line - 1). Joining the
        # parts (join of [] is '') keeps empty parts String and UTF-8,
        # which span()'s contract test pins.
        [ (lines[0, start_line - 1] || []).join,
          (lines[(start_line - 1)...(end_line - 1)] || []).join,
          (lines[end_line - 1..] || []).join ]
      end

      def split_lines(text)
        return [] if text.empty?

        parts = text.split(/(?<=\n)/, -1)
        # A text ending in "\n" yields one phantom trailing "" element from
        # the zero-width lookbehind split; a genuine final unterminated
        # empty line cannot exist (it would have no bytes), so dropping it
        # is exactly the counting rule.
        parts.pop if parts.last == ''
        parts
      end

      def check_input!(string, label)
        unless String === string
          raise EncodingError,
                "#{label} must be a String (got #{string.class})"
        end
        enc = string.encoding
        unless enc == Encoding::UTF_8
          raise EncodingError,
                "#{label} must be UTF-8 encoded (got #{enc}); transcoding " \
                'is never performed — re-encode valid text explicitly or ' \
                'fix the source'
        end
        return if string.valid_encoding?

        raise EncodingError,
              "#{label} contains invalid UTF-8 bytes; refusing to edit — " \
              'fix the source encoding'
      end
    end
  end
end
