# Agent Cortex capability matrix

This artifact is the single reference for which agent in this suite holds
which Cortex capability, at which tier, and why. It records the implemented
on-disk state after the AgentSuite Cortex rollout steps D1 (doctrine edit)
and D2 (13 start_chat edits); it is derived from the files as they exist on
disk, quoting the real lines. It does not grant authority: role contracts
and the doctrine remain the binding text.

Status: 2026-09-05; mechanism: doctrine-import propagation (the doctrine
footer carries the read-only Cortex tools for every agent that imports
`Agent/doctrine`); verified by hermetic runtime probes (agent-load without
model turns) recorded under `tmp/`.

Source of truth pointers:

- `./doctrine`, trailing footer (5 lines after the system block):
  `introduce: Cortex`, `tool: Cortex cortex_list`,
  `tool: Cortex cortex_search`, `tool: Cortex cortex_read`,
  `tool: Cortex cortex_activity`.
- Per-agent tool lines: the `tool: Cortex ...` lines in each
  `<Agent>/start_chat` (cell 3 below quotes them by line number).
- Probe outputs: `tmp/d1_verify_out.txt` (doctrine propagation after D1),
  `tmp/d2_probe_out.txt` (per-agent effective tool counts after D2),
  `tmp/d2_verify_out.txt` (39 mechanical checks).
- Diffs: `tmp/doctrine-edit.diff`, `tmp/start-chat-edits.diff`.
- Preflight evidence and GO decision:
  `research/agentsuite-cortex-rollout/01-preflight-report.md`.

## 1. Capability table

Effective sets (set notation, cumulative):
R = cortex_list, cortex_search, cortex_read, cortex_activity (4);
A = R + cortex_write, cortex_edit (6);
E = A + cortex_property_list, cortex_property_read, cortex_read_list,
cortex_write_list, cortex_entity_property (11);
P = E + cortex_property_history, cortex_property_validate,
cortex_property_define, cortex_property_update (15);
C = full Cortex task set (21, includes everything below plus the
curator-only tasks).

| Agent | Profile | Cortex tool lines in start_chat | Effective Cortex tools | Role sentence anchor |
|---|---|---|---|---|
| ChatAnalyst | A | L31 `tool: Cortex cortex_write`; L32 `tool: Cortex cortex_edit` | 6 = A | start_chat, end of system block, ends L27 ("global doctrine changes only for cross-project failure modes.") |
| ComputerUse | R | none | 4 = R | two edits: L9-12 strengthened sandbox_paths paragraph (starts "When a path is rejected, a directory seems to disappear...") and L14-16 appended Cortex paragraph (ends "...bypass a rejected path, and do not persist routine shell activity.") |
| Consultant | R | none | 4 = R | start_chat end (no later directives), ends L49 "...investigations, perform upkeep, or continue execution through Cortex." |
| Cortex | C | L88 `tool: Cortex` (bare, full set) | 21 = C | start_chat, end of system block, ends L84 "...the current version immediately before exact edits." |
| Critic | R | none | 4 = R | start_chat, end of system block, ends L277 "...the entire execution." |
| Manager | R | none | 4 = R | start_chat, end of system block, ends L121 "...Route persistent investigations and Cortex upkeep to the Cortex agent." |
| Planner | R | none | 4 = R | start_chat, end of system block, ends L42 "...into a new investigation." |
| ScoutCoder | A | L61 `tool: Cortex cortex_write`; L62 `tool: Cortex cortex_edit` | 6 = A | start_chat, end of system block, ends L54 "...implicit environment mutation." |
| Searcher | A | L40 `tool: Cortex cortex_write`; L41 `tool: Cortex cortex_edit` | 6 = A | start_chat, after the Cortex tool lines, ends L52 "...the symptoms." |
| User | R | none | 4 = R | L28-31 replaced rules line ("- Do not execute implementation, ... do not write, edit, continue, compute, or manage Cortex resources.") |
| Visualizer | A | L118 `tool: Cortex cortex_write`; L119 `tool: Cortex cortex_edit` | 6 = A | start_chat, end of system block, ends L116 "...not scientific validation." |
| Worker | E | L86-L92: cortex_write, cortex_edit, cortex_property_list, cortex_property_read, cortex_read_list, cortex_write_list, cortex_entity_property | 11 = E | start_chat, end of system block, ends L82 "...before checking path identity directly." |
| WorkflowCoder | P | L42-L52: cortex_write, cortex_edit, cortex_property_list, cortex_property_read, cortex_read_list, cortex_write_list, cortex_entity_property, cortex_property_history, cortex_property_validate, cortex_property_define, cortex_property_update | 15 = P | start_chat, end of system block, ends L31 "...process and make cache cleaning explicit." |

Every agent's start_chat line 1 is `import: Agent/doctrine`, which is what
delivers profile R to all of them. Counts were confirmed at runtime for
Critic (4), Worker (11), WorkflowCoder (15), and Cortex (21) in
`tmp/d2_probe_out.txt`; the remaining rows follow from the same mechanism
(the identical doctrine import plus the quoted per-agent lines).

