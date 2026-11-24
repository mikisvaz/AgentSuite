# Unit tests for the storage/transaction layer (WO-2 plan step 3).
#
# Coverage required by the work order:
#   - concurrent ID allocation across processes (real fork)
#   - interrupted-transaction recovery (deterministic fault injection)
#   - revision coherence (documents + attachment versions pinned)
#   - no-op semantics
#   - external drift detection and mechanical repair
#   - staging surface constraints (encoding, names, immutability)

require 'test/unit'
require 'json'
require 'fileutils'
require 'tmpdir'
require 'scout'

require_relative '../../../lib/Research/layout'
require_relative '../../../lib/Research/ids'
require_relative '../../../lib/Research/store_bytes'
require_relative '../../../lib/Research/store'
require_relative '../../support/dossier_fixtures'

# Convenience aliases: the modules live under Research::.
Store = Research::Store
Layout = Research::Layout
StoreBytes = Research::StoreBytes
Ids = Research::Ids

class TestStoreTransaction < Test::Unit::TestCase
  include DossierFixtureTeardown

  def setup
    @root = DossierFixtures.scaffold_root('store')
  end

  def d(bytes)
    DossierFixtures.digest_bytes(bytes)
  end

  def create_dossier(id: 'Q-001', body: "# Question\n\nBody v1.\n")
    Store.transaction(@root, 'question', id,
                      allow_create: true) do |ctx|
      ctx.write_document('README.md', body)
    end
  end

  # ------------------------------------------------------------ create

  def test_create_commits_revision_1_with_document_digest
    r = create_dossier
    assert_equal 1, r['revision']
    assert r['changed']
    assert_equal d("# Question\n\nBody v1.\n"), r['documents']['README.md']

    cur = Store.current_revision(@root, 'question', 'Q-001')
    assert_equal 1, cur['revision']
    assert_equal 'Q-001', cur['record']['id']

    doc = File.join(@root, 'questions', 'Q-001', 'README.md')
    assert File.file?(doc), 'README.md view must exist after create'
    assert_equal "# Question\n\nBody v1.\n", File.read(doc)
  end

  def test_create_without_allow_create_is_missing
    e = assert_raise(Research::Store::Missing) do
      Store.transaction(@root, 'question', 'Q-001') { |c| }
    end
    assert_match(/allow_create/, e.message)
  end

  def test_create_writes_object_for_document_bytes
    create_dossier
    obj = File.join(@root, 'questions', 'Q-001', 'store', 'objects',
                    d("# Question\n\nBody v1.\n"))
    assert File.file?(obj), 'content-addressed object must exist'
    assert_equal "# Question\n\nBody v1.\n", StoreBytes.read(obj)
  end

  # ------------------------------------------------------ second revision

  def test_second_commit_increments_revision_and_pins_new_digest
    create_dossier
    r = Store.transaction(@root, 'question', 'Q-001',
                          expected_revision: 1) do |ctx|
      ctx.write_document('README.md', "# Question\n\nBody v2.\n")
    end
    assert_equal 2, r['revision']
    assert_equal d("# Question\n\nBody v2.\n"), r['documents']['README.md']

    cur = Store.current_revision(@root, 'question', 'Q-001')
    assert_equal 2, cur['revision']
    # Old object still present: history is reproducible.
    old_obj = File.join(@root, 'questions', 'Q-001', 'store', 'objects',
                        d("# Question\n\nBody v1.\n"))
    assert File.file?(old_obj)
    bytes = Store.object_bytes(cur['dir'], d("# Question\n\nBody v1.\n"))
    assert_equal "# Question\n\nBody v1.\n", bytes
  end

  def test_expected_revision_mismatch_is_stale
    create_dossier
    e = assert_raise(Research::Store::StaleRevision) do
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 7) { |c| }
    end
    assert_match(/stale/i, e.message)
    assert_match(/current revision is 1/, e.message)
  end

  # ------------------------------------------------------------- no-op

  def test_identical_rewrite_is_a_no_op
    create_dossier
    pointer = File.join(@root, 'meta', 'Q-001.current')
    before = DossierFixtures.digest_of(pointer)
    history_before = Dir.children(File.join(@root, 'questions', 'Q-001',
                                             'store', 'history')).sort

    r = Store.transaction(@root, 'question', 'Q-001',
                          expected_revision: 1) do |ctx|
      ctx.write_document('README.md', "# Question\n\nBody v1.\n")
    end
    assert_equal false, r['changed']
    assert_equal 1, r['revision']
    assert_equal before, DossierFixtures.digest_of(pointer)
    assert_equal history_before,
                 Dir.children(File.join(@root, 'questions', 'Q-001',
                                        'store', 'history')).sort
  end

  # ------------------------------------------------------------- drift

  def test_external_edit_is_drift_not_silent_overwrite
    create_dossier
    doc = File.join(@root, 'questions', 'Q-001', 'README.md')
    File.binwrite(doc, "# Question\n\nEDITED OUTSIDE.\n")

    e = assert_raise(Research::Store::Drift) do
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 1) do |ctx|
        ctx.write_document('README.md', 'anything')
      end
    end
    assert_match(/external drift/i, e.message)
    assert_match(d("# Question\n\nBody v1.\n"), e.message)
    assert_match(d("# Question\n\nEDITED OUTSIDE.\n"), e.message)
  end

  def test_restore_views_repairs_drift_from_current_record
    create_dossier
    doc = File.join(@root, 'questions', 'Q-001', 'README.md')
    File.binwrite(doc, "tampered")
    Store.restore_views!(@root, 'question', 'Q-001')
    assert_equal "# Question\n\nBody v1.\n", File.read(doc)
  end

  def test_extra_supplement_file_is_drift
    create_dossier
    sdir = File.join(@root, 'questions', 'Q-001', 'supplements')
    FileUtils.mkdir_p(sdir)
    File.binwrite(File.join(sdir, 'stray.md'), 'stray')
    e = assert_raise(Research::Store::Drift) do
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 1) { |c| }
    end
    assert_match(/does not list it/, e.message)
  end

  # ------------------------------------------- attachments + coherence

  def test_revision_pins_attachment_versions
    create_dossier
    payload = "sample\tvalue\n" * 3
    r = Store.transaction(@root, 'question', 'Q-001',
                          expected_revision: 1) do |ctx|
      ctx.attach_evidence('tsv', 'table.tsv', payload)
    end
    assert_equal 2, r['revision']
    info = r['attachments']['tsv/table.tsv']
    assert_equal d(payload), info['digest']
    assert_equal payload.bytesize, info['size']

    ev = File.join(@root, 'questions', 'Q-001', 'evidence', 'tsv', 'table.tsv')
    assert_equal payload, File.read(ev)

    # Coherence: record digest map matches view bytes for both kinds.
    cur = Store.current_revision(@root, 'question', 'Q-001')
    cur['record']['documents'].each do |name, digest|
      path = name == 'README.md' ? File.join(@root, 'questions', 'Q-001', 'README.md')
                              : File.join(@root, 'questions', 'Q-001', name)
      assert_equal digest, StoreBytes.digest(path), name
    end
    cur['record']['attachments'].each do |name, info|
      assert_equal info['digest'],
                   StoreBytes.digest(File.join(@root, 'questions', 'Q-001',
                                               'evidence', name))
    end
  end

  def test_attachment_dedup_and_immutability
    create_dossier
    Store.transaction(@root, 'question', 'Q-001',
                      expected_revision: 1) do |ctx|
      ctx.attach_evidence('bin', 'a.bin', 'AAAA')
    end
    dedup_res = nil
    r2 = Store.transaction(@root, 'question', 'Q-001',
                           expected_revision: 2) do |ctx|
      dedup_res = ctx.attach_evidence('bin', 'a.bin', 'AAAA')
      ctx.write_document('README.md', "# Question\n\nBody v1b.\n") # make it not a no-op
    end
    assert_equal true, dedup_res['dedup']
    assert_equal d('AAAA'), r2['attachments']['bin/a.bin']['digest']

    e = assert_raise(Research::Store::Error) do
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 3) do |ctx|
        ctx.attach_evidence('bin', 'a.bin', 'BBBB')
      end
    end
    assert_match(/immutable/i, e.message)
  end

  def test_binary_attachment_bytes_survive_verbatim
    create_dossier
    bytes = DossierFixtures::BINARY_BYTES
    Store.transaction(@root, 'question', 'Q-001',
                      expected_revision: 1) do |ctx|
      ctx.attach_evidence('raw', 'binary.bin', bytes)
    end
    path = File.join(@root, 'questions', 'Q-001', 'evidence', 'raw',
                     'binary.bin')
    assert_equal d(bytes), StoreBytes.digest(path)
    assert_equal bytes.bytesize, File.size(path)
  end

  # --------------------------------------------- interruption semantics

  def run_interrupted(fault_point)
    create_dossier
    assert_raise(Research::Store::Interrupted) do
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 1, fault: fault_point) do |ctx|
        ctx.write_document('README.md', "# Question\n\nBody v2.\n")
        ctx.write_document('supplements/note.md', "note v2\n")
      end
    end
  end

  def assert_recovered_to_v2
    cur = Store.current_revision(@root, 'question', 'Q-001')
    assert_equal 2, cur['revision']
    doc = File.join(@root, 'questions', 'Q-001', 'README.md')
    assert_equal "# Question\n\nBody v2.\n", File.read(doc)
    sup = File.join(@root, 'questions', 'Q-001', 'supplements', 'note.md')
    assert_equal "note v2\n", File.read(sup)
    refute File.file?(File.join(@root, 'questions', 'Q-001', 'store',
                                'inflight'))
  end

  { after_stage: 'objects only', after_journal: 'journal unreferenced',
    after_marker: 'marker before views', mid_views: 'views half-written',
    after_views: 'views done pre-pointer',
    after_pointer: 'pointer before cleanup' }.each do |fault, label|
    define_method("test_interrupted_at_#{fault}_recovers_#{label.tr(' ', '_')}") do
      run_interrupted(fault)
      # Any next operation recovers deterministically. Pre-marker faults
      # abort cleanly at revision 1 (nothing in flight); the caller
      # re-applies against r1. At/after-marker faults are redone to r2 by
      # the next operation, so the caller's expectation shifts with them.
      expect = %i[after_stage after_journal].include?(fault) ? 1 : 2
      r = Store.transaction(@root, 'question', 'Q-001',
                            expected_revision: expect) do |ctx|
        ctx.write_document('README.md', "# Question\n\nBody v2 edited.\n")
        ctx.write_document('supplements/note.md', "note v2\n")
      end
      assert_equal expect + 1, r['revision']
      assert_recovered_to_v2_edited
    end

    define_method("test_interrupted_at_#{fault}_direct_recovery_#{label.tr(' ', '_')}") do
      run_interrupted(fault)
      rec = Store.recover!(@root, 'question', 'Q-001')
      if %i[after_stage after_journal].include?(fault)
        assert_nil rec # nothing in flight at/above the marker semantics
      else
        assert_equal 2, rec['recovered']
        assert_recovered_to_v2
      end
    end
  end

  def assert_recovered_to_v2_edited
    doc = File.join(@root, 'questions', 'Q-001', 'README.md')
    assert_equal "# Question\n\nBody v2 edited.\n", File.read(doc)
    sup = File.join(@root, 'questions', 'Q-001', 'supplements', 'note.md')
    assert_equal "note v2\n", File.read(sup)
  end

  def test_reader_sees_old_revision_until_pointer_swap
    create_dossier
    begin
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 1, fault: :after_views) do |ctx|
        ctx.write_document('README.md', "# Question\n\nBody v2.\n")
      end
    rescue Research::Store::Interrupted
      nil # interrupted exactly before the linearization point
    end
    cur = Store.current_revision(@root, 'question', 'Q-001')
    assert_equal 1, cur['revision'], 'pointer must still name revision 1'
  end

  # ------------------------------------------------ staging constraints

  def test_missing_doc_md_rejected
    e = assert_raise(Research::Store::Error) do
      Store.transaction(@root, 'question', 'Q-001',
                        allow_create: true) do |ctx|
        ctx.write_document('supplements/only.md', 'no README.md')
      end
    end
    assert_match(/README[.]md/, e.message)
  end

  def test_invalid_document_names_rejected
    e = assert_raise(Research::Store::Error) do
      Store.transaction(@root, 'question', 'Q-001',
                        allow_create: true) do |ctx|
        ctx.write_document('store/history/r1.json', 'escape')
      end
    end
    assert_match(/README[.]md.*supplements/m, e.message)
  end

  def test_invalid_encoding_rejected
    bad = "valid\xC3\x28invalid".dup.force_encoding(Encoding::UTF_8)
    e = assert_raise(Research::Store::Error) do
      Store.transaction(@root, 'question', 'Q-001',
                        allow_create: true) do |ctx|
        ctx.write_document('README.md', bad)
      end
    end
    assert_match(/UTF-8/, e.message)
  end

  def test_marker_without_journal_is_loud_corruption
    create_dossier
    marker = File.join(@root, 'questions', 'Q-001', 'store', 'inflight')
    FileUtils.mkdir_p(File.dirname(marker))
    File.binwrite(marker, "99\n")
    e = assert_raise(Research::Store::Corrupt) do
      Store.transaction(@root, 'question', 'Q-001',
                        expected_revision: 1) { |c| }
    end
    assert_match(/journal record is missing/, e.message)
  end
