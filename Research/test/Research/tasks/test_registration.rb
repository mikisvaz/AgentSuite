require 'test/unit'
require 'scout'
require 'scout-ai'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'Research', 'lib'))
require File.join(ROOT, 'Research', 'workflow')

class TestResearchRegistration < Test::Unit::TestCase
  def test_workflow_loads
    assert_equal 'Research', Research.name
  end

  def test_moved_tasks_are_not_registered
    names = Research.tasks.keys.map(&:to_sym)
    %i[searxng docx2md pdf2md_full pdf2md_no_images pdf2md html2md excerpts rag query pdf_query html_query].each do |name|
      assert_not_include names, name, "task #{name} moved to Reader must not be registered on Research"
    end
  end

  def test_path_kinds_still_present
    assert defined?(Research::PATH_KINDS)
    %i[claim hypothesis observation].each do |kind|
      assert_include Research::PATH_KINDS.keys.map(&:to_sym), kind
    end
  end

  def test_workspace_helpers_still_merged
    assert Research.helpers.key?(:cmd_json), 'Workspace helpers must stay merged into Research'
  end
end
