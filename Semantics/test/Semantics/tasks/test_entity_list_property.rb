require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'test/unit'
require 'json'
$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(File.expand_path(File.join(__dir__, '../../..')))))
require File.expand_path('../../../workflow.rb', File.dirname(File.expand_path(__FILE__)))

# Tests for lib/Semantics/tasks/entity_list_property.rb (per-entity fan-out).
#
# Structure assertions only, as specified: per-entity status logic must hold
# for both the live path and the network-down path (bogus id failing or, with
# network up, returning an empty done result; valid ids done either way), so
# the tests never assert specific PMIDs.
class TestSemanticsEntityPropertyList < Test::Unit::TestCase
  PMID_RE = /\A\d{6,9}\z/

  def setup
    @entity_type = Dir.glob(File.expand_path('../../../share/entities/*.rb', __dir__))
                      .collect { |file| File.basename(file, '.rb') }.first
    # These tests assert the PMID-list property shape (String PMIDs);
    # the sibling pubmed_article_details property returns Hash entries
    # and is covered by its own paired share-side test.
    @property = 'pubmed_articles'
        entity_module = Object.const_get(@entity_type.split('_').collect(&:capitalize).join, false)
    @fixture_ids = entity_module.const_get(:FIXTURE_PUBMED_ARTICLES).keys
    @bogus_id = 'ZZZQQQNOTAGENE123'
    assert @fixture_ids.length >= 2, 'need at least two fixture-bearing ids for the fan-out test'
  end

  def test_list_query_returns_per_entity_records
    entities = [@fixture_ids[0], @fixture_ids[1], @bogus_id].join("\n")
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                                property: @property,
                                                entities: entities)
    job.clean
    result = job.run

    assert_equal 'done', result[:status]
    assert_equal @entity_type, result[:entity_type]
    assert_equal @property, result[:property]
    assert_equal 3, result[:count]
    assert_equal result[:count], result[:done] + result[:failed]

    records = result[:records]
    assert_equal 3, records.length
    assert_equal [@fixture_ids[0], @fixture_ids[1], @bogus_id], records.collect { |record| record[:entity] }

    # Every record is either done (with a result field) or failed (with an
    # error envelope). Both are acceptable shapes; the bogus id may be either
    # depending on network state (empty live result or a network-down raise).
    records.each do |record|
      case record[:status]
      when :done
        assert record.key?(:result), "done record without result: #{record.inspect}"
      when :failed
        assert record.key?(:error), "failed record without error: #{record.inspect}"
        assert record[:error][:class], 'error envelope without class'
        assert record[:error][:message], 'error envelope without message'
      else
        flunk "record status must be :done or :failed, got #{record[:status].inspect}"
      end
    end

    # Valid (fixture-bearing) entities are done under BOTH network regimes:
    # live results when the network is up, fixture PMIDs when it is down.
    records[0..1].each do |record|
      assert_equal :done, record[:status], "valid entity #{record[:entity]} not done: #{record.inspect}"
      assert record[:result].is_a?(Array), "result is not an Array: #{record[:result].inspect}"
      assert record[:result].all? { |pmid| pmid =~ PMID_RE },
             "non-PMID entries for #{record[:entity]}: #{record[:result].inspect}"
    end

    receipt = result[:receipt]
    assert_equal false, receipt[:step_backed]
    assert File.exist?(receipt[:job][:path])
    assert_equal 'entity_list_property', receipt[:job][:task]

    $stderr.puts "PATH[list]=" +
                 records.collect { |record| "#{record[:entity]}:#{record[:status]}" }.join(',')
  end

  def test_one_entity_failure_does_not_block_the_rest
    # A bogus FIRST entity followed by valid ones: the failure is recorded
    # and the valid entities still dispatch.
    entities = [@bogus_id, @fixture_ids[0]].join("\n")
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                                property: @property,
                                                entities: entities)
    job.clean
    result = job.run

    assert_equal 2, result[:count]
    records = result[:records]
    assert_equal @bogus_id, records.first[:entity]
    # Network up: bogus is :done with []. Network down: :failed with an error
    # envelope. Either way the valid entity must be :done with PMIDs.
    valid = records.last
    assert_equal :done, valid[:status], "valid entity failed after bogus entity: #{valid.inspect}"
    assert valid[:result].is_a?(Array) && !valid[:result].empty?
  end

  def test_arguments_kwarg_applies_to_each_entity
    entities = @fixture_ids[0..1].join("\n")
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                                property: @property,
                                                entities: entities,
                                                arguments: '{"max": 2}')
    job.clean
    result = job.run
    result[:records].each do |record|
      next unless record[:status] == :done
      assert record[:result].length <= 2, "max: 2 not honored for #{record[:entity]}: #{record[:result].inspect}"
    end
  end

  def test_empty_entities_aborts
    job = Semantics.job(:entity_list_property, entity_type: @entity_type,
                                                property: @property,
                                                entities: '')
    assert_raise ParameterException do
      job.run
    end
  end
end
