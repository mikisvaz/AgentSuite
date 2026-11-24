# evidence_attach — attach evidence files to a dossier (copy/reference).
#
# Batch-atomic: all items stage inside ONE Store transaction, so one
# invalid item rolls back the whole batch (the dossier stays at its
# prior revision; Store commit semantics make interruption-safe
# rollback the default). Each item:
#
#   source      — path of the evidence file (authorized for reading
#                 through the actual sandbox grant policy; NEVER a
#                 permission grant by itself)
#   slot        — evidence area inside the dossier (e.g. 'data')
#   name        — attachment file name (default: source basename)
#   mode        — 'copy' (default: exact bytes retained in the
#                 content-addressed store; digest computed from the
#                 RETAINED bytes) or 'reference' (authorized source
#                 identity + observed digest retained; the evidence
#                 view is a deterministic pointer file, never a
#                 symlink)
#   caption     — optional prose caption
#   script/parameters/inputs/receipt — agent-DECLARED production
#                 metadata, recorded as declared_* only; declaring a
#                 script does not verify it produced the bytes
#   replace     — true to replace an existing attachment at the same
#                 slot/name; accidental collisions FAIL otherwise
#
# Declared vs verified are separate fields by construction: the result
# echoes every declared_* key verbatim and provides 'verified' only
# for what was actually checked (digest of retained/observed bytes).
#
# No scientific semantics: an attachment never assigns validity,
# support, contradiction or strength.

require 'json'
require 'time'
require_relative 'common'
require_relative '../evidence'

