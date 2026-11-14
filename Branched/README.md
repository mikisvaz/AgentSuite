Branched: parallel fan-out pipeline

A parallel fan-out pipeline on top of the staged `Planned` workflow: a
splitter agent divides the job into named subject-parallel sub-tasks, the
workers run in parallel via `iterate_dictionary cpus: 8` (one worker chat
per sub-task, following the same search+plan context), a `Critic` agent
reviews the per-sub-task reports, and the `ask` stage has a `User` agent
elaborate the final report. `plan` is aliased from `Planned#plan`, so
Branched depends on the deployed `Agent/Planned` workflow being
resolvable.

The worker agent is selectable via the chat options
`Branched_worker_agent` / `worker_agent` (default `Worker`).

# Tasks

## plan

Alias of `Planned#plan` (`task_alias :plan, Planned, :plan`): the staged
planning step of the `Planned` workflow, re-registered here so
Branched's `work` stage can depend on it. Hand-written entry — the alias
declaration carries no `desc`, so no in-code description exists to quote
(flagged per the minimal-entry policy).
## work

Split the job into parallel subject branches and run them concurrently.
The splitter agent (`agent nil`, tools cleared) is asked to divide the
job into sub-tasks that implement the same work on different subjects
and return them as a JSON object of names and instructions;
`iterate_dictionary cpus: 8` then runs one worker per name, each on a
fresh chat that follows the same search+plan context plus its own
instructions (worker agent from `Branched_worker_agent` /
`worker_agent`, default `Worker`). The per-branch reports are collected
and handed to a `Critic` agent for review; the job result is the Critic
agent. Hand-written entry — `work` declares no `desc` (flagged per the
minimal-entry policy).

## ask

Elaborate the final report. Follows the `request` and `plan` segments,
clears tools, and hands the `work` answer (the per-branch reports and
their Critic review) to a `User` agent with tools disabled, asking it to
elaborate a final report for the user. Hand-written entry — `ask`
declares no `desc` (flagged per the minimal-entry policy).
