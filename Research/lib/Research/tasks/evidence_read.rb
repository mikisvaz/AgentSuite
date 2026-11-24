# evidence_read — read an evidence attachment of a dossier.
#
# Default output: metadata, caption, source identity, retained address,
# and the OBSERVED integrity state. Copies: recompute the digest of the
# retained bytes. References: check the current source's existence and
# digest WITHOUT fetching web content — a reference whose source
# changed or vanished reports 'changed'/'unavailable' and NEVER
# returns changed current bytes as historical evidence.
#
# Text-range reads (start_line/max_lines, one-based, the shared
# convention with dossier_read/dossier_update) are offered for
# appropriate files; binary evidence returns file/media information
# (size, digest, detected type) — no dataframe querying, no byte dumps.
#
# Historical revisions: reading an attachment as of revision N resolves
# the attachment entry from rN's record, so the precise version
# associated at that time is what is served; for a replaced
# attachment the previous version remains reachable through the old
# revision.

require 'json'
require_relative 'common'
require_relative '../evidence'

module Research
  EVIDENCE_READ_MAX_MAX_LINES = 5000

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :attachment, :string, "Attachment key '<slot>/<name>' as returned by dossier overview or evidence_attach", nil, nofile: true
  input :revision, :integer, 'Historical revision of the attachment entry (default: current)'
  input :start_line, :integer, 'First line to return for text evidence (one-based; default 1)', 1
  input :max_lines, :integer, 'Maximum lines to return per call (1..5000; default 500)', 500
  desc 'Read an evidence attachment: metadata, integrity state, and bounded text ranges for text evidence (binary evidence returns file/media info). Never substitutes changed bytes for historical evidence.'
  task :evidence_read do |id, attachment, revision, start_line, max_lines|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)

    if revision && !revision.to_s.strip.empty?
      revision = Tasks.int!(revision, 'revision')
      revision = nil if revision <= 0
    else
      revision = nil
    end

    start_line = Tasks.int!(start_line, 'start_line')
    max_lines = Tasks.int!(max_lines, 'max_lines')
    unless max_lines >= 1 && max_lines <= EVIDENCE_READ_MAX_MAX_LINES
      raise ParameterException,
            "max_lines must be between 1 and #{EVIDENCE_READ_MAX_MAX_LINES} (got #{max_lines})"
    end

    Tasks.map_store_errors(root, id) do
      Research.read_evidence(root, type, id, attachment.to_s, revision,
                    start_line, max_lines)
    end
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.read_evidence(root, type, id, attachment, revision, start_line, max_lines)
    cur = Store.current_revision(root, type, id)
    effective = revision || cur['revision']
    record = if effective == cur['revision']
               cur['record']
             else
               Store.read_revision(cur['dir'], effective)
             end

    atts = record['attachments'] || {}
    entry = atts[attachment]
    unless entry
      raise ParameterException,
            "dossier #{id} revision #{effective} has no evidence " \
            "attachment #{attachment.inspect}; attachments: " \
            "#{atts.keys.sort.inspect}"
    end
    entry = { 'digest' => entry } unless entry.is_a?(Hash)

    dir = cur['dir']
    mode = entry['mode'] || 'copy'
    meta = {
      'id' => id,
      'type' => type,
      'attachment' => attachment,
      'slot' => entry['slot'] || attachment.split('/', 2)[0],
      'name' => entry['name'] || attachment.split('/', 2)[1],
      'revision' => effective,
      'current_revision' => cur['revision'],
      'mode' => mode,
      'caption' => entry['caption'],
      'source' => entry['source'],
      'sha256' => entry['digest'],
      'size' => entry['size'],
      'attached_at' => entry['attached_at'],
      'attach_mode' => entry['attach_mode'] || mode,
      'retained_location' => Layout.object_path(dir, Store.attachment_view_digest(entry))
    }
    entry.each { |k, v| meta[k] = v if k.to_s.start_with?('declared_') }

    if mode == 'reference'
      meta['integrity'] = Evidence.reference_integrity(entry)
      meta['reference_note'] =
        'reference history retains identity/digest only; it does not ' \
        'promise the original external bytes remain recoverable'
      meta['pointer'] = Research.evidence_pointer_text(entry)
      return meta
    end

    # Copy mode: serve bounded text when appropriate, else info.
    begin
      bytes = Store.object_bytes(dir, entry.fetch('digest'))
    rescue Store::Missing => e
      meta['integrity'] = { 'state' => 'unavailable', 'detail' => e.message }
      return meta
    end
    meta['integrity'] = Evidence.digest_integrity(entry['digest'], StoreBytes.digest_bytes(bytes))
    return meta unless meta['integrity']['state'] == 'ok'

    detected = Evidence.detected_type(bytes, entry['name'] || attachment)
    meta['detected_type'] = detected
    meta['media'] = { 'detected_type' => detected }
    ext = File.extname(entry['name'].to_s)
    meta['media']['extension'] = ext unless ext.empty?

    if detected == 'text'
      meta = Research.evidence_text_window(meta, bytes, start_line, max_lines)
    else
      meta['binary_note'] =
        'binary evidence returns file/media information only; use ' \
        'Workspace read tools on retained_location for extraction'
    end
    meta
  end

  def Research.evidence_pointer_text(entry)
    Store.reference_pointer_bytes(entry)
  rescue StandardError
    'pointer unavailable'
  end

  def Research.evidence_text_window(meta, bytes, start_line, max_lines)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    unless text.valid_encoding?
      meta['detected_type'] = 'binary'
      meta['binary_note'] =
        'bytes are not valid UTF-8; treated as binary'
      return meta
    end

    lines = LineEdit.lines(text)
    total = lines.length
    last_returned = [start_line + max_lines - 1, total].min
    if start_line > total + 1 || start_line < 1
      raise ParameterException,
            "start_line #{start_line} out of range: the attachment has " \
            "#{total} line(s); valid start_line is 1..#{total + 1}"
    end

    window = lines[(start_line - 1)...last_returned] || []
    remaining = total - last_returned
    meta.merge(
      'total_lines' => total,
      'start_line' => start_line,
      'end_line' => [last_returned, total].min,
      'lines_returned' => window.length,
      'content' => window.join,
      'continuation' => remaining.positive? ? (last_returned + 1).to_s : nil,
      'truncated' => remaining.positive?
    )
  end
  export_exec :evidence_read
end