module Research
  ATTACH_BATCH_CAP = 100

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
  input :items, :text, 'JSON array of attachment items: source (absolute path, or relative resolved against the working project), slot, name, mode (copy|reference), caption, replace, and declared script/parameters/inputs/receipt. mode "reference" retains NO source bytes — only the source identity plus the digest observed at attach time, with integrity re-checked against the live source on every later read — so use mode "copy" whenever the bytes themselves must be retained durably'
  input :change_note, :string, 'Human-readable note recorded with the new revision'
  desc 'Attach evidence files (copy or reference mode) to a dossier. Batch-atomic: one invalid item rolls back the whole batch. Returns per-item retained locations and digests.'
  task :evidence_attach do |id, expected_revision, items, change_note|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)
    expected = Tasks.int!(expected_revision, 'expected_revision')

    Tasks.reject_placeholder_text!(change_note, 'change_note')

    parsed = Research.parse_attach_items!(items)
    if parsed.empty?
      raise ParameterException, 'items must contain at least one attachment'
    end
    if parsed.length > ATTACH_BATCH_CAP
      raise ParameterException,
            "too many attachments in one batch (#{parsed.length}; cap " \
            "#{ATTACH_BATCH_CAP}); split the batch into multiple calls and " \
            're-pass the new revision each time'
    end

    keys = parsed.map { |item| [item['slot'], item['name']] }
    unless keys.uniq.size == keys.size
      raise ParameterException, 'items: duplicate attachment keys in one batch'
    end

    attached_at = Time.now.utc.iso8601

    per_item = parsed.map { |item| Research.prepare_attach_item(item) }

    result = Tasks.map_store_errors(root, id) do
      Store.transaction(root, type, id, expected_revision: expected) do |ctx|
        ctx.change_note = change_note
        per_item.each do |prepared|
          Research.stage_attach_item!(ctx, prepared, attached_at)
        end
      end
    end

    items_out = per_item.map do |prepared|
      Research.describe_attach_item(prepared, result, root, type, attached_at)
    end

    {
      'id' => id,
      'type' => type,
      'revision' => result['revision'],
      'changed' => result['changed'],
      'items' => items_out,
      'warnings' => [],
      'change_note' => change_note
    }
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.parse_attach_items!(items)
    case items
    when Array
      items.each_with_index.map { |raw, i| Evidence.parse_item!(raw, i) }
    when String
      parsed = begin
        JSON.parse(items)
      rescue JSON::ParserError => e
        raise ParameterException,
              "items must be a JSON array (parse error: #{e.message})"
      end
      raise ParameterException, 'items must be a JSON array' unless parsed.is_a?(Array)

      parsed.each_with_index.map { |raw, i| Evidence.parse_item!(raw, i) }
    else
      raise ParameterException,
            "items must be an array of attachment items (got #{items.class})"
    end
  end

  # Resolve authorization, classify, and acquire BEFORE the
  # transaction opens (fail fast, nothing staged on rejection).
  def Research.prepare_attach_item(item)
    canonical = Evidence.authorize_read!(item['source'])

    if item['mode'] == 'reference'
      Evidence.validate_reference!(item['source'], canonical)
      stat = File.stat(canonical)
      observed = StoreBytes.digest(canonical)
      item.merge('canonical' => canonical,
                 'digest' => observed,
                 'size' => stat.size)
    else
      acquired = Evidence.acquire_copy!(canonical)
      item.merge('canonical' => canonical,
                 'bytes' => acquired['bytes'],
                 'digest' => acquired['digest'],
                 'size' => acquired['observed_size'])
    end
  end

  def Research.stage_attach_item!(ctx, prepared, attached_at)
    slot = prepared['slot']
    name = prepared['name']
    key = "#{slot}/#{name}"

    committed = (ctx.current_record['attachments'] || {})[key]
    existing = committed || ctx.staged_attachments.key?(key)
    if existing && !prepared['replace']
      raise ParameterException,
            "items: evidence #{key.inspect} already exists in this " \
            'dossier; accidental collisions fail — pass replace: true ' \
            'to replace it explicitly (history keeps the previous ' \
            'attachment at old revisions)'
    end
    ctx.drop_attachment!(slot, name) if existing && prepared['replace']

    meta = Research.attach_meta(prepared, attached_at)

    if prepared['mode'] == 'reference'
      ctx.attach_reference(slot, name, meta)
    else
      ctx.attach_evidence(slot, name, prepared['bytes'], meta: meta)
    end
  end

  # Revision-record entry: carries mode, source identity, caption,
  # declared_* fields, and the OBSERVED/RETAINED digest.
  def Research.attach_meta(prepared, attached_at)
    meta = {
      'slot' => prepared['slot'],
      'name' => prepared['name'],
      'source' => prepared['canonical'],
      'caption' => prepared['caption'],
      'note' => prepared['note'],
      'digest' => prepared['digest'],
      'size' => prepared['size'],
      'attached_at' => attached_at,
      'attach_mode' => prepared['mode']
    }
    prepared['declared'].each do |k, v|
      meta["declared_#{k}"] = v
    end
    meta
  end

  def Research.describe_attach_item(prepared, result, root, type, attached_at)
    slot = prepared['slot']
    name = prepared['name']
    key = "#{slot}/#{name}"
    dir = Layout.dossier_dir(root, type, result['id'])
    entry = result.fetch('attachments').fetch(key)
    retained = Layout.object_path(dir, Store.attachment_view_digest(entry))

    item = {
      'attachment' => key,
      'evidence_read' => { 'id' => result['id'], 'revision' => result['revision'], 'attachment' => key },
      'id' => "#{result['id']}@#{result['revision']}:#{key}",
      'revision' => result['revision'],
      'slot' => slot,
      'name' => name,
      'mode' => prepared['mode'],
      'source' => prepared['canonical'],
      'sha256' => prepared['digest'],
      'size' => prepared['size'],
      'attached_at' => attached_at,
      'caption' => prepared['caption'],
      'retained_location' => retained,
      'link' => "[#{key}](#{retained})",
      'citation' => "#{result['record']}##{prepared['digest']}",
      'verified' => {
        'digest' => prepared['digest'],
        'basis' => prepared['mode'] == 'reference' ? 'observed source bytes at attach time' : 'retained bytes'
      }
    }
    prepared['declared'].each do |k, v|
      item["declared_#{k}"] = v
    end
    item
  end
  export_exec :evidence_attach
end
