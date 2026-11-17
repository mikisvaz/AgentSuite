# Job-level semantics at the REAL dispatch surface (plan step 3 of the
# Research refactor, Bout A). Root resolution is now cwd-based: the store
# root is File.expand_path('research', Dir.pwd), computed inside every
# task body at execution time. These tests pin exactly that contract
# through the public dispatcher:
#
#   agent(task, params) -> LLM.call_workflow(Research, task, params)
#   run_task(task, params) -> Research.job(task, nil, **params).exec
#
# They pin:
#
#   1. repeated dossier_create with identical inputs → distinct IDs on
#      EVERY execution (never deduplicated, on both surfaces);
#   2. repeated dossier_update / evidence_attach with identical inputs
#      → the second dispatch is REJECTED stale (performed-or-rejected,
#      never a replayed first receipt);
#   3. after a mutation, reads and checks with IDENTICAL parameters
#      observe the new revision/content (no input-keyed memoization);
#   4. two projects in ONE process: Dir.chdir between dispatches → the
#      second dispatch targets the second project's store, no leakage
#      of the first project's inputs or context;
#   5. an explicit caller jobname reaches the job unchanged;
#   6. concurrent ID allocation from four child processes in the same
#      project → distinct IDs, no reuse (job-level variant of the unit
#      test);
#   7. exec-exported dispatch (no job tree) — a second IDENTICAL
#      dispatch executes rather than replaying any cached receipt.
#
# Memoization posture (what the framework legitimately does): scout-gear
# Task#job memoizes one Step per (task, inputs) in Persist.memory; with
# only string/integer inputs the digest is faithful, an identical
# (task, inputs) pair reuses a CORRECTLY BOUND Step, and Step#exec
# instance_execs the task block fresh. Reusing the Step object is
# allowed; stale inputs or SKIPPED execution would be the defect. These
# tests assert the observable effect (new IDs, fresh reads), not object
# identity of Steps.
#
# Retry story (documented, not exactly-once): re-list/re-read to observe
# whether the effect landed, then retry or reconcile. Never assume
# exactly-once dispatch.

require 'test/unit'
require 'fileutils'
require 'tmpdir'
require 'scout'
require 'scout-ai'

ROOT = File.expand_path('../../../..', __dir__) unless defined?(ROOT)
require File.join(ROOT, 'Research', 'workflow')

# The exported-call dispatch path (what an agent's workflow tool
# actually invokes): LLM::Workflow.call_workflow builds the job and,
# for exec-exported tasks (all nine are), executes job.exec.
def agent(task, params)
  LLM.call_workflow(Research, task, params)
end

# Direct task-registration surface, same execution route for
# exec-exported tasks: workflow.job(task, nil, key: value).exec.
def run_task(task, params)
  Research.job(task, nil, **params).exec
end

# Run a dispatch with the working project as Dir.pwd (the root source).
def in_project(project)
  DossierFixturesHelper.in_project(project) { yield }
end

# Minimal cwd helper local to this file (no fixture-module dependency;
# the scaffolding itself is plain Dir.mktmpdir).
module DossierFixturesHelper
  # Stable origin captured ONCE, eagerly, at require time: the suite
  # launch directory. Dir.chdir back here after each project block, so
  # a project directory can be removed by teardown without leaving the
  # process inside a deleted path.
  ORIGIN = File.directory?(Dir.pwd) ? Dir.pwd : Dir.tmpdir

  def self.in_project(project)
    Dir.chdir(project)
    begin
      yield project
    ensure
      Dir.chdir(ORIGIN)
    end
  end
end

