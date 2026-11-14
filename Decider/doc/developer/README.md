# Decider developer documentation

Implementation mechanics of the Decider typed-decision workflow: request
parsing, state compaction, the decisions sidecar and model configuration.
The workflow introduction and the `ask` entry live in `Decider/README.md`;
user-facing request patterns are in [doc/user/README.md](../user/README.md).

All line references are to `Decider/workflow.rb` as of this writing.

## Request parsing (`parse_request`, L47-111)

- `DECISION_TAG = "scout-decision"` (L19).
- The decision block is taken from the chat's LAST message
  (`chat.pop[:content]`), matched with
  `/^<scout-decision>$\s*(.*?)\s*^<\/scout-decision>$/m` (L50). Zero or
  more than one match raises `RequestError`.
- The block must parse as JSON and be an object with a non-empty
  `questions` object (L77-82).
- An empty remaining chat (no state outside the block) raises
  `RequestError` (L85-88).

## State compaction (L90-102)

Before the state is printed, the chat is passed through
`Chat.epoch_tool_compactation` with the epoch size hard-pinned to 1:
`threshold: 0` (compact from the very first tool call), `full: 0` (no
free full-fidelity window), `base_compacted: 10` /
`configured_max_compacted: 10` (compact band capped at 19),
`compacted_growth_ratio: 0.0`, `initial_size: 1`, `epochs_per_increase:
1`, `size_increase: 0`, `repeat_increase: 0`, `configured_max_size: 1`.
Operationally: **the decision model sees only the newest tool call** in
full, inside a capped compact band — decide accordingly when a decision
depends on older history, and put the relevant state in prose outside the
block.

## Model configuration (`ask`, L21-44)

- `Decision::Jev.new(model: ENV.fetch("JEV_MODEL", "jev-latest"),
  questions: questions)` (L26-31) — the model name is environment-driven
  with `jev-latest` as default; question types `noul`, `choice` and
  `score` are the native `Decision` specification types.
- `result = decision.eval(state)` (L33); `usage` and `model` are taken
  from `result.value['usage']` / `['model']`.
- The job result is a chat: one `{role: :meta, content: {model, pt, ct,
  tt}}` message (pt/ct from input/output tokens, tt = pt+ct) followed by
  `{role: :assistant, content: result.value.to_json}` (L41-44).

## The decisions sidecar (`record_decision`, L113-152)

Every successful decision is appended to `<job>.files/decisions.json`:

```json
{
  "schema_version": 1,
  "decisions": [
    {
      "timestamp": "2025-01-01T00:00:00.000000Z",
      "questions": {},
      "state": "...",
      "result": {}
    }
  ]
}
```

- The file is created on first use with `schema_version: 1`.
- An existing file that is invalid JSON or does not match the schema
  raises `RequestError` (never silently rewritten).
- `timestamp` is UTC ISO-8601 with microseconds (`Time.now.utc.iso8601(6)`).
- This is an audit/reference artifact; the persisted Decider conversation
  and workflow provenance remain the authoritative record of the
  execution.

## Error class

`Decider::RequestError < ScoutException` (L17-18) is the single exception
type for every protocol error listed in the user guide; callers can
rescue `ScoutException` uniformly.
