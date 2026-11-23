# WO-3 part 1: the four native dossier tasks, exercised through REAL
# task registration/export (Research.job(:dossier_create).exec and
# LLM.call_workflow dispatch) — never helper-only calls.
#
# Covers: all three dossier types; create with/without content; listing
# (type filter, query, limit/continuation, view destruction proving live
# re-derivation); read (default/named documents, overview, historical
# revisions, ranges/continuation, evidence rejection); update modes;
# no-op creates no revision; stale expected_revision rejected; racing
# concurrent edits rejected under the lock; document-path restrictions;
# exact one-based half-open line semantics with byte preservation
# outside the span; README.md entry-document ruling; root identity on
# results; two configured roots with distinct ID spaces.
require 'test/unit'
require 'scout'
require 'scout-ai'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'Research', 'lib'))
require File.join(ROOT, 'Research', 'workflow')
require File.join(ROOT, 'Research', 'test', 'support', 'dossier_fixtures')

# The exported-call dispatch path (what an agent's workflow tool
# actually invokes); rescues ScoutException into a value like the real
# tool layer does.
def dispatch(task, params, project: nil)
  project ||= (($test_project rescue nil) || @project)
  DossierFixtures.in_project(project) do
    LLM.call_workflow(Research, task, params)
  end
end

# Research.job(task, nil, **inputs).exec — the direct task-registration
# surface, using the documented Scout job idiom (workflow.job(task, nil,
# key: value)); assign_inputs fills declared defaults for omitted inputs.
def run_task(task, params, project: nil)
  project ||= (($test_project rescue nil) || @project)
  DossierFixtures.in_project(project) do
    Research.job(task, nil, **params).exec
  end
end

