require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path('../../../workflow', __dir__)
require 'fileutils'

# Wave 3A, plan step 8 item 6 — end-to-end verification of precise_edit
# through the REAL exported tool surface: real workflow require, real task
# schema inputs, real result decoding (extension :json → Hash), plus the
# four shared-library cases the review requires against this tool.
#
# Fixtures live under tmp/impl-fixtures/edit/ inside the workflow root so
# the root grant covers them (the normal deployment shape for a writable
# file).  TmpFile paths under /tmp are ALSO writable by the workflow user,
# which is what test_replace_and_insert relied on before; that test is
# kept as-is below.
class TestPreciseEdit < Test::Unit::TestCase
  FIXTURES = File.expand_path('../../../tmp/impl-fixtures/edit', __dir__)

  def run_edit(path, operation, selector, replacement, count, hash=nil)
    Workspace.job(:precise_edit, nil, path: path, operation: operation,
      selector: selector, replacement: replacement, expect_matches: count,
      expected_hash: hash).run
  end

  # Decoded exactly the way the exported tool surfaces it (extension :json).
  def run_task(inputs)
    inputs = inputs.transform_keys(&:to_s)
    job = Workspace.job(:precise_edit, inputs)
    job.run
    res = job.load
    res = JSON.parse(res) if res.is_a?(String)
    res.transform_keys(&:to_sym)
  end

  def with_fixture(name, content)
    FileUtils.mkdir_p(FIXTURES)
    path = File.join(FIXTURES, "t-#{name}-#{Process.pid}.txt")
    File.open(path, 'wb') { |f| f.write(content) }
    path
  end

  def teardown
    Dir[File.join(FIXTURES, 't-*')].each { |p| File.delete(p) if File.file?(p) }
  end

  def test_replace_and_insert
    TmpFile.with_file("a\nb\na\n") do |path|
      assert_equal 'updated', run_edit(path, 'replace', 'b', 'B', 1)[:status]
      assert_equal "a\nB\na\n", File.read(path)
      assert_equal 'updated', run_edit(path, 'insert', 'B', '!', 1)[:status]
      assert_equal "a\nB!\na\n", File.read(path)
    end
  end

  def test_replace_keeps_backslash_sequences_literal
    TmpFile.with_file("before\n") do |path|
      replacement = '\\& and \\1'
      assert_equal 'updated', run_edit(path, 'replace', 'before', replacement, 1)[:status]
      assert_equal "#{replacement}\n", File.read(path)
    end
  end

  def test_ambiguous_and_hash_mismatch_are_unchanged
    TmpFile.with_file("a\na\n") do |path|
      before = File.binread(path)
      assert_equal 'precondition_failed', run_edit(path, 'delete', 'a', '', 1)[:status]
      assert_equal before, File.binread(path)
      assert_equal 'precondition_failed', run_edit(path, 'delete', 'a', '', 2, 'bad')[:status]
      assert_equal before, File.binread(path)
    end
  end

  # ---- step 8 item 6: real-schema / decoded-result end-to-end cases ----

  def test_zero_match_expectation_is_success_without_write
    original = "alpha\nbeta\n"
    path = with_fixture('zero', original)
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'zeta',
                   'replacement' => 'Z', 'expect_matches' => 0, 'expected_hash' => '')
    assert_equal 'updated', res[:status]
    assert_equal false, res[:verification][:changed]
    assert_equal 0, res[:matches]
    assert_equal original.bytesize, res[:verification][:bytes_after]
    assert_equal original, File.binread(path), 'zero-match expectation must not rewrite the file'
  end

  def test_identical_replacement_is_success_without_write
    original = "same\nsame\n"
    path = with_fixture('identical', original)
    mtime_before = File.mtime(path)
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'same',
                   'replacement' => 'same', 'expect_matches' => 2, 'expected_hash' => '')
    assert_equal 'updated', res[:status]
    assert_equal false, res[:verification][:changed]
    assert_equal original.bytesize, res[:verification][:bytes_after]
    assert_equal original, File.binread(path)
    assert_equal mtime_before, File.mtime(path), 'no-op must not touch the file at all'
  end

  def test_stale_digest_refusal_returns_original_and_reason
    original = "one\ntwo\n"
    path = with_fixture('stale', original)
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'one',
                   'replacement' => '1', 'expect_matches' => 1,
                   'expected_hash' => Digest::SHA256.hexdigest('never-matches'))
    assert_equal 'precondition_failed', res[:status]
    assert_equal false, res[:verification][:changed]
    assert_equal 'hash_mismatch', res[:verification][:reason]
    assert_equal original, File.binread(path), 'refusal must leave the file untouched'
  end

  def test_repeated_selector_without_expected_count_is_refused
    original = "x\nx\nx\n"
    path = with_fixture('repeat', original)
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'x',
                   'replacement' => 'y', 'expect_matches' => 1, 'expected_hash' => '')
    assert_equal 'precondition_failed', res[:status]
    assert_equal false, res[:verification][:changed]
    assert_equal 'match_count_mismatch', res[:verification][:reason]
    assert_equal 3, res[:matches], 'receipt reports the true selector count'
    assert_equal original, File.binread(path), 'ambiguous selector must not write'
  end

  def test_literal_backslashes_are_never_interpreted_through_the_tool
    original = "keep\n"
    path = with_fixture('backslash', original)
    replacement = "\\1 and \\& and \\n"
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'keep',
                   'replacement' => replacement, 'expect_matches' => 1, 'expected_hash' => '')
    assert_equal 'updated', res[:status]
    assert_equal true, res[:verification][:changed]
    assert_equal "#{replacement}\n", File.binread(path),
                 'backslash sequences must be written as literal bytes'
  end

  def test_success_receipt_fields_preserved_and_additive
    original = "old\n"
    path = with_fixture('receipt', original)
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'old',
                   'replacement' => 'new', 'expect_matches' => 1, 'expected_hash' => '')
    assert_equal 'updated', res[:status]
    assert_equal 1, res[:matches]
    # Public status + successful receipt fields kept from the pre-overlay shape.
    assert_equal({expected_matches: 1, expected_hash: '',
                  actual_hash: Digest::SHA256.hexdigest("old\n")},
                 res[:precondition])
    assert_equal({changed: true, hash: Digest::SHA256.hexdigest("new\n"),
                  bytes_before: 4, bytes_after: 4},
                 res[:verification])
    # Additive adapter fields only.
    assert_equal path, res[:resolved_path]
    assert_equal true, res[:existence]
    assert_equal 'new', File.read(path).chomp
  end

  def test_exported_tool_surface_decodes_json_and_casts_inputs
    # Real exported surface: LLM.call_workflow with model-supplied JSON-style
    # strings (integer input arrives as "0"), result decoded back to a Hash.
    original = "alpha\nbeta\n"
    path = with_fixture('exported', original)
    res = LLM.call_workflow(Workspace, :precise_edit, 'path' => path,
                            'operation' => 'replace', 'selector' => 'zeta',
                            'replacement' => 'Z', 'expect_matches' => '0',
                            'expected_hash' => '')
    res = JSON.parse(res) if res.is_a?(String)
    assert_equal 'updated', res[:status]
    assert_equal false, res[:verification][:changed]
    assert_equal 0, res[:matches]
    assert_equal original.bytesize, res[:verification][:bytes_after]
    assert_equal original, File.binread(path)
  end

  def test_encoded_content_round_trips_as_bytes
    original = "α\r\nα\n".b
    path = with_fixture('bytes', original)
    res = run_task('path' => path, 'operation' => 'replace', 'selector' => 'α',
                   'replacement' => 'ω', 'expect_matches' => 2, 'expected_hash' => '')
    assert_equal 'updated', res[:status]
    assert_equal true, res[:verification][:changed]
    assert_equal "ω\r\nω\n".b, File.binread(path)
  end
end
