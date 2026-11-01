# Claude agent v9 probe — partial-message streaming usage on the GLM backend (live run, claude CLI 2.1.306, model glm-5.2 via ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic/)

Scenario: `~/git/sandbox/Scenarios/scenarios/read_file/main.chat` ("Calculate how many lines
are in the file ./file.txt."), run directly against the CLI (no workflow, no code changes).
Branch id: claude-v9. Files: `events.jsonl` (214 lines, verbatim stdout), `stderr.log`,
`MANIFEST.sha256`. Run date 2026-10-30 (assistant timestamps 13:15:27Z–13:15:30Z; note the
result/init carry no wall-clock timestamps, only assistant/user events do).
Session id `dfb087c2-77df-4dba-83ab-242ccd3145c4`, cwd the scenario dir, num_turns=2,
`total_cost_usd=0.005212`, `duration_api_ms=4252`.

## Flag spelling

`--include-partial-messages` — exact, confirmed on the 2.1.306 binary via `claude --help`
(help line 120: "Include partial message chunks as they arrive (only works with --print and
--output-format=stream-json)"). No fallback surface needed.

## Verdict: tier (a) is reachable, with one caveat — real per-request usage arrives in
`stream_event` `message_delta` (NOT `message_start`), and its message id is on the envelope
field `api_message_id`, not inside `event.message`.

- `stream_event message_start` per id: usage is `{"input_tokens": 0, "output_tokens": 0}` —
  ZEROED, both turns. The persisted SDK doc's message_start row does not promise usage; the
  GLM backend populates nothing there.
- `stream_event message_delta` per id: FULL per-request usage, one delta per message id
  (one per API request): `input_tokens`, `output_tokens`, `cache_read_input_tokens`
  (+ `server_tool_use`, `service_tier`). `cache_creation_input_tokens` is ABSENT from the
  delta payload (it is present, value 0, on the session result event); absence should be
  read as 0.
- `stream_event message_stop`: no usage.

## Per-message-id usage table (from events.jsonl lines 4/28 and 32/212)

| message id                          | turn | where observed (lines) | input_tokens | cache_read | cache_creation | output_tokens |
|-------------------------------------|------|------------------------|--------------|------------|----------------|---------------|
| msg_20261030211526032748d8e31e4fbc  | 1    | message_start L4 / message_delta L28 | 79 | 960 | absent (→0) | 27 |
| msg_20261030211527995abee9a72e4ae4  | 2    | message_start L32 / message_delta L212 | 50 | 1024 | absent (→0) | 116 |

Session result event (L214) for comparison: `input_tokens=129, cache_read_input_tokens=1984,
cache_creation_input_tokens=0, output_tokens=143`, `num_turns=2`.

Arithmetic: 79+50=129, 960+1024=1984, 27+116=143 — the per-request numbers sum EXACTLY to the
session totals. Per-request usage on the GLM backend is therefore real, not a copy of the
aggregate, and the aggregate is confirmed as the sum over the 2 API requests.

## Cumulative vs increment for message_delta output_tokens

There is exactly ONE `message_delta` per message id in this stream (2 deltas, 2 ids), arriving
at the end of the message (after the last `content_block_stop`, immediately before
`message_stop`), so there is no within-id series to compare in this run. What the data pins:

- Each delta's `output_tokens` is the total for its message (27 and 116), and the sum equals
  the result total (143). If these were per-delta increments the sum interpretation is
  unchanged; if the last value were cumulative across multiple deltas, the last value would
  be the per-message total — in either reading the last `message_delta.output_tokens` per
  message id is the per-request output total, and `27 + 116 = 143` matches the session
  aggregate exactly.
- Cross-check that it is NOT one-delta-per-block: turn 2 streamed a thinking block, a text
  block, and had 2 assistant events under one id (thinking event + text event), yet produced
  exactly one `message_delta` with output 116 covering both blocks (its thinking is inside
  the 116: the text answer is ~65 tokens).
- The upstream convention (persisted SDK doc: "usage arriving in message_delta", Anthropic
  Messages API semantics: message_delta carries the message-level usage at stop) plus the
  exact-sum match makes "per-message total, take the last value per id" the safe
  consumption rule for the adapter.

## ID shape

`api_message_id` on the `stream_event` envelope (sibling of `event`, `session_id`, `uuid`,
`parent_tool_use_id`) equals EXACTLY the id on the corresponding `assistant` events'
`message.id` (verified: msg_...d8e31e4fbc on assistant L26 = message_start L4 =
message_delta L28 envelope; msg_...995abee9a72e4ae4 on assistant L151/L210 = message_start
L32 = message_delta L212 envelope). `message_delta.event.message` is `null`-ish — the id is
NOT inside the event payload; parsing must read the envelope's `api_message_id`.
`message_start.event.message.id` also matches. So the turn key the v2 probe used
(assistant message id) joins directly to stream events via `api_message_id`.

## Event inventory / surprises vs v2 probe

- 214 lines: 147 stream_event, 58 system/thinking_tokens, 3 assistant, 2 system/status,
  1 system/ui_invalidate, 1 system/init, 1 user, 1 result/success.
- stream_event subtypes: message_start ×2, content_block_start ×3 (tool_use, thinking,
  text), content_block_delta ×136 (58 thinking_delta, 56 text_delta, 20 input_json_delta,
  1 signature_delta), content_block_stop ×3, message_delta ×2, message_stop ×2.
- NEW vs v2: `stream_event` envelope (all the partial-message machinery),
  `system/status`, `system/ui_invalidate` (`event: "ui.render"`), `signature_delta`,
  thinking streamed as thinking_delta chunks (v2 saw thinking only inside assistant
  events).
- Consistent with v2: assistant events still carry zeroed usage blocks ({"input_tokens":0,
  "output_tokens":0}) — enabling the flag does NOT change that; `system/thinking_tokens`
  still a per-turn running estimate (this run: turn 1 no run; turn 2 climbs 1→85 after the
  tool_result, exactly the v2 reset-after-tool_result behavior).
- Stream ordering per turn: message_start → content_block_start → deltas (+ interleaved
  AssistantMessage events as each block completes: assistant L26 mid-turn-1, assistant
  L151/L210 mid-turn-2) → content_block_stop(s) → message_delta (usage) → message_stop →
  user tool_result. Usage therefore arrives BEFORE the next turn's API request fires —
  a streaming consumer can attribute tokens per request in real time instead of at
  session end.
- The tool call is `Bash wc -l ./file.txt` → user tool_result `4 ./file.txt`; the final
  text answers "4 lines". GLM cached only 960/1024 tokens (fresh prefix, first request)
  — the v2 cache-read-much-larger-than-input signature shows up per-request here as
  79 in / 960 cached then 50 in / 1024 cached.

## Reproduction

Binary: /home/mvazque2/tmp/claude-cli/node_modules/@anthropic-ai/claude-code-linux-x64/claude
(v2.1.306, exposed via /home/mvazque2/tmp/claude-cli/bin/claude; node from
/home/mvazque2/.local/share/pi-node/node-v22.22.3-linux-x64/bin).
GLM backend env (already exported in this environment):
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic/, ANTHROPIC_AUTH_TOKEN=***,
ANTHROPIC_MODEL=glm-5.2 (plus DEFAULT_SONNET/OPUS/HAIKU = glm-5.2).

```
cd /home/mvazque2/git/sandbox/Scenarios/scenarios/read_file
export PATH=/home/mvazque2/tmp/claude-cli/bin:/home/mvazque2/.local/share/pi-node/node-v22.22.3-linux-x64/bin:$PATH
printf '%s\n' "Calculate how many lines are in the file ./file.txt." | \
  claude --bare -p --print --output-format stream-json --verbose \
         --include-partial-messages --dangerously-skip-permissions \
  > events.jsonl 2> stderr.log
```

(`--bare` mirrors the workflow's invocation; the flag set matches Claude/workflow.rb's
`ask` task plus `--include-partial-messages`. Prompt MUST come via stdin — a positional
prompt argument combined with `--print`/`-p` is rejected: "Input must be provided either
through stdin or as a prompt argument when using --print" — actually this error fires when
the computed prompt is empty, e.g. when piping wrongly; passing the prompt on stdin as
above works and is what the workflow's `in: prompt` does. stderr.log holds only
`[claude-code:unrecognized_model] {"model":"glm-5.2","query_source":"sdk"}` — benign,
same as prior probes.)

Verification hashes: MANIFEST.sha256 (events.jsonl
d7de182265883425fcc49f542575c9d9142264404e23a326509c94afa03e4eb0).
