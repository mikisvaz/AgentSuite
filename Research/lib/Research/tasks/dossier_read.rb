# dossier_read — bounded text-document reads of a dossier.
#
# Reads authored text documents (README.md by default, supplements/*
# by name) at the current revision or an explicit historical revision.
# Returns raw text SEPARATELY from line-number metadata so callers
# never write labels back into documents.
#
# Overview mode returns the entry document plus the attachment
# inventory (names, sizes, digests — never attachment bytes). Reading
# evidence binaries as a text document is REJECTED: they are not text
# documents, and evidence_read owns their serving; the rejection
# message points there.
#
# Line semantics are one-based, exactly the LineEdit counting rule the
# update path uses (dossier_read and dossier_update share them). The
# read payload carries everything a later edit needs to anchor itself:
# pass the span text from the read as dossier_update's `anchor` — line
# numbers go stale as soon as any earlier edit lands, and the anchor
# turns a stale span into a clean rejection instead of a mis-anchored
# edit (the header of dossier_update.rb explains the contract). The
# anchor verifies the current text of the stated span only: it cannot
# distinguish identical text at two different positions, and an empty
# span's anchor is always empty (no position protection for
# insertions).

require_relative 'common'

module Research
  READ_DEFAULT_MAX_LINES = 500
  READ_MAX_MAX_LINES = 5000

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :document, :string, "Authored text document to read: 'README.md' (default) or 'supplements/<name>'", 'README.md', nofile: true
  input :revision, :integer, 'Historical revision to read (default: current)'
  input :overview, :boolean, 'Compact overview mode: entry document metadata plus attachment inventory', false
  input :start_line, :integer, 'First line to return (one-based; default 1)', 1
  input :max_lines, :integer, 'Maximum lines to return per call (1..5000; default 500)', 500
  desc 'Read authored text documents of a dossier with bounded ranges and continuation. Raw text is returned separately from line-number metadata. Evidence binaries are rejected here.'
  task :dossier_read do |id, document, revision, overview, start_line, max_lines|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)

    overview = Tasks.truthy?(overview)
    if revision && !revision.to_s.strip.empty?
      revision = Tasks.int!(revision, 'revision')
      revision = nil if revision <= 0
    else
      revision = nil
    end

    Tasks.map_store_errors(root, id) do
      cur = Store.current_revision(root, type, id)
      effective = revision || cur['revision']
      record = effective == cur['revision'] ? cur['record'] : Store.read_revision(cur['dir'], effective)
      if overview
        Research.read_overview(cur, record, effective, type, id)
      else
        Research.read_document(cur, record, effective, type, id, document, start_line, max_lines)
      end
    end
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.read_document(cur, record, effective, type, id, document, start_line, max_lines)
    name = Tasks.store_document_name!(document)
    Tasks.reject_placeholder_text!(document, 'document')

    start_line = Tasks.int!(start_line, 'start_line')
    max_lines = Tasks.int!(max_lines, 'max_lines')
    unless max_lines >= 1 && max_lines <= READ_MAX_MAX_LINES
      raise ParameterException,
            "max_lines must be between 1 and #{READ_MAX_MAX_LINES} (got #{max_lines})"
    end

    digests = record['documents'] || {}
    unless digests.key?(name)
      raise ParameterException,
            "dossier #{id} revision #{effective} has no document " \
            "#{Tasks.public_document_name(name).inspect}; authored documents: " \
            "#{digests.keys.map { |n| Tasks.public_document_name(n) }.sort.inspect}"
    end

    bytes = Store.object_bytes(cur['dir'], digests.fetch(name))
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    unless text.valid_encoding?
      raise ParameterException,
            "document #{Tasks.public_document_name(name).inspect} of #{id} " \
            'is not valid UTF-8 text; evidence binaries are not text documents'
    end

    lines = LineEdit.lines(text)
    total = lines.length
    last_returned = [start_line + max_lines - 1, total].min

    if start_line > total + 1 || start_line < 1
      raise ParameterException,
            "start_line #{start_line} out of range: the document has " \
            "#{total} line(s); valid start_line is 1..#{total + 1} " \
            '(one-based; start_line == total+1 is the empty continuation)'
    end

    window = lines[(start_line - 1)...last_returned] || []
    remaining = total - last_returned

    {
      'id' => id,
      'type' => type,
      'document' => Tasks.public_document_name(name),
      'revision' => effective,
      'current_revision' => cur['revision'],
      'total_lines' => total,
      'start_line' => start_line,
      'end_line' => [last_returned, total].min,
      'lines_returned' => window.length,
      'content' => window.join,
      'continuation' => remaining.positive? ? (last_returned + 1).to_s : nil,
      'truncated' => remaining.positive?
    }
  end

  # Compact overview: entry document (bounded) plus inventory of
  # authored documents and evidence attachments (metadata only).
  def Research.read_overview(cur, record, effective, type, id)
    dir = cur['dir']

    docs = (record['documents'] || {}).keys.sort.map do |n|
      { 'name' => Tasks.public_document_name(n) }
    end

    atts = (record['attachments'] || {}).keys.sort.map do |key|
      info = record['attachments'][key]
      slot, name = key.split('/', 2)
      {
        'slot' => slot,
        'name' => name,
        'digest' => info.is_a?(Hash) ? info['digest'] : info,
        'size' => info.is_a?(Hash) ? info['size'] : nil
      }
    end

    entry = record['documents'] && record['documents'][Layout::DOC]
    entry_meta = nil
    if entry
      bytes = Store.object_bytes(dir, entry)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      entry_meta = {
        'name' => Tasks.public_document_name(Layout::DOC),
        'title' => Tasks.title_of(text),
        'total_lines' => LineEdit.count(text),
        'digest' => StoreBytes.digest_bytes(bytes)
      }
    end

    {
      'id' => id,
      'type' => type,
      'revision' => effective,
      'current_revision' => cur['revision'],
      'entry_document' => entry_meta,
      'documents' => docs,
      'attachments' => atts
    }
  end
  export_exec :dossier_read
end
