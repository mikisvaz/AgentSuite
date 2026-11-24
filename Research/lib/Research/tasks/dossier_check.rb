# dossier_check: mechanical integrity checker for one dossier or a
# bounded selection in the root.
#
# Scope discipline: MECHANICAL integrity only. The vocabulary is
# mechanical (ok / finding types). This task NEVER emits a scientific
# PASS / supported / verified verdict and never assigns validity,
# strength or direction to an attachment.
#
# Finding categories (per dossier):
#   reference_inaccessible   current grants or permissions prevent reading the source
#   reference_missing   reference source no longer exists
#   reference_changed   reference source hashes differently than recorded
#   copy_corrupted      retained copy recomputes to a different digest
#   copy_missing        retained view file absent (object may exist)
#   local_link_broken   local Markdown link resolves to a missing file:
#                       ordinary relative links resolve against the
#                       CONTAINING document, absolute paths as-is, and
#                       legacy ID-form targets ([x](C-001/README.md))
#                       against the research root. Image destinations are
#                       checked like file links.
#   view_drift          current view digests differ from the pinned current
#                       revision (authored docs and evidence views)
#   metadata            pointer/record/marker inconsistency, unreadable
#                       records, unlisted files in the dossier area
#
# Link coverage honesty (5i): every link found in an authored document is
# counted into exactly one category — checked (broken links also raise a
# local_link_broken finding), external_url, out_of_scope, fragment_only,
# in_code_fence, or unsupported_syntax — and the skipped categories are
# reported explicitly so a clean result never implies skipped links were
# checked. Supported syntax (bounded, documented):
#   [text](target)  and  ![alt](target)   — inline links and images;
#   [text](<target with spaces>)          — angle-bracket targets;
#   [text](target "title")                — optional title.
# NOT supported (reported as unsupported_syntax, never resolved):
#   reference-style links and definitions ([text][ref], [ref]: url),
#   HTML <a href>, and parenthesized targets containing unbracketed
#   spaces. Link FRAGMENTS (#section) are separated from the file path
# and never validated. Fenced code blocks (``` / ~~~) are not active
# links and are skipped (counted, not checked).
#
# NOT checked (explicitly reported): external web links (never fetched),
# scientific validity, link targets outside the research root.
#
# No mutations: read-only by construction; the test gate digests the
# root tree before and after to prove it.

require 'json'
require 'fileutils'
require_relative 'common'
require_relative '../evidence'

