# Golden-transcript replay (Unit A): lock the transcript contract of the
# execution adapter against a RECORDED live transcript.
#
# All three inputs are committed hermetic fixtures (verbatim copies of the
# recorded live C02 baseline session under tmp/contrived/live-record):
#   C02_live.chat  — the recorded chat dump (what the adapter must keep
#                    producing: message shape, Chat.tool_calls parse,
#                    message-rule fields)
#   C02_work/      — the post-session work tree (functional match/residue)
#   C02_rubric.yaml — the rubric AS RECORDED (the catalogue's C02
#                    definition has since gained an extra
#                    output_contains needle, so materializing a fresh
#                    rubric would NOT reproduce the recorded golden; the
#                    frozen rubric is committed alongside so the replay
#                    is exact and hermetic)
# The expected verdict is the golden captured with the pre-refactor code
# (tmp/contrived/unitA_golden_before.json): every field below must stay
# identical across the refactor, and the second test re-asserts full JSON
# equality against the saved golden when it is present.
require File.expand_path('../../test_helper', __dir__)
require 'json'
require 'yaml'

class TestGoldenTranscriptReplay < Test::Unit::TestCase
  GOLDEN_DIR = File.expand_path('../../fixtures/golden', __dir__)
  CHAT = File.join(GOLDEN_DIR, 'C02_live.chat')
  WORK = File.join(GOLDEN_DIR, 'C02_work')
  RUBRIC = File.join(GOLDEN_DIR, 'C02_rubric.yaml')

  def test_recorded_live_transcript_scores_unchanged
    result = FitAgent::Scoring.score_scenario(WORK, YAML.load_file(RUBRIC), CHAT)

    # expected verdict frozen from tmp/contrived/unitA_golden_before.json
    assert_equal 'C02', result['scenario']
    assert_equal 'FAIL', result['verdict']
    assert_equal 0.0, result['score']

    assert_equal 1, result['message']['total_calls']
    assert_equal 1, result['message']['count']
    assert_equal({ 'patch' => 1 }, result['message']['by_tool'])
    assert_equal true, result['message']['count_ok']
    assert_equal false, result['message']['output_contains']
    assert_equal ['FAILED'], result['message']['output_contains_needles']
    assert_equal true, result['message']['expect']['applied']['got']
    assert_equal true, result['message']['message_ok']

    assert_equal false, result['functional']['files']['list.txt']['ok']
    assert_equal ['list.txt.orig'], result['functional']['residue']

    assert_equal ['functional:list.txt:match:mismatch',
                  'functional:residue:list.txt.orig',
                  'message:patch:output_contains:missing',
                  'message:patch:applied:want=false:got=true'],
                 result['failures']
  end

  # Full-JSON stability against the golden captured with the pre-refactor
  # code: the golden lives under tmp/contrived (gitignored scratch), so a
  # missing golden is a skip, not a failure; the field-by-field assertions
  # above carry the contract in-tree.
  def test_full_json_equality_with_saved_golden
    golden_path = File.join(Dir.pwd, 'tmp/contrived/unitA_golden_before.json')
    omit('golden tmp/contrived/unitA_golden_before.json not present') unless File.file?(golden_path)
    golden = JSON.parse(File.read(golden_path))['verdict']

    result = FitAgent::Scoring.score_scenario(WORK, YAML.load_file(RUBRIC), CHAT)
    expected = golden.merge('evidence' => golden['evidence'].merge('chat' => CHAT, 'work_dir' => WORK))
    assert_equal expected, result
  end
end
