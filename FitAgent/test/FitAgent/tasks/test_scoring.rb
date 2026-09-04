require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'tmpdir'
require 'fileutils'
require 'json'

Workflow.require_workflow File.expand_path('../../../../workflow.rb', __FILE__)

class TestScoring < Test::Unit::TestCase
  def setup
    @base = File.join(Dir.tmpdir, "fitagent-scoring-test-#{Process.pid}")
    FileUtils.mkdir_p @base
    @set = Path.setup(File.join(@base, 'set'))
  end

  def teardown
    FileUtils.rm_rf @base if File.directory?(@base)
  end

  def materialize(ids)
    FitAgent::Scenarios.materialize(@set, ids: ids)
  end

  def rubric_for(id)
    YAML.load_file(@set[id]['rubric.yaml'].find)
  end

  def write_chat(path, calls)
    lines = ["user:", "", "Apply the patch.", ""]
    pairs = case
            when Hash === calls then calls.to_a
            else calls.map { |entry| Hash === entry ? entry.first : entry }
            end
    pairs.each do |call, payload|
      lines << "function_call: #{JSON.generate({'name' => call['name'], 'arguments' => call['arguments'], 'id' => call['id']})}"
      lines << ''
      lines << "function_call_output: #{JSON.generate({'name' => call['name'], 'content' => JSON.generate(payload), 'id' => call['id']})}"
      lines << ''
    end
    lines += ["assistant:", "", "done", ""]
    File.open(path, 'wb') { |f| f.write(lines.join("\n")) }
  end

  def ok_payload(extra = {})
    { 'exit_status' => 0, 'applied' => true, 'used_strip' => 1,
      'stdout' => 'patching file', 'stderr' => '' }.merge(extra)
  end

  def test_pass_on_clean_apply
    materialize ['F01']
    # simulate a successful patch application in the work tree
    File.open(@set['F01']['work']['notes.txt'].find, 'wb') do |f|
      f.write File.binread(@set['F01']['expected']['notes.txt'].find)
    end
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['F01']['work'].find, rubric_for('F01'), chat)
    assert_equal 'PASS', result['verdict']
    assert_equal 1.0, result['score']
    assert result['functional']['files']['notes.txt']['ok']
    assert_equal 1, result['message']['count']
    assert result['message']['expect']['applied']['ok']
    assert result['message']['expect']['exit_status']['ok']
    assert result['message']['expect']['used_strip']['ok']
  end

  def test_fail_on_content_mismatch
    materialize ['F01']
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['F01']['work'].find, rubric_for('F01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].any? { |f| f.start_with?('functional:notes.txt:match') }
    assert_equal [], result['functional']['residue']
  end

  def test_fail_on_patch_residue
    materialize ['F01']
    File.open(@set['F01']['work']['notes.txt'].find, 'wb') do |f|
      f.write File.binread(@set['F01']['expected']['notes.txt'].find)
    end
    File.open(@set['F01']['work']['notes.txt.rej'].find, 'wb') { |f| f.write("leftover\n") }
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['F01']['work'].find, rubric_for('F01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert_equal ['notes.txt.rej'], result['functional']['residue']
    assert result['failures'].include?('functional:residue:notes.txt.rej')
  end

  def test_error_scenario_stale_context_passes_when_rejected
    materialize ['E01']
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } =>
                        { 'exit_status' => 1, 'applied' => false, 'used_strip' => '',
                          'suggestion' => 'Could not auto-detect -p.' }])

    result = FitAgent::Scoring.score_scenario(@set['E01']['work'].find, rubric_for('E01'), chat)
    assert_equal 'PASS', result['verdict']
    assert_equal false, result['message']['expect']['applied']['got']
    assert_equal 1, result['message']['expect']['exit_status']['got']
  end

  def test_error_scenario_ambiguous_output_contains
    materialize ['E02']
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } =>
                        { 'exception' => 'Ambiguous hunk: multiple matches found', 'stack' => ['a.rb:1'] }])

    result = FitAgent::Scoring.score_scenario(@set['E02']['work'].find, rubric_for('E02'), chat)
    assert_equal 'PASS', result['verdict']
    assert_equal true, result['message']['output_contains']
  end

  def test_delete_scenario_absent_mode
    materialize ['E06']
    File.delete(@set['E06']['work']['old_file.txt'].find)
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['E06']['work'].find, rubric_for('E06'), chat)
    assert_equal 'PASS', result['verdict']
    assert result['functional']['files']['old_file.txt']['ok']
  end

  def test_too_many_patch_calls_fails
    materialize ['F01']
    File.open(@set['F01']['work']['notes.txt'].find, 'wb') do |f|
      f.write File.binread(@set['F01']['expected']['notes.txt'].find)
    end
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload] +
                      [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c2' } => ok_payload] +
                      [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c3' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['F01']['work'].find, rubric_for('F01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert_equal 3, result['message']['count']
    assert result['failures'].include?('message:patch:count:3:1..2')
  end

  def test_other_tools_are_indexed_but_not_counted
    materialize ['F01']
    File.open(@set['F01']['work']['notes.txt'].find, 'wb') do |f|
      f.write File.binread(@set['F01']['expected']['notes.txt'].find)
    end
    chat = File.join(@base, 'main.chat')
    write_chat(chat, [{ 'name' => 'read', 'arguments' => { 'path' => 'notes.txt' }, 'id' => 'c0' } =>
                        { 'content' => 'note-1\n...' }] +
                      [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['F01']['work'].find, rubric_for('F01'), chat)
    assert_equal 'PASS', result['verdict']
    assert_equal 2, result['message']['total_calls']
    assert_equal({ 'read' => 1, 'patch' => 1 }, result['message']['by_tool'])
  end

  def test_missing_chat_file_scores_zero_calls
    materialize ['F01']
    result = FitAgent::Scoring.score_scenario(@set['F01']['work'].find, rubric_for('F01'),
                                              File.join(@base, 'missing.chat'))
    assert_equal 'FAIL', result['verdict']
    assert_equal 0, result['message']['count']
  end
end