class TestDossierTasksExported < Test::Unit::TestCase
  include DossierFixtureTeardown

  def setup
    @project = DossierFixtures.scaffold_project('wo3-tasks')
    @root = File.join(@project, 'research')
    @project2 = DossierFixtures.scaffold_project('wo3-tasks-b')
    @root2 = File.join(@project2, 'research')
    @p = {}
  end

  # ---- registration/export facts -------------------------------

  def test_tasks_registered_and_exported
    %i[dossier_create dossier_list dossier_read dossier_update].each do |t|
      assert Research.tasks.key?(t), "task #{t} must be registered"
      assert_include Research.exec_exports, t, "task #{t} must be exec-exported (D2)"
    end
  end

  def test_task_input_types_declared
    create = Research.tasks[:dossier_create]
    type_input = create.inputs.find { |i| Array === i && i.first == :type }
    assert_equal :select, type_input[1]
    assert_equal %w[question claim hypothesis], type_input[4][:select_options]
    update = Research.tasks[:dossier_update]
    mode_input = update.inputs.find { |i| Array === i && i.first == :mode }
    assert_equal :select, mode_input[1]
    assert_equal %w[create_document replace_document replace_lines delete_lines], mode_input[4][:select_options]
    # inputs arrive in declaration order; blocks bind them positionally
    assert_equal %i[type title content], create.inputs.collect(&:first)
  end

  # ---- create --------------------------------------------------

  def test_create_all_three_types_without_content
    %w[question claim hypothesis].each do |type|
      r = run_task(:dossier_create, @p.merge('type' => type, 'title' => "#{type} title"))
      assert_equal 1, r['revision'], "#{type}: first revision is 1"
      assert_equal type, r['type']
      assert_match(/\A[QCH]-\d{3}\z/, r['id'])
      assert_equal 'README.md', r['entry_document'], 'Manager ruling 1: entry document is README.md'
      # Concise payload: the absolute entry path lives inside the link
      # target and in directory; entry_document_path is retired.
      entry = r['link'][/\((.*)\)\z/, 1]
      assert File.file?(entry)
      assert_equal "[#{r['id']}](#{entry})", r['link']
      plural = { 'question' => 'questions', 'claim' => 'claims', 'hypothesis' => 'hypotheses' }.fetch(type)
      assert_equal File.join(@root, plural, r['id']),
                   File.dirname(r['link'][/\((.*)\)\z/, 1]),
                   'directory pins the typed store path'
      refute r.key?('root'), 'retired root field must be gone'
      refute r.key?('root_source'), 'retired root_source field must be gone'
      assert r['link'] =~ /README\.md\)\z/, 'link targets the entry document'
      text = File.read(entry)
      assert_match(/# #{type} title/, text)
    end
  end

  def test_create_with_content_writes_given_bytes_only
    content = "# Given title\n\nBody line.\n"
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'ignored-here', 'content' => content))
    entry = r['link'][/\((.*)\)\z/, 1]
    assert_equal content, File.read(entry)
    # No scientific status or observation structure is imposed.
    assert_not_include File.read(entry), 'status'
  end

  def test_create_unknown_type_rejected
    e = assert_raise(ParameterException) do
      run_task(:dossier_create, @p.merge('type' => 'conjecture', 'title' => 'x'))
    end
    assert_match(/unknown dossier type.*question, claim, hypothesis/, e.message)
  end

  def test_create_placeholder_content_rejected
    e = assert_raise(ParameterException) do
      run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 't',
                                         'content' => "text\n[TOOL-COMPACTION-RECORD] metadata\n"))
    end
    assert_match(/TOOL-COMPACTION-RECORD/, e.message)
  end

  # ---- list ----------------------------------------------------

  def test_list_all_and_type_filter_and_query
    run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'Alpha question', 'content' => "# Alpha question\n\na\n"))
    run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'Beta claim', 'content' => "# Beta claim\n\nb\n"))
    run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'Gamma hypothesis', 'content' => "# Gamma hypothesis\n\ng\n"))

    all = run_task(:dossier_list, @p)
    assert_equal 3, all['total']
    assert_equal %w[Q-001 C-001 H-001], all['dossiers'].map { |d| d['id'] }
    assert all['dossiers'].all? { |d| %w[question claim hypothesis].include?(d['type']) }

    claims = run_task(:dossier_list, @p.merge('type' => 'claim'))
    assert_equal ['C-001'], claims['dossiers'].map { |d| d['id'] }

    hits = run_task(:dossier_list, @p.merge('query' => 'alpha'))
    assert_equal ['Q-001'], hits['dossiers'].map { |d| d['id'] }
    hits_ci = run_task(:dossier_list, @p.merge('query' => 'ALPHA'))
    assert_equal ['Q-001'], hits_ci['dossiers'].map { |d| d['id'] }
    none = run_task(:dossier_list, @p.merge('query' => 'zzz-no-match'))
    assert_equal 0, none['total']
  end

  def test_list_limit_and_continuation
    5.times do |i|
      run_task(:dossier_create, @p.merge('type' => 'question', 'title' => "Q#{i}", 'content' => "# Q#{i}\n"))
    end
    page1 = run_task(:dossier_list, @p.merge('limit' => 2))
    assert_equal 2, page1['count']
    assert page1['truncated']
    assert_equal '2', page1['continuation'] # 0-based offset of the next item
    page2 = run_task(:dossier_list, @p.merge('limit' => 2, 'continuation' => page1['continuation']))
    assert_equal ['Q2', 'Q3'], page2['dossiers'].map { |d| d['title'] }
    page3 = run_task(:dossier_list, @p.merge('limit' => 2, 'continuation' => page2['continuation']))
    assert_equal 1, page3['count']
    assert_equal false, page3['truncated']
    assert_nil page3['continuation']
    bad = assert_raise(ParameterException) { run_task(:dossier_list, @p.merge('continuation' => 'x')) }
    assert_match(/continuation must be/, bad.message)
  end

  def test_list_derives_from_store_even_without_views
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'Kept', 'content' => "# Kept\n"))
    dir = File.dirname(r['link'][/\((.*)\)\z/, 1])
    # Destroy EVERY view file (README.md etc.) — the listing must still
    # find the dossier with its title, re-derived from store objects.
    FileUtils.rm_f(File.join(dir, 'README.md'))
    listed = run_task(:dossier_list, @p)
    assert_equal 1, listed['total']
    assert_equal 'Kept', listed['dossiers'].first['title']
    assert_equal 'C-001', listed['dossiers'].first['id']
  end

  # ---- read ----------------------------------------------------

  def test_read_default_document_and_range
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'T',
                                           'content' => "# T\n\none\n\ntwo\n"))
    id = r['id']
    full = run_task(:dossier_read, @p.merge('id' => id))
    assert_equal 'README.md', full['document']
    assert_equal 5, full['total_lines']
    assert_equal '# T', full['content'].lines.first.chomp
    assert_nil full['continuation']

    page = run_task(:dossier_read, @p.merge('id' => id, 'start_line' => 3, 'max_lines' => 1))
    assert_equal "one\n", page['content']
    assert_equal 3, page['start_line']
    assert_equal 3, page['end_line']
    assert_equal '4', page['continuation']
    assert page['truncated']

    tail = run_task(:dossier_read, @p.merge('id' => id, 'start_line' => page['continuation']))
    assert_equal "\ntwo\n", tail['content']
    assert_equal false, tail['truncated']

    oob = assert_raise(ParameterException) { run_task(:dossier_read, @p.merge('id' => id, 'start_line' => 99)) }
    assert_match(/start_line 99 out of range/, oob.message)
  end

  def test_read_named_supplement_and_missing_document
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'T', 'content' => "# T\n"))
    id = r['id']
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'create_document',
                                       'document' => 'supplements/notes.md', 'content' => "supp line\n"))
    rd = run_task(:dossier_read, @p.merge('id' => id, 'document' => 'supplements/notes.md'))
    assert_equal "supp line\n", rd['content']
    assert_equal 'supplements/notes.md', rd['document']
    miss = assert_raise(ParameterException) { run_task(:dossier_read, @p.merge('id' => id, 'document' => 'supplements/nope.md')) }
    assert_match(/has no document/, miss.message)
  end

  def test_read_historical_revision
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'V1', 'content' => "# V1\n\nold body\n"))
    id = r['id']
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document', 'content' => "# V2\n\nnew body\n"))
    old = run_task(:dossier_read, @p.merge('id' => id, 'revision' => 1))
    assert_equal "# V1\n\nold body\n", old['content']
    assert_equal 1, old['revision']
    assert_equal 2, old['current_revision']
    new = run_task(:dossier_read, @p.merge('id' => id))
    assert_equal "# V2\n\nnew body\n", new['content']
  end

  def test_read_overview_mode
    r = run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'OV', 'content' => "# OV\n\nbody\n"))
    id = r['id']
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'create_document',
                                       'document' => 'supplements/extra.md', 'content' => "x\n"))
    ov = run_task(:dossier_read, @p.merge('id' => id, 'overview' => true))
    assert_equal 'OV', ov['entry_document']['title']
    assert_equal 3, ov['entry_document']['total_lines']
    names = ov['documents'].map { |d| d['name'] }
    assert_include names, 'README.md'
    assert_include names, 'supplements/extra.md'
    assert_equal 2, ov['revision']
  end

  def test_read_evidence_rejected
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'E', 'content' => "# E\n"))
    e = assert_raise(ParameterException) do
      run_task(:dossier_read, @p.merge('id' => r['id'], 'document' => 'evidence/blob.bin'))
    end
    assert_match(/evidence/, e.message)
    assert_match(/dossier_read/, e.message)
  end

  # ---- update: modes, no-op, stale, concurrency ----------------

  def test_update_create_document_and_noop
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'U', 'content' => "# U\n"))
    id = r['id']
    c1 = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'create_document',
                                            'document' => 'supplements/a.md', 'content' => "a\n"))
    assert c1['changed']
    assert_equal 2, c1['revision']
    assert_equal 'created supplements/a.md (2 bytes)', c1['change_summary']

    noop = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2, 'mode' => 'replace_document',
                                              'document' => 'supplements/a.md', 'content' => "a\n"))
    assert_equal false, noop['changed'], 'identical bytes must create NO revision'
    assert_equal 2, noop['revision']
    assert_equal 'no change', noop['change_summary']
    # entry document cannot be create_document'd
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2, 'mode' => 'create_document', 'content' => 'x'))
    end
    assert_match(/entry document/, e.message)
  end

  def test_update_replace_document
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'Old', 'content' => "# Old\n\nold\n"))
    id = r['id']
    u = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document',
                                           'content' => "# New Title\n\nnew body\n"))
    assert u['changed']
    assert_equal 2, u['revision']
    dir = File.join(@root, 'questions', r['id'])
    assert_equal "# New Title\n\nnew body\n", File.read(File.join(dir, 'README.md'))
  end

  def test_update_replace_lines_exact_semantics
    doc = "l1\nl2\nl3\nl4\nl5\n"
    r = run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'L', 'content' => doc))
    id = r['id']
    path = File.join(@root, 'hypotheses', r['id'], 'README.md')

    # replace one line [2,3)
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_lines',
                                       'start_line' => 2, 'end_line' => 3, 'replacement' => "X2\n"))
    assert_equal "l1\nX2\nl3\nl4\nl5\n", File.read(path)
    # delete a range [4,6)
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2, 'mode' => 'replace_lines',
                                       'start_line' => 4, 'end_line' => 6, 'replacement' => ''))
    assert_equal "l1\nX2\nl3\n", File.read(path)
    # insert at [4,4)
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 3, 'mode' => 'replace_lines',
                                       'start_line' => 4, 'end_line' => 4, 'replacement' => "i1\ni2\n"))
    assert_equal "l1\nX2\nl3\ni1\ni2\n", File.read(path)
    # append at [6,6) on a newline-terminated document
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 4, 'mode' => 'replace_lines',
                                       'start_line' => 6, 'end_line' => 6, 'replacement' => "end\n"))
    assert_equal "l1\nX2\nl3\ni1\ni2\nend\n", File.read(path)

    # no trailing-newline document: insert without forcing one
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 5, 'mode' => 'replace_document',
                                       'content' => "a\nb"))
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 6, 'mode' => 'replace_lines',
                                       'start_line' => 2, 'end_line' => 2, 'replacement' => "mid\n"))
    assert_equal "a\nmid\nb", File.read(path)

    # invalid span rejected, store untouched
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 7, 'mode' => 'replace_lines',
                                         'start_line' => 0, 'end_line' => 1, 'replacement' => 'x'))
    end
    assert_match(/out of range|must be an integer/, e.message)
    assert_equal 7, run_task(:dossier_read, @p.merge('id' => id))['current_revision']
  end

  # ---- per-mode parameter contract (audit follow-up: msgs 297/300/465,
  # three failed dispatches to assemble one valid call) ---------------

  def test_update_missing_mode_is_a_missing_parameter
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'MM', 'content' => "# MM\n"))
    id = r['id']
    # omitted (nil) mode — never reported as the invalid value ""
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'replacement' => 'x', 'start_line' => 1))
    end
    assert_match(/mode is required; one of: /, e.message)
    assert_not_match(/unknown update mode/, e.message)
    # empty-string mode behaves the same (model tool layers coerce)
    e2 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => '', 'replacement' => 'x', 'start_line' => 1))
    end
    assert_match(/mode is required; one of: /, e2.message)
    # a non-empty bad value is still reported as a VALUE
    e3 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'frobnicate'))
    end
    assert_match(/unknown update mode "frobnicate"/, e3.message)
    # no side effects: nothing staged, revision untouched
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision']
  end

  def test_update_contract_reports_all_problems_in_one_message
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'CP', 'content' => "# CP\n"))
    id = r['id']
    # replace_lines missing start_line AND end_line AND carrying forbidden
    # content: all must appear in ONE message (no serial discovery).
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_lines',
                                         'replacement' => 'x', 'content' => 'y'))
    end
    assert_match(/mode replace_lines requires replacement, start_line, end_line;/, e.message)
    assert_match(/missing: start_line, end_line/, e.message)
    assert_match(/unexpected: content/, e.message)
    assert_match(/mode replace_lines requires replacement, start_line, end_line; missing: start_line, end_line; unexpected: content/, e.message)
    # document modes forbid the line-edit inputs
    e2 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_document',
                                         'content' => 'y', 'replacement' => 'x',
                                         'start_line' => 1, 'anchor' => 'z'))
    end
    assert_match(/mode replace_document requires content; unexpected: replacement, anchor, start_line/, e2.message)
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision']
  end

  def test_update_end_line_required_rejects_nil_and_omitted
    # D1: end_line is REQUIRED for replace_lines — no implicit EOF. An
    # accidentally omitted end_line must not become a destructive edit
    # (the audit's stated motivation); nil and omitted behave alike.
    r = run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'E',
                                           'content' => "a\nb\nc\nd\n"))
    id = r['id']
    path = File.join(@root, 'hypotheses', id, 'README.md')

    # omitted entirely -> one-pass contract error, nothing staged
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_lines', 'start_line' => 3,
                                         'replacement' => "c2\n"))
    end
    assert_equal 'mode replace_lines requires replacement, start_line, end_line; missing: end_line', e.message
    # explicit nil behaves identically (only nil counts as absent)
    e2 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_lines', 'start_line' => 3,
                                         'end_line' => nil,
                                         'replacement' => "c2\n"))
    end
    assert_equal e.message, e2.message
    # revision untouched by both rejected calls
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision']
    assert_equal "a\nb\nc\nd\n", File.read(path)
  end

  def test_update_end_line_total_plus_one_edits_through_end_of_document
    # D1/T2: the explicit EOF convention — end_line = total_lines + 1
    # replaces (and deletes) through end of document.
    r = run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'E2',
                                           'content' => "a\nb\nc\nd\n"))
    id = r['id']
    path = File.join(@root, 'hypotheses', id, 'README.md')

    u = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                           'mode' => 'replace_lines', 'start_line' => 3,
                                           'end_line' => 5,
                                           'replacement' => "c2\n"))
    assert u['changed']
    assert_equal "a\nb\nc2\n", File.read(path)

    # delete_lines through EOF with the same convention (document is now
    # 3 lines, so total + 1 = 4)
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                       'mode' => 'delete_lines', 'start_line' => 2,
                                       'end_line' => 4))
    doc = run_task(:dossier_read, @p.merge('id' => id))
    assert_equal "a\n", doc['content']
  end

  def test_update_delete_lines_end_line_required
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'DN',
                                           'content' => "a\nb\nc\nd\n"))
    id = r['id']
    path = File.join(@root, 'claims', id, 'README.md')
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'delete_lines', 'start_line' => 3))
    end
    assert_equal 'mode delete_lines requires start_line, end_line; missing: end_line', e.message
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision']
    assert_equal "a\nb\nc\nd\n", File.read(path)
  end

  def test_update_anchor_matching_text_edits_normally
    doc = "l1\nl2\nl3\n"
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'A', 'content' => doc))
    id = r['id']
    path = File.join(@root, 'questions', id, 'README.md')
    u = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                           'mode' => 'replace_lines',
                                           'start_line' => 2, 'end_line' => 3,
                                           'anchor' => "l2\n",
                                           'replacement' => "X2\n"))
    assert u['changed']
    assert_equal 2, u['revision']
    assert_equal "l1\nX2\nl3\n", File.read(path)
    # anchor on an empty span (pure insertion) matches "" and inserts
    u2 = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                            'mode' => 'replace_lines',
                                            'start_line' => 3, 'end_line' => 3,
                                            'anchor' => '',
                                            'replacement' => "i\n"))
    assert u2['changed']
    assert_equal "l1\nX2\ni\nl3\n", File.read(path)
    # anchor works for delete_lines too
    u3 = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 3,
                                            'mode' => 'delete_lines',
                                            'start_line' => 4, 'end_line' => 5,
                                            'anchor' => "l3\n"))
    assert u3['changed']
    assert_equal "l1\nX2\ni\n", File.read(path)
  end

  def test_update_anchor_mismatch_rejects_and_leaves_store_untouched
    r = run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'AM',
                                           'content' => "l1\nl2\nl3\n"))
    id = r['id']
    path = File.join(@root, 'hypotheses', id, 'README.md')
    # msg-488 failure shape: caller holds a stale anchor (the document
    # already moved on) — must be rejected, not spliced.
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_lines',
                                         'start_line' => 2, 'end_line' => 3,
                                         'anchor' => "OPEN — investigating.\n",
                                         'replacement' => "Status: resolved.\n"))
    end
    assert_match(/anchor mismatch/, e.message)
    # the message quotes the observed span so the caller can re-anchor
    assert_match(/lines \[2, 3\) currently read "l2\\n"/, e.message)
    assert_match(/the anchor was "OPEN — investigating\.\\n"/, e.message)
    assert_match(/document has 3 line\(s\)/, e.message)
    # rejected edit: no revision staged, bytes untouched
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision'],
                 'rejected anchor must leave the revision history untouched'
    assert_equal "l1\nl2\nl3\n", File.read(path)
  end

  def test_update_stale_revision_rejected
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'S', 'content' => "# S\n"))
    id = r['id']
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2, 'mode' => 'replace_document', 'content' => "# S2\n"))
    end
    assert_match(/StaleRevision|expected revision|expected_revision/i, e.message)
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision'], 'rejected edit must leave the revision alone'
    # bump then try the stale one
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document', 'content' => "# S2\n"))
    e2 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document', 'content' => "# S3\n"))
    end
    assert_match(/StaleRevision|expected revision|expected_revision/i, e2.message)
    assert_equal 2, run_task(:dossier_read, @p.merge('id' => id))['current_revision']
  end

  def test_concurrent_edit_race_rejected_for_loser
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'R', 'content' => "# R\n"))
    id = r['id']
    # Two racing edits both expecting revision 1: one wins under the lock,
    # the loser must be rejected, not silently merged.
    winner = nil
    loser_error = nil
    t1 = Thread.new do
      begin
        winner = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document', 'content' => "# winner\n"))
      rescue ParameterException => e
        loser_error = e
      end
    end
    t2 = Thread.new do
      begin
        winner = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document', 'content' => "# loser\n"))
      rescue ParameterException => e
        loser_error = e
      end
    end
    t1.join
    t2.join
    assert (winner && winner['changed'] == true) || loser_error, 'one racer must succeed or the other must be rejected'
    assert_equal 2, run_task(:dossier_read, @p.merge('id' => id))['current_revision'], 'exactly one revision bump may land'
    final = run_task(:dossier_read, @p.merge('id' => id))['content']
    assert ["# winner\n", "# loser\n"].include?(final), 'exactly one racing edit must land'
  end

  def test_update_delete_lines_mode
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'D',
                                           'content' => "a\nb\nc\n"))
    id = r['id']
    # delete line 3: one-based half-open [3,4)
    d = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                           'mode' => 'delete_lines',
                                           'start_line' => 3, 'end_line' => 4))
    assert_equal(2, d['revision'])
    doc = run_task(:dossier_read, @p.merge('id' => id))
    assert_equal("a\nb\n", doc['content'])

    # delete_lines must not silently swallow a supplied replacement: the
    # one-pass per-mode contract reports the forbidden input together
    # with everything else wrong in the call.
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                         'mode' => 'delete_lines',
                                         'start_line' => 1, 'end_line' => 1,
                                         'replacement' => "x\n"))
    end
    assert_match(/mode delete_lines requires start_line, end_line; unexpected: replacement/, e.message)
  end

  def test_update_unknown_mode_and_missing_content
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'M', 'content' => "# M\n"))
    id = r['id']
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'frobnicate'))
    end
    assert_match(/unknown update mode/, e.message)
    # the one-pass per-mode contract replaces the old serial
    # "content is required" from deep inside the transaction
    e2 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document'))
    end
    assert_match(/mode replace_document requires content; missing: content/, e2.message)
  end

  # ---- document path security (Manager ruling 4) ----------------  # ---- v3 audit regressions (D2/D3/D4) ----------------------------

  def test_update_v3_wrong_span_with_anchor_is_rejected
    # T3 — msg-317 shape: fresh read, WRONG span relative to that read
    # (needed [32,36), called [31,35)), no remediation by positional
    # editing. WITH the anchor quoting the intended block text, the
    # mismatch must reject before staging, quoting the observed span.
    content = ("FILLER\n" * 31) + "alpha\nbeta\ngamma\ndelta\n" + ("TAIL\n" * 10)
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'V3A', 'content' => content))
    id = r['id']
    path = File.join(@root, 'questions', id, 'README.md')
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_lines',
                                         'start_line' => 31, 'end_line' => 35,
                                         'anchor' => "alpha\nbeta\ngamma\ndelta\n",
                                         'replacement' => "alpha2\nbeta2\ngamma2\ndelta2"))
    end
    assert_match(/anchor mismatch/, e.message)
    # the message quotes the OBSERVED span, not the anchor
    assert_match(/lines \[31, 35\) currently read "FILLER\\nalpha\\nbeta\\ngamma\\n"/, e.message)
    assert_equal 1, run_task(:dossier_read, @p.merge('id' => id))['current_revision'],
                 'rejected anchor must leave the store untouched'
    assert_equal content, File.read(path)
  end

  def test_update_v3_wrong_span_without_anchor_echoes_retained_tail
    # T4 — the same call WITHOUT an anchor succeeds (positional editing
    # is a legitimate mode); the after-state echo must make the retained
    # old tail visible so the wrong span can be SEEN from the payload:
    # 4-line replacement spliced over 4 lines, first tail line 'delta'
    # survives as its own line (normalization prevents the merge).
    content = ("FILLER\n" * 31) + "alpha\nbeta\ngamma\ndelta\n" + ("TAIL\n" * 10)
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'V3B', 'content' => content))
    id = r['id']
    path = File.join(@root, 'questions', id, 'README.md')
    u = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                           'mode' => 'replace_lines',
                                           'start_line' => 31, 'end_line' => 35,
                                           'replacement' => "alpha2\nbeta2\ngamma2\ndelta2"))
    assert u['changed']
    assert_equal 2, u['revision']
    echo = u['update_echo']
    assert_equal 4, echo['lines_removed']
    assert_equal 4, echo['lines_inserted']
    assert_equal 45, echo['total_lines']
    assert echo['newline_normalized'], 'replacement lacking a trailing newline must be flagged'
    # the retained OLD line 'delta' is visible in the context excerpt
    assert(echo['context'].any? { |l| l.include?('  35: delta') },
           'context must show the surviving old first-tail line')
    assert(File.read(path).include?("delta2\ndelta\n"),
           'normalization must prevent the merged-line corruption')
  end

  def test_update_newline_normalization_rules
    # T5 — replacement without trailing newline, tail follows: no merged
    # line in the result; flagged in the payload. Span at EOF: no
    # normalization, exact bytes. CRLF: the adjacent terminator is
    # reused, not replaced by "\n".
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'NN',
                                           'content' => "l1\nl2\nl3\nl4\nl5\n"))
    id = r['id']
    path = File.join(@root, 'questions', id, 'README.md')
    u1 = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                            'mode' => 'replace_lines',
                                            'start_line' => 2, 'end_line' => 3,
                                            'replacement' => 'X2'))
    assert u1['update_echo']['newline_normalized']
    assert_equal "l1\nX2\nl3\nl4\nl5\n", File.read(path)

    # span at EOF (end_line = total + 1): byte-exact, no normalization
    u2 = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                            'mode' => 'replace_lines',
                                            'start_line' => 5, 'end_line' => 6,
                                            'replacement' => 'l5NOBREAK'))
    refute u2['update_echo']['newline_normalized']
    assert_equal 'none (span at end of document)', u2['update_echo']['tail_after_span']
    assert_equal "l1\nX2\nl3\nl4l5NOBREAK".sub('l4', "l4\n"), File.read(path)

    # CRLF document: terminator of the last removed line ("\r\n") reused
    r2 = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'CRLF',
                                            'content' => "a\r\nb\r\nc\r\n"))
    p2 = File.join(@root, 'claims', r2['id'], 'README.md')
    u3 = run_task(:dossier_update, @p.merge('id' => r2['id'], 'expected_revision' => 1,
                                            'mode' => 'replace_lines',
                                            'start_line' => 2, 'end_line' => 3,
                                            'replacement' => 'B'))
    assert u3['update_echo']['newline_normalized']
    assert_equal "a\r\nB\r\nc\r\n", File.binread(p2)
  end

  def test_update_anchor_limitations_documented_by_tests
    # T6 — D3b limitations the docs now state: an anchor verifies the
    # CURRENT text of the stated span only. It cannot distinguish
    # identical text at two positions, and an empty span's anchor is
    # always '' (no position protection for insertions).
    content = "head\ndup\ntail\ndup\n"
    r = run_task(:dossier_create, @p.merge('type' => 'hypothesis', 'title' => 'AL',
                                           'content' => content))
    id = r['id']
    path = File.join(@root, 'hypotheses', id, 'README.md')
    # identical text at two positions: anchor succeeds at the STATED one
    u = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                           'mode' => 'replace_lines',
                                           'start_line' => 4, 'end_line' => 5,
                                           'anchor' => "dup\n",
                                           'replacement' => "second\n"))
    assert u['changed']
    assert_equal "head\ndup\ntail\nsecond\n", File.read(path)
    # empty-span anchor '' matches at [n,n): always succeeds, no position
    # protection — insertions rely on start_line alone
    u2 = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                            'mode' => 'replace_lines',
                                            'start_line' => 5, 'end_line' => 5,
                                            'anchor' => '',
                                            'replacement' => "append\n"))
    assert u2['changed']
    assert_equal "head\ndup\ntail\nsecond\nappend\n", File.read(path)
  end

  def test_update_mismatch_remediation_points_at_re_anchor
    # D3a — the remediation text must steer to re-read + corrected span
    # with an anchor, NEVER to positional (anchor-less) editing.
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'RM',
                                           'content' => "l1\nl2\nl3\n"))
    id = r['id']
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                         'mode' => 'replace_lines',
                                         'start_line' => 2, 'end_line' => 3,
                                         'anchor' => "stale\n", 'replacement' => "x\n"))
    end
    assert_match(/re-read the document, then retry with the corrected span and an anchor/, e.message)
    refute_match(/omit the anchor/i, e.message)
  end

  # ---- document path security (Manager ruling 4) ----------------

  def test_document_path_restrictions
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'P', 'content' => "# P\n"))
    id = r['id']
    bad_names = [
      '/etc/passwd',
      'store/history/r1.json',
      'meta/Q-001.current',
      'store/objects/abc',
      'evidence/file.bin',
      'evidence',
      'a/../b.md',
      '../escape.md',
      './README.md',
      # NOTE: 'supplements/nested/inner.md' is now VALID (WO-4 Manager
      # ruling 1: nested supplements supported); it moved to the positive
      # nested-supplements test.
      'supplements/',
      ''
    ]
    bad_names.each do |name|
      e = assert_raise(ParameterException, "document #{name.inspect} must be rejected") do
        run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'create_document',
                                           'document' => name, 'content' => 'x'))
      end
      assert_match(/document|evidence|reserved|supplement/, e.message)
    end
    # accepted name with spaces and non-ASCII (not a character allowlist)
    ok = run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'create_document',
                                            'document' => 'supplements/café notes.md', 'content' => "ok\n"))
    assert ok['changed']
    rd = run_task(:dossier_read, @p.merge('id' => id, 'document' => 'supplements/café notes.md'))
    assert_equal "ok\n", rd['content']
  end

  # ---- root identity and isolation ------------------------------

  def test_results_pin_store_directory
    r = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'RI'))
    assert_equal File.join(@root, 'questions', r['id']),
                 File.dirname(r['link'][/\((.*)\)\z/, 1])
    refute r.key?('root'); refute r.key?('root_source'); refute r.key?('directory')
  end

  def test_two_projects_distinct_id_spaces
    a = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'A'))
    b = run_task(:dossier_create, { 'type' => 'question', 'title' => 'B' }, project: @project2)
    assert_equal 'Q-001', a['id']
    assert_equal 'Q-001', b['id'], 'each project allocates its own ID space'
    assert_not_equal File.dirname(a['link'][/\((.*)\)\z/, 1]),
                     File.dirname(b['link'][/\((.*)\)\z/, 1])
    assert_equal 1, run_task(:dossier_list, @p)['total']
    assert_equal 1, run_task(:dossier_list, {}, project: @project2)['total']
    # cross-root read is a miss
    e = assert_raise(ParameterException) do
      run_task(:dossier_read, { 'id' => 'Q-002' }, project: @project2)
    end
    assert_match(/no current revision|Missing/, e.message)
  end

  # ---- exported dispatch (LLM.call_workflow) ---------------------

  def test_exported_dispatch_end_to_end
    r = dispatch('dossier_create', @p.merge('type' => 'question', 'title' => 'EX', 'content' => "# EX\n\nbody\n"))
    assert_equal 'Q-001', r['id']
    l = dispatch('dossier_list', @p)
    assert_equal 'EX', l['dossiers'].first['title']
    rd = dispatch('dossier_read', @p.merge('id' => 'Q-001', 'start_line' => 3))
    assert_equal "body\n", rd['content']
    u = dispatch('dossier_update', @p.merge('id' => 'Q-001', 'expected_revision' => 1, 'mode' => 'replace_lines',
                                            'start_line' => 3, 'end_line' => 4, 'replacement' => "edited\n"))
    assert_equal 2, u['revision']
    # exported dispatch returns errors as values, not raises
    err = dispatch('dossier_read', @p.merge('id' => 'Q-999'))
    assert err.is_a?(ScoutException), 'Scout exceptions become structured error values on the exec path'
  end

  def test_json_round_trip_through_dispatch_coercion
    # T8 — the model-facing layer. Arguments travel as JSON text; the
    # runtime bridge (scout-ai Scout::LLM::Tools::Workflow.call_workflow,
    # lines 139-143) parses the payload and DROPS keys whose value is ''
    # ("Some models use '' for optional parameters"), so an omitted key
    # and an empty string are the same thing by the time the task runs.
    # The real bridge IS loadable here (scout-ai is required by this
    # test), and dispatch() calls it through LLM.call_workflow — so the
    # coercion is exercised for real, not replicated.
    r = dispatch('dossier_create',
                 JSON.parse(JSON.generate('type' => 'question', 'title' => 'JRT',
                                          'content' => "l1\nl2\nl3\n")))
    id = r['id']
    path = File.join(@root, 'questions', id, 'README.md')

    # (1) end_line dropped by JSON ('' is the only way to "send nothing")
    # and by the bridge ('' rejected before the job) -> contract error
    e = dispatch('dossier_update',
                 JSON.parse(JSON.generate('id' => id, 'expected_revision' => 1,
                                          'mode' => 'replace_lines',
                                          'start_line' => 2, 'end_line' => '',
                                          'replacement' => "X2\n")))
    assert e.is_a?(ScoutException)
    assert_match(/missing: end_line/, e.message)
    assert_equal "l1\nl2\nl3\n", File.read(path)

    # (2) empty-string mode -> the bridge drops it -> "mode is required"
    e2 = dispatch('dossier_update',
                  JSON.parse(JSON.generate('id' => id, 'expected_revision' => 1,
                                           'mode' => '',
                                           'start_line' => 2, 'end_line' => 3,
                                           'replacement' => "X2\n")))
    assert e2.is_a?(ScoutException)
    assert_match(/mode is required; one of: /, e2.message)

    # (3) multiline replacement without trailing newline -> normalized
    u = dispatch('dossier_update',
                 JSON.parse(JSON.generate('id' => id, 'expected_revision' => 1,
                                          'mode' => 'replace_lines',
                                          'start_line' => 2, 'end_line' => 3,
                                          'replacement' => "n1\nn2")))
    assert_equal 2, u['revision']
    assert u['update_echo']['newline_normalized']
    assert_equal "l1\nn1\nn2\nl3\n", File.read(path)
  end
end

