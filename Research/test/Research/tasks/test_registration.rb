require 'test/unit'
require 'scout'
require 'scout-ai'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'Research', 'lib'))
require File.join(ROOT, 'Research', 'workflow')

class TestResearchRegistration < Test::Unit::TestCase
  def test_workflow_loads_and_registers_expected_tasks
    names = Research.tasks.keys.map(&:to_sym)
    %i[searxng docx2md pdf2md_full pdf2md_no_images pdf2md html2md excerpts rag query pdf_query html_query].each do |name|
      assert_include names, name
    end
  end

  def test_aliases_are_registered
    names = Research.tasks.keys.map(&:to_sym)
    %i[pdf2md pdf_query html_query].each { |name| assert_include names, name }
  end

  def test_excerpts_task_runs_without_external_services
    text = 'This is a locally testable paragraph containing more than forty characters for the paragraph chunking rule.'
    job = Research.job(:excerpts, nil, text: text, strategy: 'paragraph', chunk_words: 50, overlap: 10)
    ids = job.run
    assert_equal 1, ids.length
    assert_match(/locally testable paragraph/, job.file(ids.first).read)
  end
end
