# Claude CLI bridge: developer documentation

Operational detail of the `Claude` workflow, which runs the external
`claude` CLI as a Scout chat agent with per-turn token attribution.
Provenance: everything below is extracted from the code comments and
structure of `Claude/workflow.rb` (L8-497); line references are to that
file.

## CLI invocation and run artifacts (L8-32)

- Task `ask` (L7, `chat_task`) writes its run artifacts under the job's
  files directory: `events.jsonl` (every raw streamed event, written and
  flushed line by line), `debug.log` (the CLI's own debug file) and
  `stderr.log` (the subprocess stderr).
- `max_turns` comes from `config :max_turns, :claude, :Claude, env:
  'CLAUDE_MAX_TURNS', default: 2000`.
- The command is
  `claude --bare -p --output-format stream-json --verbose
  --include-partial-messages --print --debug-file <debug>
  --max-turns <n> --dangerously-skip-permissions`, with the prompt —
  `LLM.print(chat)` — piped to stdin (`CMD.cmd ..., in: prompt, no_fail:
  true, stderr: stderr_file, pipe: true`).

## Event model (streaming pass)

The pass reads one JSON event per line and dispatches on `event["type"]`:

- `system` — `subtype: "thinking_tokens"` carries `estimated_tokens`, a
  RUNNING estimate that resets after every tool result; `subtype: "init"`
  seeds the model string.
- `stream_event` — partial-message envelope (present only because of
  `--include-partial-messages`). `message_delta` is the only usage
  carrier (`message_start` usage is zeroed on the GLM backend); one delta
  per message id arrives at end of message, so the pass keeps the LAST
  delta per id (`Claude.stream_delta_usage`). Every other subtype is
  tolerated and ignored.
- `assistant` — complete assistant events. Claude may split one turn over
  several assistant events sharing a message id; text and thinking blocks
  accumulate per id, and a `tool_use` block flushes pending text and
  emits a `function_call` record.
- `user` — `tool_result` blocks are mapped to `function_call_output`
  records with `is_error` propagation.
- `result` — closes the run: remaining assistant states are flushed, and
  `merge_info(usage:, total_cost_usd:, model:, session_id:)` records the
  run summary in the job info.

## Turn model (L62-90)

One Claude API turn == one backend request == one assistant message id
(Claude may split a turn over several assistant events that all share the
message id). Each turn gets:

- its own `inference_id` (a fresh `SecureRandom.uuid`), so `Chat.project`
  and `Chat.token_totals` inference_id dedup counts exactly one entry per
  turn;
- a first-assistant-event timestamp;
- a thinking-text accumulator (`reas`), since a turn may stream thinking,
  call a tool, then stream more thinking with the answer;
- a `turn_rt` thinking-token estimate total: the CLI streams
  `thinking_tokens` as a RUNNING estimate that resets after every tool
  result, so consecutive estimate events form a run belonging to the turn
  whose assistant events follow it; a run's total is its LAST estimate
  (the series climbs within a run). A turn with no run gets rt delta 0.
  Summing runs between turns is only a defensive fallback for streams
  that interleave several runs.

Token attribution itself is computed at chat-assembly time, after the
result event closes the run; the streaming pass only collects per-turn
facts.

## Token attribution: two layouts, never mixed (L232-340)

Attribution happens once the run is closed. `Claude.attribution_mode`
picks the layout for the WHOLE run:

- **PER-TURN** (research/claude-meta-evidence/v9-probe): used only when
  EVERY accounted turn has a collected `message_delta` entry. Each
  accounted turn's FIRST meta carries that API request's own
  pt/ct/tt/cct/cwt from its message_delta envelope
  (`Claude.turn_token_delta`, the same usage→meta mapping as the
  aggregate path); later metas of the turn carry zeros and share the
  turn's inference_id. The result-event aggregate is then a cross-check
  only and must NOT also be dumped onto the last turn's meta (double
  counting).
