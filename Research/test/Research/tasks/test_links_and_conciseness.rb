# frozen_string_literal: true

# Plan step 5 regressions (5g-5k): ordinary local Markdown links,
# generated-link consistency (5h), coverage honesty (5i), and the
# exact 5j cases. Plan step 4e conciseness assertions live here too.
require 'test/unit'
require 'scout'
require 'scout-ai'
require 'fileutils'
require 'json'

ROOT = File.expand_path('../../../..', __FILE__)
$LOAD_PATH.unshift(File.join(ROOT, 'lib'))
require File.join(ROOT, 'workflow')
require File.join(ROOT, 'test', 'support', 'dossier_fixtures')

# Same real-dispatch harness idiom as the other task suites.
def dispatch(task, params = {})
  DossierFixtures.in_project(@project) do |project|
    LLM.call_workflow(Research, task, params)
  end
end

class TestLinksAndConciseness < Test::Unit::TestCase
  def setup
    @base = DossierFixtures.tmp_base('links')
    @project = File.join(@base, 'project')
    FileUtils.mkdir_p(@project)
    Research::Layout.ensure_root!(File.join(@project, 'research'))
  end

  def teardown
    origin = ($dossier_stable_origin ||= Dir.tmpdir)
    Dir.chdir(origin) rescue nil
    DossierFixtures.cleanup(@base)
  end

  def test_j_broken_vs_correct_relative_links_from_hypothesis
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      h = dispatch(:dossier_create, type: 'hypothesis', title: 'H')
      c = dispatch(:dossier_create, type: 'claim', title: 'C')

      dispatch(:dossier_update, id: h['id'], expected_revision: 1,
                                mode: 'replace_document',
                                content: "# H\n\n[bad](../C-001/README.md) [good](../../claims/C-001/README.md)\n")
      # re-point at the actual allocated id for stable assertions
      doc = dispatch(:dossier_read, id: h['id'], mode: 'document')
      content = doc['content'].gsub('C-001', c['id'])
      dispatch(:dossier_update, id: h['id'], expected_revision: 2,
                                mode: 'replace_document', content: content)

      chk = dispatch(:dossier_check, id: h['id'])
      d = chk['dossiers'].first
      broken = d['findings'].select { |f| f['category'] == 'local_link_broken' }
      assert_equal 1, broken.length, 'exactly one broken link'
      assert_match(/#{h['id']}|C-001/, broken.first['detail'])
      assert broken.first['detail'].include?("../#{c['id']}/README.md"),
             'the ../<id> form is the one flagged'
      assert_equal 2, d['links']['checked'], 'both links checked'
      assert_equal 1, d['links']['local_link_broken']
    end
  end

  def test_j_shared_evidence_link_from_claim_validates
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      q = dispatch(:dossier_create, type: 'question', title: 'Q')
      c = dispatch(:dossier_create, type: 'claim', title: 'C')
      src = File.join(project, 'tbl.tsv')
      File.binwrite(src, "x\t1\n")
      dispatch(:evidence_attach, id: q['id'], expected_revision: 1,
                                 items: JSON.generate([{ 'source' => src, 'slot' => 'data', 'mode' => 'copy' }]))

      dispatch(:dossier_update, id: c['id'], expected_revision: 1,
                                mode: 'replace_document',
                                content: "# C\n\n[ev](../../questions/#{q['id']}/evidence/data/tbl.tsv)\n")
      chk = dispatch(:dossier_check, id: c['id'])
      d = chk['dossiers'].first
      assert_equal 'ok', d['status'], d['findings'].map { |f| f['detail'] }.inspect
      assert_equal 1, d['links']['checked']
      # evidence must NOT have been duplicated into the claim (the
      # scaffold's empty evidence/ dir may exist; no files may)
      dup = Dir.glob(File.join(root, 'claims', c['id'], 'evidence', '**', '*'))
               .select { |f| File.file?(f) }
      assert_empty dup, 'no evidence files duplicated into the claim'
    end
  end

  def test_links_in_code_fences_are_ignored
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      h = dispatch(:dossier_create, type: 'hypothesis', title: 'H')
      dispatch(:dossier_update, id: h['id'], expected_revision: 1,
                                mode: 'replace_document',
                                content: "# H\n\n```markdown\n[in fence](definitely/missing.md)\n```\n")
      chk = dispatch(:dossier_check, id: h['id'])
      d = chk['dossiers'].first
      assert_equal 'ok', d['status'], 'fenced link must not count as broken'
      assert_equal 1, d['links']['in_code_fence']
      assert_equal 0, d['links']['checked']
    end
  end

  def test_coverage_categories_are_distinct_and_explicit
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      h = dispatch(:dossier_create, type: 'hypothesis', title: 'H')
      dispatch(:dossier_update, id: h['id'], expected_revision: 1,
                                mode: 'replace_document',
                                content: "# H\n\n" \
                                  "[web](https://example.com/a) " \
                                  "[frag](#section) " \
                                  "[out](../../../../outside.md) " \
                                  "[ref][r]\n\n[r]: somewhere.md\n")
      chk = dispatch(:dossier_check, id: h['id'])
      d = chk['dossiers'].first
      links = d['links']
      assert_equal 1, links['external_url']
      assert_equal 1, links['fragment_only']
      assert_equal 1, links['out_of_scope']
      assert_equal 1, links['unsupported_syntax'], 'reference-style counted, not silently skipped'
      assert_equal 0, links['checked']
      assert_equal 'ok', d['status'], 'skipped categories are not findings'
      assert chk['not_checked'].any? { |n| n.include?('fragments') },
             'output states fragments are not validated'
      assert chk['not_checked'].any? { |n| n.include?('unsupported') },
             'output lists unsupported syntax explicitly'
    end
  end

  def test_h_generated_links_pass_the_checker
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      q = dispatch(:dossier_create, type: 'question', title: 'Q')
      # dossier_create's result link field must be a checkable local link
      create_result = dispatch(:dossier_create, type: 'claim', title: 'C')
      link_target = create_result['link'][/\]\((.*)\)\z/, 1]

      src = File.join(project, 'e.tsv')
      File.binwrite(src, "a\n")
      attach = dispatch(:evidence_attach, id: q['id'], expected_revision: 1,
                                          items: JSON.generate([{ 'source' => src, 'slot' => 's', 'mode' => 'copy' }]))
      attach_link_target = attach['items'].first['link'][/\]\((.*)\)\z/, 1]

      [q, create_result].each do |d|
        chk = dispatch(:dossier_check, id: d['id'])
        dd = chk['dossiers'].first
        assert_equal 'ok', dd['status'],
                     "generated links broke the checker: #{dd['findings'].map { |f| f['detail'] }}"
      end

      # the emitted targets exist as files (copy mode) or are reference-mode
      # descriptors, and the README's own attachment notice checks clean
      assert File.exist?(attach_link_target) || attach['items'].first['mode'] == 'reference'
      assert link_target.start_with?('/') && File.exist?(link_target),
             "dossier_create link target must be an existing absolute path: #{link_target}" 
    end
  end

  def test_conciseness_all_tasks_no_dead_fields
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      dead = %w[root root_source record record_digest directory integrity_state
                record_path record_revision meta].freeze

      q = dispatch(:dossier_create, type: 'question', title: 'Q')
      assert_dead_free(dead, q, 'dossier_create')
      qid = q['id']

      src = File.join(project, 't.tsv')
      File.binwrite(src, "a\n")
      att = dispatch(:evidence_attach, id: qid, expected_revision: 1,
                                       items: JSON.generate([{ 'source' => src, 'slot' => 'x', 'mode' => 'copy' }]))
      assert_dead_free(dead, att, 'evidence_attach')

      upd = dispatch(:dossier_update, id: qid, expected_revision: 2,
                                      mode: 'replace_document',
                                      content: "# Q\n\nline1\nline2\nline3\n")
      assert_dead_free(dead, upd, 'dossier_update')

      lst = dispatch(:dossier_list)
      assert_dead_free(dead, lst, 'dossier_list')

      doc = dispatch(:dossier_read, id: qid, mode: 'document')
      assert_dead_free(dead, doc, 'dossier_read document')
      assert_equal upd['revision'], doc['revision'], 'reads carry revision'
      assert doc['content'].is_a?(String)
      assert doc.key?('total_lines') || doc.key?('line_count') || doc['content'].lines.size >= 3,
             'reads keep line information for safe line edits'

      ov = dispatch(:dossier_read, id: qid, mode: 'overview')
      assert_dead_free(dead, ov, 'dossier_read overview')

      ev = dispatch(:evidence_read, id: qid, attachment: 'x/t.tsv')
      assert_dead_free(dead, ev, 'evidence_read')

      chk = dispatch(:dossier_check, id: qid)
      assert_dead_free(dead, chk, 'dossier_check')

      hist = dispatch(:dossier_history, id: qid)
      assert_dead_free(dead, hist, 'dossier_history')

      cap = dispatch(:dossier_capture, id: qid, expected_revision: doc['revision'])
      assert_dead_free(dead, cap, 'dossier_capture')
    end
  end

  def test_relative_source_without_base_path_attaches_from_working_project
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      q = dispatch(:dossier_create, type: 'question', title: 'Q')
      rel = File.join('data', 'local.tsv')
      FileUtils.mkdir_p(File.dirname(File.join(project, rel)))
      File.binwrite(File.join(project, rel), "a\tb\n")

      att = dispatch(:evidence_attach, id: q['id'], expected_revision: 1,
                                       items: JSON.generate([{ 'source' => rel, 'slot' => 'rel', 'mode' => 'copy' }]))
      item = att['items'].first
      assert File.exist?(item['retained_location']),
             'relative source resolved against the working project'
      # the source echo is the resolved working-project path
      assert item['source'].start_with?(project + '/'), item['source'].inspect
      assert_equal File.join(project, rel), item['source'],
                   'relative spelling resolved against the working project'
    end
  end

  def test_source_escape_and_destination_escape_rejected
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      q = dispatch(:dossier_create, type: 'question', title: 'Q')
      # An absolute path under NO sandbox grant. The workspace tmp/ roots and
      # /tmp itself ARE writable grants of this process (a test-side artifact
      # of the harness), so use a home-path file, which no grant covers.
      outside = File.join(ENV['HOME'], "escape_src_#{Process.pid}.tsv")
      skip "HOME (#{ENV['HOME']}) is granted to this process" if
        LLM::Sandbox.authorize_path(outside,
                                    root: Dir.pwd,
                                    writable_paths: LLM::Sandbox.writable_grants(scope: 'Research'),
                                    read_paths: LLM::Sandbox.readable_grants(scope: 'Research'),
                                    mode: :read).allowed
      File.binwrite(outside, "x\n")

      e = assert_raises(ParameterException) do
        Research.job(:evidence_attach, nil, 'id' => q['id'], 'expected_revision' => 1,
                                        'items' => JSON.generate([{ 'source' => outside, 'slot' => 'esc', 'mode' => 'copy' }])).exec
      end
      assert_match(/outside the granted paths|not a permission grant/i, e.message)

      File.binwrite(File.join(project, 'ok.tsv'), "ok\n")
      rel_escape = '../../escape_src.tsv'
      e2 = assert_raises(ParameterException) do
        Research.job(:evidence_attach, nil, 'id' => q['id'], 'expected_revision' => 1,
                                        'items' => JSON.generate([{ 'source' => rel_escape, 'slot' => 'esc', 'mode' => 'copy' }])).exec
      end
      assert_match(/outside|not authorized|escape/i, e2.message)

      e3 = assert_raises(ParameterException) do
        r3 = dispatch(:evidence_attach, id: q['id'], expected_revision: 1,
                                        items: JSON.generate([
                                          { 'source' => File.join(project, 'ok.tsv'), 'slot' => 'data', 'name' => '../../../evil.tsv', 'mode' => 'copy' }
                                        ]))
        raise r3 if r3.is_a?(Exception)
        r3
      end
      assert_match(/slot|invalid/i, e3.message)
    ensure
      File.delete(outside) if outside && File.exist?(outside)
    end
  end

  def test_absolute_authorized_source_still_works
    root = File.join(@project, 'research')
    DossierFixtures.in_project(@project) do |project|
      q = dispatch(:dossier_create, type: 'question', title: 'Q')
      abs = File.join(project, 'abs.tsv')
      File.binwrite(abs, "z\n")
      att = dispatch(:evidence_attach, id: q['id'], expected_revision: 1,
                                       items: JSON.generate([{ 'source' => abs, 'slot' => 'abs', 'mode' => 'copy' }]))
      assert File.exist?(att['items'].first['retained_location'])
    end
  end

  def test_no_fallback_root_chain_anywhere
    lib = File.join(ROOT, 'lib')
    forbidden = [/[.]git/, /project registry/, /Scout\.var\.research/]
    Dir.glob(File.join(lib, '**', '*.rb')).each do |f|
      src = File.read(f)
      forbidden.each do |re|
        refute_match re, src, "#{f} mentions retired root-resolution machinery"
      end
    end
  end

  private

  def assert_dead_free(dead, payload, label)
    case payload
    when Hash
      payload.each do |k, v|
        next if k == 'integrity' && v.is_a?(Hash)

        assert_not_include dead, k, "#{label} emits dead field #{k.inspect}" if dead.include?(k) && k != 'integrity'
        assert_dead_free(dead, v, label) if v.is_a?(Hash) || v.is_a?(Array)
      end
    when Array
      payload.each { |v| assert_dead_free(dead, v, label) if v.is_a?(Hash) || v.is_a?(Array) }
    end
  end
end