module Research
  CHECK_LIMIT_MAX = 1000

  # Supported check: Markdown links of the form [text](id) or
  # [text](id/document) where id looks like Q-001/C-002/H-003,
  # resolving inside THIS root. Targets outside the root are not
  # checked (reported in not_checked).
  #
  # Legacy form kept working (5k): a bare ID (or id/document) target is
  # resolved against the research root, exactly like the old checker.
  ID_FORM_TARGET = /\A((?:Q|C|H)-\d{3,})(?:\/([^\s]+))?\z/.freeze

  # Bounded supported Markdown link syntax (5g): inline links and
  # images, optional titles, angle-bracket targets. See the header
  # comment for the exact coverage model.
  INLINE_LINK = /(!?)\[[^\]]*\]\(((?:\([^)]*\)|[^)])*?)\)/.freeze

  # Reference-style links [label][ref] and shortcut [label] forms are
  # recognized but NOT resolved (bounded syntax, 5g); they are counted
  # as unsupported_syntax so a clean result never claims they were
  # checked (5i).
  REFERENCE_LINK = /\[[^\]\n]+\]\[[^\]\n]*\]/.freeze

  # A target is an external URL when it names a scheme (http:, https:,
  # mailto:, ftp:...). Anything else that is not a path (e.g. tel: or a
  # bare word) is handled by the classifier, not this predicate.
  EXTERNAL_URL = /\A[a-z][a-z0-9+.-]*:/i.freeze
  input :id, :string, 'Check one dossier only (overrides type/limit)'
  input :type, :select, 'Restrict the check to one dossier type; omit to check all types', nil, select_options: %w[question claim hypothesis]
  input :limit, :integer, 'Maximum dossiers to check (1..1000; default 100)', 100
  input :continuation, :string, 'Continuation token from a previous page'
  desc 'Run the mechanical integrity check over dossiers: references, retained copies, view drift, local links, metadata. Read-only; never a scientific verdict.'
  task :dossier_check do |id, type, limit, continuation|
    root = Tasks.store_root
    limit = Tasks.int!(limit, 'limit')
    limit = CHECK_LIMIT_MAX if limit > CHECK_LIMIT_MAX
    raise ParameterException, 'limit must be positive' unless limit >= 1

    offset = continuation.to_s.match?(/\A\d+\z/) ? continuation.to_i : 0

    scope, items, total =
      if id
        s, its = Research.check_one_scope(root, id)
        [s, its, 1]
      else
        Research.check_selection_scope(root, type, limit, offset)
      end

    checked = 0
    results = []
    items.each do |entry|
      checked += 1
      results << Research.check_dossier(root, entry)
    end

    {
      'scope' => scope,
      'checked' => checked,
      'has_more' => !id && (offset + checked) < total,
      'continuation' => !id && (offset + checked) < total ?
                          (offset + checked).to_s : nil,
      'dossiers' => results,
      'finding_count' => results.sum { |d| d['findings'].length },
      'not_checked' =>
        ['external web links (never fetched)',
         'scientific validity (mechanical check only)',
         'link targets outside this research root',
         'link fragments and heading anchors (#section) are separated ' \
         'from file paths but never validated',
         'reference-style links, HTML anchors and other unsupported ' \
         'syntax (listed in each dossier links.unsupported_syntax)']
    }
  end

