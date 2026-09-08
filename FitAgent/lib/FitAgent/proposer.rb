require 'yaml'
require 'json'

module FitAgent
  # Live proposer: turns an Evolve.propose_prompt into a candidate proposal
  # {instructions, tools} by asking the model through the framework's normal
  # chat path.
  #
  # Endpoint policy (research/07 addendum 2026-09-05, decision 1): NO endpoint
  # is ever specified here — the agent is built plain (LLM::Agent.new) so the
  # configured default applies by omission. No endpoint option and no
  # endpoint-table lookup of any kind.
  #
  # The model reply is parsed as YAML. Malformed replies become validator
  # errors (empty instructions etc.) and flow into Evolve.validate_with_repairs
  # so the bounded repair loop re-asks with the error text appended.
  class DefaultProposer
    # system preamble pinned into the agent's start_chat; keeps the reply
    # shape stable so YAML parsing is reliable. No tool wiring — the proposer
    # only ever produces instructions text, it does not execute tools.
    PREAMBLE = <<~'CHAT'.strip
      You are the instruction-proposer component of an agent-improvement loop.
      You receive deterministic rubric scores for an agent under test and
      return a revised instruction block for its start_chat.

      Reply with ONLY a fenced ```yaml block (no prose before or after) with
      exactly these keys:

      ```yaml
      instructions: |
        <the full revised instruction text, multi-line>
      tools:
        - "Workflow [task [input|name=value ...]]"
      ```

      Never mention endpoints, models, or inference points. Tool spec lines
      follow the grammar `Workflow [task [input|name=value ...]]`.
    CHAT

    # Minimal valid examples used in repair prompts, matched to the failure
    # kind so the model has an unambiguous target shape to copy. The spec
    # example is DERIVED from the configured target's primary tool at prompt
    # time (see .repair_example_spec); the constants below are the
    # grammar-shaped fallbacks for a bare/no-target load, never a concrete
    # workflow name.
    REPAIR_EXAMPLE_SPEC = 'Workflow task'
    REPAIR_EXAMPLE_NOT_STRING =
      'tools: ["Workflow task"] (a plain YAML list of quoted spec strings)'
    REPAIR_EXAMPLE_DEFAULT = REPAIR_EXAMPLE_SPEC

    class << self
      # The spec example quoted in repair prompts: the primary tool of the
      # CONFIGURED target (FitAgent::Scenarios.loaded_target), falling back
      # to the grammar-shaped placeholder constant when no target is loaded.
      def repair_example_spec
        FitAgent::Scenarios.loaded_target&.primary_tool || REPAIR_EXAMPLE_SPEC
      end

      def repair_example_not_string
        "tools: [\"#{repair_example_spec}\"] (a plain YAML list of quoted spec strings)"
      end
    end

    # +chat_builder+ is a callable returning a fresh LLM::Agent-like object
    # responding to +user+ and +chat+ (returns the assistant text). It exists
    # so tests can stub the model; the default builds the plain agent.
    def initialize(chat_builder = nil, &block)
      @chat_builder = chat_builder || block || method(:default_agent)
    end

    # Interface expected by Evolve.evolve_loop: call(experiment, prompt,
    # generation:) -> proposal Hash (possibly invalid; the loop
    # validates/repairs). The extra kwargs are accepted and ignored so any
    # 2-arity stub proposers keep working (loop passes generation:).
    def call(experiment, prompt, **_kwargs)
      reply = ask_model(build_prompt(experiment, prompt))
      parse_reply(reply)
    end

    # Repair hook used by Evolve.validate_with_repairs: append the validation
    # errors and ask again. Bounded by the caller (<= MAX_REPAIRS).
    def repair(proposal, errors)
      return nil unless errors.is_a?(Array) && !errors.empty?
      reply = ask_model(build_prompt(nil, repair_prompt_body(errors)))
      parse_reply(reply)
    end

    # Build the repair body: quote the FIRST validation error verbatim and
    # append a minimal valid example matching the failure kind:
    #   - "must be a string, got ..."    -> entry was not a string (Hash etc.)
    #   - "must be 'Workflow [task ...'" -> string that is not a spec line
    #   - anything else                  -> safe default example
    # Pure string builder over the given errors; kept public so the unit
    # tests can assert its shape without a model.
    def repair_prompt_body(errors, example_spec: nil)
      example_spec = self.class.repair_example_spec if example_spec.nil?
      errors = Array(errors)
      listing = errors.map { |e| "- #{e}" }.join("\n")
      first = errors.first.to_s
      example = if first.include?('must be a string, got')
                  "tools entries must be plain strings, never structured " \
                  "objects or descriptions; e.g. #{self.class.repair_example_not_string}"
                elsif first.include?("must be 'Workflow [task [input|name=value ...]]'")
                  "each tools entry is ONE spec line, never a description or " \
                  "signature; e.g. #{example_spec}"
                else
                  "e.g. #{example_spec}"
                end
      "Your previous proposal was rejected:\n" \
        "#{listing}\n\n" \
        "First error, verbatim: #{first}\n" \
        "#{example}\n" \
        "tools: [] is valid and means: keep the default tooling.\n\n" \
        'Return a corrected ```yaml block with ' \
        'exactly the keys instructions and tools.'
    end

    # Prompt the model receives (excluding the preamble, which lives in the
    # start_chat). Kept public so the unit test can assert its shape.
    def build_prompt(experiment, prompt)
      exp = experiment.to_s.strip
      head = exp.empty? ? '' : "Experiment: #{exp}\n\n"
      "#{head}#{prompt.to_s}"
    end

    # Extract the proposal Hash from a model reply. Tolerant: a fenced yaml
    # block is preferred; a bare YAML mapping is accepted; anything else is
    # returned as {} so the validator reports it instead of raising.
    def parse_reply(reply)
      text = reply.to_s
      block = text.scan(/```ya?ml\s*\n(.*?)```/m).flatten.map(&:strip).reverse.find { |b| !b.empty? }
      body = block || (text =~ /\A\s*(instructions|tools):/ ? text.strip : nil)
      return {} if body.nil?
      YAML.safe_load(body, permitted_classes: [], aliases: false) || {}
    rescue Psych::SyntaxError, StandardError
      {}
    end

    private

    # Plain agent — no endpoint, no options: the framework default applies.
    def default_agent
      LLM::Agent.new
    end

    def ask_model(prompt)
      agent = @chat_builder.call
      agent.user prompt
      agent.chat
    end
  end
end
