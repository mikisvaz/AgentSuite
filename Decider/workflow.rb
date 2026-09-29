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

    decision = Decision::Jev.new(
      model: ENV.fetch("JEV_MODEL", "jev-latest"),
      questions: request.fetch(:questions)
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
    text = Chat.print(chat)

    pattern = /<#{DECISION_TAG}>\s*(.*?)\s*<\/#{DECISION_TAG}>/m
    matches = text.scan(pattern)

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

    state = text.sub(
      pattern,
      ""
    ).strip

    if state.empty?
      raise RequestError,
        "Decider request contains no state outside the <#{DECISION_TAG}> block"
    end

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

