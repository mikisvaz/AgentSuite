require 'scout-ai'
require "json"
require "time"

Misc.add_libdir if __FILE__ == $PROGRAM_NAME

#require 'rbbt/sources/MODULE'

require 'scout/model/decision/jev'

module Decider
  extend Workflow
  include_workflow AgentWorkflow
  self.name = "Decider"

  class RequestError < ScoutException
  end

  DECISION_TAG = "scout-decision"

  chat_task :ask do
    request = parse_request(chat)

    questions = request.fetch(:questions)

    decision = Decision::Jev.new(
      model: ENV.fetch("JEV_MODEL", "jev-latest"),
      questions: questions
    )

    result = decision.eval(request.fetch(:state))

    record_decision(
      request: request,
      result: result
    )

    usage = result.value['usage']
    model = result.value['model']

    meta = {model: model, pt: usage['input_tokens'], ct: usage['output_tokens'], tt: usage['input_tokens'] + usage['output_tokens'] }

    [{role: :meta, content: meta},
    {role: :assistant, content: result.value.to_json}]
  end

  helper :parse_request do |chat|
    decision = chat.pop[:content]

    pattern = /^<#{DECISION_TAG}>$\s*(.*?)\s*^<\/#{DECISION_TAG}>$/m
    matches = decision.scan(pattern)

    if matches.empty?
      raise RequestError,
        "Decider request does not contain a <#{DECISION_TAG}> JSON block"
    end

    if matches.length > 1
      raise RequestError,
        "Decider request contains more than one <#{DECISION_TAG}> block"
    end

    json = matches.first.first

    begin
      specification = JSON.parse(json)
    rescue JSON::ParserError => e
      raise RequestError,
        "Invalid JSON in <#{DECISION_TAG}> block: #{e.message}"
    end

    unless specification.is_a?(Hash)
      raise RequestError,
        "The <#{DECISION_TAG}> block must contain a JSON object"
    end

    questions = specification["questions"]

    unless questions.is_a?(Hash) && !questions.empty?
      raise RequestError,
        "The <#{DECISION_TAG}> JSON must contain a non-empty 'questions' object"
    end


    if chat.empty?
      raise RequestError,
        "Decider request contains no state outside the <#{DECISION_TAG}> block"
    end

    short_chat = Chat.epoch_tool_compactation(
        chat,
        threshold: 0,                 # compact from the very first tool call, every step
        full: 0,                      # no free full-fidelity window: only the newest call survives whole
        base_compacted: 10,           # compact band
        configured_max_compacted: 10, # cap the band at 19
        compacted_growth_ratio: 0.0,  # never grow the band
        initial_size: 1,              # epoch pinned to the newest call only
        epochs_per_increase: 1,       # neutralized together with...
        size_increase: 0,             # ...the two increase knobs: epoch size stays 1
        repeat_increase: 0,
        configured_max_size: 1        # hard-pins the schedule's epoch size at 1
    )

    state = short_chat.print

    {
      specification: specification,
      questions: questions,
      state: state
    }
  end

  helper :record_decision do |request:, result:|
    path = file("decisions.json")

    records =
      if File.file?(path)
        begin
          JSON.parse(File.read(path))
        rescue JSON::ParserError => e
          raise RequestError,
            "Existing decisions.json is invalid JSON: #{e.message}"
        end
      else
        {
          "schema_version" => 1,
          "decisions" => []
        }
      end

    unless records.is_a?(Hash) &&
           records["schema_version"] == 1 &&
           records["decisions"].is_a?(Array)

      raise RequestError,
        "Existing decisions.json does not have the expected schema"
    end

    records["decisions"] << {
      "timestamp" => Time.now.utc.iso8601(6),
      "questions" => request.fetch(:questions),
      "state" => request.fetch(:state),
      "result" => result.value
    }

    Open.write(
      path,
      JSON.pretty_generate(records) + "\n"
    )

    path
  end
end