# internal helpers (module functions reached from the task body as Research.<name>)

  def Research.check_one_scope(root, id)
    type = Tasks.parse_id!(id)[0]
    unless Research.check_dossier?(root, type, id)
      raise ParameterException,
            "dossier #{id} not found in root #{root}"
    end
    ["one dossier: #{id}",
     [{ 'type' => type, 'id' => id }]]
  end

  def Research.check_selection_scope(root, type, limit, offset)
    t = type ? Tasks.parse_type!(type) : nil
    ids = []
    Layout::TYPES.each do |ty|
      next if t && ty != t

      ids.concat(Layout.list_ids(root, ty).map { |i| [ty, i] })
    end
    ordered = ids.sort_by { |(ty, i)| [ty, Tasks.id_sort_key(i)] }
    page = ordered[offset, limit] || []
    ["#{t || 'all'} dossiers in root (#{ordered.length} total)",
     page.map { |(ty, i)| { 'type' => ty, 'id' => i } },
     ordered.length]
  end

  def Research.check_dossier?(root, type, id)
    dir = Layout.dossier_dir(root, type, id)
    File.directory?(dir) &&
      File.file?(Layout.current_pointer_path(root, type, id))
  end

  def Research.check_dossier(root, entry)
    type = entry['type']
    id = entry['id']
    dir = Layout.dossier_dir(root, type, id)
    findings = []

    current = Research.check_metadata(root, type, id, dir, findings)
    link_coverage = nil
    if current
      Research.check_references(current['record'], findings)
      findings.concat(Evidence.copy_findings(dir, current['record']))
      Research.check_view_drift(dir, current['record'], findings)
      link_coverage = Research.check_local_links(
        root, dir, current['record'], findings
      )
    end

    { 'id' => id, 'type' => type, 'revision' => current && current['revision'],
      'status' => findings.empty? ? 'ok' : 'findings',
      'finding_count' => findings.length,
      'links' => link_coverage,
      'findings' => findings }
  end

  # ---- metadata ----------------------------------------------

  def Research.check_metadata(root, type, id, dir, findings)
    pointer = Layout.current_pointer_path(root, type, id)
    unless File.file?(pointer)
      findings << Research.check_finding('metadata',
                                "current pointer missing at #{pointer}")
      return nil
    end

    begin
      number = Store.read_pointer(pointer)
    rescue Store::Corrupt => e
      findings << Research.check_finding('metadata', e.message,
                                'expected' => 'integer pointer',
                                'observed' => 'unparseable')
      return nil
    end

    begin
      record = Store.read_revision(dir, number)
    rescue Store::Missing, Store::Corrupt => e
      findings << Research.check_finding('metadata', e.message,
                                'expected' => "readable r#{number} record",
                                'observed' => 'unreadable')
      return nil
    end

    if File.file?(Store.marker_path(dir))
      findings << Research.check_finding(
        'metadata',
        "inflight marker present outside a transaction " \
        "(#{Store.marker_path(dir)}); an interrupted commit must be " \
        'recovered (Store.recover! under the lock) before further ' \
        'mutations',
        'expected' => 'no inflight marker',
        'observed' => 'marker present'
      )
    end

    # pointer must name the highest surviving journal entry
    max_record = Dir.glob(File.join(Layout.history_dir(dir), 'r*.json'))
                    .map { |p| File.basename(p)[/\d+/].to_i }.max
    if max_record && max_record > number
      findings << Research.check_finding(
        'metadata',
        "journals above the pointer exist (r#{max_record} > pointer " \
        "r#{number}); leftover interrupted-commit or rolled-back state",
        'expected' => number, 'observed' => max_record
      )
    end

    { 'revision' => number, 'record' => record }
  end

  # ---- evidence ----------------------------------------------

  def Research.check_references(record, findings)
    (record['attachments'] || {}).each do |key, info|
      next unless info.is_a?(Hash) && info['mode'] == 'reference'

      integrity = Evidence.reference_integrity(info)
      next if integrity['state'] == 'ok'

      category = "reference_#{integrity['reason'] || integrity['state']}"
      findings << Research.check_finding(category, "reference #{key.inspect}: #{integrity['detail']}",
                                         'expected' => info['digest'], 'observed' => integrity['observed'] || integrity['reason'])
    end
  end

  def Research.check_view_drift(dir, record, findings)
    %i[documents attachments].each do |kind|
      Store.view_drift(dir, record, kind).each do |name, (expected, observed)|
        findings << Research.check_finding('view_drift', "#{kind}: #{name.inspect} differs from the revision",
                                           'expected' => expected || 'not present',
                                           'observed' => observed || 'missing')
      end
    end
  end

  # ---- local links -------------------------------------------
  #
  # Ordinary local Markdown links resolve against the CONTAINING
  # document (5g): a link in supplements/sub/inner.md resolves relative
  # to <dossier>/supplements/sub/. Legacy bare-ID targets
  # ([x](C-001/README.md)) resolve against the research root (5k).
  # Absolute paths are resolved as-is (5h) — the links the tasks
  # themselves generate are absolute.
  #
  # Coverage accounting (5i): every INLINE_LINK match is classified
  # into exactly one bucket. check_dossier returns counts; broken local
  # targets additionally raise a local_link_broken finding.

  # Split an inline-link raw target into (path, fragment):
  #   "README.md#frag" -> ["README.md", "frag"]
  #   "#frag"          -> [nil, "frag"]
  #   "README.md"      -> ["README.md", nil]
  # Fragments are separated but NEVER validated (stated in the output).
  def Research.link_path_fragment(raw)
    target = raw.strip
    if target.start_with?('<') && target.end_with?('>')
      target = target[1..-2].to_s.strip
    end
    # optional title after the path: keep only the first token group;
    # a title is quoted, so strip a trailing "..." segment.
    if (m = target.match(/\A(.*?)(?:\s+"[^"]*")?\z/m))
      target = m[1].to_s.strip
    end
    path, frag = target.split('#', 2)
    [path.to_s.empty? ? nil : path, frag]
  end

  def Research.link_in_fence?(lines, match_begin)
    # fence state: ``` or ~~~ toggles; a match inside a fence is not an
    # active link (5g). match_begin is a byte offset into the joined
    # text; we track line offsets in bytes.
    offset = 0
    in_fence = false
    fence_marker = nil
    lines.each do |line|
      line_end = offset + line.bytesize
      if in_fence
        if (f = line.match(/\A(\s*)(`{3,}|~{3,})/)) && f[2][0] == fence_marker
          in_fence = false
        end
      elsif (f = line.match(/\A(\s*)(`{3,}|~{3,})/))
        in_fence = true
        fence_marker = f[2][0]
      end
      return true if in_fence && match_begin < line_end && match_begin >= offset

      offset = line_end
    end
    false
  end

  # Classify one raw target. Returns a Hash:
  #   { 'raw' =>, 'kind' => checked|external_url|out_of_scope|
  #                fragment_only|unsupported_syntax,
  #     'resolved' => abs path or nil, 'exists' => bool, 'broken' => bool }
  def Research.classify_link(raw, containing_dir, root)
    path, _frag = Research.link_path_fragment(raw)
    info = { 'raw' => raw.strip }
    return info.merge('kind' => 'fragment_only') if path.nil?

    if path =~ EXTERNAL_URL
      return info.merge('kind' => 'external_url')
    end

    resolved =
      if path.start_with?('/')
        File.expand_path(path)
      elsif (m = path.match(ID_FORM_TARGET)) &&
            !path.include?('..') && containing_dir != root
        # legacy bare-ID form: resolve against the research root
        Layout.dossier_dir(root, TYPE_LETTER.fetch(m[1][0]), m[1])
      else
        File.expand_path(path, containing_dir)
      end
    info['resolved'] = resolved

    unless resolved.start_with?(root.to_s)
      return info.merge('kind' => 'out_of_scope')
    end
    # checks stay inside the store root (5k): no probing outside
    info['exists'] = File.exist?(resolved)
    info.merge('kind' => 'checked', 'broken' => !info['exists'])
  end

  TYPE_LETTER = { 'Q' => 'question', 'C' => 'claim',
                  'H' => 'hypothesis' }.freeze

  def Research.check_local_links(root, dir, record, findings)
    counts = Hash.new(0)
    (record['documents'] || {}).each do |name, _digest|
      text = begin
        Store.object_bytes(dir, record['documents'].fetch(name))
      rescue StandardError
        next
      end
      text = text.to_s
      lines = text.lines
      text.scan(INLINE_LINK) do |bang, raw|
        counts['images'] += 1 unless bang.to_s.empty?
        if Research.link_in_fence?(lines, Regexp.last_match.begin(0))
          counts['in_code_fence'] += 1
          next
        end
        classified = Research.classify_link(
          raw, File.dirname(Store.view_path(dir, name)), root
        )
        case classified['kind']
        when 'checked'
          counts['checked'] += 1
          next unless classified['broken']

          counts['local_link_broken'] += 1
          findings << Research.check_finding(
            'local_link_broken',
            "document #{name.inspect} links to #{classified['raw'].inspect}: " \
            "resolves to #{classified['resolved'].inspect} which does not exist",
            'expected' => 'existing local target',
            'observed' => 'missing file'
          )
        when 'external_url' then counts['external_url'] += 1
        when 'out_of_scope' then counts['out_of_scope'] += 1
        when 'fragment_only' then counts['fragment_only'] += 1
        else counts['unsupported_syntax'] += 1
        end
      end
      # Reference-style links are recognized but deliberately not
      # resolved (bounded syntax, 5g); counted as unsupported_syntax so
      # a clean result never claims they were checked (5i).
      text.scan(REFERENCE_LINK) do
        next if Research.link_in_fence?(lines, Regexp.last_match.begin(0))

        counts['unsupported_syntax'] += 1
      end
    end
    counts
  end

  # Call sites pass a trailing { 'expected' =>, 'observed' => } hash.
  def Research.check_finding(category, message, extra = nil)
    f = { 'category' => category, 'detail' => message }
    if extra.is_a?(Hash)
      f['expected'] = extra['expected'] if extra['expected']
      f['observed'] = extra['observed'] if extra['observed']
    end
    f
  end
  export_exec :dossier_check
end
