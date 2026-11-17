# dossier_update — revisioned edits to authored documents.
#
# Three modes share one commit path through the Store transaction:
#
#   create_document   write a new supplements/<name> document (never the
#                     entry document, which always exists);
#   replace_document  whole-document replacement (title/heading changes,
#                     substantial rewrites);
#   replace_lines     one-based half-open [start_line, end_line) span
#                     edit composed through the PURE LineEdit module
#                     (the composition wrapper lives here in the task
#                     layer, never in line_edit.rb).
#
# NO Markdown parsing, no regexp selectors, no character selectors, no
# unified patches — the caller states spans and literal text only.
#
# Optimistic concurrency: expected_revision must equal the current
# pointer under the per-dossier lock, otherwise the mutation is
# rejected (StaleRevision) and nothing is written. A no-op edit (same
# document bytes AND same attachment inventory) creates NO revision.
# Byte-preservation outside the edited span is exact (LineEdit contract,
# pinned by test/Research/line_edit/test_line_edit.rb).

require_relative 'common'

module Research
  # delete_lines is the explicit form of replace_lines with an empty
  # replacement: model tool layers commonly coerce '' to "absent"
  # (scout-ai rejects empty-string parameters before the task runs),
  # which would make deletion unreachable through that surface.
  UPDATE_MODES = %w[create_document replace_document replace_lines delete_lines].freeze

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
  input :mode, :select, 'Update mode: create_document, replace_document, replace_lines or delete_lines', nil, select_options: %w[create_document replace_document replace_lines delete_lines]
  input :document, :string, "Target authored document: 'README.md' (default) or 'supplements/<name>'", 'README.md', nofile: true
  input :content, :text, 'New document content for create_document / replace_document'
  input :replacement, :text, 'Replacement text for the one-based half-open span [start_line, end_line)'
  input :start_line, :integer, 'First line of the edited span (one-based)'
  input :end_line, :integer, 'End of the edited span (exclusive); nil means through end of document'
  input :change_note, :string, 'Human-readable note recorded with the new revision'
  desc 'Apply revisioned edits to authored documents: create, replace or line-span edit. Optimistic concurrency on expected_revision; no-op edits create no revision.'
  task :dossier_update do |id, expected_revision, mode, document, content, replacement, start_line, end_line, change_note|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)
    name = Tasks.store_document_name!(document)

    expected = Tasks.int!(expected_revision, 'expected_revision')
    mode = mode.to_s
    unless UPDATE_MODES.include?(mode)
      raise ParameterException,
            "unknown update mode #{mode.inspect}; modes are #{UPDATE_MODES.join(', ')}"
    end
    Tasks.reject_placeholder_text!(change_note, 'change_note') unless change_note.nil?
    Tasks.reject_placeholder_text!(content, 'content') unless content.nil?
    Tasks.reject_placeholder_text!(replacement, 'replacement') unless replacement.nil?

    result = Tasks.map_store_errors(root, id) do
      Store.transaction(root, type, id, expected_revision: expected) do |ctx|
        ctx.change_note = change_note
        Research.apply_update(ctx, id, name, mode, content, replacement,
                     start_line, end_line)
      end
    end

    {
      'id' => id,
      'type' => type,
      'document' => Tasks.public_document_name(name),
      'mode' => mode,
      'changed' => result['changed'],
      'revision' => result['revision'],
      'previous_revision' => result['changed'] ? expected : result['revision'],
      'change_summary' => Research.update_summary(name, mode, result, content, replacement),
      'change_note' => change_note.to_s
    }
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.apply_update(ctx, id, name, mode, content, replacement, start_line, end_line)
    case mode
    when 'create_document'
      if name == Layout::DOC
        raise ParameterException,
              'create_document cannot target the entry document; it always ' \
              "exists — use replace_document on '#{Tasks.public_document_name(Layout::DOC)}' " \
              "or create documents under #{Layout::SUPPLEMENTS}/"
      end
      raise ParameterException, 'content is required for create_document' if content.nil?

      ctx.write_document(name, content.to_s)
    when 'replace_document'
      raise ParameterException, 'content is required for replace_document' if content.nil?

      ctx.write_document(name, content.to_s)
    when 'replace_lines'
      Research.update_lines(ctx, id, name, replacement, start_line, end_line)
    when 'delete_lines'
      # A delete must not silently swallow a supplied replacement.
      unless replacement.nil?
        raise ParameterException,
              'replacement must be omitted for delete_lines; it deletes ' \
              'the one-based half-open span [start_line, end_line)'
      end
      Research.update_lines(ctx, id, name, '', start_line, end_line)
    end
  end

  # The line-edit composition wrapper. Reads the CURRENT staged bytes
  # for the document (which for an untouched document equal the current
  # revision's bytes), applies the pure LineEdit.edit with one-based
  # half-open semantics, and stages the result. LineEdit raises
  # RangeError/EncodingError before anything is staged, so a rejected
  # span leaves the store untouched.
  def Research.update_lines(ctx, id, name, replacement, start_line, end_line)
    if replacement.nil?
      raise ParameterException, 'replacement is required for replace_lines'
    end
    start_line = Tasks.int!(start_line, 'start_line')
    end_line = Tasks.int!(end_line, 'end_line')

    digests = ctx.staged_documents
    unless digests.key?(name)
      raise ParameterException,
            "dossier #{id} has no document " \
            "#{Tasks.public_document_name(name).inspect}; create it first " \
            'with mode create_document'
    end

    bytes = ctx.staged_document_bytes[name] ||
            Store.object_bytes(ctx.dir, ctx.current_record, name)
    text = bytes.dup.force_encoding(Encoding::UTF_8)

    new_text = LineEdit.edit(text, start_line, end_line, replacement.to_s)
    ctx.write_document(name, new_text)
  end

  def Research.update_summary(name, mode, result, content, replacement)
    return 'no change' unless result['changed']

    case mode
    when 'create_document'
      "created #{Tasks.public_document_name(name)} (#{content.to_s.bytesize} bytes)"
    when 'replace_document'
      "replaced #{Tasks.public_document_name(name)} (#{content.to_s.bytesize} bytes)"
    when 'replace_lines'
      "edited #{Tasks.public_document_name(name)} (replacement " \
        "#{replacement.to_s.bytesize} bytes)"
    end
  end
  export_exec :dossier_update
end
