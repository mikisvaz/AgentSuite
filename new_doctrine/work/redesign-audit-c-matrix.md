# Agent effective-capability matrix — 2026-11-01 redesign audit (packet C)

Successor measurement of `research/agent-cortex-capabilities.md` (status
2026-09-05, extended 2026-11-01 by the orchestration packet for Reader /
FitAgent / ChatAnalyst only). This file re-baselines **every** agent with a
`start_chat` in the repository at the Phase 0 audit state, with full
effective tool sets (not only Cortex), each row citing its probe evidence.

Status: 2026-11-01 (Phase 0, read-only audit packet C).
Method: hermetic effective-tools probe, NO model turns — the production
Chat pipeline (`Chat.parse` → `Chat.imports` → `Chat.tools`, the function
`AgentWorkflow` uses to build the tool table), imports resolved through a
scratch `Agent/` mirror because the repo `chats` symlink is broken in this
execution context. Same technique as `tmp/d2_probe.rb` (2026-09-05
verification) and `tmp/redesign_audit_matrix_probe.rb` (2026-11-01
orchestration packet).

Evidence (per-row citations all point here):
- Script: `tmp/redesign-probes/redesign_c_probe.rb`
- Raw output (human + JSON sections, one section per agent):
  `tmp/redesign-probes/redesign_c_probe.out` (stderr
  `tmp/redesign-probes/redesign_c_probe.err`, empty, exit 0)
- Cross-validation: Reader/FitAgent/ChatAnalyst numbers reproduce
  `tmp/redesign_audit_matrix_probe.out` exactly (Reader 40 raw entries /
  10 distinct cortex, FitAgent 3, ChatAnalyst 44 raw / 5 cortex).

Environment: gem scout-ai 2.1.0, run from the repo root
`/bulk/mvazque2/git/AgentSuite`; workflows preloaded hermetically from
`<wf>/workflow.rb` files (Workspace, Cortex, ComputerUse, Reader,
ChatAnalyst, Semantics, Research, ScoutCoder, FitAgent).

## 0. Agent census

17 directories carry a `start_chat` (probed): Basic, ChatAnalyst, Clean,
ComputerUse, Consultant, Cortex, Critic, FitAgent, Manager, Planner,
Reader, Research, ScoutCoder, Searcher, User, Visualizer, Worker.

Beyond the expected list (Manager, Worker, Research, Searcher, Critic,
Planner, User, ScoutCoder, Consultant, Reader, FitAgent + Cortex,
ChatAnalyst, ComputerUse, Visualizer): **Basic** and **Clean** are minimal
scaffold agents (5 and 3 lines; Basic imports doctrine, Clean imports
nothing). **WorkflowCoder is absent** — no directory at the repo root
(its 2026-09-05 matrix row cites a start_chat that no longer exists here).
Workflow-only directories without a start_chat (not agents, not probed):
Branched, Decider, Direct, Planned, Claude, Semantics, Workspace.

## 1. Effective capability table (probe truth)

Cortex tiers against the **current 10-task Cortex checkout** (the
2026-09-05 R/A/E/P/C scheme is stale: `cortex_activity` was removed from
the doctrine footer, and all property/list/entity tasks moved to
Semantics):

- **R3** = cortex_list, cortex_search, cortex_read (doctrine footer, free
  with `import: Agent/doctrine`)
- **A5** = R3 + cortex_write, cortex_edit
- **D5** = R3 + cortex_continue, cortex_brief (delegation tier, Manager)
- **C10** = full Cortex task set (10 tasks: the above plus
  cortex_rename, cortex_move, cortex_remove)

