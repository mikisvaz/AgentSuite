# dossier_list — concise inventory of dossiers under the store root.
#
# Searches CURRENT authored documents and titles ONLY: for each dossier
# the current revision record (pointer -> record -> objects) supplies
# the title (first H1 of the entry document) and the authored-document
# names; no history snapshots and no binary attachments are read
# (query text never matches inside evidence bytes).
#
# THERE IS NO INDEX FILE. The inventory is derived live from
# pointer -> record -> entry-document bytes on every call, so it is
# rebuildable by construction: destroying any derived artifact cannot
# lose a dossier, and no index can ever disagree with the store.

require_relative 'common'

module Research
  DEFAULT_LIMIT = 100
  MAX_LIMIT = 1000

  input :type, :select, 'Restrict the listing to one dossier type; omit to list all types', nil, select_options: %w[question claim hypothesis]
  input :query, :string, 'Case-insensitive substring matched against id, title, authored-document names and CURRENT authored-document contents (never history snapshots, never attachment bytes). Scan cost is one read per document per listed dossier.'
  input :limit, :integer, 'Maximum dossiers to return (1..1000)', 100
  input :continuation, :string, 'Continuation token from a previous page'
  desc 'List dossiers under the research root: id, title, type, revision, location. Derived live from the store; there is no index file to go stale.'
  task :dossier_list do |type, query, limit, continuation|
    root = Tasks.store_root

    types = type.nil? || type.to_s.strip.empty? ? Tasks::TYPES : [Tasks.parse_type!(type)]
    Tasks.reject_placeholder_text!(query, 'query') unless query.nil?

    limit = Tasks.int!(limit, 'limit')
    unless limit >= 1 && limit <= MAX_LIMIT
      raise ParameterException,
            "limit must be between 1 and #{MAX_LIMIT} (got #{limit})"
    end

    offset = 0
    if continuation && !continuation.to_s.strip.empty?
      c = continuation.to_s
      unless c =~ /\A\d+\z/
        raise ParameterException,
              "continuation must be a non-negative integer token (got #{continuation.inspect})"
      end
      offset = c.to_i
    end

    entries =
      Tasks.map_store_errors(root) do
        Research.collect_list_entries(root, types, query.to_s)
      end

    total = entries.length
    window = entries[offset, limit] || []
    next_offset = offset + window.length
    more = next_offset < total

    {
      'total' => total,
      'offset' => offset,
      'count' => window.length,
      'dossiers' => window,
      'continuation' => more ? next_offset.to_s : nil,
      'truncated' => more
    }
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  # One inventory entry per dossier with a current revision, in
  # stable order (type order, then numeric id). A dossier whose
  # entry document has no H1 falls back to nil title; dossiers are
  # never silently dropped for lacking a title.
  def Research.collect_list_entries(root, types, query)
    q = query.strip
    entries = []
    types.each do |t|
      Layout.list_ids(root, t).each do |id|
        cur = begin
          Store.current_revision(root, t, id)
        rescue Store::Missing
          next
        end
        # Current authored documents only (never history, never
        # attachment bytes). Bounded: one read per document per
        # listed dossier — the scan cost is O(documents).
        documents = (cur['record']['documents'] || {}).keys.sort
        texts = documents.map do |name|
          bytes = Store.object_bytes(cur['dir'], cur['record'], name)
          bytes.dup.force_encoding(Encoding::UTF_8)
        end
        title = Tasks.title_of(texts.first.to_s)
        body_match = !q.empty? &&
                     texts.any? { |txt| txt.to_s.downcase.include?(q.downcase) }

        if Research.list_matches?(q, id, title, documents) || body_match
          entries << {
            'id' => id,
            'type' => t,
            'title' => title,
            'revision' => cur['revision'],
            'documents' => documents
          }
        end
      end
    end
    entries.sort_by! { |e| Tasks.id_sort_key(e['id']) }
  end

  # Simple text query: case-insensitive substring match against the
  # id, the title and the authored-document NAMES; current document
  # CONTENTS are matched in collect_entries. Not matched: evidence
  # names, history snapshots, attachment bytes. Empty query matches
  # everything.
  def Research.list_matches?(query, id, title, documents)
    return true if query.empty?

    q = query.downcase
    [id, title.to_s, documents.join(' ')].any? do |field|
      field.to_s.downcase.include?(q)
    end
  end
  export_exec :dossier_list
end