## 2. Profiles

- R (recall, free from the doctrine import): ComputerUse, Consultant,
  Critic, Manager, Planner, User. Read-only recall of the Cortex workspace
  (list, search, read, activity). No writes, no conversations, no
  computation, no management.
- A (R + contribution): ChatAnalyst, ScoutCoder, Searcher, Visualizer. Adds
  `cortex_write` and `cortex_edit`, i.e. persisting and correcting durable
  artifacts. No conversation continuation, no executable evidence, no
  workspace management.
- E (A + evidence execution): Worker. Adds `cortex_property_list`,
  `cortex_property_read`, `cortex_read_list`, `cortex_write_list`,
  `cortex_entity_property`, i.e. discovering and running entity properties
  over named lists and reading the receipts. Cannot define or change
  definitions.
- P (E + property authorship): WorkflowCoder. Adds
  `cortex_property_history`, `cortex_property_validate`,
  `cortex_property_define`, `cortex_property_update`: authoring and
  versioning executable property definitions, with validate-before-activate
  and optimistic expected_version as its role sentence demands.
- C (curator, full set): Cortex, and only the Cortex agent. One bare
  `tool: Cortex` line covers the whole task set.

Curator-only reserved list (exclusive to the Cortex agent, not granted by
any tier above): `cortex_continue`, `cortex_brief`, `cortex_rename`,
`cortex_move`, `cortex_remove`, `cortex_property_remove`. These implement
conversation continuation, reusable agent preparation, and irreversible or
workspace-wide management, so they stay out of every per-agent profile.

## 3. How the mechanism works

The doctrine file ends (outside its system block) with `introduce: Cortex`
plus four granular read-only lines. Every agent start_chat begins with
`import: Agent/doctrine`; scout-ai expands imports into the importing chat
(`Chat.imports`, gem scout-ai 2.0.0, `lib/scout/llm/chat/process/files.rb`)
before directive processing (`Chat.tools`), so the imported tool and
introduce lines take effect exactly like local ones. The per-agent
`tool: Cortex <task>` lines are processed by the same machinery and add on
top. This was the preflight GO question: probe 4 of the preflight report
showed, at runtime and hermetically, that agents with no Cortex tool lines
of their own (Critic, ComputerUse, Worker) still received the doctrine's
Cortex tools; hence the design decision that the doctrine carries the
read-only set. The fallback design considered in the spec (splitting the
doctrine or repeating the four lines per agent) was therefore not needed.

Evidence: `research/agentsuite-cortex-rollout/01-preflight-report.md`
(probes 1-8, GO decision), `tmp/d1_verify_out.txt` (post-D1: Critic,
ComputerUse, Worker each show the 4 read-only tools), `tmp/d2_probe_out.txt`
(post-D2: Critic 4, Worker 11, WorkflowCoder 15, Cortex 21, all as
expected; stderr clean).

Note on bare `tool: Cortex` in the Cortex agent: it is redundant with
nothing (that agent previously had no Cortex line of its own; its tools came
from the doctrine import), and it resolves through the same
agent-name-to-workflow default, so it is additive and idempotent - the probe
shows exactly 21 distinct cortex tools with 4 duplicate task-name keys
resolved by the task-name table, no error.

## 4. Known limitations (caveats)

Verbatim, as recorded during preflight and verification:

- ask delegation defaults to inherit=tools
- cortex_continue attaches full Cortex tooling to contributors
- cached agent jobs are not invalidated by start_chat edits

And explicitly: start_chat edits do not invalidate cached agent jobs; when
testing an agent after editing its start_chat, clean the agent job or vary
the inputs so a fresh load occurs.

## 5. Maintenance

When adding a new agent: first decide its profile (R, A, E, P, or C); then,
if it is above R, add the exact `tool: Cortex <task>` lines to its
start_chat (adjacent to its other tool lines, or at the end of the directive
area if none); add its role sentence at the end of its system block; and
update the table in this file in the same change. R comes for free with the
`import: Agent/doctrine` line the start_chat should carry anyway. Keep the
curator-only list exclusive to the Cortex agent unless the rollout spec is
formally revised.

## 6. Discrepancies

One limitation on diff attribution: the submodule working trees (and the
superproject tree) carry unrelated pre-existing uncommitted changes - for
example Cortex/lib/Cortex/tasks/conversation.rb, the WorkflowCoder lib diff,
and the root .gitignore/.vimproject/Planned/workflow.rb edits plus the stray
`]` file - that are NOT part of this rollout and must not be attributed to it.
Apart from that: none found between the packet summary and the on-disk files. All 13 agents
matched the stated profile assignments, line numbers, and effective counts;
the only content visible on disk beyond the expected 13 start_chats is the
pre-existing unrelated `FitAgent/` job sandbox area, which carries copies of
other projects' agent files and is not part of this suite's agent set.
