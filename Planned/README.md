# Planned multi-agent inference workflow

A staged inference pipeline for Scout-AI: a user request is restated by a
liaison agent, optionally enriched with a research report, turned into a plan
by a Planner agent, executed by a worker agent with full tooling, and finally
summarized back into a report for the user.

The workflow is built on `AgentWorkflow` (from `scout-ai`) using `chat_task`
declarations. Every task takes a single `chat` input, a text in Scout-AI
chat-file format that carries the original user request plus any chat options.
Each `chat_task` loads one named agent, appends a prompt, lets the agent run
(with or without tools), and returns the messages the agent produced. Scout
wraps each result in a projected chat segment that starts with a `meta` marker
recording the producing job, so downstream tasks can append the segment with
`chat.follow step(:name).load` and keep provenance of where each contribution
came from.

The tasks form a linear dependency chain, and `ask` is the entry point that
triggers the whole pipeline:

    request -> search -> plan -> work -> ask

Stage by stage:

- `request` runs the `User` agent to restate the raw user request as self
  contained instructions, so later stages no longer depend on conversational
  context.
- `search` runs the `Searcher` agent to produce a reference report for the
  request. This stage can be switched off with the chat option `use_search`,
  in which case the dependency is redirected to the `request` job so the rest
  of the chain proceeds without a search step.
- `plan` runs the `Planner` agent over the restated request (plus the search
  report when available) to elaborate a plan. It only receives the workflow
  introductions as tooling, not the full tool set, so the plan stays at the
  design level.
- `work` runs a worker agent that executes the plan. By default this is the
  `Manager` agent; it can be changed with the chat options `worker_agent` or
  `Planned_worker_agent` (the latter takes precedence). This is the stage
  that receives the full tooling declared in the chat.
- `ask` runs the `User` agent once more, with tools disabled, to elaborate the
  final report from everything produced upstream.

Tool exposure is controlled per stage: `request` and `work` receive every
`tool`, `kb`, `mcp` and `introduce` message of the chat, `search` and `plan`
receive only the `introduce` messages (the workflows the user explicitly
introduced), and `ask` disables tooling altogether. In addition, the stages
`plan`, `work` and `ask` inject a `clear_tools` message before prompting the
agent, so tool-call traces from earlier segments are dropped from the context
sent to the model.

Example usage:

    scout workflow task Planned ask --chat chat_file

where `chat_file` contains the user request in Scout-AI chat format, and may
include lines such as `option use_search false` to skip the search stage or
`option worker_agent Worker` to pick the executing agent.

# Tasks

## request
Restate the user request as self contained instructions

This task loads the `User` agent and passes it the input chat, then asks it to
restate the request as instructions that make sense on their own, without
relying on prior conversation or implicit context.

The result is the projected chat segment of the job, whose last message is the
restated request. It is the first stage of the pipeline and the anchor that
all later stages follow.

## search
Gather reference material for the request

This task loads the `Searcher` agent over the chat extended with the `request`
segment and asks it to prepare a report that can be used as reference to
fulfil the user request. The agent receives only the workflow introductions
present in the chat as tooling, so it can read the tools but not exercise
them.

The dependency is declared through a block that inspects the chat options of
the job. When the `use_search` option is set to `false`, the dependency is
redirected to the `request` task instead, so the search stage is skipped and
the pipeline continues from the restated request directly. Because the
redirected job keeps the `search` task name, later stages that consult
`step(:search)` still resolve the dependency without special handling.

## plan
Elaborate a plan to fulfil the request

This task follows the last message of the `request` segment and, when the
search stage ran, the last message of the `search` segment. It then injects a
`clear_tools` message and loads the `Planner` agent, asking it to elaborate a
plan for the user request.

The agent receives only the workflow introductions as tooling, keeping the
planning conversation free of tool-call noise and focused on deciding what to
do rather than doing it.

## work
Execute the plan

This task follows the last messages of the `request` and `plan` segments,
injects a `clear_tools` message, and loads the agent in charge of executing
the plan with the full tooling of the chat, asking it to proceed with the
plan.

The executing agent is selected from the chat options: `Planned_worker_agent`
if present, then `worker_agent`, and the `Manager` agent by default. This is
the stage where files are actually read, written, and commands run, so it is
also the stage that produces the artifacts referenced by the final report.

## ask
Elaborate the final report for the user

This task follows the full segments of `request`, `plan` and `work`, injects a
`clear_tools` message, and loads the `User` agent with tools disabled, asking
it to elaborate a final report for the user.

It is the entry point of the workflow: running the `ask` task runs the whole
chain, since each stage is a dependency of the next. The result is the chat
segment containing the final report.
