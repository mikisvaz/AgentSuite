require_relative 'dossier_check'
require_relative '../sections'

module Research
  input :id, :string, 'Target dossier whose incoming links and reviewed premises to inspect'
  input :limit, :integer, 'Number of source dossiers to scan per page (1..1000)', 100
  input :continuation, :string, 'Next source dossier offset'
  desc 'Find authored links to a dossier and flag scientific or unclassified changes since an explicitly reviewed integer revision.'
  task :dossier_backlinks do |id, limit, continuation|
    root = Tasks.store_root
    type, id = Tasks.parse_id!(id)
    limit = Tasks.int!(limit, 'limit')
    offset = continuation.nil? ? 0 : Tasks.int!(continuation, 'continuation')
    raise ParameterException, 'invalid page bounds' unless limit.between?(1, 1000) && offset >= 0

    Tasks.map_store_errors(root, id) do
      target = Store.current_revision(root, type, id)
      _, sources, total = Research.check_selection_scope(root, nil, limit, offset)
      baselines = {}
      links = sources.flat_map do |source|
        next [] if source['id'] == id
        cur = Store.current_revision(root, source['type'], source['id'])
        cur['record'].fetch('documents').flat_map do |name, digest|
          text = Store.object_bytes(cur['dir'], digest).dup.force_encoding('UTF-8')
          directory = File.dirname(Store.view_path(cur['dir'], name))
          Research.incoming_links(text, directory, root, target, baselines).map do |link|
            link.merge('id' => source['id'], 'document' => name, 'revision' => cur['revision'])
          end
        end
      end
      after = offset + sources.size
      { 'id' => id, 'revision' => target['revision'], 'links' => links,
        'continuation' => after < total ? after.to_s : nil }
    end
  end

  def Research.incoming_links(text, directory, root, target, baselines)
    headings = Sections.outline(text)
    entries = []
    # Inline destinations on prose lines, using the same fenced-code rules as outlines.
    Sections.prose_lines(text.lines) do |prose, index|
      # Mask code spans before looking for links in examples.
      prose.gsub(/(`+).*?\1/) { |code| ' ' * code.size }.scan(INLINE_LINK) do |image, raw|
        match = Regexp.last_match
        next unless image.empty?
        resolved = Research.classify_link(raw, directory, root)
        next unless resolved['kind'] == 'checked'
        path = resolved['resolved']
        home = target['dir']
        next unless path == home || path.start_with?(home + '/')
        line = index + 1
        heading = headings.reverse_each.find { |h| h['start_line'] <= line }
        link = { 'line' => line, 'section' => heading && heading['selector'],
                 'heading_path' => heading && heading['path'], 'link' => prose[match.begin(0)...match.end(0)],
                 'relation' => 'mention' }
        if (review = raw.match(/\s+"reviewed@(\d+)"\s*\z/)) &&
           [home, Layout.doc_path(home)].include?(path)
          baseline = review[1].to_i
          link.merge!('relation' => 'reviewed_premise', 'reviewed_revision' => baseline)
          link.merge!(baselines[baseline] ||= Research.changes_since(target, baseline))
        end
        entries << link
      end
    end
    entries
  end

  def Research.changes_since(target, baseline)
    current = target.fetch('revision')
    return { 'review_status' => 'invalid_baseline' } unless baseline.between?(1, current)
    changes = ((baseline + 1)..current).filter_map do |number|
      journal = Store.read_revision(target['dir'], number)
      kind = journal.fetch('change_kind', 'unclassified')
      next if kind == 'documentary'
      { 'revision' => number, 'change_kind' => kind, 'change_note' => journal['change_note'] }
    end
    status = if changes.any? { |r| r['change_kind'] == 'scientific' }
               'review_suggested'
             elsif changes.any?
               'classification_unknown'
             else
               'current'
             end
    { 'review_status' => status, 'changes' => changes }
  end
  export_exec :dossier_backlinks
end
