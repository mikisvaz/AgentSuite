# dossier_history: revision inventory browser plus optional text diff
# of one authored document between two revisions.
#
# Contract: returns revision numbers, timestamps, change notes,
# per-revision document set and attachment IDENTITIES (digests). NO
# binary content ever appears in the output; historical authored
# content is read through dossier_read; historical attachment bytes
# through evidence_read (pointer text for references, retained bytes
# for copies). The diff is a clearly-labeled line diff with one-based
# line references consistent with dossier_read/update.
#
# No mutations; uses the store's immutable revision records only.

require 'json'
require_relative 'common'
require_relative '../evidence'

module Research
  HISTORY_DIFF_MAX_LINES = 2000

  input :id, :string, 'Dossier id, e.g. Q-001'
  input :limit, :integer, 'Maximum revisions per page (default 100)', 100
  input :continuation, :string, 'Continuation token from a previous page'
  input :diff_document, :string, "When set, produce a line diff of this document between from_revision and to_revision ('README.md' or 'supplements/<name>')"
  input :from_revision, :integer, 'Diff start revision (default: first revision)'
  input :to_revision, :integer, 'Diff end revision (default: current revision)'
  desc 'Browse the immutable revision inventory of a dossier: revisions, timestamps, change notes, document and attachment identities; optional line diff of one document between two revisions.'
  task :dossier_history do |id, limit, continuation, diff_document, from_revision, to_revision|
    root = Tasks.store_root
    type, = Tasks.parse_id!(id)
    dir = Layout.dossier_dir(root, type, id)
    limit = Tasks.int!(limit, 'limit')
    raise ParameterException, 'limit must be positive' unless limit >= 1

    limit = 1000 if limit > 1000

    current = Store.current_revision(root, type, id)

    revision_files = Dir.glob(File.join(Layout.history_dir(dir), 'r*.json'))
    all = revision_files.map { |p| File.basename(p)[/\d+/].to_i }.sort
    offset = continuation.to_s.match?(/\A\d+\z/) ? continuation.to_i : 0
    page = all.reverse[offset, limit] || []

    entries = page.map { |n| Research.describe_revision(root, type, id, n, current) }

    out = { 'id' => id, 'current_revision' => current['revision'],
            'total_revisions' => all.length,
            'revisions' => entries }

    if diff_document
      out.merge!(Research.history_diff_block(dir, all, current, diff_document,
                                    from_revision, to_revision))
    end
    out['has_more'] = (offset + page.length) < all.length
    out['continuation'] = out['has_more'] ?
                            (offset + page.length).to_s : nil
    out
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.describe_revision(root, type, id, number, current)
    record = Store.read_revision(Layout.dossier_dir(root, type, id), number)
    docs = record['documents'] || {}
    atts = record['attachments'] || {}

    { 'revision' => number,
      'is_current' => number == current['revision'],
      'timestamp' => record['timestamp'] || record['committed_at'],
      'change_note' => record['change_note'],
      'documents' => docs.keys.sort,
      'attachments' => atts.map { |key, info|
        info.is_a?(Hash) ?
          { 'key' => key, 'digest' => info['digest'],
            'mode' => info['mode'] || 'copy',
            'size' => info['size'] } :
          { 'key' => key, 'digest' => info, 'mode' => 'copy' }
      }.sort_by { |a| a['key'] } }
  rescue Store::Missing, Store::Corrupt => e
    { 'revision' => number,
      'unreadable' => "revision record r#{number} unreadable: #{e.message}" }
  end

  def Research.decode_history_document(bytes)
    text = bytes.to_s.dup.force_encoding('UTF-8')
    unless text.valid_encoding?
      raise ParameterException,
            'document bytes are not valid UTF-8; authored documents ' \
            'are text — diff is unavailable (use evidence_read for ' \
            'binary attachments)'
    end
    text
  end

  def Research.history_diff_block(dir, all, current, document, from_revision, to_revision)
    Tasks.store_document_name!(document)
    from = from_revision ? Tasks.int!(from_revision, 'from_revision') : 1
    to = to_revision ? Tasks.int!(to_revision, 'to_revision') : current['revision']

    unless all.include?(from)
      raise ParameterException,
            "from_revision #{from} not found for this dossier " \
            "(available: #{all.first}..#{all.last})"
    end
    unless all.include?(to)
      raise ParameterException,
            "to_revision #{to} not found for this dossier " \
            "(available: #{all.first}..#{all.last})"
    end
    if from > to
      raise ParameterException,
            "from_revision #{from} must be <= to_revision #{to}"
    end

    old_rec = Store.read_revision(dir, from)
    new_rec = Store.read_revision(dir, to)
    old = old_rec['documents'][document]
    new = new_rec['documents'][document]
    if old.nil? && new.nil?
      raise ParameterException,
            "document #{document.inspect} exists in neither r#{from} " \
            'nor r#{to}'
    end

    old_text = Research.decode_history_document(old ? Store.object_bytes(dir, old_rec, document) : '')
    new_text = Research.decode_history_document(new ? Store.object_bytes(dir, new_rec, document) : '')

    hunks = LineEdit.diff(old_text, new_text,
                          max_lines: HISTORY_DIFF_MAX_LINES)

    { 'diff' => { 'document' => document,
                  'from_revision' => from, 'to_revision' => to,
                  'line_semantics' =>
                    'one-based, half-open [start, end) like ' \
                    'dossier_read/dossier_update',
                  'from_existed' => !old.nil?,
                  'to_existed' => !new.nil?,
                  'hunks' => hunks } }
  end
  export_exec :dossier_history
end