| Agent | imports | own tool/introduce lines (condensed) | other directives | Cortex (distinct) | non-Cortex effective | total | tier |
|---|---|---|---|---|---|---|---|
| Basic | Agent/doctrine | none | — | 3 (list, read, search) | 0 | 3 | R3 |
| ChatAnalyst | Agent/doctrine | `tool: Workspace`; `tool: Cortex cortex_write`, `cortex_edit`; `tool: ChatAnalyst` (+introduce Workspace, ChatAnalyst) | — | 5 | 39: full Workspace + full ChatAnalyst (chat_report, live_chats, message_index, post_inbox_advice, inbox_state, …) | 44 | A5 |
| Clean | none | none | — | 0 | 0 | 0 | none |
| ComputerUse | Agent/doctrine | `introduce: ComputerUse` (no `tool:` line!) | `exec_task: ComputerUse pwd` | 3 | **0** | 3 | R3 |
| Consultant | Agent/doctrine | none | `endpoint: consultant` | 3 | 0 | 3 | R3 |
| Cortex | Agent/doctrine, Agent/society | `tool: ComputerUse` (+introduce), `tool: Cortex` (bare) | — | 10 (full) | 29: full ComputerUse (bash, read/write/copy/delete, doc/web tasks docx2md/html2md/html_query/searxng, kb_register, playwright, current_time, tsv_*) | 39 | C10 |
| Critic | Agent/doctrine | `tool: Workspace` (+introduce) | — | 3 | 23: full Workspace (incl. write, delete, bash, patch, precise_edit) | 26 | R3 (+Workspace) |
| FitAgent | Agent/doctrine | none | — | 3 | 0 | 3 | R3 |
| Manager | Agent/doctrine, Agent/society | `tool: Cortex cortex_continue`, `tool: Cortex cortex_brief` | `socialize: true` | 5 (continue, brief + R3) | 0 | 5 | D5 |
| Planner | Agent/doctrine, Agent/society | `tool: ScoutCoder help_*` ×5 (+introduce ScoutCoder) | — | 3 | 5: ScoutCoder help_list_repos, help_list_repo_documents, help_get_repo_document, help_overview, help_workflow | 8 | R3 (+docs) |
| Reader | Agent/doctrine | `tool: Reader`, `tool: Workspace`, `tool: Cortex` (bare) (+introduce ×3) | — | 10 (full) | 27: full Workspace + Reader searxng, docx2md, html2md, html_query | 37 | **C10** |
| Research | Agent/doctrine, Agent/society | `tool: Research` (0 tasks — no-op), `tool: Semantics`, `tool: Workspace`, `tool: Cortex cortex_list/read/write/edit` (+introduce Semantics, Workspace) | `exec_task: Workspace pwd`, `socialize: true` | 5 | 26: full Workspace + Semantics entity_property, entity_list_property, list_entities | 31 | A5 (+Semantics) |
| ScoutCoder | Agent/doctrine, Agent/scout | `tool: Cortex cortex_write/edit`, `tool: Workspace`, `tool: ScoutCoder` (+introduce Workspace, ScoutCoder) | `exec_task: Workspace pwd` | 5 | 40: full ScoutCoder (list_tasks, task_inputs, task_code, run_test, run_probe, run_task, help_*, list_entities, document_task, job_info/status) + full Workspace | 45 | A5 |
| Searcher | Agent/doctrine | `tool: Workspace list_directory/search/read`, `tool: Reader searxng/html2md`, `tool: ScoutCoder help_*` ×5, `tool: Cortex cortex_write/edit` (+introduce Workspace, Reader, ScoutCoder) | — | 5 | 10: list_directory, search, read, searxng, html2md, help_* ×5 | 15 | A5 (narrow) |
| User | Agent/doctrine, Agent/society | none | — | 3 | 0 | 3 | R3 |
| Visualizer | Agent/doctrine | `tool: Cortex cortex_write/edit` | `endpoint: visual`, `attachments: true` | 5 | 0 | 5 | A5 |
| Worker | Agent/doctrine | `tool: Workspace`, `tool: Cortex` (bare) (+introduce Workspace, Cortex) | — | 10 (full) | 23: full Workspace | 33 | **C10** |

