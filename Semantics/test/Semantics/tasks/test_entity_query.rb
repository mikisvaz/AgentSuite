require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'test/unit'
require 'json'
$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(File.expand_path(File.join(__dir__, '../../..')))))
require File.expand_path('../../../workflow.rb', File.dirname(File.expand_path(__FILE__)))

# Tests for lib/Semantics/tasks/entity_query.rb (Semantics::EntityQuery and
# the list_entities task).
#
# Discovery must come from registration, not literals: the assertions derive
# the expected gene/property names from the share/ draft filenames, so a grep
# of this file for entity names must come up empty by design. This test file
# DOES contain the names in comments only for documentation, never in code.
class TestSemanticsListEntities < Test::Unit::TestCase
  def setup
    @draft_names = Dir.glob(File.expand_path('../../../share/entities/*.rb', __dir__))
                      .collect { |file| File.basename(file, '.rb') }
    assert !@draft_names.empty?, 'no share/entities drafts found; test setup invalid'
  end

  def test_lists_all_drafted_entities_as_registered
    listing = Semantics.job(:list_entities).run

    listed = listing.collect { |record| record[:entity] }
    assert_equal @draft_names.sort, listed.sort,
                 'list_entities did not report every drafted entity type'

    listing.each do |record|
      assert_equal true, record[:registered], "#{record[:entity]} reported as not registered"
      assert_equal true, record[:entity_workflow], "#{record[:entity]} does not extend EntityWorkflow"
      assert record[:properties].any? { |prop| prop[:property] == 'job' },
             "#{record[:entity]} is missing the framework :job property"
    end
  end

  def test_lists_the_generated_property_without_literals
    listing = Semantics.job(:list_entities).run

    gene_record = listing.find { |record| record[:entity] == @draft_names.first }
    property_names = gene_record[:properties].collect { |prop| prop[:property] }
    draft_properties = Dir.glob(File.expand_path('../../../share/entity_properties/**/*.rb', __dir__))
                          .collect { |file| File.basename(file, '.rb') }
    assert_equal draft_properties.sort, (property_names - ['job']).sort,
                 'registered properties do not match the drafted property files'
  end

  def test_task_source_carries_no_entity_literals
    task_source = File.read(File.expand_path('../../../lib/Semantics/tasks/entity_query.rb', __dir__))
    @draft_names.each do |name|
      constant = name.split('_').collect(&:capitalize).join
      assert_nil task_source =~ /#{Regexp.escape(constant)}(?![A-Za-z_])/,
                 "task source mentions entity constant #{constant}"
    end
    draft_properties = Dir.glob(File.expand_path('../../../share/entity_properties/**/*.rb', __dir__))
                          .collect { |file| File.basename(file, '.rb') }
    draft_properties.each do |property|
      assert_nil task_source =~ /#{Regexp.escape(property)}/,
                 "task source mentions property name #{property}"
    end
  end

  def test_resolve_property_rejects_unknowns
    assert_raise ParameterException do
      Semantics::EntityQuery.resolve_property!('no_such_entity_type', 'whatever')
    end
    known = @draft_names.first
    assert_raise ParameterException do
      Semantics::EntityQuery.resolve_property!(known, 'no_such_property')
    end
    mod, prop = Semantics::EntityQuery.resolve_property!(
      known,
      Dir.glob(File.expand_path("../../../share/entity_properties/#{known}/*.rb", __dir__))
         .collect { |file| File.basename(file, '.rb') }.first
    )
    assert mod.is_a?(Module), 'resolve_property! did not return a module'
  end

  def test_parse_arguments_accepts_json_hash_and_nil
    assert_equal({}, Semantics::EntityQuery.parse_arguments(nil))
    assert_equal({}, Semantics::EntityQuery.parse_arguments(''))
    assert_equal({ max: 2 }, Semantics::EntityQuery.parse_arguments('{"max": 2}'))
    # A plain Hash passes through unchanged (String keys stay String keys;
    # only the JSON-string path symbolizes keys).
    assert_equal({ 'max' => 2 }, Semantics::EntityQuery.parse_arguments('max' => 2))
    assert_raise ParameterException do
      Semantics::EntityQuery.parse_arguments('[1,2,3]')
    end
    assert_raise ParameterException do
      Semantics::EntityQuery.parse_arguments('not json')
    end
    assert_raise ParameterException do
      Semantics::EntityQuery.parse_arguments(42)
    end
  end
end
