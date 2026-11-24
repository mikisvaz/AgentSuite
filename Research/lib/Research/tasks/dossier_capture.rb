# dossier_capture: explicit recovery task for externally edited
# authored documents.
#
# Contract:
# - The caller names the drifted authored document(s) (or asks for
#   all-drifted). The CURRENT OBSERVED BYTES become a new revision.
# - Guarded by BOTH the last managed revision (expected_revision, under
#   the per-dossier lock) AND the observed current digests (recorded in
#   the new revision as what was observed at capture time).
# - REJECTS when retained evidence copies are corrupted: corruption is
#   never laundered into history; the caller must repair or replace the
#   evidence explicitly first.
# - Captured revision = observed END STATE. Intermediate unobserved
#   edits cannot be reconstructed and are not claimed (documented in the
#   result under 'captures').
# - No silent adoption anywhere: ordinary mutations never adopt external
#   edits (Store rejects drift with digests); capture is the ONLY
#   adoption path, and it is explicit and audited.
#
# Relation to Store.restore_views! (documented, not duplicated):
# restore_views! DISCARDS external edits by re-materializing the pinned
# views from the current revision's objects. It is reachable in-process
# only (Store.restore_views!, used by Store's own recovery paths); it is
# NOT exposed as a task. Discarding external work must stay explicit and
# separate from capture; if a discard task is ever exposed, it must carry
# its own guard (expected digests of the pinned state), which is why it
# is deliberately not reachable through this task.

require 'json'
require 'fileutils'
require_relative 'common'
require_relative '../evidence'

module Research
  CAPTURE_DOCUMENTS_MAX = 100

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
  input :documents, :string, "Documents to capture: 'all' (default), a comma/newline list, or a JSON array of document names", nil, nofile: true
  input :change_note, :string, 'Human-readable note recorded with the new revision'
  desc 'Capture externally edited authored documents as a new revision (the only explicit adoption path for drift). Rejects when retained evidence is corrupted.'
  task :dossier_capture do |id, expected_revision, documents, change_note|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)
    dir = Layout.dossier_dir(root, type, id)

    Tasks.reject_placeholder_text!(change_note, 'change note') if change_note

    docs =
      if documents.nil? || documents == 'all' || documents == 'drifted'
        nil # all drifted
      else
        list = Research.parse_capture_documents(documents)
        list.each { |d| Tasks.store_document_name!(d) }
        list
      end

    observed = {}
    result = Tasks.map_store_errors(root, id) do
      Store.transaction(root, type, id,
                        expected_revision: Tasks.int!(
                          expected_revision, 'expected_revision'
                        ),
                        allow_drift: true) do |ctx|
        ctx.change_note = change_note
        current = Store.current_revision(root, type, id)
        record = current['record']

        # Evidence corruption gate: never capture over corrupted
        # retained evidence (the new revision would inherit a broken
        # attachment mapping; corruption must be repaired explicitly).
        Research.capture_evidence_gate!(record, dir)

        drift = Research.capture_drifted_documents(dir, record)
        targets = docs ? docs & drift.keys : drift.keys

        if docs
          missing = docs - drift.keys
          unless missing.empty?
            raise ParameterException,
                  "no drift to capture for #{missing.sort.join(', ')} " \
                  "(expected: #{docs.sort.join(', ')}; drifted: " \
                  "#{drift.keys.sort.join(', ') || 'none'}); capture " \
                  'requires observed external edits (run dossier_check ' \
                  'to see the drift report)'
          end
        end

        if targets.empty?
          raise ParameterException,
                'no drift to capture: no authored document differs ' \
                'from the current revision (capture adopts observed ' \
                'external edits; nothing was observed to change)'
        end

        targets.sort.each do |name|
          bytes = File.binread(Research.capture_view_file(dir, name))
          bytes = bytes.dup.force_encoding('UTF-8')
          unless bytes.valid_encoding?
            raise ParameterException,
                  "document #{name} contains invalid UTF-8 bytes; " \
                  'authored documents are text — capture cannot adopt ' \
                  'binary content (attach it as evidence instead)'
          end
          Tasks.reject_placeholder_text!(bytes, "document #{name}")
          ctx.write_document(name, bytes)
          observed[name] = {
            'observed_digest' => StoreBytes.digest_bytes(bytes),
            'pinned_digest' => record['documents'][name]
          }
        end
      end
    end.reject { |k, _| %w[record record_digest].include?(k) }

    result.merge(
      'id' => id,
      'captured_documents' => observed,
      'change_note' => change_note,
      'capture_semantics' =>
        'the captured revision records the OBSERVED end state of the ' \
        'named documents; intermediate unobserved edits are not ' \
        'reconstructed and not claimed'
    )
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.parse_capture_documents(documents)
    list =
      if documents.is_a?(Array)
        documents.map(&:to_s)
      else
        text = documents.to_s
        begin
          parsed = JSON.parse(text)
          parsed.is_a?(Array) ? parsed.map(&:to_s) : [text]
        rescue JSON::ParserError
          text.split(/[,\n]/).map(&:strip).reject(&:empty?)
        end
      end
    if list.length > CAPTURE_DOCUMENTS_MAX
      raise ParameterException,
            "too many documents to capture (#{list.length}; cap " \
            "#{CAPTURE_DOCUMENTS_MAX}); split the capture"
    end
    list
  end

  # Never capture over corrupted retained evidence: the new revision
  # would inherit a broken attachment mapping. Corruption must be
  # repaired or replaced explicitly, never laundered into history.
  def Research.capture_evidence_gate!(record, dir)
    Evidence.attachment_integrity_findings(record, dir).each do |f|
      next unless f['category'] == 'copy_corrupted'

      raise ParameterException,
            "refusing capture: retained evidence is corrupted " \
            "(#{f['key']}: #{f['detail']}); repair or replace the " \
            'evidence explicitly before capturing document edits ' \
            '(corruption is never laundered into history)'
    end
  end

  def Research.capture_drifted_documents(dir, record)
    actual = Store.view_digests(
      Layout.doc_path(dir), Layout.supplement_dir(dir),
      Layout::DOC, Layout::SUPPLEMENTS
    )
    expected = record['documents'] || {}
    drifted = {}
    (expected.keys | actual.keys).each do |name|
      next if actual[name] == expected[name]

      drifted[name] = { 'observed' => actual[name],
                        'pinned' => expected[name] }
    end
    drifted
  end

  def Research.capture_view_file(dir, name)
    if name == Layout::DOC
      Layout.doc_path(dir)
    else
      File.join(Layout.supplement_dir(dir),
                name.delete_prefix("#{Layout::SUPPLEMENTS}/"))
    end
  end
  export_exec :dossier_capture
end
