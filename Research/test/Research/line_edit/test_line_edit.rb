# Exhaustive contract tests for Research::LineEdit (WO-2 plan step 4).
# Every clause of the pinned contract has at least one test; byte
# assertions compare SHA-256 digests of exact bytes, never normalized
# strings.

require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(/test/.*), '/lib/Research/line_edit.rb')
require 'digest'

class TestLineEditContract < Test::Unit::TestCase
  def d(bytes)
    Digest::SHA256.hexdigest(bytes)
  end

  ## -- basic positioning semantics ------------------------------------

  def test_replace_exactly_one_line
    text = "alpha\nbeta\ngamma\n"
    out = Research::LineEdit.edit(text, 2, 3, "BETA\n")
    assert_equal "alpha\nBETA\ngamma\n", out
    assert_equal d("alpha\nBETA\ngamma\n"), d(out)
  end

  def test_replace_one_line_without_final_newline_document
    text = "alpha\nbeta\ngamma"
    out = Research::LineEdit.edit(text, 3, 4, 'GAMMA')
    assert_equal "alpha\nbeta\nGAMMA", out
  end

  def test_delete_a_range
    text = "one\ntwo\nthree\nfour\n"
    out = Research::LineEdit.edit(text, 2, 4, '')
    assert_equal "one\nfour\n", out
    assert_equal d("one\nfour\n"), d(out)
  end

  def test_delete_every_line
    text = "one\ntwo\n"
    out = Research::LineEdit.edit(text, 1, 3, '')
    assert_equal '', out
  end

  def test_insert_between_lines
    text = "one\nthree\n"
    out = Research::LineEdit.edit(text, 2, 2, "two\n")
    assert_equal "one\ntwo\nthree\n", out
  end

  def test_insert_at_start
    text = "body\n"
    out = Research::LineEdit.edit(text, 1, 1, "title\n")
    assert_equal "title\nbody\n", out
  end

  def test_append_at_n_plus_one
    text = "one\ntwo\n"
    out = Research::LineEdit.edit(text, 3, 3, "three\n")
    assert_equal "one\ntwo\nthree\n", out
  end

  def test_append_after_final_line_lacking_terminator_needs_leading_newline
    text = "one\ntwo"
    # Correct caller form: leading newline in the replacement.
    out = Research::LineEdit.edit(text, 3, 3, "\nthree\n")
    assert_equal "one\ntwo\nthree\n", out
    # The naive form joins the last line (documented caller rule).
    joined = Research::LineEdit.edit(text, 3, 3, 'three')
    assert_equal "one\ntwothree", joined
  end

  def test_replace_final_line_without_terminator
    text = "one\ntwo"
    out = Research::LineEdit.edit(text, 2, 3, 'TWO')
    assert_equal "one\nTWO", out
  end

  ## -- empty replacement == deletion; empty document -------------------

  def test_empty_replacement_deletes_selected_range
    text = "a\nb\nc\n"
    out = Research::LineEdit.edit(text, 1, 2, '')
    assert_equal "b\nc\n", out
  end

  def test_empty_document_allows_only_one_one
    out = Research::LineEdit.edit('', 1, 1, "first\n")
    assert_equal "first\n", out
    assert_equal '', Research::LineEdit.edit('', 1, 1, '')
  end

  def test_empty_document_rejects_everything_else
    [0, 2].each do |bad|
      e = assert_raise(Research::LineEdit::RangeError) do
        Research::LineEdit.edit('', bad, 1, 'x')
      end
      assert_match(/start_line #{bad} out of range/, e.message)
    end
    assert_raise(Research::LineEdit::RangeError) do
      Research::LineEdit.edit('', 1, 2, 'x')
    end
  end

  ## -- byte preservation: CRLF and final-newline cases (digest-based) --

  def test_crlf_document_replaces_one_line_and_preserves_other_bytes
    text = "first\r\nsecond\r\nthird\r\n"
    out = Research::LineEdit.edit(text, 2, 3, "SECOND\r\n")
    assert_equal "first\r\nSECOND\r\nthird\r\n", out
    # Byte-level untouched-span check (digests, not string equality):
    assert_equal d("first\r\n"), d(out[0, 7])
    assert_equal d("third\r\n"), d(out[15..] || '')
    assert_equal d("first\r\nSECOND\r\nthird\r\n"), d(out)
  end

  def test_crlf_document_insert_between_lines
    text = "first\r\nthird\r\n"
    out = Research::LineEdit.edit(text, 2, 2, "second\r\n")
    assert_equal "first\r\nsecond\r\nthird\r\n", out
    assert_equal d("first\r\nsecond\r\nthird\r\n"), d(out)
  end

  def test_crlf_document_delete_range_keeps_crlf_bytes_intact
    text = "a\r\nb\r\nc\r\nd\r\n"
    out = Research::LineEdit.edit(text, 2, 4, '')
    assert_equal "a\r\nd\r\n", out
    assert_equal d("a\r\nd\r\n"), d(out)
  end

  def test_mixed_terminators_preserved_byte_for_byte
    text = "lf\ncrlf\r\nlast"
    out = Research::LineEdit.edit(text, 1, 1, "head\n")
    assert_equal "head\nlf\ncrlf\r\nlast", out
    assert_equal d("head\nlf\ncrlf\r\nlast"), d(out)
  end

  def test_final_newline_preserved_when_span_stops_before_it
    text = "one\ntwo\n"
    out = Research::LineEdit.edit(text, 1, 2, 'ONE')
    # Replacing line 1 without terminator merges with line 2 — literal
    # semantics; the untouched tail (including the final \n) is intact.
    assert_equal "ONEtwo\n", out
    assert_equal d("ONEtwo\n"), d(out)
  end

  def test_final_newline_case_append_with_existing_final_newline
    text = "one\n"
    out = Research::LineEdit.edit(text, 2, 2, "two\n")
    assert_equal "one\ntwo\n", out
  end

  def test_replacement_of_whole_document
    text = "old1\nold2\n"
    out = Research::LineEdit.edit(text, 1, 3, "new\n")
    assert_equal "new\n", out
  end

  ## -- out-of-range rejection (no clamping) ----------------------------

  def test_rejects_zero_start
    e = assert_raise(Research::LineEdit::RangeError) do
      Research::LineEdit.edit("a\n", 0, 1, 'x')
    end
    assert_match(/start_line 0 out of range/, e.message)
  end

  def test_rejects_n_plus_two_end
    text = "a\nb\n"
    e = assert_raise(Research::LineEdit::RangeError) do
      Research::LineEdit.edit(text, 1, 4, 'x')
    end
    assert_match(/end_line 4 out of range/, e.message)
  end

  def test_rejects_start_greater_than_end
    e = assert_raise(Research::LineEdit::RangeError) do
      Research::LineEdit.edit("a\nb\n", 2, 1, 'x')
    end
    assert_match(/end_line 1 out of range for start_line 2/, e.message)
  end

  def test_rejects_non_integer_positions
    e = assert_raise(Research::LineEdit::RangeError) do
      Research::LineEdit.edit("a\n", '1', 1, 'x')
    end
    assert_match(/must be Integers/, e.message)
  end

  def test_rejects_nil_positions
    assert_raise(Research::LineEdit::RangeError) do
      Research::LineEdit.edit("a\n", nil, 1, 'x')
    end
  end

  ## -- encoding discipline ---------------------------------------------

  def test_rejects_invalid_utf8_document
    bad = "ok\n".dup.force_encoding(Encoding::UTF_8)
    bad << "\xFF\xFE\n".dup.force_encoding(Encoding::UTF_8)
    e = assert_raise(Research::LineEdit::EncodingError) do
      Research::LineEdit.edit(bad, 1, 1, 'x')
    end
    assert_match(/invalid UTF-8/, e.message)
  end

  def test_rejects_non_utf8_encoding_without_transcoding
    latin = "caf\xE9\n".dup.force_encoding(Encoding::ISO_8859_1)
    e = assert_raise(Research::LineEdit::EncodingError) do
      Research::LineEdit.edit(latin, 1, 1, 'x')
    end
    assert_match(/must be UTF-8 encoded/, e.message)
    # Bytes untouched by the rejection:
    assert_equal "caf\xE9\n".dup.force_encoding(Encoding::ISO_8859_1), latin
  end

  def test_rejects_invalid_utf8_replacement
    bad = "x".dup << "\xFF".dup.force_encoding(Encoding::UTF_8)
    bad = (bad.bytes.pack('C*').force_encoding(Encoding::UTF_8))
    e = assert_raise(Research::LineEdit::EncodingError) do
      Research::LineEdit.edit("a\n", 1, 1, bad)
    end
    assert_match(/invalid UTF-8/, e.message)
  end

  def test_rejects_binary_input
    bin = "a\n".dup.force_encoding(Encoding::ASCII_8BIT)
    e = assert_raise(Research::LineEdit::EncodingError) do
      Research::LineEdit.edit(bin, 1, 1, 'x')
    end
    assert_match(/must be UTF-8 encoded/, e.message)
  end

  def test_valid_multibyte_utf8_passes_through
    text = "héllo\nwörld\n"
    out = Research::LineEdit.edit(text, 2, 3, "WÖRLD\n")
    assert_equal "héllo\nWÖRLD\n", out
    assert_equal d("héllo\nWÖRLD\n"), d(out)
  end

  ## -- counting helpers use the same one-based convention ---------------

  def test_lines_and_count_share_the_convention
    assert_equal 0, Research::LineEdit.count('')
    assert_equal 1, Research::LineEdit.count("a\n")
    assert_equal 1, Research::LineEdit.count('a')
    assert_equal 2, Research::LineEdit.count("a\r\nb")
    assert_equal 3, Research::LineEdit.count("a\nb\nc\n")

    assert_equal ["a\n", 'b'], Research::LineEdit.lines("a\nb")
    assert_raise(Research::LineEdit::EncodingError) do
      Research::LineEdit.lines("x".dup.force_encoding(Encoding::ASCII_8BIT))
    end
  end

  def test_edit_is_pure_input_untouched
    text = "one\ntwo\n"
    frozen = text.dup
    Research::LineEdit.edit(text, 1, 2, 'ONE')
    assert_equal frozen, text
  end

  # ---- span(): current text of a half-open span, pure ---------------

  def test_span_extracts_exact_span_including_terminators
    assert_equal "two\n", Research::LineEdit.span("one\ntwo\nthree\n", 2, 3)
    assert_equal "one\ntwo\n", Research::LineEdit.span("one\ntwo\nthree\n", 1, 3)
    assert_equal "two\nthree\n", Research::LineEdit.span("one\ntwo\nthree\n", 2, 4)
    assert_equal "one\ntwo\nthree\n", Research::LineEdit.span("one\ntwo\nthree\n", 1, 4)
  end

  def test_span_empty_span_is_empty_insertion_point
    assert_equal '', Research::LineEdit.span("one\ntwo\n", 1, 1)
    assert_equal '', Research::LineEdit.span("one\ntwo\n", 2, 2)
    # one past the last line: the append point
    assert_equal '', Research::LineEdit.span("one\ntwo\n", 3, 3)
  end

  def test_span_final_line_without_terminator
    # document whose last line lacks a terminator: the span covers it
    assert_equal 'two', Research::LineEdit.span("one\ntwo", 2, 3)
    # trailing-newline semantics unchanged: terminator not part of the
    # span when end_line stops before it
    assert_equal "two\n", Research::LineEdit.span("one\ntwo\n", 2, 3)
  end

  def test_span_rejects_the_same_ranges_edit_rejects
    assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.span("a\n", 0, 1) }
    assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.span("a\n", 1, 3) }
    assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.span("a\n", 2, 1) }
    assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.span("a\n", nil, 1) }
  end

  def test_span_matches_what_edit_removes
    # invariant: edit replaces exactly the text span() reports
    text = "one\ntwo\nthree\n"
    1.upto(4) do |s|
      s.upto(4) do |e|
        next unless e >= s

        extracted = Research::LineEdit.span(text, s, e)
        # invariant: edited == head + replacement + tail where head/tail
        # are the complements of span() in the original text
        head_len = (Research::LineEdit.lines(text)[0, s - 1] || []).join.bytesize
        expected = text.byteslice(0, head_len) + 'X' +
                   text.byteslice(head_len + extracted.bytesize, text.bytesize)
        assert_equal expected, Research::LineEdit.edit(text, s, e, 'X'),
                     "span [#{s}, #{e}) must be what edit removes"
      end
    end
  end

  def test_span_is_pure_and_byte_faithful
    text = "a\r\nb\nc"
    frozen = text.dup
    out = Research::LineEdit.span(text, 1, 3)
    # byte faithful: terminators included as-is, nothing normalized;
    # span [1, 3) covers lines 1-2 including their terminators, not the
    # unterminated final line
    assert_equal "a\r\nb\n", out
    assert_equal frozen, text
    assert_equal Encoding::UTF_8, out.encoding
    # empty span still reports UTF-8 (join of [] would tag US-ASCII)
    assert_equal Encoding::UTF_8, Research::LineEdit.span(text, 2, 2).encoding
  end

  ## -- single-helper refactor (D5) ------------------------------------

  def test_edit_and_span_agree_for_all_span_shapes
    # One helper (split_span) validates positions once and returns
    # [head, selected, tail]; edit and span must therefore agree on
    # validation AND extraction for every span shape, including the
    # final line without terminator, empty spans and [n+1, n+1) append.
    shapes = [
      ["alpha\nbeta\ngamma\n", 1, 1],   # empty span at head
      ["alpha\nbeta\ngamma\n", 2, 2],   # empty span mid-document
      ["alpha\nbeta\ngamma\n", 4, 4],   # [n+1, n+1) append point
      ["alpha\nbeta\ngamma\n", 1, 4],   # whole document
      ["alpha\nbeta\ngamma",   3, 4],   # final line, no terminator
      ["a\r\nb\r\nc\r\n",      2, 3],   # CRLF terminator reuse
      ["a\nb\rc\n",            1, 3],   # mixed terminators
      ["",                     1, 1]    # empty document
    ]
    shapes.each do |(text, s, e)|
      selected = Research::LineEdit.span(text, s, e)
      # exact invariant: edit with '' removes exactly what span returns
      assert_equal Research::LineEdit.edit(text, s, e, '').bytesize + selected.bytesize, text.bytesize,
                   "edit(text,#{s},#{e},'') must equal text minus span(text,#{s},#{e})"
      # and inserting the extracted span back reproduces edit(text, s, e, span)
      assert_equal Research::LineEdit.edit(text, s, e, selected), text,
                   "re-inserting the extracted span must reproduce the original text for [#{s}, #{e})"
    end
  end

  def test_split_span_validates_and_splits_in_one_pass
    # The helper itself: [head, selected, tail] with head+selected+tail ==
    # original bytes, same validation as edit/span raise for bad positions.
    text = "a\nb\nc\n"
    head, selected, tail = Research::LineEdit.split_span(text, 2, 3)
    assert_equal 'a' + "\n", head
    assert_equal "b\n", selected
    assert_equal "c\n", tail
    assert_equal text.bytesize, head.bytesize + selected.bytesize + tail.bytesize
    assert_equal text, head + selected + tail
    # validation parity for rejected positions (LineEdit::RangeError is
    # the pinned class for out-of-range, inverted or non-Integer
    # positions)
    [[0, 1], [2, 1], [1, 5], [-1, 2], ['1', 2]].each do |(s, e)|
      assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.split_span(text, s, e) }
      assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.edit(text, s, e, 'X') }
      assert_raise(Research::LineEdit::RangeError) { Research::LineEdit.span(text, s, e) }
    end
    # purity: input unchanged
    frozen = 'a' + "\nb\nc\n"
    Research::LineEdit.split_span(frozen.dup, 1, 3)
    assert_equal 'a' + "\nb\nc\n", frozen
  end

  def test_split_span_byte_faithfulness_on_mixed_terminators
    # CRLF/LF mixes must pass through untouched — no terminator
    # rewriting anywhere in head/selected/tail.
    text = "a\r\nb\nc\r\nd"
    head, selected, tail = Research::LineEdit.split_span(text, 2, 4)
    assert_equal "a\r\n", head
    assert_equal "b\nc\r\n", selected
    assert_equal 'd', tail
    assert_equal text, head + selected + tail
    assert_equal Encoding::UTF_8, selected.encoding
  end
end
