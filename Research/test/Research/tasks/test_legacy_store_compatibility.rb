# frozen_string_literal: true

# 4d: OLD-FORMAT store compatibility. The fixture is generated in a
# CHILD process from the pre-refactor backup code
# (tmp/bout_a/backup_before_step2) using the old service modules
# (research_root: passed explicitly, base_path-era evidence_attach),
# then read/checked/edited/historied by the NEW code through the real
# dispatcher in a second child process. Old bytes must not be rewritten
# by reads/checks (only the edited dossier and its pointer may change).
require 'test/unit'
require 'tmpdir'
require 'fileutils'
require 'json'

class TestLegacyStoreCompatibility < Test::Unit::TestCase
  ROOT = File.expand_path('../../../..', __FILE__).freeze
  BACKUP = File.join(ROOT, 'tmp/bout_a/backup_before_step2').freeze

  def self.backup_available?
    File.directory?(File.join(BACKUP, 'lib', 'Research'))
  end

  BUILDER = <<~'RUBY'
    require 'json'
    require 'fileutils'
    base = ARGV[0]
    project = File.join(base, 'oldproj')
    FileUtils.mkdir_p(project)
    backup = ARGV[1]
    $LOAD_PATH.unshift(File.join(backup, 'lib'))
    require 'scout'
    require 'scout-ai'
    module Research
      extend Workflow
    end
    %w[common evidence dossier_create dossier_update evidence_attach].each do |f|
      require File.join(backup, 'lib', 'Research', 'tasks', "#{f}.rb")
    end
    require File.join(backup, 'lib', 'Research', 'roots.rb')
    Dir.chdir(project) do
      root = File.join(project, 'research')
      q = Research::Tasks::DossierCreate.call(type: 'question', title: 'Legacy question', research_root: root)
      c = Research::Tasks::DossierCreate.call(type: 'claim', title: 'Legacy claim', research_root: root)
      src = File.join(base, 'legacy.tsv')
      File.binwrite(src, "a\tb\n1\t2\n")
      Research::Tasks::EvidenceAttach.call(
        id: q['id'], expected_revision: 1,
        items: JSON.generate([{ 'source' => src, 'slot' => 'legacy', 'mode' => 'copy' }]),
        research_root: root
      )
      Research::Tasks::DossierUpdate.call(
        id: c['id'], expected_revision: 1, mode: 'replace_document',
        content: "# Legacy claim\n\nRelated: [Q](../../questions/#{q['id']}/README.md)\n",
        research_root: root
      )
      Research::Tasks::DossierUpdate.call(
        id: q['id'], expected_revision: 2, mode: 'replace_document',
        content: "# Legacy question\n\nrev 2\n",
        research_root: root
      )
      puts "BUILT #{q['id']} #{c['id']}"
    end
  RUBY

  VERIFIER = <<~'RUBY'
    require 'json'
    project = ARGV[0]
    checkout = ARGV[1]
    require File.join(checkout, 'workflow')
    results = {}
    Dir.chdir(project) do
      root = File.join(project, 'research')
      qid = 'Q-001'; cid = 'C-001'

      before = Dir.glob(File.join(root, '**', '*')).select { |f| File.file?(f) }
                  .to_h { |f| [f, File.binread(f)] }

      ov = Research.job(:dossier_read, nil, id: qid, mode: 'overview').exec
      doc = Research.job(:dossier_read, nil, id: qid, mode: 'document').exec
      results['read'] = { 'revision' => doc['revision'],
                          'lines' => doc['content'].to_s.lines.size,
                          'overview_revision' => ov['revision'] }

      ev = Research.job(:evidence_read, nil, id: qid, attachment: 'legacy/legacy.tsv').exec
      results['evidence'] = { 'integrity' => ev['integrity']['state'] }

      chk = Research.job(:dossier_check, nil, id: cid).exec
      d = chk['dossiers'].first
      results['check'] = { 'status' => d['status'], 'links' => d['links'] }

      hist = Research.job(:dossier_history, nil, id: qid).exec
      results['history'] = { 'count' => (hist['revisions'] || []).length }

      upd = Research.job(:dossier_update, nil, id: qid, expected_revision: 3,
        mode: 'replace_document', content: "# Legacy question\n\nrev 3 by NEW code\n").exec
      results['edit'] = { 'changed' => upd['changed'], 'revision' => upd['revision'] }

      after = Dir.glob(File.join(root, '**', '*')).select { |f| File.file?(f) }
                 .to_h { |f| [f, File.binread(f)] }
      allowed = %w[current pointer]
      changed_outside = before.keys
                            .reject { |p| p.include?("/questions/#{qid}/") }
                            .select { |p| after[p] != before[p] }
      # the Q dossier pointer legitimately changes with the new revision
      changed_outside = changed_outside.reject { |p| p == File.join(root, 'meta', "#{qid}.current") }
      results['bytes'] = { 'changed_outside' => changed_outside }
    end
    puts "RESULT " + JSON.generate(results)
  RUBY

  def test_old_format_store_remains_valid_under_new_code
    omit 'pre-refactor backup not present' unless self.class.backup_available?

    Dir.mktmpdir do |base|
      run_child(BUILDER, base.to_s, BACKUP)
      project = File.join(base, 'oldproj')
      out = run_child(VERIFIER, project.to_s, ROOT)
      result = JSON.parse(out[/^RESULT (.*)$/, 1])

      assert_equal 3, result['read']['revision'], 'document read at rev 3'
      assert_equal 3, result['read']['lines']
      assert_equal 3, result['read']['overview_revision']
      assert_equal 'ok', result['evidence']['integrity'], 'legacy evidence integrity'
      assert_equal 'ok', result['check']['status'], 'legacy claim checks clean'
      assert_equal 1, result['check']['links']['checked']
      assert_equal 3, result['history']['count'], 'three revisions of history'
      assert result['edit']['changed'], 'new code commits on old store'
      assert_equal 4, result['edit']['revision']
      assert_empty result['bytes']['changed_outside'],
                   'reads/checks must not rewrite old bytes'
    end
  end

  private

  def run_child(script, *args)
    out = +''
    IO.popen(['ruby', '-e', script, *args], err: [:child, :out]) do |io|
      io.each_line do |l|
        out << l
        warn l unless l.include?('warning:') || l.start_with?('RESULT', 'BUILT')
      end
    end
    assert_equal 0, $?.exitstatus, "child failed:\n#{out}"
    out
  end
end
