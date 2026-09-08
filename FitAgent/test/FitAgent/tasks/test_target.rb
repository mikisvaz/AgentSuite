# Dummy second-target test: the harness core fits a DIFFERENT target with
# zero edits in lib/. A tiny throwaway workflow checkout + target config +
# catalogue live under test/fixtures/dummy_target/; this test selects it
# purely via TargetSpec.load / Scenarios.load and asserts the catalogue,
# defaults, materialization and grammar derivation all follow the target
# DATA (no workflow name is hardcoded in lib/).
require File.expand_path('../../test_helper', __dir__)
require 'tmpdir'
require 'FitAgent/proposer'

class TestDummyTarget < Test::Unit::TestCase
  FIXTURE = File.expand_path('../../fixtures/dummy_target', __dir__)

  def test_second_target_loads_and_materializes
    Dir.mktmpdir('fitagent-dummy') do |tmp|
      # a throwaway "checkout" for the dummy workflow
      checkout = File.join(tmp, 'Dummy')
      FileUtils.mkdir_p(checkout)
      File.write(File.join(checkout, 'workflow.rb'),
                 "# dummy target workflow\nclass DummyWorkflow; end\n")

      ENV['FITAGENT_DUMMY_DIR'] = checkout
      begin
        target = FitAgent::TargetSpec.load(File.join(FIXTURE, 'target.yaml'))

        assert_equal 'dummy', target.name
        assert_equal checkout, target.workflow_dir
        assert_equal ['Dummy echo'], target.tools
        assert_equal 'echo', target.message_rules['tool']
        assert_equal 1, target.message_rules['min_calls']
        assert_equal({ 'applied' => true }, target.message_rules['expect'])

        # loading by target (not by raw catalogue path) registers the
        # catalogue and the defaults together
        FitAgent::Scenarios.load(target)
        assert_equal %w[D01 D02], FitAgent::Scenarios.definitions.map { |d| d['id'] }

        # the target's default message rules are the define() fallbacks
        d01 = FitAgent::Scenarios.definitions.first
        assert_equal 'echo', d01['message_rules']['tool']
        assert_equal 1, d01['message_rules']['min_calls']
        assert_equal({ 'applied' => true }, d01['message_rules']['expect'])

        # materialization works from the second target alone
        set = File.join(tmp, 'set')
        FitAgent::Scenarios.materialize(set, ids: %w[D01 D02])
        assert_equal %w[D01 D02], FitAgent::Scenarios.scenario_ids(set)
        assert File.file?(File.join(set, 'D01', 'rubric.yaml'))

        # grammar derivation follows the target's primary tool
        assert_equal 'Dummy echo', FitAgent::Evolve.default_tool_example
        assert_equal 'Dummy echo', FitAgent::DefaultProposer.repair_example_spec
      ensure
        ENV.delete('FITAGENT_DUMMY_DIR')
        # restore the repo default target for any later test in this process
        FitAgent::Scenarios.load(FitAgent::TargetSpec.load(
                                   File.expand_path('../../../examples/computeruse-patch/target.yaml', __dir__)
                                 ))
      end
    end
  end

  # Loading a target by config path alone (no Scenarios.load of the example)
  # must not silently keep the previously loaded catalogue.
  def test_second_target_replaces_catalogue
    ENV['FITAGENT_DUMMY_DIR'] = FIXTURE
    begin
      FitAgent::Scenarios.load(FitAgent::TargetSpec.load(File.join(FIXTURE, 'target.yaml')))
      assert_equal %w[D01 D02], FitAgent::Scenarios.definitions.map { |d| d['id'] }
    ensure
      ENV.delete('FITAGENT_DUMMY_DIR')
      FitAgent::Scenarios.load(FitAgent::TargetSpec.load(
                                 File.expand_path('../../../examples/computeruse-patch/target.yaml', __dir__)
                               ))
    end
  end
end
