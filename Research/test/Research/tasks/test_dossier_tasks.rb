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

    # delete_lines must not silently swallow a supplied replacement
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                         'mode' => 'delete_lines',
                                         'start_line' => 1, 'end_line' => 1,
                                         'replacement' => "x\n"))
    end
    assert_match(/replacement must be omitted for delete_lines/, e.message)
  end

  def test_update_unknown_mode_and_missing_content
    r = run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'M', 'content' => "# M\n"))
    id = r['id']
    e = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'frobnicate'))
    end
    assert_match(/unknown update mode/, e.message)
    e2 = assert_raise(ParameterException) do
      run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1, 'mode' => 'replace_document'))
    end
    assert_match(/content is required/, e2.message)
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
end
  def test_nested_supplement_documents_any_depth
    c = run_task(:dossier_create, @p.merge('type' => 'question', 'title' => 'Nested'))
    id = c['id']
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 1,
                                       'mode' => 'create_document',
                                       'document' => 'supplements/nested/inner.md',
                                       'content' => "# inner\n"))
    run_task(:dossier_update, @p.merge('id' => id, 'expected_revision' => 2,
                                       'mode' => 'create_document',
                                       'document' => 'supplements/a/b/c/deep.md',
                                       'content' => "# deep\n"))
    rd = run_task(:dossier_read, @p.merge('id' => id,
                                          'document' => 'supplements/a/b/c/deep.md'))
    assert_equal "# deep\n", rd['content']
    ls = run_task(:dossier_list, @p.merge('query' => 'inner'))
    assert ls['items'].any? { |i| i['id'] == id }
  end

