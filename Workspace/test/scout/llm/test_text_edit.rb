require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require File.expand_path(__FILE__).sub(%r(.*/test/), '').sub(/test_(.*)\.rb/,'\1')

class TestScoutTextEdit < Test::Unit::TestCase
  def apply(source, selector, replacement, count, operation: 'replace', hash: nil)
    ScoutTextEdit.apply(source, selector: selector, replacement: replacement,
      expect_matches: count, operation: operation, expected_hash: hash)
  end

  def test_literal_bytes_and_receipt
    source = "α\r\nα".b
    result, receipt = apply(source, 'α', '\\1', 2, operation: 'insert')
    assert_equal "α\\1\r\nα\\1".b, result
    assert_equal Digest::SHA256.hexdigest(result), receipt[:verification][:hash]
    assert_equal 2, receipt[:matches]
    assert_equal "α\r\nα".b, source
  end

  def test_hash_and_count_preconditions
    [['stale', 'hash_mismatch'], [nil, 'match_count_mismatch']].each do |hash, reason|
      result, receipt = apply('cat cat', 'cat', 'dog', 1, hash: hash)
      assert_equal 'cat cat', result
      assert_equal 'precondition_failed', receipt[:status]
      assert_equal({changed: false, reason: reason}, receipt[:verification])
    end
  end

  def test_no_op_and_nonoverlapping_deletion
    assert_equal false, apply('a', 'x', 'z', 0).last[:verification][:changed]
    assert_equal false, apply('a', 'a', 'a', 1).last[:verification][:changed]
    assert_equal 'a', apply('aaa', 'aa', '', 1, operation: 'delete').first
  end

  def test_rejects_invalid_edits
    assert_raise(ArgumentError) { apply('abc', '', '', 0) }
    assert_raise(ArgumentError) { apply('abc', 'a', '', -1) }
    assert_raise(ArgumentError) { apply('abc', 'a', '', 1, operation: 'move') }
  end
end
