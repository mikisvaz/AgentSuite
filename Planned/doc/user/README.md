# Using Planned (user guide)

How to drive the Planned staged-inference pipeline: request → search →
plan → work → ask. The workflow introduction and the five task entries
live in `Planned/README.md`; implementation mechanics in
[doc/developer/README.md](../developer/README.md).

## Example usage

    scout workflow task Planned ask --chat chat_file

where `chat_file` contains the user request in Scout-AI chat format. `ask`
is the entry point: running it runs the whole chain, since each stage is a
dependency of the next.

## Chat options

Options are carried as `option <name> <value>` lines in the chat file:

- `option use_search false` — skip the search stage. The `search`
  dependency is redirected to the `request` job, so the rest of the chain
  proceeds without a search step; because the redirected job keeps the
  `search` task name, later stages that consult `step(:search)` still
  resolve it without special handling.
- `option worker_agent <Agent>` — pick the agent that executes the `work`
  stage.
- `option Planned_worker_agent <Agent>` — same, with **precedence** over
  `worker_agent`; the effective order is `Planned_worker_agent`, then
  `worker_agent`, then the `Manager` default.

## How the work stage gets its context

The `work` stage is fed by the three upstream stages: it follows the last
message of the `request` segment, the last message of the `search` segment
when the search stage ran, and the last message of the `plan` segment. The
worker prompt then asks the agent to follow the plan, citing the plan step
it executes and logging deviations from it. The final `ask` stage follows
the full segments of `request`, `plan` and `work` to elaborate the report.
