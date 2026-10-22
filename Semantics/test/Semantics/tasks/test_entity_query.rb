require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'test/unit'
require 'json'
$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(File.expand_path(File.join(__dir__, '../../..')))))
require File.expand_path('../../../workflow.rb', File.dirname(File.expand_path(__FILE__)))

# Tests for lib/Semantics/tasks/entity_query.rb (Semantics::EntityQuery and
# the list_entities task).
#
# Discovery is REGISTRY-driven (Entity::MODULES), so these tests register
# their own probe entity module — the same registration a loaded
# share/entities draft performs — and assert discovery finds it through the
# task. No share/ layout is assumed: the checkout may carry zero drafts.
class TestSemanticsListEntities < Test::Unit::TestCase
  module ProbeDiscoveryWidget
    extend EntityWorkflow
    property :probe_single => :single do |factor = 2|
      self.to_s.to_i * factor
    end
    property :probe_multiple => :multiple do
      collect { |item| "m:#{item}" }
    end
    property :probe_plain do
      "plain:#{self}"
    end
  end

  def setup
    @probe_name = 'probe_discovery_widget'
  end

  def test_lists_registered_probe_and_framework_entities
    listing = Semantics.job(:list_entities).clean.run

    names = listing.collect { |record| record[:entity] }
    assert names.include?(@probe_name),
           "registry listing does not include the probe entity: #{names.inspect}"
    assert names.include?('association_item'),
           'registry listing does not include the framework AssociationItem'

    probe = listing.find { |record| record[:entity] == @probe_name }
    assert probe[:constant].end_with?('ProbeDiscoveryWidget'),
           "unexpected constant name: #{probe[:constant].inspect}"
    assert_equal true, probe[:entity_workflow]
  end

  def test_lists_properties_with_effective_dispatch_and_parameters
    probe = Semantics.job(:list_entities).clean.run
                   .find { |record| record[:entity] == @probe_name }
    props = probe[:properties].collect { |p| [p[:property], p] }.to_h

    assert props.key?('probe_single'), "probe_single not listed: #{props.keys.inspect}"
    assert_equal 'single', props['probe_single'][:dispatch]
    assert_equal [{ kind: 'opt', name: 'factor' }], props['probe_single'][:parameters]
    assert_equal 'multiple', props['probe_multiple'][:dispatch]
    assert_equal 'both', props['probe_plain'][:dispatch], 'typeless property must report :both'
    assert_equal false, props['probe_plain'][:persisted]
    assert props.key?('job'), 'EntityWorkflow entity is missing the framework :job property'
  end

  def test_source_reports_ownership_boundary
    probe = Semantics.job(:list_entities).clean.run
                   .find { |record| record[:entity] == @probe_name }
    # The probe module is not defined by a checkout file; source must say so
    # instead of inventing one.
    assert_nil probe[:source], "inline probe reported a checkout source: #{probe[:source].inspect}"

    framework = Semantics.job(:list_entities).clean.run
                      .find { |record| record[:entity] == 'association_item' }
    assert_nil framework[:source], 'framework entity must not claim checkout ownership'
  end

  def test_resolve_property_rejects_unknowns
    assert_raise(ParameterException) do
      Semantics::EntityQuery.resolve_property!('no_such_entity_type', 'whatever')
    end
    assert_raise(ParameterException) do
      Semantics::EntityQuery.resolve_property!(@probe_name, 'no_such_property')
    end
    mod, prop = Semantics::EntityQuery.resolve_property!(@probe_name, 'probe_single')
    assert_equal ProbeDiscoveryWidget, mod
    assert_equal :probe_single, prop
  end

  def test_resolve_property_accepts_constant_name
    mod, = Semantics::EntityQuery.resolve_property!('ProbeDiscoveryWidget', 'probe_plain')
    assert_equal ProbeDiscoveryWidget, mod, 'constant spelling must resolve like the snake_case one'
  end

  def test_entity_name_uses_last_constant_segment
    assert_equal @probe_name, Semantics::EntityQuery.entity_name(ProbeDiscoveryWidget)
  end

  def test_parse_arguments_accepts_json_hash_and_nil
    assert_equal({}, Semantics::EntityQuery.parse_arguments(nil))
    assert_equal({}, Semantics::EntityQuery.parse_arguments(''))
    assert_equal({ max: 2 }, Semantics::EntityQuery.parse_arguments('{"max": 2}'))
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

  def test_task_source_carries_no_entity_literals
    source = File.read(File.expand_path('../../../lib/Semantics/tasks/entity_query.rb', __dir__))
    %w[Gene TP53 pubmed].each do |literal|
      assert_nil source =~ /#{literal}/,
                 "task source mentions #{literal}; discovery must stay literal-free"
    end
  end
end
