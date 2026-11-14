Claude: running the Claude CLI as a Scout chat agent

A bridge workflow that runs the external `claude` CLI in `--bare`
streaming mode (`--output-format stream-json --verbose
--include-partial-messages --print --dangerously-skip-permissions`) with
the task chat printed to its stdin, and assembles from the event stream a
Scout chat with per-turn token attribution. Run artifacts (`events.jsonl`,
`debug.log`, `stderr.log`, `agent.chat`) are written under the job's
files directory. Requires the `claude` CLI on PATH; `CLAUDE_MAX_TURNS`
caps the run (default 2000).

The event model, turn model, the two token-attribution layouts
(per-turn via message_delta envelopes vs aggregate result-event fallback;
never mixed), cache-inclusive prompt accounting and the helper contracts
are documented in [doc/developer/Claude.md](doc/developer/Claude.md).

# Tasks

## ask

Run the task chat through the external `claude` CLI and return the
assembled Scout chat. The chat is printed to the CLI's stdin as the
prompt; every streamed event is logged to `<job>.files/events.jsonl`
while the pass assembles assistant text, thinking, tool calls and tool
results into messages, and a final attribution pass emits the per-turn
meta records (or the aggregate fallback) before the chat is written to
`<job>.files/agent.chat`. Usage and cost from the run's result event are
merged into the job info (`usage`, `total_cost_usd`, `model`,
`session_id`).
