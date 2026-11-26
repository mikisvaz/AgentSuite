# Task registration and export contract (Bout A structural migration).
#
# This file pins the conventional-workflow shape after the migration:
#
#   - the native dossier tasks are registered and exec-exported;
#   - NO task carries a research_root input (the root is fixed
#     project-relative, resolved from Dir.pwd at execution time);
#   - the retired exec-memoization apparatus is gone (grep-clean):
#     no Research.job override, no dispatch_job_id, no
#     DISPATCH_EXEC_TASKS, no roots fallback chain;
#   - tasks are declared in ordinary task files under
#     lib/Research/tasks/, each file declaring exactly the task(s) it
#     owns (no service-module forwarding layer);
#   - loading workflow.rb must NOT transitively load the Workspace
#     workflow (no Workspace require, no helper merge);
#   - Research::PATH_KINDS stays gone (earlier retirement).
#
# The transitive-load check uses $LOADED_FEATURES: any file path under a
# Workspace checkout or install tree appearing there after require is a
# violation.

require 'test/unit'
require 'scout'

ROOT = File.expand_path('../../../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'Research', 'lib'))

class TestRegistration < Test::Unit::TestCase
  EXPECTED_TASKS = %w[dossier_backlinks dossier_capture dossier_check dossier_create
                      dossier_history dossier_list dossier_read
                      dossier_update evidence_attach evidence_read].freeze

  def workflow_root
    File.join(ROOT, 'Research')
  end

  def load_workflow!
    require File.join(workflow_root, 'workflow')
  end

  def test_tasks_registered_and_exec_exported
    load_workflow!
    assert_equal EXPECTED_TASKS, Research.tasks.keys.map(&:to_s).sort
    EXPECTED_TASKS.each do |t|
      assert_include Research.exec_exports.map(&:to_s), t,
                     "task #{t} must be exec-exported"
    end
  end

  def test_no_task_carries_research_root_input
    load_workflow!
    offenders = Research.tasks.select do |_name, task|
      task.inputs.any? { |i| i[0].to_s == 'research_root' }
    end
    assert_equal({}, offenders,
                 'no task may declare a research_root input; the root is ' \
                 'resolved from Dir.pwd at execution time')
  end

  def test_tasks_declared_in_task_files_not_in_workflow_bootstrap
    load_workflow!
    bootstrap = File.read(File.join(workflow_root, 'workflow.rb'))
    refute_match(/^\s*(input|desc|task|export_exec)\b/, bootstrap,
                 'workflow.rb must be a bootstrap only: no task DSL ' \
                 'declarations belong there')

    task_files = Dir.glob(File.join(workflow_root,
                                    'lib', 'Research', 'tasks', '*.rb'))
    declared = task_files.flat_map do |f|
      File.read(f).scan(/^\s*task\s+:([\w_]+)/).flatten
    end
    assert_equal EXPECTED_TASKS, declared.map(&:to_s).sort,
                 'every task must be declared in a task file under ' \
                 'lib/Research/tasks/ (one task per file)'
  end

  def test_no_service_module_forwarding_layer
    lib = File.join(workflow_root, 'lib')
    offenders = Dir.glob(File.join(lib, '**', '*.rb')).select do |f|
      src = File.read(f)
      src.match?(/^\s*module\s+Tasks\b/) &&
        src.match?(/^\s*def\s+call\b/)
    end
    assert_equal [], offenders,
                 'no Tasks::<Name>.call service module may remain; task ' \
                 'bodies own their orchestration'
  end

  def test_retired_exec_apparatus_grep_clean
    %w[workflow.rb].each do |f|
      src = File.read(File.join(workflow_root, f))
      %w[dispatch_job_id DISPATCH_EXEC_TASKS].each do |sym|
        refute src.include?(sym),
               "#{f} still mentions #{sym} (retired exec apparatus)"
      end
    end
    refute Research.respond_to?(:job_from_dispatch),
           'Research must not carry a dispatch-specific job shim'
    # The Research.job override is gone: Research.job must be the plain
    # Workflow-provided module_function (defined in a Workflow file,
    # not under this checkout).
    owner = Research.method(:job).source_location
    refute owner.nil? || owner[0].to_s.start_with?(workflow_root),
           "Research.job is overridden inside this checkout (#{owner})"
  end

  def test_no_roots_fallback_chain
    refute File.exist?(File.join(workflow_root, 'lib', 'Research', 'roots.rb')),
           'lib/Research/roots.rb must be deleted'
    lib = Dir.glob(File.join(workflow_root, 'lib', '**', '*.rb'))
    offenders = lib.select do |f|
      File.read(f).match?(/Scout\.var\.research|SCOUT_RESEARCH_ROOT/)
    end
    assert_equal [], offenders,
                 'no roots fallback chain (config/env/Scout.var) may remain'
  end

  def test_path_kinds_constant_absent
    load_workflow!
    assert_nil defined?(Research::PATH_KINDS),
           'Research::PATH_KINDS must not exist after the retirement'
  end

  def test_no_transitive_workspace_load
    load_workflow!
    offenders = $LOADED_FEATURES.grep(/Workspace|workspace/i)
    assert_equal [], offenders,
                 'workflow.rb transitively loaded Workspace'
    refute Research.respond_to?(:write),
           'Research must not inherit Workspace task helpers (no merge)'
  end

  def test_no_observation_path_kind_anywhere
    start_chat = File.read(File.join(workflow_root, 'start_chat'))
    refute_match(/^\s*path_kind:\s*\w+/, start_chat,
                 'start_chat must not declare a path_kind after retirement')
    entry = File.read(File.join(workflow_root, 'workflow.rb'))
    refute entry.include?('integrate_workflow_path_kinds'),
           'workflow.rb must not call integrate_workflow_path_kinds'

    engine =
      begin
        Scout::LLM::Agent::Path
      rescue NameError
        nil
      end
    return if engine.nil? # path engine not loaded in this process

    refute engine.kinds.keys.map(&:to_s).include?('observation'),
           'an observation path kind is registered in this process'
  end
end
