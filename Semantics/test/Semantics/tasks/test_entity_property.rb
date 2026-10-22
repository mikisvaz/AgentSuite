require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'test/unit'
require 'json'
$LOAD_PATH.unshift(File.expand_path('lib', File.dirname(File.expand_path(File.join(__dir__, '../../..')))))
require File.expand_path('../../../workflow.rb', File.dirname(File.expand_path(__FILE__)))

# Tests for lib/Semantics/tasks/entity_property.rb (single-entity query).
#
# The checkout carries no entity drafts of its own (Semantics is a general
# semantic layer), so these tests define a probe entity module in-process —
# the same registration a loaded share/entities draft performs — and run the
# real task jobs against it. No network is involved.
class TestSemanticsEntityProperty < Test::Unit::TestCase
  module ProbePropertyWidget
    extend EntityWorkflow
    property :probe_value => :single do |factor = 2|
      raise "widget #{self} is not computable" if self.to_s == 'boom'
      self.to_s.to_i * factor
    end
    property :probe_documents => :array do |output_dir: nil|
      label = first.to_s
      dir = Path.setup(output_dir || Path.tmpdir)
      file = File.join(dir, "#{label}.txt")
      Open.write(file, "document for #{label}")
      ["#{label}:1", "#{label}:2"]
    end
  end

  def setup
    @entity_type = 'probe_property_widget'
  end

  def test_single_entity_query_returns_result_and_receipt
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: '7',
                                          property: 'probe_value')
    job.clean
    record = job.run

    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert_equal '7', record[:entity]
    assert_equal 'probe_value', record[:property]
    assert_equal 14, record[:result]

    receipt = record[:receipt]
    assert_equal false, receipt[:step_backed], 'receipt claims a Step that does not exist'
    assert_equal '7', receipt[:dispatched][:entity]
    assert receipt[:job][:path].to_s.start_with?(File.join(ENV['HOME'], '.scout')),
           "job path does not look like a Scout job: #{receipt[:job][:path]}"
    assert File.exist?(receipt[:job][:path]),
           "receipt job file does not exist: #{receipt[:job][:path]}"
    assert_equal 'entity_property', receipt[:job][:task]
    assert_equal 'Semantics', receipt[:job][:workflow]
  end

  def test_arguments_kwarg_is_forwarded
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: '7',
                                          property: 'probe_value',
                                          arguments: '{"factor": 5}')
    job.clean
    record = job.run
    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert_equal 35, record[:result], 'positional opt argument not forwarded from arguments JSON'
  end

  def test_arguments_string_kwarg_is_forwarded
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: '8',
                                          property: 'probe_value',
                                          arguments: '{"factor": 10}')
    job.clean
    record = job.run
    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert_equal 80, record[:result]
  end

  def test_payload_output_dir_lands_in_job_files_dir
    # The bulk-payload contract: dispatching a property that declares an
    # output_dir kwarg without passing one routes the payloads into the task
    # job's files_dir, and the result carries the payload_dir pointer.
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: 'gene-a',
                                          property: 'probe_documents')
    job.clean
    record = job.run

    assert_equal 'done', record[:status], "error: #{record[:error].inspect}"
    assert_equal %w[gene-a:1 gene-a:2], record[:result]
    assert record[:payload_dir].to_s.start_with?(job.path.to_s + '.files'),
           "payload_dir not under the job files_dir: #{record[:payload_dir]}"
    file = File.join(record[:payload_dir].to_s, 'gene-a.txt')
    assert File.exist?(file), "payload file missing: #{file}"
    assert_equal 'document for gene-a', File.read(file)
  end

  def test_property_execution_failure_becomes_error_envelope
    # A property that raises returns a structured error record, never an
    # exception from the task, and the receipt is still present.
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: 'boom',
                                          property: 'probe_value',
                                          arguments: '{"factor": 3}')
    job.clean
    record = job.run
    assert_equal 'error', record[:status]
    assert_equal 'boom', record[:entity]
    assert record[:error][:class], 'error envelope without class'
    assert record[:error][:message], 'error envelope without message'
    assert record[:receipt], 'error record missing receipt'
  end

  def test_unknown_property_aborts_loudly
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: '7',
                                          property: 'no_such_property')
    assert_raise ParameterException do
      job.run
    end
  end

  def test_unknown_entity_type_aborts_loudly
    job = Semantics.job(:entity_property, entity_type: 'no_such_entity_type',
                                          entity: '7',
                                          property: 'probe_value')
    assert_raise ParameterException do
      job.run
    end
  end

  def test_malformed_arguments_abort_loudly
    job = Semantics.job(:entity_property, entity_type: @entity_type,
                                          entity: '7',
                                          property: 'probe_value',
                                          arguments: 'not json')
    assert_raise ParameterException do
      job.run
    end
  end
end