No `kb:` or `mcp:` lines exist in any start_chat (grep across all 17:
zero hits). Duplicate cortex keys (cortex_list/read/search appearing both
via the doctrine footer and via bare `tool: Cortex`/own lines) resolve
idempotently for Cortex, Reader, Worker (3 duplicate raw keys each, no
error) — same behavior the 2026-09-05 verification recorded.

## 2. Declared-vs-effective discrepancies and drift vs the 2026-09-05 matrix

Labeled by confidence: **validated** = probe output quotes it;
**unverified** = not checkable at this layer.

1. **Worker holds the full Cortex curator set** (validated). The
   2026-09-05 matrix recorded Worker = E (11 tools, granular per-task
   lines). The current start_chat carries bare `tool: Cortex` → all 10
   tasks including cortex_rename/move/remove, which the old matrix's
   "curator-only" list reserved for the Cortex agent. Reader holds the
   same full set.
2. **Doctrine footer is now 3 tools, not 4** (validated): `introduce:
   Cortex` + cortex_list, cortex_search, cortex_read; `cortex_activity`
   no longer exists anywhere (superproject commit a060da7, per the §7
   extension already in the repo matrix).
3. **Manager drifted from R to D5** (validated): the old matrix recorded
   "none" own Cortex lines; the current start_chat adds cortex_continue +
   cortex_brief — consistent with its delegating role, inconsistent with
   the old row.
4. **Critic's `tool: Workspace` contradicts its own text** (validated
   tension): the role text says "read-oriented Workspace tasks", but the
   whole-workflow tool line exposes write, delete, bash, patch,
   precise_edit too (23 tools). The 2026-09-05 matrix recorded Critic
   with no tool lines at all — the Workspace line was added since.
5. **ComputerUse's start_chat references a tool it does not expose**
   (validated at the Chat.tools layer): it instructs "run the task
   'sandbox_paths'" but has only `introduce: ComputerUse` with no
   `tool: ComputerUse` line → 0 ComputerUse tasks in the effective
   table. Whether `LLM.load_agent` auto-attaches the agent's own
   workflow at runtime is **unverified** here (the Chat.tools layer is
   the documented production tool-table builder; the earlier
   load_agent-based probe could not run in this sandbox because
   `~/.scout` agent paths are absent — see tmp/p4_load_agent_tools.rb
   header).
6. **Research declares `tool: Research` but Research defines 0 tasks**
   (validated no-op): its workflow.rb loads only path_kinds; the line is
   inert at the tool level.
7. **FitAgent's evaluator runs tool-less by design** (validated from
   code): its effective baseline here is R3 via doctrine, but
   `evaluate_agent` runs the FitAgent persona with `agent.workflow = nil`
   (lib/FitAgent/tasks/agent_ask.rb), so at evaluation time it judges
   from chat material only.
8. **Clean has no import and zero effective tools** (validated): it does
   not even receive the doctrine Cortex baseline. Basic does (R3).
9. **WorkflowCoder row in the old matrix is orphaned** (validated): no
   such directory exists at the repo root.

## 3. FitAgent scenario mechanics (for later smoke tests)

From `FitAgent/README.md`, `FitAgent/start_chat`, and
`FitAgent/lib/FitAgent/tasks/{use_case,agent_ask}.rb`:

- **use_case** stages a per-job sandbox (`<job>.files/sandbox/`, or
  `<job>.files/<repo-name>/` when `repo` is given): use_case dir contents
  (`main.chat`, optional `analyze.chat`, data) copied in; `--agents` dir
  copied to `sandbox/Agent/`; endpoint definitions from `etc/AI/<name>`
  copied with the key materialized from `SCOUT_AI_<NAME>_KEY` env when
  present; `etc/path_maps` set to `default: :current`; local
  `var/cache/ask`; `workflows/` symlinked — MiniTools always, plus every
  workflow named in any `introduce:`/`tool:` line of `main.chat` or the
  agents' start_chats, searched under `FitAgent/workflows`, the
  AgentSuite parent dir, `./workflows`, and the configured workflow dir.
  An optional `repo` is staged by rsync copy (excluding `.git`, `tmp`,
  `etc/AI`, `main.chat.files`), symlink (`link`), or `git clone`. Then it
  runs `scout-ai agent ask <main_agent> -c main.chat -e <endpoint>`
  inside the sandbox with `BWRAP_PATH=false`, `SCOUT_NO_ASK_CACHE=
  recursive`, `ASK_PERSIST=false`. Result: the agent's final answer;
  transcript stays in `sandbox/main.chat`; log in `<job>.files/log.txt`;
  sandbox path recorded in job info key `sandbox`.
