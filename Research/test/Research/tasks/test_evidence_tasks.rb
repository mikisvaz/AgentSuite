# Task-layer tests for the evidence surface (WO-4): evidence_attach and
# evidence_read exercised through ACTUAL registration/export — fresh
# jobs (Research.job(...).exec) and LLM.call_workflow dispatch — never
# helper-only calls.
require 'test/unit'
require 'fileutils'
require 'scout'
require 'scout-ai'
require 'json'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'Research', 'lib'))
require File.join(ROOT, 'Research', 'workflow')
require File.join(ROOT, 'Research', 'test', 'support', 'dossier_fixtures')

class TestEvidenceTasksExported < Test::Unit::TestCase
  include DossierFixtureTeardown

  def setup
    @project = DossierFixtures.scaffold_project('evidence_tasks')
    @root = File.join(@project, 'research')
    @sources = File.join(File.dirname(@project), 'sources')
    @p = {}
    @base = {
      'type' => 'question', 'title' => 'Evidence test',
      'content' => "# Evidence test\n\nbody\n"
    }
    @create = run_task(:dossier_create, @base.merge(@p))
    @id = @create['id']
    @rev = @create['revision']
  end

  def run_task(task, params)
    DossierFixtures.in_project(@project) { Research.job(task, nil, params).exec }
  end

  def attach(items, expected = @rev, extra = {})
    run_task(:evidence_attach, @p.merge('id' => @id,
                                        'expected_revision' => expected,
                                        'items' => JSON.generate(items)).merge(extra))
  end

  def read_evidence(attachment, extra = {})
    run_task(:evidence_read, @p.merge('id' => @id,
                                      'attachment' => attachment).merge(extra))
  end

  def test_tasks_are_registered_and_exported
    assert_equal %w[dossier_capture dossier_check dossier_create
                    dossier_history dossier_list dossier_read dossier_update
                    evidence_attach evidence_read],
                 Research.tasks.keys.map(&:to_s).sort
    assert_include Research.exec_exports.map(&:to_s), 'evidence_attach'
    assert_include Research.exec_exports.map(&:to_s), 'evidence_read'
    # through the actual dispatch surface (same process; cwd is the project)
    out = DossierFixtures.in_project(@project) do
      LLM.call_workflow(Research, :evidence_attach,
                        { 'id' => @id, 'expected_revision' => @rev,
                          'items' => '[]' })
    end
    assert_include out.to_s, 'at least one attachment'
  end

  def test_copy_mode_retains_bytes_and_digest_from_retained
    tsv = File.join(@sources, 'table.tsv')
    out = attach([{ 'source' => tsv, 'slot' => 'data', 'mode' => 'copy',
                    'caption' => 'Counts per row' }])
    item = out['items'].first
    assert_equal 'copy', item['mode']
    assert_equal DossierFixtures.digest_of(tsv), item['sha256']
    assert File.file?(item['retained_location'])
    assert_equal DossierFixtures.digest_of(tsv),
                 DossierFixtures.digest_of(item['retained_location'])
    assert_match %r{data/table\.tsv}, item['attachment']
    assert_equal 2, out['revision'] # create was revision 1
    assert_equal 'retained bytes', item['verified']['basis']
  end

  def test_copy_mode_source_mutation_does_not_change_retained_copy
    src = File.join(@sources, 'note.md')
    out = attach([{ 'source' => src, 'slot' => 'data', 'mode' => 'copy' }])
    retained = out['items'].first['retained_location']
    digest_before = DossierFixtures.digest_of(retained)

    File.binwrite(src, "# MUTATED\n") # source drifts after acquisition
    rd = read_evidence('data/note.md')
    assert_equal 'ok', rd['integrity']['state']
    assert_equal digest_before, DossierFixtures.digest_of(retained)
    assert_equal digest_before, rd['sha256']
  end

  def test_binary_fixture_known_sha256
    bin = File.join(@sources, 'binary.bin')
    expected = Digest::SHA256.hexdigest(DossierFixtures::BINARY_BYTES)
    attach([{ 'source' => bin, 'slot' => 'data', 'mode' => 'copy' }])
    rd = read_evidence('data/binary.bin')
    assert_equal expected, rd['sha256']
    assert_equal DossierFixtures::BINARY_BYTES.bytesize, rd['size']
    assert_equal 'binary', rd['detected_type']
    assert rd['binary_note']
    assert_nil rd['content'] # never a text dump for binaries
  end

  def test_reference_mode_changed_source_reports_changed_never_substitutes
    src = File.join(@sources, 'reference.md')
    out = attach([{ 'source' => src, 'slot' => 'data', 'mode' => 'reference' }])
    assert_equal 'reference', out['items'].first['mode']
    old_digest = out['items'].first['sha256']

    File.binwrite(src, "# Reference\n\nMUTATED body\n")
    rd = read_evidence('data/reference.md')
    assert_equal 'changed', rd['integrity']['state']
    assert_equal old_digest, rd['sha256'] # recorded digest unchanged
    assert rd['pointer'].include?('mode: reference')
    assert rd['reference_note']
    # historical read of the reference still pins the ORIGINAL digest
    hist = read_evidence('data/reference.md', 'revision' => out['revision'])
    assert_equal old_digest, hist['sha256']
    assert_match(/source: /, hist['pointer'])
  end

  def test_reference_mode_missing_source_reports_unavailable
    src = File.join(@sources, 'meta.json')
    doomed = File.join(@sources, 'gone.json')
    FileUtils.cp(src, doomed)
    attach([{ 'source' => doomed, 'slot' => 'data', 'mode' => 'reference' }])
    FileUtils.rm_f(doomed)
    rd = read_evidence('data/gone.json')
    assert_equal 'unavailable', rd['integrity']['state']
    assert_match(/no longer exists/, rd['integrity']['detail'])
    # the dossier itself is not corrupted: other reads still work
    dr = run_task(:dossier_read, @p.merge('id' => @id))
    assert_equal @id, dr['id']
  end

  def test_directory_source_is_explicit_unsupported
    e = assert_raise(ParameterException) do
      attach([{ 'source' => @sources, 'slot' => 'data', 'mode' => 'copy' }])
    end
    assert_match(/directory/, e.message)
    assert_match(/not supported/i, e.message)
    # dossier stays at prior revision — nothing staged
    assert_equal @rev, run_task(:dossier_read, @p.merge('id' => @id))['current_revision']
  end

  def test_reference_mode_directory_source_names_the_condition
    # T8: reference mode must distinguish an EXISTING DIRECTORY from a
    # missing path (both used to say "does not resolve to an existing
    # regular file").
    e = assert_raise(ParameterException) do
      attach([{ 'source' => @sources, 'slot' => 'data', 'mode' => 'reference' }])
    end
    assert_match(/is a directory/, e.message)
    assert_match(/one regular file/, e.message)
    refute_match(/does not resolve/, e.message)
    # batch atomicity preserved: no revision bump, no staged attachments
    assert_equal @rev, run_task(:dossier_read, @p.merge('id' => @id))['current_revision']
    ov = run_task(:dossier_read, @p.merge('id' => @id, 'overview' => true))
    assert_equal [], ov['attachments']

    # missing path keeps its own (unchanged) message
    missing = File.join(@sources, 'no-such-file.txt')
    m = assert_raise(ParameterException) do
      attach([{ 'source' => missing, 'slot' => 'data', 'mode' => 'reference' }])
    end
    assert_match(/does not resolve to an existing regular file/, m.message)
    assert_equal @rev, run_task(:dossier_read, @p.merge('id' => @id))['current_revision']
  end

  def test_batch_with_one_invalid_item_rolls_back_whole_batch
    tsv = File.join(@sources, 'table.tsv')
    missing = File.join(@sources, 'nope.tsv')
    e = assert_raise(ParameterException) do
      attach([
               { 'source' => tsv, 'slot' => 'data', 'mode' => 'copy' },
               { 'source' => missing, 'slot' => 'data', 'mode' => 'copy' }
             ])
    end
    assert_match(/broken reference/, e.message)
    assert_equal @rev, run_task(:dossier_read, @p.merge('id' => @id))['current_revision']
    # no orphan attachments reachable
    ov = run_task(:dossier_read, @p.merge('id' => @id, 'overview' => true))
    assert_equal [], ov['attachments']
  end

  def test_accidental_collision_fails_and_explicit_replace_succeeds
    tsv = File.join(@sources, 'table.tsv')
    attach([{ 'source' => tsv, 'slot' => 'data', 'mode' => 'copy' }])

    rev_after_first = run_task(:dossier_read, @p.merge('id' => @id))['current_revision']

    e = assert_raise(ParameterException) do
      attach([{ 'source' => File.join(@sources, 'note.md'),
                'slot' => 'data', 'name' => 'table.tsv', 'mode' => 'copy' }],
             rev_after_first)
    end
    assert_match(/replace: true/, e.message)

    note = File.join(@sources, 'note.md')
    out = attach([{ 'source' => note, 'slot' => 'data',
                    'name' => 'table.tsv', 'mode' => 'copy',
                    'replace' => true }],
                  rev_after_first)
    assert_equal rev_after_first + 1, out['revision']

    # history preserves the previous attachment mapping at old revisions
    old = read_evidence('data/table.tsv', 'revision' => rev_after_first)
    assert_equal DossierFixtures.digest_of(tsv), old['sha256']
    now = read_evidence('data/table.tsv')
    assert_equal DossierFixtures.digest_of(note), now['sha256']
  end

  def test_granted_outside_root_read_works_and_ungranted_fails
    # The fixture sources tree lives OUTSIDE the research root and is
    # still attachable when the grant policy covers it (Scout default
    # grants include the tmp tree the fixtures scaffold under).
    tsv = File.join(@sources, 'table.tsv')
    out = attach([{ 'source' => tsv, 'slot' => 'data', 'mode' => 'copy' }])
    assert out['items'].first['sha256']

    # An ungranted location: /bulk/mvazque2/git/AgentSuite/ScoutCoder is
    # outside every grant of this process (Research and Reader only).
    e = assert_raise(ParameterException) do
      attach([{ 'source' => '/bulk/mvazque2/git/AgentSuite/ScoutCoder/workflow.rb',
                'slot' => 'data', 'mode' => 'copy' }])
    end
    assert_match(/outside the granted paths/, e.message)
    assert_match(/not a permission grant/, e.message)
  end

  def test_symlink_escape_rejected
    # A symlink living under a granted tree whose TARGET is outside every
    # grant: component-realpath resolution must reject it (sandbox layer,
    # not a string-prefix check).
    link = File.join(@sources, "escape-#{Process.pid}.txt")
    File.symlink('/proc/1/environ', link)
    e = assert_raise(ParameterException) do
      attach([{ 'source' => link, 'slot' => 'data', 'mode' => 'copy' }])
    end
    assert_match(/outside the granted paths|unresolvable/, e.message)
  end

  def test_stale_expected_revision_rejected
    tsv = File.join(@sources, 'table.tsv')
    attach([{ 'source' => tsv, 'slot' => 'data', 'mode' => 'copy' }])
    e = assert_raise(ParameterException) do
      attach([{ 'source' => tsv, 'slot' => 'data',
                'name' => 'second.tsv', 'mode' => 'copy' }], @rev)
    end
    assert_match(/StaleRevision|stale mutation/, e.message)
  end

  def test_corrupted_retained_copy_surfaces_integrity_failure
    tsv = File.join(@sources, 'table.tsv')
    out = attach([{ 'source' => tsv, 'slot' => 'data', 'mode' => 'copy' }])
    digest = out['items'].first['sha256']
    dir = File.join(@root, 'questions', @id)
    # the retained bytes live digest-addressed in the object store; corrupt them
    File.binwrite(File.join(dir, 'store', 'objects', digest), "corrupted\n")

    rd = read_evidence('data/table.tsv')
    assert_equal 'changed', rd['integrity']['state']
    assert_match(/corrupted|mismatches?|hashes to/, rd['integrity']['detail'])
  end

  def test_declared_vs_verified_field_separation
    tsv = File.join(@sources, 'table.tsv')
    out = attach([{ 'source' => tsv, 'slot' => 'data', 'mode' => 'copy',
                    'caption' => 'run 12 output',
                    'script' => 'scripts/build_table.py',
                    'parameters' => { 'seed' => 7 },
                    'inputs' => ['raw/a.tsv'],
                    'receipt' => 'job:Analyst/run/Default_x' }])
    item = out['items'].first
    assert_equal 'scripts/build_table.py', item['declared_script']
    assert_equal({ 'seed' => 7 }, item['declared_parameters'])
    assert_equal ['raw/a.tsv'], item['declared_inputs']
    assert_equal 'job:Analyst/run/Default_x', item['declared_receipt']
    assert item['verified']['digest']
    assert_equal 'retained bytes', item['verified']['basis']
    # the verified block never carries the declared keys
    assert_nil item['verified']['script']
    assert_nil item['verified']['script']

    rd = read_evidence('data/table.tsv')
    assert_equal 'run 12 output', rd['caption']
    assert_equal tsv, rd['source']
    # declared_* survive the round trip into the read result
    assert_equal 'scripts/build_table.py', rd['declared_script']
  end

  def test_text_range_read_bounds_on_text_attachment
    src = File.join(@sources, 'note.md')
    attach([{ 'source' => src, 'slot' => 'data', 'mode' => 'copy' }])
    full = read_evidence('data/note.md')
    assert full['content'].include?('Synthetic consumer document')

    window = read_evidence('data/note.md',
                           'start_line' => 3, 'max_lines' => 2)
    assert_equal 3, window['start_line']
    assert_equal 2, window['lines_returned']
    assert_equal false, window['truncated']
    assert_nil window['continuation']

    window2 = read_evidence('data/note.md',
                            'start_line' => 1, 'max_lines' => 2)
    assert window2['truncated']
    assert_equal '3', window2['continuation']

    e = assert_raise(ParameterException) do
      read_evidence('data/note.md', 'start_line' => 999)
    end
    assert_match(/out of range/, e.message)
  end

  def test_placeholder_markers_rejected_on_caption_and_note
    tsv = File.join(@sources, 'table.tsv')
    e = assert_raise(ParameterException) do
      attach([{ 'source' => tsv, 'slot' => 'data',
                'caption' => 'see [TOOL-COMPACTION-RECORD] above' }])
    end
    assert_match(/compaction marker/, e.message)

    e2 = assert_raise(ParameterException) do
      attach([{ 'source' => tsv, 'slot' => 'data' }],
             @rev, 'change_note' => '[TOOL-COMPACTION-RECORD] junk')
    end
    assert_match(/compaction marker/, e2.message)
  end

  def test_nested_supplement_documents_supported
    c = run_task(:dossier_update,
                 @p.merge('id' => @id, 'expected_revision' => @rev,
                          'mode' => 'create_document',
                          'document' => 'supplements/sub/inner.md',
                          'content' => "# inner\n\nnested note\n"))
    assert_equal true, c['changed']

    rd = run_task(:dossier_read, @p.merge('id' => @id,
                                          'document' => 'supplements/sub/inner.md'))
    assert_equal 'nested note', rd['content'].lines.last.strip

    lst = run_task(:dossier_list, @p.merge('query' => 'nested note'))
    assert_equal [@id], lst['dossiers'].map { |d| d['id'] }
  end

  def test_reference_to_ephemeral_tmp_rejected_with_promote_message
    # TmpFile.with_file creates under Scout.tmp — but that is a durable
    # var tree here, so use the true system /tmp for the ephemeral case.
    eph = File.join('/tmp', "ephemeral-#{Process.pid}-#{rand(1e9)}.txt")
    File.binwrite(eph, "scratch\n")
    begin
      e = assert_raise(ParameterException) do
        attach([{ 'source' => eph, 'slot' => 'data', 'mode' => 'reference' }])
      end
      assert_match(/ephemeral reference/, e.message)
      assert_match(/mode "copy"/, e.message)
    ensure
      FileUtils.rm_f(eph)
    end
  end

  def test_reference_attach_without_grant_rejected
    e = assert_raise(ParameterException) do
      attach([{ 'source' => '/proc/1/environ', 'slot' => 'data',
                'mode' => 'reference' }])
    end
    assert_match(/outside the granted paths/, e.message)
  end
end
