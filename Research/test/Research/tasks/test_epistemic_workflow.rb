require 'test/unit'
require_relative '../../../workflow'
require_relative '../../support/dossier_fixtures'

class TestEpistemicWorkflow < Test::Unit::TestCase
  def setup
    @project = DossierFixtures.scaffold_project('epistemic')
  end

  def dispatch(task, **inputs)
    result = DossierFixtures.in_project(@project) { LLM.call_workflow(Research, task, inputs.transform_keys(&:to_s)) }
    raise result if result.is_a?(Exception)
    result
  end

  def test_documentary_and_scientific_changes
    q = dispatch(:dossier_create, type: 'question', title: 'How broad is the response?')['id']
    assert_equal "# How broad is the response?\n", dispatch(:dossier_read, id: q)['content']
    c = dispatch(:dossier_create, type: 'claim', title: 'Panel response')['id']
    source = File.join(File.dirname(@project), 'sources/table.tsv')
    receipt = dispatch(:evidence_attach, id: q, expected_revision: 1,
                       items: [{ source: source, slot: 'tables' }].to_json)['items'].first
    rd = dispatch(:evidence_read, id: q, digest: receipt['digest_prefix'], revision: 2)
    %w[evidence_read evidence_digest project_locator retained_kind retained_digest].each do |field|
      assert_equal receipt[field], rd[field]
    end
    brief = dispatch(:evidence_read, **receipt['evidence_read'], compact: true)
    assert_equal receipt['digest_prefix'], brief['digest_prefix']
    assert_equal rd['content'], brief['content']
    refute brief.to_json.include?(rd['sha256'])
    assert_equal rd['content'], File.read(File.join(@project, receipt['project_locator']))
    dependent = dispatch(:dossier_create, type: 'claim', title: 'Extent',
                         content: "# Extent\n## Warrant\nUses [premise](#{c}/README.md \"reviewed@1\").\n#{receipt['link']}\n")
    dispatch(:dossier_update, id: q, expected_revision: 2, mode: 'add_section', section: 'L1',
             content: "## Measurements\nCaption.", change_kind: 'documentary')
    assert_equal rd['content'], dispatch(:evidence_read, **receipt['evidence_read'])['content']
    dispatch(:dossier_update, id: c, expected_revision: 1, mode: 'add_section', section: 'L1',
             content: "## Scope\nPanel.", change_kind: 'documentary')
    incoming = -> { dispatch(:dossier_backlinks, id: c).fetch('links').fetch(0) }
    assert_equal 'current', incoming.call['review_status']
    dispatch(:dossier_update, id: c, expected_revision: 2, mode: 'replace_section', section: 'L3',
             content: 'Annotation-defined panel.', change_kind: 'scientific', change_note: 'Narrow population')
    link = incoming.call
    assert_equal dependent['id'], link['id']
    assert_equal ['Extent', 'Warrant'], link['heading_path']
    assert_equal 'review_suggested', link['review_status']
    assert_equal ['Narrow population'], link['changes'].map { |r| r['change_note'] }
    assert_equal 1, dispatch(:dossier_read, id: dependent['id'])['revision']
    assert_equal 'scientific', dispatch(:dossier_history, id: c)['revisions'].first['change_kind']
  end

  def test_sections_are_revision_local_and_protect_children
    body = "# T\n## X\nold\n### Child\nvalue\n## X\n~~~~\n## hidden\n~~~\n~~~~\n"
    id = dispatch(:dossier_create, type: 'hypothesis', title: 'T', content: body)['id']
    rows = dispatch(:dossier_read, id: id, outline: true)['outline']
    assert_equal %w[L1 L2 L4 L6], rows.map { |r| r['selector'] }
    page = dispatch(:dossier_read, id: id, section: 'L2', max_lines: 2)
    assert_equal "## X\nold\n", page['content']
    assert_equal "### Child\nvalue\n", dispatch(:dossier_read, id: id, section: 'L2', start_line: page['continuation'])['content']
    dispatch(:dossier_update, id: id, expected_revision: 1, mode: 'replace_section', section: 'L2', content: 'new')
    assert_equal body.sub('old', 'new'), dispatch(:dossier_read, id: id)['content']
    assert_equal body, dispatch(:dossier_read, id: id, revision: 1)['content']
    assert_raise(ParameterException) do
      dispatch(:dossier_update, id: id, expected_revision: 1, mode: 'replace_section', section: 'L2', content: 'stale')
    end
  end

  def test_paged_direct_body_round_trip
    text = "# Root\r\nbody one\r\nbody two\r\n## Child\r\nchild bytes"
    id = dispatch(:dossier_create, type: 'question', title: 'Root', content: text)['id']
    args = { id: id, revision: 1, section: 'L1', body_only: true, max_lines: 1 }
    page = dispatch(:dossier_read, **args)
    assert_equal [2, 4, 'L1', 1], page.values_at('body_start_line', 'body_end_line_exclusive', 'section', 'revision')
    last = dispatch(:dossier_read, **args, start_line: page['continuation'])
    assert_nil last['continuation']
    body = page['content'] + last['content']
    assert_equal "body one\r\nbody two\r\n", body
    edit = { id: id, mode: 'replace_section', expected_revision: 1, section: 'L1' }
    assert_equal false, dispatch(:dossier_update, **edit, content: body)['changed']
    assert_raise(ParameterException) { dispatch(:dossier_update, **edit) }
    dispatch(:dossier_update, **edit, content: body.sub('one', 'changed'))
    assert_equal text.sub('one', 'changed'), dispatch(:dossier_read, id: id)['content']
    assert_equal page.merge('current_revision' => 2), dispatch(:dossier_read, **args)
    assert_raise(ParameterException) { dispatch(:dossier_read, id: id, body_only: true) }
  end

  def test_empty_direct_body_and_add_boundaries
    id = dispatch(:dossier_create, type: 'claim', title: 'Scope', content: "# Scope")['id']
    read = dispatch(:dossier_read, id: id, section: 'L1', body_only: true)
    assert_equal ['', 2, 2], read.values_at('content', 'body_start_line', 'body_end_line_exclusive')
    no_op = dispatch(:dossier_update, id: id, mode: 'replace_section', section: 'L1',
                     expected_revision: 1, content: read['content'])
    assert_equal false, no_op['changed']
    assert_equal '# Scope', dispatch(:dossier_read, id: id)['content']
    text = "# T\r\n## P\r\nprose\r\n## S\r\n"
    changed = Research::Sections.edit(text, 'add_section', 'L2', "### New\r\nbody")
    assert_equal text.sub("prose\r\n", "prose\r\n\r\n### New\r\nbody\r\n\r\n"), changed
    spaced = "# T\nprose\n\n\n"
    assert_equal spaced + "## New", Research::Sections.edit(spaced, 'add_section', 'L1', '## New')
  end

  def test_regeneration_uses_pinned_full_digest
    id = dispatch(:dossier_create, type: 'claim', title: 'Reproduction')['id']
    src = File.join(File.dirname(@project), 'sources/table.tsv')
    item = dispatch(:evidence_attach, id: id, expected_revision: 1, compact: true,
                    items: [{ source: src, slot: 'data' }].to_json)['items'].first
    original = dispatch(:evidence_read, **item['evidence_read'], digest: item['digest_prefix'], max_lines: 1)
    assert_equal ['copy', 'ok'], [original['mode'], original['integrity']['state']]
    rerun = File.join(@project, 'regenerated.tsv')
    File.binwrite(rerun, File.binread(src))
    assert_equal original['sha256'], Digest::SHA256.file(rerun).hexdigest
    File.open(rerun, 'ab') { |f| f.write("different\n") }
    assert_not_equal original['sha256'], Digest::SHA256.file(rerun).hexdigest
  end

  def test_reference_pointer_and_observed_bytes_have_distinct_identities
    id = dispatch(:dossier_create, type: 'question', title: 'Reference')['id']
    source = File.join(File.dirname(@project), 'sources/table.tsv')
    item = dispatch(:evidence_attach, id: id, expected_revision: 1, change_kind: 'documentary',
                    items: [{ source: source, slot: 'tables', mode: 'reference' }].to_json)['items'].first
    read = dispatch(:evidence_read, id: id, digest: item.fetch('evidence_digest'))
    assert_equal 'reference_pointer', read['retained_kind']
    assert_equal Digest::SHA256.file(source).hexdigest, read['sha256']
    assert_equal Digest::SHA256.file(File.join(@project, item['project_locator'])).hexdigest, read['retained_digest']
    assert_not_equal read['sha256'], read['retained_digest']
    assert_equal 'documentary', dispatch(:dossier_history, id: id)['revisions'].first['change_kind']
  end

  def test_capture_and_unclassified_review
    c = dispatch(:dossier_create, type: 'claim', title: 'Scope')['id']
    q = dispatch(:dossier_create, type: 'question', title: 'Q',
                 content: "[premise](#{c} \"reviewed@1\")")['id']
    File.write(File.join(@project, 'research', 'claims', c, 'README.md'), "# Scope revised\n")
    dispatch(:dossier_capture, id: c, expected_revision: 1, change_note: 'Adopt scope')
    check = -> { dispatch(:dossier_backlinks, id: c)['links'].first }
    assert_equal 'classification_unknown', check.call['review_status']
    dispatch(:dossier_update, id: q, expected_revision: 1, mode: 'replace_text',
             old_text: 'reviewed@1', new_text: 'reviewed@2', change_kind: 'documentary')
    assert_equal 'current', check.call['review_status']
  end

  def test_prefix_collision_and_multiple_receipts
    a = 'abcde1'.ljust(64, '0')
    b = 'abcde2'.ljust(64, '0')
    lib = Research::EvidenceIdentity
    records = { 'a' => a, 'b' => b, 'also_a' => a }
    assert_equal 'abcde1', lib.prefixes([a, b]).fetch(a)
    assert_raise(ParameterException) { lib.resolve!(records, 'abcde', nil) }
    assert_raise(ParameterException) { lib.resolve!(records, 'abcde1', nil) }
    assert_equal 'also_a', lib.resolve!(records, 'abcde1', 'also_a')
    assert_equal 'b', lib.resolve!(records, b, nil)
  end

  def test_legacy_link_checks_its_document_path
    c = dispatch(:dossier_create, type: 'claim', title: 'T')['id']
    q = dispatch(:dossier_create, type: 'question', title: 'Q', content: "[limitation](#{c}/supplements/absent.md#limits)")['id']
    report = dispatch(:dossier_check, id: q)
    assert_include report['dossiers'].first['findings'].map { |f| f['category'] }, 'local_link_broken'
  end
end