- **CASE B aggregate** (research/claude-meta-evidence/v2-probe): used
  when the CLI exposes real usage ONLY on the final result event, as the
  SESSION-WIDE SUM over every API request of the run. Per-turn
  pt/ct/tt/cct/cwt are then not recoverable, and the layout stays honest
  about that: every accounted meta carries zeros for pt/ct/tt/cct/cwt
  except the FINAL accounted turn's first meta, which carries the session
  aggregate from the result event. rt still carries the turn's own
  thinking_tokens estimate total — an estimate, not billed usage; the
  final turn keeps its own rt delta rather than the aggregate, because rt
  is a per-turn estimate series and a sub-component of ct (output
  includes thinking), never added into tt.

A single missing id (a backend zeroing deltas again) falls the whole run
back to CASE B; the modes are never mixed, and a per-turn split is never
fabricated. An empty accounted-turn list is aggregate mode so the
degenerate fallback keeps firing exactly as before.

Every `function_call` and assistant message is immediately preceded by
exactly one meta and the chat ends on the assistant message;
`function_call_output` messages are not accounted. `tt` is emitted
explicitly everywhere (including 0) so no later normalize pass recomputes
it from pt+ct.

`<key>_c` is the running chat cumulative of these deltas and telescopes
(final `tt_c` == aggregate tt); `<key>_s` mirrors the native
session-cumulative field set (fresh process per run, so numerically equal
to `<key>_c`).

Degenerate fallback (L331-340): a run that emitted NO accounted message
at all (no tool call, no assistant text) would otherwise lose the session
usage entirely, so the aggregate is emitted on one trailing meta in that
case only.

## Cache-inclusive prompt accounting (L393-402)

`CACHE_INCLUSIVE_PROMPT = true`: cache tokens count as part of the
prompt. The CLI's result usage reports `input_tokens` WITHOUT cache
tokens, which would read as a parallel category exceeding the prompt;
`transform_result_usage` sums them into `prompt_tokens` (the map-order
winner over `input_tokens`) and keeps an explicit `total_tokens` so tt
stays the true session total. Flip the constant to `false` for
cache-exclusive pt (tt keeps the same explicit total either way).

## Helper contracts (module level, L393-497)

- `Claude.transform_result_usage(usage)` (L404-422) — rewrites a
  RESULT-EVENT usage hash for `Chat.normalize_usage` only; the raw usage
  stays available for `merge_info` (`result_event_usage` copies it).
- `Claude.result_event_usage(event)` (L427-434) — Claude reports thinking
  tokens under `output_tokens_details.thinking_tokens`, but the native
  `Chat::USAGE_FIELD_MAP` only maps `...reasoning_tokens` to rt, so the
  helper copies `thinking_tokens` into `reasoning_tokens`.
- `Claude.stream_delta_usage(event)` (L445-464) — extracts one
  per-API-request usage record from a `--include-partial-messages`
  stream: only `stream_event`/`message_delta` envelopes qualify, the id
  lives on the ENVELOPE field `api_message_id` (the delta's
  `event.message` is null in real streams). Returns
  `[api_message_id, usage]` with a deep copy and the four token fields
  defaulted to 0, or nil.
- `Claude.turn_token_delta(usage)` (L475-482) — maps ONE per-request usage
  hash onto the meta token keys through the SAME
  `transform_result_usage` + `Chat.normalize_usage` pair as the aggregate
  path: pt = prompt_tokens (cache-inclusive), ct = output_tokens, tt =
  the injected total_tokens (== pt+ct), cct = cache_read_input_tokens,
  cwt = cache_creation_input_tokens. rt is deliberately NOT taken from
  usage: it stays the per-turn estimate series and is never added into
  tt.
- `Claude.attribution_mode(accounted_turns, usage_by_id)` (L490-497) —
  `:per_turn` only when every accounted turn has a collected delta, else
  `:aggregate`.

## Files written

| File | Content |
|---|---|
| `<job>.files/events.jsonl` | every raw CLI event, one JSON per line, flushed as read |
| `<job>.files/debug.log` | the CLI's own debug log (`--debug-file`) |
| `<job>.files/stderr.log` | subprocess stderr |
| `<job>.files/agent.chat` | the assembled Scout chat (metas included) |
