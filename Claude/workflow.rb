require 'scout-ai'

Misc.add_libdir if __FILE__ == $PROGRAM_NAME

module Claude
  extend Workflow
  self.include_workflow AgentWorkflow

  chat_task :ask do
    require 'securerandom'

    log_dir = files_dir
    events_file = File.join(log_dir, "events.jsonl")
    debug_file = File.join(log_dir, "debug.log")
    stderr_file = File.join(log_dir, "stderr.log")

    max_turns = config :max_turns, :claude, :Claude, env: 'CLAUDE_MAX_TURNS', default: 2000
    cmd = [
      "claude",
      "--bare",
      "-p",
      "--output-format", "stream-json",
      "--verbose",
      "--include-partial-messages",
      "--print",
      "--debug-file", debug_file,
      "--max-turns", max_turns.to_s,
      "--dangerously-skip-permissions"
    ]

    prompt = LLM.print(chat)
    io = CMD.cmd(
      cmd,
      in: prompt,
      no_fail: true,
      stderr: stderr_file,
      pipe: true
    )

    tool_names = {}
    tool_turns = {}
    assistant_messages = {}
    # Per-API-request usage collected from stream_event message_delta
    # envelopes (research/claude-meta-evidence/v9-probe):
    # api_message_id => usage hash, the four token fields defaulted to 0.
    # Stays empty when the backend does not fill the deltas; the
    # attribution pass then falls back to the aggregate layout.
    usage_by_id = {}
    # Model string: assistant/system events carry it in message["model"];
    # the result event's model field is nil in real streams.
    model = nil

    messages = []
    records = []
    emit = lambda do |role, content, turn = nil|
      message = { role: role, content: content }
      # Replace with Scout's actual incremental message-emission API.
      Log.high message.to_json
      records << { role: role, content: content, turn: turn }
    end

    # --- Turn model -------------------------------------------------------
    # One Claude API turn == one backend request == one assistant message
    # id (Claude may split a turn over several assistant events that all
    # share the message id).  Token attribution is computed at
    # chat-assembly time, after the result event closes the run; the
    # streaming pass below only collects per-turn facts.  Each turn gets
    # its own inference_id so Chat.project's and Chat.token_totals'
    # inference_id dedup counts exactly one entry per turn.

    turn_rt = {}            # message_id => thinking_tokens estimate total
    turn_inference_id = {}  # message_id => per-turn inference identity
    turn_timestamp = {}     # message_id => first assistant event timestamp
    turn_reas = {}          # message_id => thinking text
    turns = []

    # The CLI streams system/thinking_tokens as a RUNNING estimate that
    # resets after every tool_result: one run of consecutive estimate
    # events belongs to the turn whose assistant events follow it, and a
    # run's total is its last estimate (the series climbs within a run).
    # A turn with no run gets rt delta 0.
    estimate_runs = []
    pending_estimate = nil
    close_estimate_run = lambda do
      if pending_estimate
        estimate_runs << pending_estimate
        pending_estimate = nil
      end
    end

    flush_assistant = lambda do |message_id|
      state = assistant_messages.delete(message_id)
      next unless state

      # Accumulate every thinking segment of the turn (a turn may stream
      # thinking, call a tool, then stream more thinking with the answer);
      # metas are emitted later, at chat-assembly time.
      unless state[:thinking].empty?
        turn_reas[message_id] = [
          turn_reas[message_id], state[:thinking]
        ].compact.join("\n")
      end

      unless state[:text].empty?
        emit.call(:assistant, state[:text], message_id)
      end
    end

    # Kept for the attribution pass below; the result event carries the
    # session-wide usage aggregate.
    result_event = nil

    Open.open(events_file, mode: "w") do |file|
      while line = io.gets
        file.write(line)
        file.flush

        begin
          event = JSON.parse(line)
        rescue JSON::ParserError
          next
        end

        case event["type"]
        when "system"
          if event["subtype"] == "thinking_tokens"
            # Running estimate within the current turn; the LAST value of
            # a run is the run's total, so just keep overwriting.
            pending_estimate = event["estimated_tokens"].to_i
          elsif event["subtype"] == "init"
            model ||= event["model"]
          end

        when "stream_event"
          # Partial-message envelope (only present with
          # --include-partial-messages).  message_delta is the only
          # usage carrier (message_start's usage is zeroed on the GLM
          # backend) and one delta per message id arrives at end of
          # message, so overwriting keeps the LAST delta per id (never
          # sum deltas).  Every other subtype is tolerated and ignored:
          # content assembly stays on the complete assistant events.
          if (pair = Claude.stream_delta_usage(event))
            usage_by_id[pair[0]] = pair[1]
          end

        when "assistant"
          # Estimate events precede the assistant events of the turn they
          # belong to.
          close_estimate_run.call

          message = event["message"] || {}
          model ||= message["model"]
          message_id = message["id"] || event["uuid"]

          unless turn_inference_id.key?(message_id)
            turns << message_id
            turn_inference_id[message_id] = SecureRandom.uuid
            turn_timestamp[message_id] = event["timestamp"]
            # Normally exactly one estimate run accumulated since the
            # previous turn; summing is the defensive fallback for a
            # stream that interleaves several runs between turns.
            turn_rt[message_id] = estimate_runs.sum
            estimate_runs.clear
          end

          state = (assistant_messages[message_id] ||= {
            text: +"",
            thinking: +""
          })

          Array(message["content"]).each do |block|
            case block["type"]
            when "text"
              state[:text] << block["text"].to_s

            when "thinking"
              state[:thinking] << block["thinking"].to_s

            when "tool_use"
              flush_assistant.call(message_id)

              call = {
                name: block["name"],
                arguments: block["input"] || {},
                id: block["id"]
              }

              tool_names[block["id"]] = block["name"]
              tool_turns[block["id"]] = message_id
              emit.call(
                :function_call,
                JSON.generate(call),
                message_id
              )
            end
          end

          # Do not flush here: Claude may send multiple assistant
          # events for the same message. Flush at a real boundary.

        when "user"
          close_estimate_run.call

          message = event["message"] || {}

          Array(message["content"]).each do |block|
            next unless block["type"] == "tool_result"

            tool_id = block["tool_use_id"]
            output = {
              name: tool_names[tool_id],
              content: block["content"],
              id: tool_id
            }
            output[:is_error] = true if block["is_error"]

            emit.call(
              :function_call_output,
              JSON.generate(output),
              tool_turns[tool_id]
            )
          end

          # A tool-result event follows the assistant's tool call.
          # Any pending assistant content should already have flushed.

        when "result"
          close_estimate_run.call

          # The result event marks the end of the run.
          assistant_messages.keys.each do |message_id|
            flush_assistant.call(message_id)
          end

          merge_info(
            usage: event["usage"],
            total_cost_usd: event["total_cost_usd"],
            model: model || event["model"],
            session_id: event["session_id"]
          )

          result_event = event
        end
      end

      # --- Token attribution (computed at chat-assembly time) -------------
      # Two layouts, chosen per run (Claude.attribution_mode):
      #
      # PER-TURN (research/claude-meta-evidence/v9-probe): each accounted
      # turn's FIRST meta carries that API request's own pt/ct/tt/cct/cwt
      # from its message_delta envelope (Claude.turn_token_delta, same
      # usage->meta field mapping as the aggregate path); later metas of
      # the turn carry zeros and share the turn's inference_id.  The
      # result-event aggregate is then a cross-check only and must NOT
      # also be dumped onto the last turn's meta (double counting).
      #
      # CASE B (research/claude-meta-evidence/v2-probe): the CLI exposes
      # real usage ONLY on the final result event, as the SESSION-WIDE SUM
      # over every API request of the run; assistant usage blocks are
      # zeros and modelUsage equals the result usage.  Per-turn
      # pt/ct/tt/cct/cwt are therefore NOT recoverable, and the layout
      # stays honest about that:
      #   * every accounted meta carries zeros for pt/ct/tt/cct/cwt except
      #     the FINAL accounted turn's first meta, which carries the
      #     session aggregate from the result event (tt = pt+ct via
      #     normalize_usage);
      #   * rt carries the turn's own thinking_tokens estimate total -- an
      #     estimate, not billed usage; the final turn keeps its own rt
      #     delta rather than the aggregate because rt is a per-turn
      #     estimate series and a sub-component of ct (output includes
      #     thinking), never added into tt;
      #   * <key>_c is the running chat cumulative of these deltas and
      #     telescopes (final tt_c == aggregate tt); <key>_s mirrors the
      #     native session-cumulative field set (fresh process per run, so
      #     numerically equal to <key>_c).
      # Every function_call and assistant message is immediately preceded
      # by exactly one meta and the chat ends on the assistant message;
      # function_call_output messages are not accounted.  tt is emitted
      # explicitly everywhere (including 0) so no later normalize pass
      # recomputes it from pt+ct.

      aggregate = {}
      if result_event
        normalized = Chat.normalize_usage(
          Claude.transform_result_usage(
            Claude.result_event_usage(result_event)
          )
        )
        %w[pt ct tt cct cwt].each do |key|
          aggregate[key] = normalized[key].to_i
        end
      end

      accounted_roles = %i[function_call assistant]
      accounted_turns = turns.select do |message_id|
        records.any? do |record|
          record[:turn] == message_id &&
            accounted_roles.include?(record[:role])
        end
      end

      # Per-request attribution requires an entry for EVERY accounted
      # turn; one missing id (a backend zeroing deltas again) falls the
      # whole run back to CASE B below -- modes are never mixed.
      per_turn = Claude.attribution_mode(accounted_turns, usage_by_id) ==
                 :per_turn

      deltas = {}
      accounted_turns.each_with_index do |message_id, index|
        delta = {
          pt: 0, ct: 0, tt: 0, cct: 0, cwt: 0,
          rt: turn_rt[message_id].to_i
        }
        if per_turn
          delta.merge!(
            Claude.turn_token_delta(usage_by_id[message_id])
          )
        elsif index == accounted_turns.length - 1
          aggregate.each { |key, value| delta[key.to_sym] = value }
        end
        deltas[message_id] = delta
      end

      zero_delta = { pt: 0, ct: 0, tt: 0, cct: 0, cwt: 0, rt: 0 }
      cumulatives = { pt: 0, ct: 0, tt: 0, cct: 0, cwt: 0, rt: 0 }
      turn_counted = {}

      # Degenerate fallback: a run that emitted NO accounted message at all
      # (no tool call, no assistant text) would otherwise lose the session
      # usage entirely; emit it on one trailing meta in that case only.
      if accounted_turns.empty? && !aggregate.empty?
        meta = { inference_id: SecureRandom.uuid, timestamp: Chat.timestamp }
        meta[:model] = model if model
        %w[pt ct tt cct cwt rt].each do |key|
          meta[key.to_sym] = aggregate[key].to_i
        end
        serialized = Chat.serialize_meta(meta)
        Log.high({ role: :meta, content: serialized }.to_json)
        messages << { role: :meta, content: serialized }
      end

      records.each do |record|
        message_id = record[:turn]
        delta = nil
        first = false

        if accounted_roles.include?(record[:role]) &&
           deltas.key?(message_id)
          first = !turn_counted[message_id]
          turn_counted[message_id] = true
          # Only the FIRST accounted meta of a turn carries the turn's
          # delta; later metas of the same turn carry zeros and share the
          # turn's inference_id, so the inference_id dedup in
          # Chat.trace_indices / Chat.project counts the turn exactly
          # once (a turn with several tool calls).
          delta = first ? deltas[message_id] : zero_delta
        end

        if delta
          meta = {}
          Chat::TOKEN_KEYS.each do |key|
            value = delta[key.to_sym]
            meta[key.to_sym] = value
            meta["#{key}_c".to_sym] = cumulatives[key.to_sym] + value
            meta["#{key}_s".to_sym] = cumulatives[key.to_sym] + value
          end
          Chat::TOKEN_KEYS.each do |key|
            cumulatives[key.to_sym] += delta[key.to_sym]
          end

          meta[:model] = model if model
          meta[:inference_id] = turn_inference_id[message_id]
          meta[:timestamp] = turn_timestamp[message_id]

          # reas (reasoning text) rides the same metas; only the first
          # accounted meta of a turn needs it.
          reas = turn_reas[message_id]
          meta[:reas] = reas if first && reas && !reas.empty?

          serialized = Chat.serialize_meta(meta)
          Log.high({ role: :meta, content: serialized }.to_json)
          messages << { role: :meta, content: serialized }
        end

        messages << { role: record[:role], content: record[:content] }
      end

      file('agent.chat').write Chat.print(messages)
      messages
    end
  end

  # Cache-INCLUSIVE prompt accounting: cache tokens count as part of the
  # prompt.  The CLI's result usage reports input_tokens WITHOUT cache
  # tokens, which reads as a parallel category exceeding the prompt; sum
  # them into prompt_tokens (the map-order winner over input_tokens) and
  # keep an explicit total_tokens so tt stays the true session total.
  # Flip CACHE_INCLUSIVE_PROMPT to false for cache-exclusive pt (tt keeps
  # the same explicit total either way).
  CACHE_INCLUSIVE_PROMPT = true

  # Rewrites a RESULT-EVENT usage hash for normalize_usage only; the raw
  # usage stays available (result_event_usage copies it) for merge_info.
  def self.transform_result_usage(usage)
    usage = JSON.parse(JSON.generate(usage))
    return usage unless Hash === usage

    input = usage['input_tokens'].to_i
    cache_read = usage['cache_read_input_tokens'].to_i
    cache_creation = usage['cache_creation_input_tokens'].to_i
    output = usage['output_tokens'].to_i

    prompt = CACHE_INCLUSIVE_PROMPT ?
      input + cache_read + cache_creation :
      input

    usage['prompt_tokens'] = prompt
    # tt stays the true session total (input + cache + output) whichever
    # way the prompt switch flips.
    usage['total_tokens'] = input + cache_read + cache_creation + output
    usage
  end

  # Claude reports thinking tokens under
  # output_tokens_details.thinking_tokens, but the native
  # Chat::USAGE_FIELD_MAP only maps ...reasoning_tokens to rt.
  def self.result_event_usage(event)
    usage = JSON.parse(JSON.generate(event["usage"])) || {}
    details = usage["output_tokens_details"]
    if Hash === details && details["thinking_tokens"]
      details["reasoning_tokens"] = details["thinking_tokens"]
    end
    usage
  end

  # Extracts one per-API-request usage record from a
  # --include-partial-messages stream (research/claude-meta-evidence/
  # v9-probe).  The stream_event/message_delta envelope is the only usage
  # carrier (message_start's usage is zeroed on the GLM backend) and its
  # id lives on the ENVELOPE field api_message_id -- the delta's
  # event.message is null in real streams.  Returns
  # [api_message_id, usage] with a deep copy of the usage hash and the
  # four token fields defaulted to 0, or nil for any event that is not a
  # usage-bearing message_delta.
  def self.stream_delta_usage(event)
    return nil unless Hash === event
    return nil unless event['type'] == 'stream_event'

    inner = event['event']
    return nil unless Hash === inner && inner['type'] == 'message_delta'

    id = event['api_message_id']
    usage = inner['usage']
    return nil unless id && Hash === usage

    usage = JSON.parse(JSON.generate(usage))
    %w[
      input_tokens cache_read_input_tokens
      cache_creation_input_tokens output_tokens
    ].each do |field|
      usage[field] = usage[field].to_i
    end
    [id, usage]
  end

  # Maps ONE per-request usage hash onto the meta token keys through the
  # SAME transform_result_usage + Chat.normalize_usage pair as the
  # aggregate path, so the field mapping is shared between layouts:
  # pt = prompt_tokens (cache-inclusive input + cache_read +
  # cache_creation while CACHE_INCLUSIVE_PROMPT), ct = output_tokens,
  # tt = the injected total_tokens (== pt + ct, cache-inclusive),
  # cct = cache_read_input_tokens, cwt = cache_creation_input_tokens.
  # rt is deliberately NOT taken from usage: it stays the per-turn
  # thinking_tokens estimate series and is never added into tt.
  def self.turn_token_delta(usage)
    normalized = Chat.normalize_usage(
      Claude.transform_result_usage(usage)
    )
    %w[pt ct tt cct cwt].each_with_object({}) do |key, result|
      result[key.to_sym] = normalized[key].to_i
    end
  end

  # Per-request attribution is used only when EVERY accounted turn has a
  # collected message_delta entry; a single missing id (e.g. a backend
  # that zeroes deltas again) falls the whole run back to the aggregate
  # layout -- modes are never mixed and a per-turn split is never
  # fabricated.  An empty accounted-turn list is aggregate mode so the
  # degenerate trailing-meta fallback keeps firing exactly as before.
  def self.attribution_mode(accounted_turns, usage_by_id)
    if accounted_turns.any? &&
       accounted_turns.all? { |id| usage_by_id.key?(id) }
      :per_turn
    else
      :aggregate
    end
  end
end
