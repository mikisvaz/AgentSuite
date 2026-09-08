# Unit tests for FitAgent::DefaultProposer (research/07 §2 step 6-7).
#
# No real model: the agent object is a stub built by the injected
# chat_builder, so nothing leaves the process and no endpoint is ever
# involved.
require File.expand_path('../../test_helper', __dir__)
require 'FitAgent/proposer'

class TestDefaultProposer < Test::Unit::TestCase
  # Minimal stand-in for LLM::Agent: records prompts, replies with canned
  # text. Exposes exactly the surface DefaultProposer uses (+user+, +chat+).
  class FakeAgent
    attr_reader :prompts

    def initialize(replies)
      @replies = Array(replies)
      @prompts = []
    end

    def user(text)
      @prompts << text.to_s
      self
    end

    def chat(_options = {})
      @replies.shift || ''
    end
  end

  GOOD_REPLY = <<~REPLY
    Sure, here is the revision:

    ```yaml
    instructions: |
      Always try patch first.
      Use dry_run only for verification.
    tools:
      - "ComputerUse patch"
      - "ComputerUse read"
    ```
  REPLY

  def test_prompt_includes_failing_ids_and_rubric
    prior = [
      { 'arm' => 'baseline', 'scenario' => 'F01', 'verdict' => 'PASS', 'score' => '1.0', 'failures' => [] },
      { 'arm' => 'baseline', 'scenario' => 'E01', 'verdict' => 'FAIL', 'score' => '0.0',
        'failures' => ['functional:readme.txt:match:diff'] }
    ]
    prompt = FitAgent::Evolve.propose_prompt('e2e', prior, 'F01..E06 all-pass shape')
    assert prompt.include?('E01'), 'failing scenario id must appear'
    assert prompt.include?('F01'), 'passing scenario id must appear'
    assert prompt.include?('baseline'), 'arm name must appear'
    assert prompt.include?('F01..E06 all-pass shape'), 'rubric summary must appear'
    assert prompt.include?('instructions'), 'reply format hint must appear'
    assert prompt.include?('YAML') || prompt.include?('yaml')
  end

  def test_good_reply_round_trips_through_validator
    agent = FakeAgent.new(GOOD_REPLY)
    proposer = FitAgent::DefaultProposer.new(-> { agent })
    proposal = proposer.call('e2e', FitAgent::Evolve.propose_prompt('e2e', [], 'summary'))
    assert_not_nil proposal
    assert_equal 'Always try patch first.', proposal['instructions'].lines.first.strip
    assert_equal ['ComputerUse patch', 'ComputerUse read'], proposal['tools'].map(&:to_s)
    errors = FitAgent::Evolve.validate_proposal(proposal)
    assert_equal [], errors, "good reply must validate cleanly, got #{errors.inspect}"
  end

  def test_preamble_and_prompt_reach_the_agent
    agent = FakeAgent.new(GOOD_REPLY)
    FitAgent::DefaultProposer.new(-> { agent }).call('e2e', 'PROMPT-BODY')
    assert_equal 1, agent.prompts.length
    assert agent.prompts.first.include?('PROMPT-BODY')
    assert agent.prompts.first.include?('Experiment: e2e')
  end

  def test_no_endpoint_anywhere_in_default_construction
    src = File.read(File.expand_path('../../../lib/FitAgent/proposer.rb', __dir__))
    refute src =~ /endpoint\s*:/, 'no endpoint: option may be passed'
    refute src =~ /Scout\.etc\.AI/, 'no Scout.etc.AI selection'
    refute src =~ /LLM::Agent\.new\(.*endpoint/m, 'agent construction must be plain'
    # the only Agent construction allowed is the bare default
    assert src.include?('LLM::Agent.new')
  end

  def test_malformed_reply_becomes_invalid_proposal_and_repair_fixes_it
    bad = 'I will do better next time, trust me'
    good = GOOD_REPLY
    agent = FakeAgent.new([bad, good])
    proposer = FitAgent::DefaultProposer.new(-> { agent })
    first = proposer.call('e2e', 'prompt')
    assert FitAgent::Evolve.validate_proposal(first).any?,
           "malformed reply must not validate, got #{first.inspect}"

    final, attempts = FitAgent::Evolve.validate_with_repairs(first, proposer)
    assert_equal 2, agent.prompts.length, 'repair must have re-asked the model once'
    assert agent.prompts.last.include?('rejected'), 'repair prompt must carry the errors'
    assert_not_nil final
    assert_equal [], FitAgent::Evolve.validate_proposal(final)
    assert attempts.length >= 2
  end

  def test_bare_yaml_reply_is_accepted
    bare = <<~REPLY
      instructions: |
        Use patch then verify with read.
      tools: []
    REPLY
    agent = FakeAgent.new(bare)
    proposal = FitAgent::DefaultProposer.new(-> { agent }).call('e2e', 'prompt')
    assert_equal [], FitAgent::Evolve.validate_proposal(proposal)
  end

  # repair_prompt_body: quotes the first error verbatim and appends a minimal
  # valid example matching the failure kind (string-not-grammar vs
  # non-string). These use the exact error shapes recorded in the dead live
  # run results/patch-mini-1/evolution.json, attempts 0 and 1.
  def test_repair_prompt_body_for_not_grammar_string_kind
    errors = FitAgent::Evolve.validate_proposal(
      'instructions' => 'x',
      'tools' => ['read(path) -> exact current contents of a file in the work tree']
    )
    assert !errors.empty?
    body = FitAgent::DefaultProposer.new.repair_prompt_body(errors)
    # first error quoted verbatim
    assert body.include?("First error, verbatim: #{errors.first}"), body
    # minimal valid example for the string-not-grammar kind: a spec line
    assert body.include?('ComputerUse patch'), body
    assert body.include?('ONE spec line'), body
    refute body.include?('never structured objects'), body
  end

  def test_repair_prompt_body_for_non_string_kind
    errors = FitAgent::Evolve.validate_proposal(
      'instructions' => 'x',
      'tools' => [{ 'name' => 'read' }, { 'name' => 'write' }]
    )
    assert errors.any? { |e| e.include?('must be a string, got Hash') }, errors.inspect
    body = FitAgent::DefaultProposer.new.repair_prompt_body(errors)
    assert body.include?("First error, verbatim: #{errors.first}"), body
    # minimal valid example for the non-string kind: a YAML list of strings
    assert body.include?('never structured objects'), body
    assert body.include?('tools: ["ComputerUse patch"]'), body
  end

  def test_repair_prompt_body_for_other_kinds_falls_back_to_default_example
    body = FitAgent::DefaultProposer.new.repair_prompt_body(['instructions must be a non-empty string'])
    assert body.include?('First error, verbatim: instructions must be a non-empty string'), body
    assert body.include?('ComputerUse patch'), body
    # the empty-tools escape hatch is always offered
    assert body.include?('tools: [] is valid and means: keep the default tooling.'), body
  end

  def test_repair_prompt_reaches_the_fake_agent_and_round_trips
    # the full repair path: a broken tools entry, then a valid reply — the
    # repair prompt must carry the verbatim error and the example, and the
    # repaired proposal must validate. No network: FakeAgent only.
    broken_reply = <<~REPLY
      ```yaml
      instructions: |
        Patch agent instructions.
      tools:
        - "read(path) -> exact current contents"
      ```
    REPLY
    agent = FakeAgent.new([broken_reply, GOOD_REPLY])
    proposer = FitAgent::DefaultProposer.new(-> { agent })
    first = proposer.call('e2e', 'prompt')
    assert FitAgent::Evolve.validate_proposal(first).any?

    final, _attempts = FitAgent::Evolve.validate_with_repairs(first, proposer)
    assert_equal 2, agent.prompts.length, 'repair must re-ask exactly once'
    repair_prompt = agent.prompts.last
    errs = FitAgent::Evolve.validate_proposal(first)
    assert repair_prompt.include?('First error, verbatim: ' + errs.first), repair_prompt
    assert repair_prompt.include?('ComputerUse patch'), repair_prompt
    assert repair_prompt.include?('rejected'), repair_prompt
    assert_not_nil final
    assert_equal [], FitAgent::Evolve.validate_proposal(final)
  end
end
