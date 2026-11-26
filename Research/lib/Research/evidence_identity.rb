module Research
  module EvidenceIdentity
    module_function

    def digest(entry)
      entry.is_a?(Hash) ? entry.fetch('digest') : entry
    end

    # Prefixes are a convenience scoped to one integer revision's inventory.
    def prefixes(inventory)
      sorted = inventory.uniq.sort
      sorted.each_with_index.to_h do |value, index|
        # Only lexical neighbors can share the longest prefix.
        neighbors = [index.positive? && sorted[index - 1], sorted[index + 1]].select { |d| d }
        length = 5
        length += 1 while length < value.size && neighbors.any? { |d| d.start_with?(value[0, length]) }
        [value, value[0, length]]
      end
    end

    def resolve!(attachments, prefix, key)
      prefix = prefix.delete_prefix('sha256:')
      unless prefix.match?(/\A[0-9a-f]{5,64}\z/)
        raise ParameterException, 'digest must be 5 to 64 lowercase SHA-256 characters'
      end
      matches = attachments.select { |_, entry| digest(entry).start_with?(prefix) }
      digests = matches.values.map { |entry| digest(entry) }.uniq
      raise ParameterException, 'no evidence matches this digest in the selected revision' if matches.empty?
      if digests.size > 1
        choices = prefixes(digests).values
        raise ParameterException, "ambiguous digest; use one of #{choices.join(', ')}"
      end
      return key if key && matches.key?(key)
      return matches.keys.first if !key && matches.size == 1
      raise ParameterException, "specify a matching attachment: #{matches.keys.sort.join(', ')}"
    end

    # Optional agent-facing projection. Keep the receipt needed to reopen
    # the full record, integrity failures, and any requested text window.
    def compact(description)
      description.slice('attachment', 'revision', 'mode', 'digest_prefix',
                        'retained_kind', 'evidence_read', 'caption', 'size',
                        'content', 'start_line', 'end_line', 'total_lines',
                        'lines_returned', 'truncated', 'continuation',
                        'detected_type', 'reference_note', 'binary_note').tap do |result|
        if (integrity = description['integrity'])
          result['integrity'] = integrity['state'] == 'ok' ? { 'state' => 'ok' } : integrity
        end
        result['verified_basis'] = description['verified']['basis'] if description['verified']
      end
    end

    def describe(id, type, revision, key, entry, prefixes)
      source_digest = digest(entry)
      retained_digest = Store.attachment_view_digest(entry)
      { 'digest_prefix' => prefixes.fetch(source_digest),
        'evidence_digest' => "sha256:#{source_digest}",
        'historical_citation' => "#{id}@#{revision}:#{key}",
        'retained_digest' => retained_digest,
        'retained_kind' => entry.is_a?(Hash) && entry['mode'] == 'reference' ? 'reference_pointer' : 'copy',
        'project_locator' => File.join('research', Layout::TYPE_DIRS.fetch(type), id,
                                       Layout::STORE, Layout::OBJECTS, retained_digest),
        'evidence_read' => { 'id' => id, 'revision' => revision, 'attachment' => key } }
    end
  end
end
