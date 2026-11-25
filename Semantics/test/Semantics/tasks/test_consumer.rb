require 'test/unit'
require 'tmpdir'
require 'open3'
require 'fileutils'
require 'json'
require 'digest'
require 'rbconfig'

class TestSemanticsConsumer < Test::Unit::TestCase
  WORKFLOW = File.expand_path('../../../workflow.rb', __dir__)

  def child(directory, script, *arguments)
    output, diagnostics, status = Open3.capture3(RbConfig.ruby, '-e', script, *arguments, chdir: directory)
    assert_predicate status, :success?, diagnostics
    JSON.parse(output.lines.last)
  end

  def test_foreign_workflow_to_persisted_evidence
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'share/entities'))
      FileUtils.mkdir_p(File.join(dir, 'share/entity_properties/ConsumerItem'))
      File.write(File.join(dir, 'workflow.rb'), <<~'SOURCE')
        require 'scout-ai'
        require 'scout/workflow/live'
        module ConsumerProject
          extend Workflow
        end
        ConsumerProject.libdir = __dir__
        ConsumerProject.extend LiveWorkflow
      SOURCE
      File.write(File.join(dir, 'share/entities/ConsumerItem.rb'), <<~'SOURCE')
        module ConsumerItem
          extend EntityWorkflow
          property(:next_id => :single) { succ }
        end
      SOURCE
      File.write(File.join(dir, 'share/entity_properties/ConsumerItem/summary.rb'), <<~'SOURCE')
        ConsumerItem.property(:summary => :single) { { count: to_i, comparable: false } }
      SOURCE
      path, digest, source = child(dir, <<~'SOURCE', WORKFLOW)
        require ARGV.fetch(0)
        require 'digest'
        row = LLM.call_workflow(Semantics, :list_entities).find { |r| r[:entity] == 'ConsumerItem' }
        type = row.fetch(:constant)
        id = LLM.call_workflow(Semantics, :entity_property, entity_type: type, entity: '6',
                               property: 'next_id', refresh: 'refresh').run.fetch(:result)
        inputs = { entity_type: type, entity: id, property: 'summary' }
        path = LLM.call_workflow(Semantics, :entity_property, **inputs, refresh: 'refresh', return_path: true)
        Semantics.job(:entity_property, inputs).join
        source = row.fetch(:properties).find { |prop| prop[:property] == 'summary' }.fetch(:source)
        puts JSON.generate([path.to_s, Digest::SHA256.file(path).hexdigest, source])
      SOURCE
      assert_equal File.join(dir, 'share/entity_properties/ConsumerItem/summary.rb'), source
      evidence = child(dir, <<~'SOURCE', path)
        require 'json'
        require 'digest'
        bytes = File.binread(ARGV.fetch(0))
        record = JSON.parse(bytes)
        puts JSON.generate([record.fetch('status'), record.fetch('entity_type'), record.fetch('entity'),
                            record.fetch('result').fetch('count'), record.fetch('result').fetch('comparable'),
                            Digest::SHA256.hexdigest(bytes)])
      SOURCE
      assert_equal ['done', 'ConsumerItem', '7', 7, false, digest], evidence
    end
  end
end
