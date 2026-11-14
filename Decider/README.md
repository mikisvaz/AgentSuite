Decider: typed decision inference for agents

The `Decider` agent provides typed decision inference to other agents: a
Manager sends an ordinary natural-language prompt containing exactly one
`<scout-decision>` block whose JSON describes the questions to answer;
everything outside the block is the decision state. The Decider parses the
request, runs the configured `Decision::Jev` model, records the decision
in the `<job>.files/decisions.json` sidecar, and returns the structured
result as JSON.

`ask` is invoked through the agent route (it is an `AgentWorkflow`
persona whose `start_chat` system prompt carries the Decider
instructions), not through a direct CLI tool call; agents delegate a chat
whose last message holds the request block.

Request format, worked examples, question types (`noul`/`choice`/`score`)
and the Manager pattern are in [doc/user/README.md](doc/user/README.md);
the decisions sidecar schema and model configuration are in
[doc/developer/README.md](doc/developer/README.md).

# Tasks

## ask

Parse a `<scout-decision>` request from the task chat, run the `Decision::Jev`
model over its questions and state, record the decision, and return the
structured result as JSON.

The request must be exactly one `<scout-decision>` JSON block (with a
non-empty `questions` object) in the chat's last message; the chat outside
the block becomes the state. The model is chosen by `JEV_MODEL`
(default `jev-latest`); each decision is appended to
`<job>.files/decisions.json` (schema v1) and the job result is a chat
whose final assistant message is the decision result as JSON, preceded by
a meta message recording model and token usage. Malformed requests raise
`Decider::RequestError` (a `ScoutException`).
