require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'test/unit'
require 'json'
$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(File.expand_path(File.join(__dir__, '../../..')))))
require File.expand_path('../../../workflow.rb', File.dirname(File.expand_path(__FILE__)))

# Tests for lib/Semantics/tasks/entity_property.rb (single-entity query).
#
# Entity/property names are derived from the share/ drafts, never written as
# literals. The PMID regex is generic (digits only), so the assertions hold
# for both the live path and the fixture path.
class TestSemanticsEntityProperty < Test::Unit::TestCase
  PMID_RE = /\A\d{6,9}\z/

  def setup
    @entity_type = Dir.glob(File.expand_path('../../../share/entities/*.rb', __dir__))
                      .collect { |file| File.basename(file, '.rb') }.first
    # These tests assert the PMID-list property shape (String PMIDs);
    # the sibling pubmed_article_details property returns Hash entries
    # and is covered by its own paired share-side test.
    @property = 'pubmed_articles'
    # The fixture-bearing gene ids used by the draft's fallback map. Derived
    # by reading the draft constant rather than hardcoding, so this test does
    # not name any gene either.
    entity_module = Object.const_get(@entity_type.split('_').collect(&:capitalize).join, false)
    @fixture_ids = entity_module.const_get(:FIXTURE_PUBMED_ARTICLES).keys
    @query_id = @fixture_ids.first
  end

  def test_single_entity_query_returns_result_and_receipt
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: @query_id,
                                          property: @property)
    job.clean
    record = job.run

    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert_equal @query_id, record[:entity]
    assert_equal @property, record[:property]

    result = record[:result]
    assert Array === result, "result is not an Array: #{result.inspect}"
    assert !result.empty?, 'result empty for a fixture-bearing gene'
    assert result.all? { |pmid| String === pmid && pmid =~ PMID_RE },
           "non-PMID-shaped entries: #{result.inspect}"

    receipt = record[:receipt]
    assert_equal false, receipt[:step_backed], 'receipt claims a Step that does not exist'
    assert_equal @query_id, receipt[:dispatched][:entity]
    assert receipt[:job][:path].to_s.start_with?(File.join(ENV['HOME'], '.scout')),
           "job path does not look like a Scout job: #{receipt[:job][:path]}"
    assert File.exist?(receipt[:job][:path]),
           "receipt job file does not exist: #{receipt[:job][:path]}"
    assert_equal 'entity_property', receipt[:job][:task]
    assert_equal 'Semantics', receipt[:job][:workflow]
    $stderr.puts "PATH[single]=#{result.sort == @fixture_ids.map { |g| Object.const_get(@entity_type.split('_').collect(&:capitalize).join, false).const_get(:FIXTURE_PUBMED_ARTICLES)[g] }.flatten.sort ? 'fixture' : 'live'}"
  end

  def test_arguments_kwarg_is_forwarded
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: @query_id,
                                          property: @property,
                                          arguments: '{"max": 2}')
    job.clean
    record = job.run
    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert record[:result].length <= 2, "max: 2 not honored: #{record[:result].inspect}"
  end

  def test_payload_output_dir_lands_in_job_files_dir
    # The abstract-outputs contract: dispatching a property that declares an
    # output_dir kwarg without passing one routes the bulk payloads into the
    # task job's files_dir, and the result entry carries only a POINTER.
    # Property name is derived from the drafts, not hardcoded.
    detail_property = Dir.glob(File.expand_path("../../../share/entity_properties/#{@entity_type}/*.rb", __dir__))
                         .collect { |file| File.basename(file, '.rb') }
                         .find { |name| name.include?('details') }
    skip 'no details property drafted; nothing to test' if detail_property.nil?

    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: @query_id,
                                          property: detail_property,
                                          arguments: %q({"pmids": ["20182602"]}))
    job.clean
    record = job.run

    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert record[:payload_dir].to_s.start_with?(job.path.to_s + '.files'),
           "payload_dir not under the job files_dir: #{record[:payload_dir]}"
    entry = record[:result].first
    assert_nil entry[:abstract], 'result entry carries abstract text; contract is pointer-only'
    file = entry[:abstract_file]
    assert file.to_s.start_with?(record[:payload_dir].to_s),
           "abstract_file not inside payload_dir: #{file}"
    assert File.exist?(file), "abstract payload file missing: #{file}"
    assert File.read(file).length > 100, 'abstract payload suspiciously short'
  end

  def test_unknown_property_aborts_loudly
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: @query_id,
                                          property: 'no_such_property')
    assert_raise ParameterException do
      job.run
    end
  end

  def test_unknown_entity_type_aborts_loudly
    job = Semantics.job(:entity_property, entity_type: 'no_such_entity_type',
                                          entity: @query_id,
                                          property: @property)
    assert_raise ParameterException do
      job.run
    end
  end
end
