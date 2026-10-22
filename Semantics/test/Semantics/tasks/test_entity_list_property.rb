require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'test/unit'
require 'json'
$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(File.expand_path(File.join(__dir__, '../../..')))))
require File.expand_path('../../../workflow.rb', File.dirname(File.expand_path(__FILE__)))

# Tests for lib/Semantics/tasks/entity_list_property.rb (list fan-out).
#
# The checkout carries no entity drafts, so the tests register probe entity
# modules covering every dispatch shape, then run the real task jobs. Every
# dispatch mode is exercised: :single, :array, :multiple (one-shot list
# dispatch through the special accessor) and typeless :both (per-entity
# fallback, because a 'both' block receives the receiver as-is).
class TestSemanticsEntityListProperty < Test::Unit::TestCase
  module ProbeListWidget
    extend EntityWorkflow
    property :probe_doubled => :single do |factor = 2|
      self.to_s.to_i * factor
    end
    property :probe_summary => :multiple do
      collect { |item| "m:#{item}" }
    end
    property :probe_tagged => :array do
      collect { |item| "#{item}-tag" }
    end
    property :probe_plain do
      "plain:#{self}"
    end
    property :probe_boom => :single do
      raise "boom for #{self}" unless self.to_s.start_with?('ok')
      "value:#{self}"
    end
  end

  def setup
    @entity_type = 'probe_list_widget'
  end

  def run_list(property, entities: %w[4 2], arguments: nil)
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                               property: property,
                                               entities: entities,
                                               arguments: arguments)
    job.clean
    job.run
  end

  def test_single_property_fans_out_per_entity
    result = run_list('probe_doubled')
    assert_equal 'done', result[:status]
    assert_equal 'list', result[:dispatch_mode]
    assert_equal 2, result[:count]
    assert_equal 2, result[:done]
    assert_equal 0, result[:failed]
    assert_equal [{ entity: '4', status: :done, result: 8 },
                  { entity: '2', status: :done, result: 4 }], result[:records]
  end

  def test_multiple_property_gets_whole_list
    result = run_list('probe_summary')
    assert_equal 'list', result[:dispatch_mode]
    assert_equal %w[m:4 m:2], result[:records].collect { |r| r[:result] }
  end

  def test_array_property_is_collected_element_wise
    result = run_list('probe_tagged')
    assert_equal 'list', result[:dispatch_mode]
    assert_equal %w[4-tag 2-tag], result[:records].collect { |r| r[:result] }
  end

  def test_typeless_property_falls_back_to_per_entity
    result = run_list('probe_plain')
    assert_equal 'per_entity', result[:dispatch_mode]
    assert_equal %w[plain:4 plain:2], result[:records].collect { |r| r[:result] }
  end

  def test_arguments_are_forwarded_in_list_mode
    result = run_list('probe_doubled', arguments: '{"factor": 10}')
    assert_equal 'list', result[:dispatch_mode]
    assert_equal [40, 20], result[:records].collect { |r| r[:result] }
  end

  def test_one_failure_never_blocks_the_rest
    result = run_list('probe_boom', entities: %w[ok-1 boom ok-2])
    assert_equal 3, result[:count]
    assert_equal 2, result[:done]
    assert_equal 1, result[:failed]

    records = result[:records]
    assert_equal 'ok-1', records[0][:entity]
    assert_equal :done, records[0][:status]
    assert_equal 'value:ok-1', records[0][:result]
    assert_equal 'boom', records[1][:entity]
    assert_equal :failed, records[1][:status]
    assert records[1][:error][:message].include?('boom for'), 'error envelope lost the message'
    assert_equal 'ok-2', records[2][:entity]
    assert_equal :done, records[2][:status]
  end

  def test_receipt_carries_job_identity
    result = run_list('probe_doubled')
    receipt = result[:receipt]
    assert_equal false, receipt[:step_backed]
    assert File.exist?(receipt[:job][:path]), 'receipt job file missing'
    assert_equal 'entity_list_property', receipt[:job][:task]
    assert_equal 'Semantics', receipt[:job][:workflow]
  end

  def test_empty_entities_abort_loudly
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                                property: 'probe_doubled',
                                                entities: '')
    assert_raise ParameterException do
      job.run
    end
  end

  def test_unknown_property_aborts_loudly
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                                property: 'no_such_property',
                                                entities: %w[4 2])
    assert_raise ParameterException do
      job.run
    end
  end

  def test_unknown_entity_type_aborts_loudly
    job = Semantics.job(:entity_list_property, entity_type: 'no_such_entity_type',
                                                property: 'probe_doubled',
                                                entities: %w[4 2])
    assert_raise ParameterException do
      job.run
    end
  end
end
