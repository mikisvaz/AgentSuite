# dossier_update — revisioned edits to authored documents.
#
# Four modes share one commit path through the Store transaction:
#
#   create_document   write a new supplements/<name> document (never the
#                     entry document, which always exists);
#   replace_document  whole-document replacement (title/heading changes,
#                     substantial rewrites);
#   replace_lines     one-based half-open [start_line, end_line) span
#                     edit composed through the PURE LineEdit module
#                     (the composition wrapper lives here in the task
#                     layer, never in line_edit.rb); end_line is
#                     required — to edit through end of document pass
#                     end_line = total_lines + 1;
#   delete_lines      delete a span (end_line required, same rule) —
#                     the explicit form of replace_lines with an empty
#                     replacement (model tool layers commonly coerce ''
#                     to "absent", which would make deletion unreachable
#                     through that surface).
#
# NO Markdown parsing, no regexp selectors, no character selectors, no
# unified patches — the caller states spans and literal text only.
#
# Parameter contract (ONE pass, BEFORE the store transaction opens):
# each mode's required and forbidden inputs are validated together and
# reported in ONE message ("mode replace_lines requires replacement,
# start_line, end_line; missing: end_line; unexpected: content"), so a
# caller assembling a call learns the whole shape at once instead of
# discovering one omission per failed dispatch. A missing/empty mode is
# a MISSING parameter, never an invalid value.
#
# Content anchoring: the optional `anchor` is the exact text the caller
# believes currently occupies [start_line, end_line). It is compared
# with the live span BEFORE anything is staged. Line numbers go stale
# the moment any earlier edit lands (every edit shifts later lines),
# and expected_revision only guards concurrent commits — the anchor
# turns a mis-anchored span into a loud rejection instead of a spliced
# document. The anchor verifies the CURRENT TEXT of the stated span
# only: it cannot distinguish identical text at different positions
# (both match), and an empty span anchors against "" — an empty anchor
# always matches, so insertions get NO position protection from it.
# Pass the span text from the read that established the line numbers.
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

  # Per-mode parameter contract, validated in one pass before the store
  # transaction opens (see header). Only nil counts as absent: an empty
  # string is a present value (replace_lines deletes via
  # replacement: ''). `end_line` is REQUIRED for the line modes — there
  # is NO implicit end-of-document (an accidentally omitted end_line
  # must not become a destructive edit); to edit through end of document
  # pass end_line = total_lines + 1 (total_lines comes from the read).
  # `anchor` is accepted wherever a span is
  # addressed, deletions included: the text about to be removed is
  # exactly as worth anchoring as the text about to be rewritten.
  UPDATE_INPUT_CONTRACT = {
    'create_document' => {
      'required' => %w[content],
      'forbidden' => %w[replacement anchor start_line end_line]
    },
    'replace_document' => {
      'required' => %w[content],
      'forbidden' => %w[replacement anchor start_line end_line]
    },
    'replace_lines' => {
      'required' => %w[replacement start_line end_line],
      'forbidden' => %w[content]
    },
    'delete_lines' => {
      'required' => %w[start_line end_line],
      'forbidden' => %w[content replacement]
    }
  }.freeze

  # Anchor quotes in error messages are truncated so one long span
  # cannot flood the transcript; the marker keeps that fact visible.
  ANCHOR_QUOTE_LIMIT = 160

  # Result-payload echo bounds (D4): context excerpt size and per-line
  # truncation for the after-state shown on every line-mode edit.
  CONTEXT_BEFORE = 2
  CONTEXT_AFTER = 2
  CONTEXT_SPAN = 3
  CONTEXT_LINE_LIMIT = 160

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
  input :mode, :select, 'Update mode: create_document, replace_document, replace_lines or delete_lines', nil, select_options: %w[create_document replace_document replace_lines delete_lines]
  input :document, :string, "Target authored document: 'README.md' (default) or 'supplements/<name>'", 'README.md', nofile: true
  input :content, :text, 'New document content for create_document / replace_document'
  input :replacement, :text, 'Replacement text for the one-based half-open span [start_line, end_line)'
  input :start_line, :integer, 'First line of the edited span (one-based)'
  input :end_line, :integer, 'End of the edited span (exclusive); required for replace_lines and delete_lines — to edit through end of document pass total_lines + 1 from the read'
  input :anchor, :text, 'Optional content anchor: the exact text currently occupying [start_line, end_line); a mismatch rejects the edit before anything is staged, guarding against stale line numbers. Verifies the CURRENT TEXT of the stated span only — identical text at another position also matches, and an empty span anchors against "" (no position protection for insertions)'
  input :change_note, :string, 'Human-readable note recorded with the new revision'
  desc 'Apply revisioned edits to authored documents: create, replace or line-span edit. Optimistic concurrency on expected_revision; optional anchor verifies the addressed span first; no-op edits create no revision.'
  task :dossier_update do |id, expected_revision, mode, document, content, replacement, start_line, end_line, anchor, change_note|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)
    name = Tasks.store_document_name!(document)

    expected = Tasks.int!(expected_revision, 'expected_revision')
    mode = Research.validate_update_mode!(mode)
    Research.validate_update_inputs!(mode, 'content' => content,
                                     'replacement' => replacement,
                                     'anchor' => anchor,
                                     'start_line' => start_line,
                                     'end_line' => end_line)
    Tasks.reject_placeholder_text!(change_note, 'change_note') unless change_note.nil?
    Tasks.reject_placeholder_text!(content, 'content') unless content.nil?
    Tasks.reject_placeholder_text!(replacement, 'replacement') unless replacement.nil?

    result = Tasks.map_store_errors(root, id) do
      Store.transaction(root, type, id, expected_revision: expected) do |ctx|
        ctx.change_note = change_note
        Research.apply_update(ctx, id, name, mode, content, replacement,
                              anchor, start_line, end_line)
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
    }.merge(Research.echo_fields(result, mode))
  end

  # Line-mode after-state echo (D4): merged into the payload only for
  # the line modes, and only when the store path produced it (rejected
  # dispatches never reach here; document modes have no span to echo).
  def Research.echo_fields(result, mode)
    return {} unless %w[replace_lines delete_lines].include?(mode)

    echo = result['update_echo']
    echo ? { 'update_echo' => echo } : {}
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  # mode gate. A missing or blank mode is a MISSING parameter — the old
  # `mode.to_s` coercion reported nil as the invalid value "" and sent
  # callers hunting a value problem. A non-empty unknown value keeps the
  # value-shaped message, so typos are still reported as values.
  def Research.validate_update_mode!(mode)
    mode = mode.to_s
    if mode.strip.empty?
      raise ParameterException,
            "mode is required; one of: #{UPDATE_MODES.join(', ')}"
    end
    unless UPDATE_MODES.include?(mode)
      raise ParameterException,
            "unknown update mode #{mode.inspect}; modes are #{UPDATE_MODES.join(', ')}"
    end
    mode
  end

  # One-pass per-mode parameter contract: every missing required input
  # and every present forbidden input is reported in ONE message, before
  # the store transaction opens (so a rejected call has no side effects
  # at all). nil is absent; '' is a present value.
  def Research.validate_update_inputs!(mode, params)
    contract = UPDATE_INPUT_CONTRACT.fetch(mode)
    missing = contract['required'].select { |p| params[p].nil? }
    unexpected = contract['forbidden'].select { |p| !params[p].nil? }
    return if missing.empty? && unexpected.empty?

    message = +"mode #{mode} requires #{contract['required'].join(', ')}"
    message << "; missing: #{missing.join(', ')}" unless missing.empty?
    message << "; unexpected: #{unexpected.join(', ')}" unless unexpected.empty?
    raise ParameterException, message
  end

  def Research.apply_update(ctx, id, name, mode, content, replacement, anchor, start_line, end_line)
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
      Research.update_lines(ctx, id, name, replacement, anchor, start_line, end_line)
    when 'delete_lines'
      # A delete must not silently swallow a supplied replacement.
      unless replacement.nil?
        raise ParameterException,
              'replacement must be omitted for delete_lines; it deletes ' \
              'the one-based half-open span [start_line, end_line)'
      end
      Research.update_lines(ctx, id, name, '', anchor, start_line, end_line)
    end
  end

  # The line-edit composition wrapper. Reads the CURRENT staged bytes
  # for the document (which for an untouched document equal the current
  # revision's bytes), applies the pure LineEdit.edit with one-based
  # half-open semantics, and stages the result. LineEdit raises
  # RangeError/EncodingError before anything is staged, so a rejected
  # span leaves the store untouched.
  #
  # NEWLINE NORMALIZATION (task layer; LineEdit stays pure and
  # byte-exact): when a NON-EMPTY tail follows the span and the
  # replacement is non-empty and does not end with a line terminator,
  # the adjacent terminator is appended — reusing the terminator of the
  # last removed line (or of head's last line for insertions), default
  # "\n" — so a replacement lacking its trailing break cannot splice
  # onto the first surviving tail line. When the tail is empty (span at
  # EOF) NOTHING is normalized: bytes are preserved exactly.
  #
  # The result payload carries the after-state every caller needs to
  # SEE what landed: total_lines (after), lines_removed,
  # lines_inserted, newline_normalized and a compact context excerpt
  # (up to 2 lines before and after the span plus the first lines of
  # the new span, each truncated with a marker) — so a wrong-span edit
  # is visible in the success payload itself, not only after a re-read.
  # anchor, when given, must equal the live span text or the edit is
  # rejected before anything is staged.
  def Research.update_lines(ctx, id, name, replacement, anchor, start_line, end_line)
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

    n = LineEdit.count(text)

    unless anchor.nil?
      observed = LineEdit.span(text, start_line, end_line)
      unless observed == anchor
        raise ParameterException, Research.anchor_mismatch_message(
          id, name, start_line, end_line, observed, anchor, n
        )
      end
    end

    replacement = replacement.to_s
    selected = LineEdit.span(text, start_line, end_line)
    removed_count = selected.empty? ? 0 : LineEdit.count(selected)

    all_lines = LineEdit.lines(text)
    tail_lines = all_lines[end_line - 1..] || []
    tail_empty = tail_lines.empty?
    terminator = if selected.empty?
                   # insertion: reuse head's terminator when it has one
                   Research.terminator_of(all_lines[0, start_line - 1].last)
                 else
                   # reuse the terminator of the last removed line
                   Research.terminator_of(all_lines[end_line - 2])
                 end

    normalized = false
    effective = replacement
    if !tail_empty && !replacement.empty? && !replacement.end_with?("\n")
      effective = replacement + terminator
      normalized = true
    end

    new_text = LineEdit.edit(text, start_line, end_line, effective)
    ctx.write_document(name, new_text)

    ctx.update_echo = Research.line_edit_echo(
      new_text, start_line, end_line, removed_count, effective, normalized,
      tail_empty
    )
  end

  # terminator_of(last_line) -> the terminator the line ends with, or
  # "\n" for an unterminated final line (the only lines that lack one).
  def Research.terminator_of(line)
    return "\n" unless line
    return "\r\n" if line.end_with?("\r\n")
    return "\n" if line.end_with?("\n")

    "\n"
  end

  # Compact after-state excerpt for the update payload: up to
  # CONTEXT_BEFORE/CONTEXT_AFTER surviving lines around the new span
  # plus the first CONTEXT_SPAN lines of the inserted text, each line
  # truncated to CONTEXT_LINE_LIMIT characters with an explicit marker.
  # Shows a wrong-span edit (retained old text) in the success payload.
  def Research.line_edit_echo(new_text, start_line, end_line, removed_count,
                              effective, normalized, tail_empty)
    lines = LineEdit.lines(new_text)
    inserted = effective.empty? ? 0 : LineEdit.count(effective)
    new_end = start_line + inserted

    context = []
    before_start = [start_line - CONTEXT_BEFORE, 1].max
    (before_start...start_line).each do |ln|
      context << format('  %d: %s', ln, Research.excerpt_line(lines[ln - 1]))
    end
    first_new = [start_line, 1].max
    last_new = [new_end - 1, lines.length].min
    (first_new..last_new).first(CONTEXT_SPAN).each do |ln|
      next unless lines[ln - 1]

      context << format('+ %d: %s', ln, Research.excerpt_line(lines[ln - 1]))
    end
    after_start = [new_end, 1].max
    after_end = [after_start + CONTEXT_AFTER - 1, lines.length].min
    (after_start..after_end).each do |ln|
      next unless lines[ln - 1]

      context << format('  %d: %s', ln, Research.excerpt_line(lines[ln - 1]))
    end

    { 'total_lines' => lines.length,
      'lines_removed' => removed_count,
      'lines_inserted' => inserted,
      'newline_normalized' => normalized,
      'tail_after_span' => tail_empty ? 'none (span at end of document)' : 'present',
      'context' => context }
  end

  def Research.excerpt_line(line, limit = CONTEXT_LINE_LIMIT)
    line = line.to_s
    stripped = line.sub(/\r?\n\z/, '')
    return stripped if stripped.length <= limit

    "#{stripped[0, limit]}… (#{stripped.length - limit} more characters)"
  end

  # Anchor-mismatch message: quotes the observed span and the expected
  # anchor (truncated when long), the span bounds and the current line
  # count, so the caller can re-anchor from this one rejection without
  # guessing which lines moved. The remedy is re-read + corrected span:
  # it deliberately does NOT suggest omitting the anchor (positional
  # editing is what corrupted the document in the v3 run).
  def Research.anchor_mismatch_message(id, name, start_line, end_line, observed, anchor, line_count)
    "anchor mismatch in #{Tasks.public_document_name(name).inspect} of " \
      "dossier #{id}: lines [#{start_line}, #{end_line}) currently read " \
      "#{Research.truncate_for_error(observed)} but the anchor was " \
      "#{Research.truncate_for_error(anchor)} " \
      "(document has #{line_count} line(s)); the document changed since " \
      'it was read — re-read the document, then retry with the corrected ' \
      'span and an anchor quoting the text you intend to replace'
  end

  def Research.truncate_for_error(text, limit = ANCHOR_QUOTE_LIMIT)
    text = text.to_s
    return text.inspect if text.length <= limit

    "#{text[0, limit].inspect} (…#{text.length - limit} more characters)"
  end

  def Research.update_summary(name, mode, result, content, replacement)
    return 'no change' unless result['changed']

    case mode
    when 'create_document'
      "created #{Tasks.public_document_name(name)} (#{content.to_s.bytesize} bytes)"
    when 'replace_document'
      "replaced #{Tasks.public_document_name(name)} (#{content.to_s.bytesize} bytes)"
    when 'replace_lines', 'delete_lines'
      echo = result['update_echo']
      base = mode == 'replace_lines' ?
               "edited #{Tasks.public_document_name(name)} (replacement " \
               "#{replacement.to_s.bytesize} bytes" :
               "deleted span from #{Tasks.public_document_name(name)}"
      detail = if echo
                 if mode == 'replace_lines'
                   "; lines #{echo['lines_removed']} out, " \
                     "#{echo['lines_inserted']} in, document now " \
                     "#{echo['total_lines']} lines" +
                     (echo['newline_normalized'] ? '; trailing newline normalized' : '')
                 else
                   ": #{echo['lines_removed']} line(s), document now " \
                     "#{echo['total_lines']} lines"
                 end
               else
                 ''
               end
      mode == 'replace_lines' ? base + detail + ')' : base + detail
    end
  end
  export_exec :dossier_update
end