- **analyze** (depends on use_case, inherits its inputs) loads the
  ChatAnalyst agent, lets it follow the use_case job links, and feeds it
  instructions (explicit input > sandbox `analyze.chat` > built-in
  default criteria), the use_case result file, and the sandbox/main.chat
  paths; returns the analyst's written assessment (.md result;
  conversation saved as `analysis.chat`).
- **Response avenue**: `agent_ask` = one inference by the named agent
  (`return_tool_calls: true`; tool calls returned, not executed);
  `evaluate_agent` grades that response against a rubric file using the
  FitAgent persona with its workflow detached.
- **Minimal smoke-test scenario a Worker would author** (5–10 line
  recipe):
  1. create a use_case directory with `main.chat` (the blind task in
     Scout-AI chat format — plain `user:` content), optional
     `analyze.chat` criteria, plus any data files the task needs;
  2. pick `--agents` (agent-definition dir with `<name>/start_chat`;
     for suite agents use the AgentSuite root), `--main_agent <name>`,
     `--endpoint <name>` resolvable from `etc/AI` (or env key
     `SCOUT_AI_<NAME>_KEY`), and optionally `--repo <target>` with
     `repo_mode copy`;
  3. run `scout workflow task FitAgent use_case --agents … --use_case …
     --endpoint … --main_agent …` (add `analyze` to get the ChatAnalyst
     assessment in the same call);
  4. caveats: every workflow named in the agents' `introduce:`/`tool:`
     lines must be discoverable under the search paths above (new
     agents' tool workflows must live in the AgentSuite tree or
     FitAgent/workflows) or the inner run will not resolve them;
     `agent none` is currently broken (raises
     `No agent found with name none`); `exclude` input is declared but
     not consumed by the rsync call; `endpoint_analyst` does not
     actually forward to the dep (set `endpoint` too).

## 4. Notes for the redesign (first cut, measurement only)

- New agents ScientificLead/Investigator inherit R3 automatically through
  `import: Agent/doctrine`; anything above that is a start_chat tool-line
  decision. The old E/P tiers are unachievable with today's Cortex
  (property tasks live in Semantics), so per-role provisioning should be
  expressed against the current 10-task set.
- Worker as Investigator template would carry bare `tool: Cortex`
  (curator set) today — decide deliberately whether an Investigator
  should hold rename/move/remove.
- Reader's C10 (bare `tool: Cortex`) is broader than its dossier role
  needs (write/edit would suffice).

## 5. Limitations

- Chat.tools is the documented production tool-table builder (capability
  matrix §3, verified at runtime in 2026-09-05); any runtime layer that
  adds tools outside directive processing (e.g. load_agent
  workflow auto-attachment) is outside this probe and remains
  unverified.
- start_chat edits do not invalidate cached agent jobs (known caveat,
  inherited from the original matrix §4); all numbers here are from a
  fresh process over current files.
- The repo matrix `research/agent-cortex-capabilities.md` already carries
  a 2026-11-01 §7 extension (Reader/FitAgent/ChatAnalyst only) written by
  the parallel orchestration packet; this file supersedes it in coverage.
  No Cortex artifact named `research/agent-cortex-capabilities.md` exists
  in the artifacts namespace (verified by `cortex_list`), so there is
  nothing to update there; if one is wanted, it needs a separate
  `cortex_write`.