class TestJobLevelSemantics < Test::Unit::TestCase
  def setup
    @scratch = Dir.mktmpdir('refactor_job_semantics')
    @project = File.join(@scratch, 'project')
    FileUtils.mkdir_p(@project)
  end

  def teardown
    Dir.chdir(DossierFixturesHelper::ORIGIN) rescue nil
    FileUtils.remove_entry(@scratch) if @scratch
  end

  def test_repeated_create_yields_distinct_dossiers_not_deduplicated
    inputs = { 'type' => 'question', 'title' => 'Repeated create' }
    first = in_project(@project) { run_task(:dossier_create, inputs) }
    second = in_project(@project) { run_task(:dossier_create, inputs) }
    assert_not_equal first['id'], second['id'],
                     'identical create inputs must allocate distinct IDs'
    assert first['revision'] >= 1
    list = in_project(@project) { run_task(:dossier_list, {}) }
    ids = list['dossiers'].map { |d| d['id'] }
    assert_equal [first['id'], second['id']].sort, ids.sort,
                 'both creates must be observable in the store exactly once'
    # And via the agent surface: a third identical dispatch performs too.
    third = in_project(@project) { agent(:dossier_create, inputs) }
    assert_not_equal first['id'], third['id']
    assert_not_equal second['id'], third['id']
  end

  def test_repeated_update_is_rejected_stale_not_replayed
    created = in_project(@project) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'Update semantics' })
    end
    inputs = { 'id' => created['id'],
               'expected_revision' => created['revision'],
               'mode' => 'replace_document', 'content' => 'v1 body' }
    first = in_project(@project) { run_task(:dossier_update, inputs) }
    assert_equal true, first['changed'], 'first update must perform'
    assert_equal created['revision'] + 1, first['revision']
    # Identical retry: the base revision is stale now — rejected, never
    # a replay of the first receipt.
    e = assert_raise(ParameterException) do
      in_project(@project) { run_task(:dossier_update, inputs) }
    end
    assert_match(/StaleRevision|expected revision|expected_revision|stale/i,
                 e.message)
    # A DIFFERENT-content retry from the same stale base is still stale.
    e2 = assert_raise(ParameterException) do
      in_project(@project) do
        run_task(:dossier_update, inputs.merge('content' => 'v2 body'))
      end
    end
    assert_match(/StaleRevision|expected revision|expected_revision|stale/i,
                 e2.message)
    # Store untouched by the rejections.
    reread = in_project(@project) do
      run_task(:dossier_read, { 'id' => created['id'] })
    end
    assert_equal first['revision'], reread['current_revision']
  end

  def test_repeated_evidence_attach_is_rejected_stale_not_replayed
    src = File.expand_path(__FILE__)
    created = in_project(@project) do
      run_task(:dossier_create,
               { 'type' => 'claim', 'title' => 'Evidence semantics' })
    end
    items = [{ 'source' => src, 'slot' => 'log', 'mode' => 'copy' }].to_json
    inputs = { 'id' => created['id'],
               'expected_revision' => created['revision'],
               'items' => items }
    first = in_project(@project) { run_task(:evidence_attach, inputs) }
    assert_equal true, first['changed'], 'first attach must perform'
    assert_equal created['revision'] + 1, first['revision']
    e = assert_raise(ParameterException) do
      in_project(@project) { run_task(:evidence_attach, inputs) }
    end
    assert_match(/StaleRevision|stale/i, e.message)
    # Different item payload, still a stale base revision → rejected.
    items2 = [{ 'source' => src, 'slot' => 'log2', 'mode' => 'copy' }].to_json
    e2 = assert_raise(ParameterException) do
      in_project(@project) { run_task(:evidence_attach, inputs.merge('items' => items2)) }
    end
    assert_match(/StaleRevision|stale/i, e2.message)
    reread = in_project(@project) do
      run_task(:dossier_read, { 'id' => created['id'] })
    end
    assert_equal first['revision'], reread['current_revision']
  end

  def test_read_and_check_fresh_after_mutation_identical_parameters
    created = in_project(@project) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'Freshness' })
    end
    read_params = { 'id' => created['id'] }
    before = in_project(@project) { agent(:dossier_read, read_params) }
    assert_equal created['revision'], before['revision']
    assert_not_include before['content'], 'mutated body'

    in_project(@project) do
      run_task(:dossier_update,
               { 'id' => created['id'],
                 'expected_revision' => created['revision'],
                 'mode' => 'replace_document',
                 'content' => "mutated body\nsecond line" })
    end

    # IDENTICAL read parameters after the mutation: must observe the new
    # revision and content — no input-keyed memoization anywhere.
    after = in_project(@project) { agent(:dossier_read, read_params) }
    assert after['revision'] > before['revision'],
           "re-read must see the mutated revision " \
           "(#{after['revision']} vs #{before['revision']})"
    assert_include after['content'], 'mutated body'
    check = in_project(@project) { agent(:dossier_check, { 'id' => created['id'] }) }
    assert_equal 1, check['checked']
    assert_equal 0, check['finding_count'],
                 'check after the mutation must validate the new state'
    checked = check['dossiers'].first
    assert_equal 'ok', checked['status']
    assert_equal created['id'], checked['id']
    assert_equal after['revision'], checked['revision'],
                 'check and read must agree on the current revision'
  end

  def test_two_projects_one_process_cwd_switch_isolation
    project_a = File.join(@scratch, 'project_a')
    project_b = File.join(@scratch, 'project_b')
    FileUtils.mkdir_p([project_a, project_b])

    a1 = in_project(project_a) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'A first' })
    end
    a2 = in_project(project_a) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'A second' })
    end
    b1 = in_project(project_b) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'B first' })
    end
    # Distinct ID spaces: both projects start at their own Q-001.
    assert_equal a1['id'], b1['id'],
                 'each project has an independent ID space'
    assert_not_equal File.dirname(a1['link'][/\((.*)\)\z/, 1]),
                     File.dirname(b1['link'][/\((.*)\)\z/, 1])
    assert a1['link'].start_with?("[#{a1['id']}](" + project_a)
    assert b1['link'].start_with?("[#{b1['id']}](" + project_b)
    # No cross-project visibility: A lists two dossiers, B one.
    la = in_project(project_a) { run_task(:dossier_list, {}) }
    ids_a = la['dossiers'].map { |d| d['id'] }
    lb = in_project(project_b) { run_task(:dossier_list, {}) }
    ids_b = lb['dossiers'].map { |d| d['id'] }
    assert_equal [a1['id'], a2['id']].sort, ids_a.sort
    assert_equal [b1['id']], ids_b
    # An ID that exists only in project A does not resolve in project B.
    assert_raise(ParameterException) do
      in_project(project_b) { run_task(:dossier_read, { 'id' => a2['id'] }) }
    end
    # The SAME ID text in project B resolves to B's own dossier, never
    # falls through to A's store (overview mode carries 'directory').
    same_id_in_b = in_project(project_b) do
      run_task(:dossier_read,
               { 'id' => a1['id'], 'overview' => 'true' })
    end
    assert_equal b1['directory'], same_id_in_b['directory']
  end

  def test_explicit_caller_jobname_reaches_the_job_unchanged
    created = in_project(@project) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'Jobname' })
    end
    name = 'caller-chosen-name'
    job = Research.job(:dossier_read, name, id: created['id'])
    # Scout job paths are '<caller-name>_<input-digest>'; the caller
    # name is preserved as the prefix and clean_name recovers it.
    assert job.name.start_with?(name + '_'),
           "caller jobname lost: #{job.name}"
    assert_equal name, job.clean_name,
                 'the caller-supplied jobname must reach the job unchanged'
    out = in_project(@project) { job.exec }
    assert_equal created['id'], out['id']
    # And again with a different explicit name: still executed, not
    # deduplicated, name preserved.
    job2 = Research.job(:dossier_read, 'another-caller-name', id: created['id'])
    assert job2.name.start_with?('another-caller-name_'),
           "second caller jobname lost: #{job2.name}"
    out2 = in_project(@project) { job2.exec }
    assert_equal created['id'], out2['id']
  end

  def test_concurrent_id_allocation_from_processes
    base = in_project(@project) do
      run_task(:dossier_create,
               { 'type' => 'question', 'title' => 'concurrent base' })
    end
    script = <<~RB
      require 'scout'
      require 'scout-ai'
      require File.join(#{ROOT.inspect}, 'Research', 'workflow')
      out = Research.job(:dossier_create, nil,
                         type: 'question',
                         title: 'concurrent child').exec
      puts out['id']
    RB
    kids = 4.times.map do
      IO.popen(['ruby', '-e', script, { chdir: @project }],
               err: [:child, :out]) { |io| io.read }
    end
    # Child output is log noise plus the final ID line: take the LAST
    # Q-xxx token from each.
    allocated = kids.map { |out| out.scan(/Q-\d{3}/).last }.compact
    assert_equal 4, allocated.size, "children failed: #{kids.inspect}"
    assert_equal allocated.uniq.size, allocated.size,
                  "concurrent allocation reused an ID: #{allocated.inspect}"
    # Every allocation is observable exactly once; the parent's ID was
    # never handed out twice.
    lst = in_project(@project) { run_task(:dossier_list, {}) }
    ids = lst['dossiers'].map { |d| d['id'] }
    assert_equal (allocated + [base['id']]).sort, ids.sort,
                 'store must show every concurrent allocation exactly once'
  end

  def test_exec_export_second_identical_dispatch_executes_not_replays
    # exec-exported dispatches carry no job tree, so there is no
    # persisted receipt to replay. Two truly identical dispatches in
    # the same project must both perform.
    inputs = { 'type' => 'question', 'title' => 'Exec dispatch' }
    first = in_project(@project) { agent(:dossier_create, inputs) }
    second = in_project(@project) { agent(:dossier_create, inputs) }
    assert_not_equal first['id'], second['id'],
                     'identical exec dispatches must execute twice'
    lst = in_project(@project) { run_task(:dossier_list, {}) }
    ids = lst['dossiers'].map { |d| d['id'] }
    assert_equal [first['id'], second['id']].sort, ids.sort,
                 'both exec dispatches must be observable in the store'
  end
end