end

class TestStoreSweepAndLayout < Test::Unit::TestCase
  include DossierFixtureTeardown

  def setup
    @root = DossierFixtures.scaffold_root('sweep')
  end

  def test_orphan_journal_above_pointer_swept_on_open
    id = 'C-001'
    Store.transaction(@root, 'claim', id, allow_create: true) do |ctx|
      ctx.write_document('README.md', "claim v1\n")
    end
    # Simulate crash-before-pointer orphan: journal r2 unreferenced.
    dir = File.join(@root, 'claims', id)
    orphan = Layout.revision_path(dir, 2)
    StoreBytes.write_atomic(orphan, "not a real record\n")
    Store.transaction(@root, 'claim', id, expected_revision: 1) do |ctx|
      ctx.write_document('README.md', "claim v2\n")
    end
    rec = JSON.parse(File.read(orphan))
    assert_equal 2, rec['revision'], 'orphan garbage replaced by fresh r2'
    assert_equal DossierFixtures.digest_bytes("claim v2\n"),
                 rec['documents']['README.md']
  end

  def test_objects_never_swept
    id = 'H-001'
    Store.transaction(@root, 'hypothesis', id, allow_create: true) do |ctx|
      ctx.write_document('README.md', "h1\n")
    end
    Store.transaction(@root, 'hypothesis', id, expected_revision: 1) do |ctx|
      ctx.write_document('README.md', "h2\n")
    end
    dir = File.join(@root, 'hypotheses', id)
    assert File.file?(Layout.object_path(dir, DossierFixtures.digest_bytes("h1\n")))
    assert File.file?(Layout.object_path(dir, DossierFixtures.digest_bytes("h2\n")))
  end
end
