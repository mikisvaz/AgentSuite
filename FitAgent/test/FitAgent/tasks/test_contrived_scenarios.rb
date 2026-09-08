require File.expand_path(__FILE__).sub(%r(/test/.*), '/test/test_helper.rb')
require 'tmpdir'
require 'fileutils'
require 'json'

# Contrived C-series scenarios: the F/E mini-set is baseline-saturated at
# 1.0, so these scenarios are designed to be *plausibly failed* by the
# baseline agent (naive fragment write / force-overwrite rescue) while a
# disciplined agent passes. Deterministic only: catalogue materialization +
# Scoring over synthetic transcripts, no model and no network.
class TestContrivedScenarios < Test::Unit::TestCase
  def setup
    @base = Path.setup(File.join(Dir.tmpdir, "fitagent-contrived-#{Process.pid}"))
    FileUtils.mkdir_p @base.find
    @set = @base['set']
  end

  def teardown
    FileUtils.rm_rf @base.find if File.directory?(@base.find)
  end

  def materialize(ids)
    FitAgent::Scenarios.materialize(@set, ids: ids)
  end

  def rubric_for(id)
    YAML.load_file(@set[id]['rubric.yaml'].find)
  end

  def write_chat(path, calls)
    lines = ['user:', '', 'Apply the patch.', '']
    pairs = case
            when Hash === calls then calls.to_a
            else calls.map { |entry| Hash === entry ? entry.first : entry }
            end
    pairs.each do |call, payload|
      lines << "function_call: #{JSON.generate('name' => call['name'], 'arguments' => call['arguments'], 'id' => call['id'])}"
      lines << ''
      lines << "function_call_output: #{JSON.generate('name' => call['name'], 'content' => JSON.generate(payload), 'id' => call['id'])}"
      lines << ''
    end
    lines += ['assistant:', '', 'done', '']
    File.open(path, 'wb') { |f| f.write(lines.join("\n")) }
  end

  def ok_payload(extra = {})
    { 'exit_status' => 0, 'applied' => true, 'used_strip' => 1,
      'stdout' => 'patching file', 'stderr' => '' }.merge(extra)
  end

  def stale_payload
    { 'applied' => false, 'used_strip' => nil, 'exit_status' => -1,
      'tried_strips' => [{ 'strip' => 1, 'stderr' => 'Hunk #1 FAILED at 5.',
                           'exit_status' => -1 }],
      'suggestion' => 'Patch failed on apply.' }
  end

  # -- catalogue ---------------------------------------------------------

  def test_c_series_materializes_with_rubrics_and_fixtures
    manifest = materialize %w[C01 C02]
    assert_equal %w[C01 C02], manifest['scenarios'].map { |s| s['id'] }
    %w[C01 C02].each do |id|
      %w[rubric.yaml scenario.yaml patch.txt].each do |f|
        assert @set[id][f].exists?, "#{id}/#{f} missing"
      end
      assert @set[id]['work'].directory?, "#{id}/work missing"
      assert @set[id]['expected'].directory?, "#{id}/expected missing"
    end
  end

  def test_c_series_deterministic_digests
    m1 = materialize(%w[C01 C02])['scenarios'].map { |s| s['digest'] }
    other = Path.setup(File.join(Dir.tmpdir, "fitagent-contrived-digest-#{Process.pid}"))
    m2 = FitAgent::Scenarios.materialize(other, ids: %w[C01 C02])['scenarios']
                     .map { |s| s['digest'] }
    FileUtils.rm_rf other.find
    assert_equal m1, m2
  end

  def test_c01_material_is_fragment_with_ellipses_and_rename_reaches_every_site
    materialize %w[C01]
    patch = File.read(@set['C01']['patch.txt'].find)
    assert patch.include?('```ruby'), 'C01 patch must be prose + fenced fragment'
    assert patch.include?("...\n"), 'C01 fragment must carry the bare ellipses line'
    assert !patch.include?('-'), 'C01 must not be a diff'

    work = File.read(@set['C01']['work']['calc.rb'].find)
    expected = File.read(@set['C01']['expected']['calc.rb'].find)
    assert work.include?('def add(a, b)'), 'work tree starts with the old name'
    assert !expected.include?('add('), 'expected rename reaches every call site'
    assert expected.include?('def plus(a, b)')
    # other methods byte-identical modulo the rename
    %w[def scale(v, k) def label(v) def combine(xs)].each do |frag|
      assert expected.include?(frag), "expected keeps #{frag.inspect}"
    end
  end

  def test_c02_patch_is_stale_but_plausible
    materialize %w[C02]
    patch = File.read(@set['C02']['patch.txt'].find)
    list = File.read(@set['C02']['work']['list.txt'].find)
    assert patch.start_with?('--- a/list.txt'), 'C02 is a canonical unified diff'
    assert patch.include?(' epsiln') && list.include?('epsilon'),
           'middle context line is subtly misspelled (epsiln vs epsilon)'
    # same file before and after: the ONLY correct outcome is pristine
    assert_equal list, File.read(@set['C02']['expected']['list.txt'].find)
    # and GNU patch must actually REFUSE this hunk (no fuzz slack)
    # GNU patch behaviour is asserted indirectly through the scenarios own
    # materialization: the middle-line misspelling has no fuzz slack while an
    # edge-line error would apply. Both cases are pinned live in
    # results/contrived-baseline (see tmp/contrived/gnu-patch-behaviour.md);
    # running patch from the test suite is unreliable under bwrap, so the
    # stale/edge distinction is enforced by the exact context lines below.
    refute patch.include?(' theta'),
           'edge-line staleness (theta) is fuzz-tolerated by GNU patch and APPLIES'
    hunk = patch.lines[2..-1].reject { |l| l.start_with?('-', '+') }
                 .map(&:chomp).map { |l| l.sub(/^ /, '') }
    context = hunk[1..-2]
    wrong = context.reject { |l| list.include?(l) }
    assert_equal 1, wrong.size, 'exactly one wrong context line in the middle'
    idx = context.index(wrong.first)
    refute_equal 0, idx
    refute_equal context.size - 1, idx,
                 'wrong line must not sit at the hunk edge (fuzz applies there)'
  end

  def test_rubric_grammar_c_series
    materialize %w[C01 C02]
    r1 = rubric_for('C01')
    assert_equal 'C01', r1['scenario']
    assert_equal 'contrived', r1['class']
    assert_equal 'match', r1['functional']['expect_files']['calc.rb']
    assert_equal 8, r1['message_rules']['max_total_calls']
    assert r1['message_rules']['min_calls'] == 0

    r2 = rubric_for('C02')
    assert_equal false, r2['message_rules']['expect']['applied']
    assert_equal ['FAILED', 'Hunk #1 FAILED'], r2['message_rules']['expect']['output_contains']
    assert r2['message_rules']['forbid_after_failed'].include?('write')
    assert r2['message_rules']['forbid_after_failed'].include?('bash')
    assert_equal 6, r2['message_rules']['max_total_calls']
  end

  # -- scoring: C01 ------------------------------------------------------

  def test_c01_naive_fragment_write_fails
    materialize %w[C01]
    # naive agent: `write` the fenced fragment verbatim into calc.rb
    fragment = File.read(@set['C01']['patch.txt'].find)
    File.open(@set['C01']['work']['calc.rb'].find, 'wb') { |f| f.write fragment }
    chat = File.join(@base.find, 'main.chat')
    write_chat(chat, [{ 'name' => 'write', 'arguments' => { 'path' => 'calc.rb' }, 'id' => 'c1' } =>
                        { 'exit_status' => 0, 'path' => 'calc.rb' }])

    result = FitAgent::Scoring.score_scenario(@set['C01']['work'].find, rubric_for('C01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].any? { |f| f.start_with?('functional:calc.rb:match') },
           result['failures'].inspect
    # write-instead-of-patch is a LEGITIMATE path for C01 (min_calls 0): the
    # naive agent fails on CONTENT, not on tool choice
    assert result['message']['count_ok']
  end

  def test_c01_naive_rename_only_definition_fails
    materialize %w[C01]
    # naive agent: renames only the definition, misses both call sites
    work = File.read(@set['C01']['work']['calc.rb'].find)
    File.open(@set['C01']['work']['calc.rb'].find, 'wb') do |f|
      f.write work.sub('def add(a, b)', 'def plus(a, b)')
    end
    chat = File.join(@base.find, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => ok_payload])

    result = FitAgent::Scoring.score_scenario(@set['C01']['work'].find, rubric_for('C01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].any? { |f| f.start_with?('functional:calc.rb:match') }
  end

  def test_c01_full_rename_with_many_reads_passes
    materialize %w[C01]
    # disciplined agent: 3 reads to find call sites + 2 patch calls, still
    # within the total cap of 8
    FileUtils.cp(@set['C01']['expected']['calc.rb'].find,
                 @set['C01']['work']['calc.rb'].find)
    chat = File.join(@base.find, 'main.chat')
    calls = []
    3.times do |i|
      calls << [{ 'name' => 'read', 'arguments' => { 'path' => 'calc.rb' }, 'id' => "r#{i}" } =>
                  { 'content' => 'def add(a, b) ...' }]
    end
    2.times do |i|
      calls << [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => "p#{i}" } => ok_payload]
    end
    write_chat(chat, calls)

    result = FitAgent::Scoring.score_scenario(@set['C01']['work'].find, rubric_for('C01'), chat)
    assert_equal 'PASS', result['verdict'], result['failures'].inspect
    assert_equal 5, result['message']['total_calls']
  end

  def test_c01_chatter_exceeding_total_cap_fails
    materialize %w[C01]
    FileUtils.cp(@set['C01']['expected']['calc.rb'].find,
                 @set['C01']['work']['calc.rb'].find)
    chat = File.join(@base.find, 'main.chat')
    calls = []
    9.times do |i|
      calls << [{ 'name' => 'read', 'arguments' => { 'path' => 'calc.rb' }, 'id' => "r#{i}" } =>
                  { 'content' => '...' }]
    end
    write_chat(chat, calls)
    result = FitAgent::Scoring.score_scenario(@set['C01']['work'].find, rubric_for('C01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].include?('message:total_calls:9:max=8')
  end

  # Live-shape regression (contrived-baseline probe): the reported wart was a
  # 13-call session (patch:2 read:3 pwd:1 bash:6 write:1) that failed only on
  # functional residue while scores_tsv showed message_ok=true, because the
  # column read count_ok (2 patch calls, within 0..2) and ignored the violated
  # max_total_calls cap. message_ok must aggregate every message-tier rule.
  def test_c01_live_shape_total_cap_violates_message_ok
    materialize %w[C01]
    FileUtils.cp(@set['C01']['expected']['calc.rb'].find,
                 @set['C01']['work']['calc.rb'].find)
    chat = File.join(@base.find, 'main.chat')
    mix = Array.new(2) { 'patch' } + Array.new(3) { 'read' } +
          Array.new(1) { 'pwd' } + Array.new(6) { 'bash' } + Array.new(1) { 'write' }
    assert_equal 13, mix.length
    calls = mix.each_with_index.map do |tool, i|
      [{ 'name' => tool, 'arguments' => {}, 'id' => "c#{i}" } =>
         { 'exit_status' => 0, 'stdout' => '', 'stderr' => '' }]
    end
    write_chat(chat, calls)

    result = FitAgent::Scoring.score_scenario(@set['C01']['work'].find, rubric_for('C01'), chat)
    assert_equal 'FAIL', result['verdict']
    assert_equal 13, result['message']['total_calls']
    assert_equal false, result['message']['total_cap_ok']
    assert result['message']['count_ok'], 'patch count 2 is within 0..2'
    assert_equal false, result['message']['message_ok'],
                 'total-cap violation must flip the aggregate message_ok flag'
    assert result['failures'].include?('message:total_calls:13:max=8')

    tsv = FitAgent::Runner.scores_tsv('C01' => result)
    row = TSV.open(tsv, type: :list)['C01']
    assert_equal 'false', row['message_ok'],
                 'scores_tsv message_ok column must reflect the cap violation'
  end

  # Live-shape regression (contrived-baseline probe): the reported wart was a
  # 13-call session (patch:2 read:3 pwd:1 bash:6 write:1) that failed only on
  # functional residue while scores_tsv showed message_ok=true, because the
  # column read count_ok (2 patch calls, within 0..2) and ignored the violated
  # max_total_calls cap. message_ok must aggregate every message-tier rule.

  # -- scoring: C02 ------------------------------------------------------

  def test_c02_refused_patch_pristine_tree_passes
    materialize %w[C02]
    chat = File.join(@base.find, 'main.chat')
    write_chat(chat, [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => stale_payload])

    result = FitAgent::Scoring.score_scenario(@set['C02']['work'].find, rubric_for('C02'), chat)
    assert_equal 'PASS', result['verdict'], result['failures'].inspect
    assert_equal false, result['message']['expect']['applied']['got']
    assert_equal true, result['message']['output_contains']
    assert result['functional']['files']['list.txt']['ok'], 'tree must stay pristine'
  end

  def test_c02_write_after_failed_patch_fails
    materialize %w[C02]
    # naive agent: patch refuses, agent "fixes" it by overwriting list.txt
    File.open(@set['C02']['work']['list.txt'].find, 'wb') { |f| f.write "alpha\nbeta\nDELTA\n" }
    chat = File.join(@base.find, 'main.chat')
    write_chat(chat,
               [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => stale_payload] +
               [{ 'name' => 'write', 'arguments' => { 'path' => 'list.txt' }, 'id' => 'c2' } =>
                  { 'exit_status' => 0, 'path' => 'list.txt' }])

    result = FitAgent::Scoring.score_scenario(@set['C02']['work'].find, rubric_for('C02'), chat)
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].include?('message:forbid_after_failed:write'),
           result['failures'].inspect
    assert result['failures'].any? { |f| f.start_with?('functional:list.txt:match') }
    assert_equal ['write'], result['message']['forbidden_seen']
  end

  def test_c02_bash_rescue_after_failed_patch_fails_even_if_tree_pristine
    materialize %w[C02]
    chat = File.join(@base.find, 'main.chat')
    write_chat(chat,
               [{ 'name' => 'patch', 'arguments' => { 'patch' => '...' }, 'id' => 'c1' } => stale_payload] +
               [{ 'name' => 'bash', 'arguments' => { 'cmd' => "echo x > list.txt" }, 'id' => 'c2' } =>
                  { 'exit_status' => 0, 'stdout' => '', 'stderr' => '' }] +
               [{ 'name' => 'bash', 'arguments' => { 'cmd' => "cp list.txt.bak list.txt" }, 'id' => 'c3' } =>
                  { 'exit_status' => 0, 'stdout' => '', 'stderr' => '' }])

    result = FitAgent::Scoring.score_scenario(@set['C02']['work'].find, rubric_for('C02'), chat)
    # tree is pristine, but the bash rescue is etiquette-forbidden
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].include?('message:forbid_after_failed:bash')
    assert_equal ['bash'], result['message']['forbidden_seen']
  end

  def test_c02_no_patch_call_at_all_fails
    materialize %w[C02]
    chat = File.join(@base.find, 'main.chat')
    write_chat(chat, [{ 'name' => 'read', 'arguments' => { 'path' => 'list.txt' }, 'id' => 'c1' } =>
                        { 'content' => 'alpha' }])
    result = FitAgent::Scoring.score_scenario(@set['C02']['work'].find, rubric_for('C02'), chat)
    assert_equal 'FAIL', result['verdict']
    assert result['failures'].include?('message:patch:count:0:1..2')
  end
end
