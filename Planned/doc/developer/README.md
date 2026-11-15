# Planned developer documentation

Implementation mechanics for the Planned staged-inference workflow. The
workflow introduction and task entries live in `Planned/README.md`; agent
usage (chat options, examples) in [doc/user/README.md](../user/README.md).

## chat_task mechanics and projected segments

The workflow is built on `AgentWorkflow` (from `scout-ai`) using
`chat_task` declarations. Every task takes a single `chat` input, a text in
Scout-AI chat-file format that carries the original user request plus any
chat options. Each `chat_task` loads one named agent, appends a prompt,
lets the agent run (with or without tools), and returns the messages the
agent produced. Scout wraps each result in a projected chat segment that
starts with a `meta` marker recording the producing job, so downstream
tasks can append the segment with `chat.follow step(:name).load` and keep
provenance of where each contribution came from.

## Tool exposure per stage and clear_tools

Tool exposure is controlled per stage in `workflow.rb`: `request` and
`work` receive every `tool`, `kb`, `mcp` and `introduce` message of the
chat (the `agent` helper defaults to `tooling: self.tooling` when no
value is passed, which is what `request` relies on; `work` passes
`tooling: self.tooling` explicitly), `search` and `plan` receive only
the `introduce` messages (`tooling: self.tooling_intro` — the workflows
the user explicitly introduced), and `ask` disables tooling altogether
(`tooling: false`). In addition, the stages `plan` and `ask` inject a
`chat.message :clear_tools, true` before prompting the agent
(`workflow.rb` L46 and L80), so tool-call traces from earlier segments
are dropped from the context sent to the model.

Segment-following differs by stage: `plan` and `work` follow only the
`.last` message of their upstream segments (`work` also follows
`step(:search).load.last` when the search stage ran), while `ask` follows
the full segments of `request`, `plan` and `work`.

## Worker selection

The `work` stage resolves its agent through
`config :worker_agent, default: (options[:Planned_worker_agent] ||
options[:worker_agent] || 'Manager')` — so `Planned_worker_agent` takes
precedence over `worker_agent`, and `Manager` is the default. The stages
name the agents `User`, `Searcher`, `Planner` and `Manager`; those agents
must be resolvable in the environment's society configuration.

## Testing

No test suite ships with Planned and no `test/` tree exists in the
checkout. The behavior statements above were verified against
`Planned/workflow.rb` by reading it; there is no automated verification
today.
