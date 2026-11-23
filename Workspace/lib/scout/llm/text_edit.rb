require 'digest'

module ScoutTextEdit
  module_function

  # Returns [candidate content, verification record]. No IO or workflow state.
  # Selectors and replacements are literal bytes, including newlines and backslashes.
  def apply(original, operation:, selector:, replacement:, expect_matches:, expected_hash: nil)
    operation = operation.to_s
    raise ArgumentError, 'operation must be replace, insert or delete' unless %w[replace insert delete].include?(operation)
    raise ArgumentError, 'selector must be nonempty text' unless selector.is_a?(String) && !selector.empty?
    raise ArgumentError, 'replacement must be text' unless replacement.is_a?(String)
    unless expect_matches.is_a?(Integer) && expect_matches >= 0
      raise ArgumentError, 'expect_matches must be a non-negative integer'
    end

    digest = Digest::SHA256.hexdigest(original)
    receipt = {
      status: 'precondition_failed', matches: 0,
      precondition: {expected_matches: expect_matches, expected_hash: expected_hash, actual_hash: digest}
    }
    if expected_hash && !expected_hash.empty? && expected_hash != digest
      receipt[:verification] = {changed: false, reason: 'hash_mismatch'}
      return original, receipt
    end

    bytes = original.b
    needle = selector.b
    matches = 0
    bytes.scan(Regexp.new(Regexp.escape(needle))) { matches += 1 }
    receipt[:matches] = matches
    if matches != expect_matches
      receipt[:verification] = {changed: false, reason: 'match_count_mismatch'}
      return original, receipt
    end

    value = case operation
            when 'insert' then needle + replacement.b
            when 'delete' then ''.b
            else replacement.b
            end
    updated = bytes.gsub(needle) { value }.force_encoding(original.encoding)
    changed = updated != original
    receipt[:status] = 'updated'
    receipt[:verification] = {changed: changed, hash: Digest::SHA256.hexdigest(updated),
                              bytes_before: original.bytesize, bytes_after: updated.bytesize}
    [updated, receipt]
  end
end
