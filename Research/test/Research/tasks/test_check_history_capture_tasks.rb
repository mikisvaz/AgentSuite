# Task-layer tests for the WO-5 surface: dossier_check, dossier_history,
# dossier_capture — exercised through ACTUAL registration/export (fresh
# jobs via Research.job(...).exec and LLM.call_workflow dispatch), plus
# the two ruled amendments (batch cap, sweep-orphan safety at the store
# level, as ruled).
require 'test/unit'
require 'fileutils'
require 'scout'
require 'scout-ai'
require 'json'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'Research', 'lib'))
require File.join(ROOT, 'Research', 'workflow')
require File.join(ROOT, 'Research', 'test', 'support', 'dossier_fixtures')

class TestCheckHistoryCaptureTasks < Test::Unit::TestCase
  include DossierFixtureTeardown

  def setup
    @project = DossierFixtures.scaffold_project('check_tasks')
    @root = File.join(@project, 'research')
    @sources = File.join(File.dirname(@project), 'sources')
    @p = {}
    @create = run_task(:dossier_create,
                       @p.merge('type' => 'question', 'title' => 'WO-5',
                                'content' => "# WO-5\n\none\ntwo\nthree\n"))
    @id = @create['id']
    @rev = @create['revision']
    @dir = File.join(@root, 'questions', @id)
  end

  def run_task(task, params)
    DossierFixtures.in_project(@project) { Research.job(task, nil, **params).exec }
  end

  # The exported-call dispatch path (what an agent's workflow tool
  # actually invokes), same contract as the dossier suite.
  def dispatch(task, params)
    DossierFixtures.in_project(@project) { LLM.call_workflow(Research, task, params) }
  end

  def check(extra = {})
    run_task(:dossier_check, @p.merge(extra))
  end

  def history(extra = {})
    run_task(:dossier_history, @p.merge('id' => @id).merge(extra))
  end

  def update(params)
    run_task(:dossier_update,
             @p.merge('id' => @id).merge(params))
  end

  def tree_digest(dir)
    entries = []
    Dir.glob(File.join(dir, '**', '*')).sort.each do |p|
      if File.file?(p)
        entries << [p, File.binread(p).length,
                    Digest::SHA256.file(p).hexdigest]
      elsif File.directory?(p)
        entries << [p, :dir]
      end
    end
    Digest::SHA256.hexdigest(entries.inspect)
  end

  # ---- registration / export ---------------------------------------

  def test_tasks_are_registered_and_exported
    assert_equal %w[dossier_capture dossier_check dossier_create
                    dossier_history dossier_list dossier_read dossier_update
                    evidence_attach evidence_read],
                 Research.tasks.keys.map(&:to_s).sort
    %w[dossier_check dossier_history dossier_capture].each do |t|
      assert_include Research.exec_exports.map(&:to_s), t
    end
    # through the dispatch surface (same process; cwd is the project)
    out = DossierFixtures.in_project(@project) do
      LLM.call_workflow(Research, :dossier_check, { 'id' => @id })
    end
    assert_equal 'ok', out['dossiers'].first['status']
  end

  # ---- dossier_check ------------------------------------------------

  def test_check_healthy_dossier_is_ok_and_never_mutates
    before = tree_digest(@root)
    out = check('id' => @id)
    d = out['dossiers'].first
    assert_equal 'ok', d['status']
    assert_equal 0, d['finding_count']
    assert out['not_checked'].any? { |s| s.include?('scientific validity') }
    assert out['not_checked'].any? { |s| s.include?('web') }
    after = tree_digest(@root)
    assert_equal before, after
  end

  def test_check_reports_view_drift_reference_change_and_broken_link
    # commit a document whose link target does not exist (record-level
    # finding), then attach a reference and change its source
    upd = update('expected_revision' => @rev, 'mode' => 'replace_document',

                 'content' => "# WO-5\n\nsee [Q-009](Q-009/README.md)\n")
    src = File.join(@sources, 'table.tsv')
    attach = run_task(:evidence_attach,
                      @p.merge('id' => @id,
                               'expected_revision' => upd['revision'],
                               'items' => JSON.generate(
                                 [{ 'source' => src, 'slot' => 'data',
                                    'mode' => 'reference' }]
                               )))
    assert_equal 3, attach['revision']
    # external drift on the committed document
    File.binwrite(File.join(@dir, 'README.md'), "# WO-5\n\ndrifted\n")
    # reference source changed after attach
    File.binwrite(src, "#\tkey\tvalue\nrowX\tmutated\t9\n")
    out = check('id' => @id)
    cats = out['dossiers'].first['findings'].map { |f| f['category'] }
    assert_include cats, 'view_drift'
    assert_include cats, 'reference_changed'
    assert_include cats, 'local_link_broken'
    assert_equal 'findings', out['dossiers'].first['status']
  end

  def test_check_reports_missing_reference_and_corrupted_copy
    src_copy = File.join(@sources, 'note.md')
    src_ref = File.join(@sources, 'meta.json')
    run_task(:evidence_attach,
             @p.merge('id' => @id, 'expected_revision' => @rev,
                      'items' => JSON.generate(
                        [{ 'source' => src_copy, 'slot' => 'a', 'mode' => 'copy' },
                         { 'source' => src_ref, 'slot' => 'b', 'mode' => 'reference' }]
                      )))
    # corrupt the retained bytes on disk: the digest-addressed object is
    # what the retention guarantee covers; the view is a materialization
    record = JSON.parse(File.read(Dir.glob(File.join(@dir, 'store', 'history', '*.json')).sort.last))
    att = record['attachments'].values.find { |i| i['name'] == 'note.md' }
    obj = File.join(@dir, 'store', 'objects', att['digest'])
    assert File.file?(obj), 'retained object path'
    File.binwrite(obj, "# Working note\n\nCORRUPTED\n")
    # remove the reference source
    FileUtils.rm(src_ref)
    out = check('id' => @id)
    cats = out['dossiers'].first['findings'].map { |f| f['category'] }
    assert_include cats, 'copy_corrupted'
    assert_include cats, 'reference_missing'
  end

  def test_check_metadata_inconsistency_detected_not_crash
    # corrupt the current pointer deliberately: point at a missing revision
    pointer = File.join(@root, 'meta', "#{@id}.current")
    assert File.file?(pointer)
    File.binwrite(pointer, "9\n")
    out = check('id' => @id)
    d = out['dossiers'].first
    assert_equal 'findings', d['status']
    assert d['findings'].any? { |f| f['category'] == 'metadata' }
  end

  def test_check_scoped_selection_by_type_and_bounded
    run_task(:dossier_create, @p.merge('type' => 'claim', 'title' => 'C1',
                                       'content' => "# C1\n"))
    out = check('type' => 'question')
    assert_equal 1, out['checked']
    out = check
    assert out['checked'] >= 2
    bounded = check('limit' => 1)
    assert_equal 1, bounded['checked']
    assert bounded['has_more']
    assert bounded['continuation']
    page2 = check('limit' => 1, 'continuation' => bounded['continuation'])
    assert_equal 1, page2['checked']
  end

  # ---- dossier_history ----------------------------------------------

  def test_history_inventory_and_attachment_identities
    src = File.join(@sources, 'table.tsv')
    attach1 = run_task(:evidence_attach,
                       @p.merge('id' => @id, 'expected_revision' => @rev,
                                'items' => JSON.generate(
                                  [{ 'source' => src, 'slot' => 'data',
                                     'mode' => 'copy' }]
                                )))
    upd = update('expected_revision' => attach1['revision'],
                 'mode' => 'replace_lines',
                 'start_line' => 2, 'end_line' => 3,
                 'replacement' => "TWO\n", 'change_note' => 'line edit')
    out = history
    revs = out['revisions'].map { |r| r['revision'] }.sort
    assert_equal [1, 2, 3], revs
    assert_equal 3, out['total_revisions']
    r3 = out['revisions'].find { |r| r['revision'] == 3 }
    assert_equal 'line edit', r3['change_note']
    # attachments appear as identity/digest entries only — no content
    r2 = out['revisions'].find { |r| r['revision'] == 2 }
    assert r2['attachments'].any? { |a| a['key'] == 'data/table.tsv' }
    assert_equal 'data/table.tsv', r2['attachments'].first['key']
    assert r2['attachments'].first['digest']
    assert_equal %w[digest key mode size], r2['attachments'].first.keys.sort
    out_json = JSON.generate(out)
    refute out_json.include?('row1'), 'binary/table content must not leak'
  end

  def test_history_diff_between_revisions
    # r1 README.md lines: 1 '# WO-5', 2 '', 3 'one', 4 'two', 5 'three'
    update('expected_revision' => @rev, 'mode' => 'replace_lines',
           'start_line' => 4, 'end_line' => 5,
           'replacement' => "TWO\n")
    update('expected_revision' => 2, 'mode' => 'replace_lines',
           'start_line' => 5, 'end_line' => 6,
           'replacement' => "three\nfour\n")
    out = history('diff_document' => 'README.md',
                  'from_revision' => 1, 'to_revision' => 3)
    hunks = out['diff']['hunks']
    # LCS alignment keeps 'three' aligned; two separate hunks result.
    assert_equal 2, hunks.length
    h1, h2 = hunks
    assert_equal 4, h1['start']
    assert_equal 5, h1['end']
    assert_equal 4, h1['old_start']
    assert_equal 5, h1['old_end']
    assert_equal ["two\n"], h1['removed']
    assert_equal ["TWO\n"], h1['added']
    assert_equal 6, h2['start']
    assert_equal 7, h2['end']
    assert_equal 6, h2['old_start']
    assert_equal 6, h2['old_end']
    assert_equal [], h2['removed']
    assert_equal ["four\n"], h2['added']
  end

  def test_history_continuation_bounds
    update('expected_revision' => @rev, 'mode' => 'replace_document',
 'content' => "# WO-5\n\nv2\n")
    update('expected_revision' => 2, 'mode' => 'replace_document',
 'content' => "# WO-5\n\nv3\n")
    page1 = history('limit' => 2)
    assert_equal 2, page1['revisions'].length
    assert page1['has_more']
    assert_equal '2', page1['continuation']
    page2 = history('limit' => 2, 'continuation' => '2')
    assert_equal 1, page2['revisions'].length
    refute page2['has_more']
  end

  def test_history_attachment_identity_changes_across_replacement
    src = File.join(@sources, 'table.tsv')
    run_task(:evidence_attach,
             @p.merge('id' => @id, 'expected_revision' => @rev,
                      'items' => JSON.generate(
                        [{ 'source' => src, 'slot' => 'data', 'mode' => 'copy' }]
                      )))
    File.binwrite(src, "#\tkey\tvalue\nrowR\treplaced\t7\n")
    rep = run_task(:evidence_attach,
                   @p.merge('id' => @id, 'expected_revision' => 2,
                            'items' => JSON.generate(
                              [{ 'source' => src, 'slot' => 'data',
                                 'mode' => 'copy', 'replace' => true }]
                            )))
    assert_equal 3, rep['revision']
    out = history
    r2 = out['revisions'].find { |r| r['revision'] == 2 }
    r3 = out['revisions'].find { |r| r['revision'] == 3 }
    old_sha = r2['attachments'].first['digest']
    new_sha = r3['attachments'].first['digest']
    refute_equal old_sha, new_sha
  end

  # ---- dossier_capture ----------------------------------------------

  def test_capture_adopts_drift_with_observed_digests_and_preserves_history
    update('expected_revision' => @rev, 'mode' => 'replace_lines',
 'start_line' => 3, 'end_line' => 4,
           'replacement' => "three\nthree-and-a-half\n")
    external = "# WO-5\n\none\ntwo\nthree\nEXTERNAL EDIT\n"
    File.binwrite(File.join(@dir, 'README.md'), external)
    # ordinary update must refuse (no silent adoption)
    err = assert_raise(ParameterException) do
      update('expected_revision' => 2, 'mode' => 'replace_lines',
             'start_line' => 1, 'end_line' => 2,
             'replacement' => "X\n")
    end
    assert err.message.include?('Drift') || err.message.include?('drift')
    cap = run_task(:dossier_capture,
                   @p.merge('id' => @id, 'expected_revision' => 2,
                            'documents' => 'all', 'change_note' => 'adopt'))
    assert_equal 3, cap['revision']
    assert_equal true, cap['changed']
    assert cap['captured_documents']['README.md']['observed_digest']
    # drift is gone: check reports ok now
    out = check('id' => @id)
    assert_equal 'ok', out['dossiers'].first['status']
    # prior revisions intact and unchanged
    old = run_task(:dossier_read, @p.merge('id' => @id,

                                           'revision' => 1))
    assert old['content'].include?("three\n")
    refute old['content'].include?('EXTERNAL')
  end

  def test_capture_rejects_stale_expected_revision
    File.binwrite(File.join(@dir, 'README.md'), "# WO-5\n\nmutated\n")
    err = assert_raise(ParameterException) do
      run_task(:dossier_capture,
               @p.merge('id' => @id, 'expected_revision' => 99,
                        'documents' => 'all'))
    end
    assert err.message.include?('revision')
  end

  def test_capture_rejects_when_evidence_corrupted
    src = File.join(@sources, 'note.md')
    run_task(:evidence_attach,
             @p.merge('id' => @id, 'expected_revision' => @rev,
                      'items' => JSON.generate(
                        [{ 'source' => src, 'slot' => 'a', 'mode' => 'copy' }]
                      )))
    retained = Dir.glob(File.join(@dir, 'evidence', '**', 'note.md')).first
    File.binwrite(retained, "# Working note\n\nCORRUPTED\n")
    File.binwrite(File.join(@dir, 'README.md'), "# WO-5\n\nexternally edited\n")
    err = assert_raise(ParameterException) do
      run_task(:dossier_capture,
               @p.merge('id' => @id, 'expected_revision' => 2,
                        'documents' => 'all'))
    end
    assert err.message.include?('corrupt')
    # the dossier must be at the prior revision (no laundered capture)
    out = history
    assert_equal 2, out['current_revision']
  end

  def test_partial_capture_leaves_both_edits_in_place
    readme = File.join(@dir, 'README.md')
    relative = 'supplements/nested/deep/note.md'
    note = File.join(@dir, relative)
    FileUtils.mkdir_p(File.dirname(note))
    File.binwrite(readme, "# Edited\n")
    File.binwrite(note, "Uncommitted note\n")
    params = { 'id' => @id, 'expected_revision' => @rev }
    err = assert_raise(ParameterException) do
      run_task(:dossier_capture, params.merge('documents' => 'README.md'))
    end
    assert_include err.message, relative
    assert_equal "# Edited\n", File.binread(readme)
    assert_equal "Uncommitted note\n", File.binread(note)
    cap = run_task(:dossier_capture, params)
    assert_equal "Uncommitted note\n", File.binread(note)
    File.unlink(note)
    deleted = run_task(:dossier_capture, params.merge('expected_revision' => cap['revision']))
    assert_nil deleted['captured_documents'].fetch(relative)['observed_digest']
    assert_not_include deleted['documents'].keys, relative
  end

  def test_capture_rejects_damaged_object_even_with_intact_evidence_view
    src = File.join(@sources, 'note.md')
    item = run_task(:evidence_attach, 'id' => @id, 'expected_revision' => @rev,
                    'items' => JSON.generate([{ 'source' => src, 'slot' => 'data' }]))['items'].first
    File.binwrite(item.fetch('retained_location'), 'damaged object')
    File.binwrite(File.join(@dir, 'README.md'), "# External edit\n")
    assert_raise(ParameterException) do
      run_task(:dossier_capture, 'id' => @id, 'expected_revision' => item['revision'])
    end
    assert_equal item['revision'], history['current_revision']
    assert_equal File.binread(src), File.binread(File.join(@dir, 'evidence', item['attachment']))
  end

  def test_capture_without_drift_rejected
    err = assert_raise(ParameterException) do
      run_task(:dossier_capture,
               @p.merge('id' => @id, 'expected_revision' => @rev,
                        'documents' => 'all'))
    end
    assert err.message.include?('drift')
  end

  # ---- ruled amendment: batch cap -----------------------------------

  # ---- nofile regression: document-name literals must not be replaced  # T5 (unit variant): a legitimate selection exceeding 100 documents
  # still raises the cap error — building 101 supplements through the API
  # is too slow for the suite, so the rule is pinned directly here.
  def test_capture_documents_over_cap_still_raises
    big = (1..101).map { |i| "supplements/p#{i}.md" }
    e = assert_raise(ParameterException) do
      Research.parse_capture_documents(JSON.generate(big))
    end
    assert_match(/too many documents to capture \(101; cap 100\)/, e.message)
    refute_match(/README/, e.message) # no file contents leaked in
  end

  # ---- nofile regression: document-name literals must not be replaced
  # by file CONTENTS (scout-gear Task.format_input substitutes a :string
  # literal that names an existing cwd-relative file when the input lacks
  # nofile; the dossier store plants README.md in the project cwd, so the
  # collision is self-inflicted — v4 hit this with documents:"README.md",
  # parsing the whole README as a 935-entry document list).

  def test_capture_documents_literal_readme_is_not_substituted_by_contents
    external = "# WO-5\n\none\ntwo\nEXTERNAL EDIT\n"
    File.binwrite(File.join(@dir, 'README.md'), external)
    cap = dispatch(:dossier_capture,
                   'id' => @id, 'expected_revision' => @rev,
                   'documents' => 'README.md')
    assert_equal 2, cap['revision']
    assert_equal true, cap['changed']
    assert_equal %w[README.md], cap['documents'].keys
    assert cap['captured_documents']['README.md']['observed_digest']
    read = run_task(:dossier_read, @p.merge('id' => @id))
    assert_equal external, read['content']
  end

  def test_capture_documents_json_array_form_parity
    external = "# WO-5\n\none\ntwo\nEXTERNAL EDIT\n"
    File.binwrite(File.join(@dir, 'README.md'), external)
    cap = dispatch(:dossier_capture,
                   'id' => @id, 'expected_revision' => @rev,
                   'documents' => '["README.md"]')
    assert_equal %w[README.md], cap['documents'].keys
    assert_equal 2, cap['revision']
  end

  def test_capture_documents_comma_list_captures_both
    FileUtils.mkdir_p(File.join(@dir, 'supplements'))
    File.binwrite(File.join(@dir, 'README.md'), "# WO-5\n\nDRIFT\n")
    File.binwrite(File.join(@dir, 'supplements', 'notes.md'), "# notes\n\nDRIFT\n")
    cap = dispatch(:dossier_capture,
                   'id' => @id, 'expected_revision' => @rev,
                   'documents' => 'README.md, supplements/notes.md')
    assert_equal %w[README.md supplements/notes.md].sort,
                 cap['documents'].keys.sort
  end

  def test_capture_documents_all_captures_all_authored_documents
    FileUtils.mkdir_p(File.join(@dir, 'supplements'))
    File.binwrite(File.join(@dir, 'README.md'), "# WO-5\n\nDRIFT\n")
    File.binwrite(File.join(@dir, 'supplements', 'notes.md'), "# notes\n\nDRIFT\n")
    cap = dispatch(:dossier_capture,
                   'id' => @id, 'expected_revision' => @rev,
                   'documents' => 'all')
    assert_equal %w[README.md supplements/notes.md].sort,
                 cap['documents'].keys.sort
  end

  # diff_document is the sibling demonstrated case (v3): with nofile the
  # NAME reaches the task and the history diff is normal, not a 45 kB blob.
  def test_history_diff_document_literal_name_reaches_task
    external = "# WO-5\n\none\ntwo\nEXTERNAL EDIT\n"
    File.binwrite(File.join(@dir, 'README.md'), external)
    dispatch(:dossier_capture, 'id' => @id, 'expected_revision' => @rev,
                               'documents' => 'README.md')
    out = dispatch(:dossier_history, 'id' => @id,
                                     'diff_document' => 'README.md')
    assert out['diff']
    assert_equal 'README.md', out['diff']['document']
    assert_operator out['diff'].to_s.length, :<, 2000,
                    'history diff must not embed file contents in errors'
  end

  # ---- ruled amendment: batch cap -----------------------------------

  def test_evidence_attach_batch_cap_is_100
    items = (1..101).map do |i|
      { 'source' => File.join(@sources, 'note.md'),
        'slot' => "slot#{i}", 'mode' => 'copy' }
    end
    err = assert_raise(ParameterException) do
      attach_items(items)
    end
    assert err.message.include?('100')
    assert err.message.include?('split')
  end

  def attach_items(items)
    run_task(:evidence_attach,
             @p.merge('id' => @id, 'expected_revision' => @rev,
                      'items' => JSON.generate(items)))
  end

  # ---- ruled amendment: sweep_orphans! never drops referenced objects

  def test_sweep_orphans_never_drops_referenced_copies
    src = File.join(@sources, 'table.tsv')
    attach1 = run_task(:evidence_attach,
                       @p.merge('id' => @id, 'expected_revision' => @rev,
                                'items' => JSON.generate(
                                  [{ 'source' => src, 'slot' => 'data',
                                     'mode' => 'copy' }]
                                )))
    r1_key = attach1['items'].first['attachment']
    # replace the attachment (old object no longer current)
    File.binwrite(src, "#\tkey\tvalue\nrowR\tnew\t3\n")
    run_task(:evidence_attach,
             @p.merge('id' => @id, 'expected_revision' => 2,
                      'items' => JSON.generate(
                        [{ 'source' => src, 'slot' => 'data',
                           'mode' => 'copy', 'replace' => true }]
                      )))
    # sweep
    Research::Store.sweep_orphans!(Research::Layout.dossier_dir(
                                    @root, 'question', @id
                                  ))
    # BOTH versions must remain readable at their revisions (history
    # references both)
    r1 = run_task(:evidence_read, @p.merge('id' => @id,
                                           'attachment' => r1_key,
                                           'revision' => attach1['revision']))
    assert_equal 'ok', r1['integrity']['state']
    r3 = run_task(:evidence_read, @p.merge('id' => @id,
                                           'attachment' => r1_key,
                                           'revision' => 3))
    refute_equal r1['sha256'], r3['sha256']
    assert_equal 'ok', r3['integrity']['state']
  end
end
