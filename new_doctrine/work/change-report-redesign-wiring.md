# Phase 4 — context/tool wiring completion (AgentSuite redesign)

- **Date:** 2026-11-01 (Phase 4, single bout)
- **Repo:** `/bulk/mvazque2/git/AgentSuite`, branch `ags-redesign`
- **Predecessors:** `change-report-redesign-roles.md` (Phase 3),
  `redesign-audit-c-matrix.md` (Phase 0), `redesign-role-contracts.md`
  (Phase 1, frozen contracts §2.8/§8)
- **Successor artifact:** `new_doctrine/work/redesign-matrix-final.md`
  (final-state matrix; supersedes the Phase 0 matrix)

## 1. Files changed

| File | Change | Why |
|---|---|---|
| `Critic/start_chat` | replaced the two-line block `introduce: Workspace` + `tool: Workspace` with `introduce: Workspace` plus **seven explicit task lines**: `tool: Workspace read`, `list_directory`, `file_stats`, `search`, `sandbox_paths`, `pwd`, `bash` | MC4: contracts §2.8 D8 — read-only verification set + bash for probes; full Workspace (26 effective, incl. write/delete/patch/python/ruby/tsv) exceeded the role's authority |
| `Searcher/start_chat` | added one clarifying line to the Output-format section after the brief template: `"Relevant skills" is informational only: skills the searcher knows of from its briefs; "none identified" is a valid entry, and no tool backs the field.` | MC6: keep the field informational, no tool behind it, do not restore match_skills |

Two `precise_edit` calls, one per file, each count-checked (matches: 1).
One corrective follow-up edit in Searcher (a duplicated `- Recommendation`
line introduced by the insert was collapsed back; final file verified by
re-read, lines 34–47).

## 2. Files deliberately NOT changed

- `ScientificLead/start_chat` — no `endpoint:` line added (MC5 decision,
  §3 below). Count verified unchanged at 3 effective.
- `Research/` (agent dir), `society`, `Manager/start_chat`, `scout`,
  READMEs — rename to EvidenceCurator **stays deferred** (contracts §5);
  this phase produced the inventory only (§4).
- All other 15 start_chats — probe-verified byte-identical to Phase 3
  state; only Critic's effective count changed (G13).
- `new_doctrine/work/redesign-audit-c-matrix.md` and
  `research/agent-cortex-capabilities.md` — left in place as historical
  records; superseded by the new final matrix, which says so in its
  header.

## 3. Manager decisions MC4–MC6, with evidence

### MC4 — Critic tool-line narrowing (applied)

- **Decision:** replace bare `tool: Workspace` with seven explicit lines
  (read, list_directory, file_stats, search, sandbox_paths, pwd + bash).
- **Evidence:**
  - Pre-write spelling probe enumerated the Workspace workflow's 23 tasks
    and confirmed all 7 target spellings exist verbatim, and that none of
    the denied tasks is misspelled into existence:
    `tmp/redesign-probes/redesign_phase4_workspace_task_spellings.out`
    (`MC4 targets present: true`, `missing: []`,
    `denied tasks missing from workflow (expect []): []`).
  - Post-write full re-probe: Critic effective = **10** (cortex 3 +
    non-cortex 7); non-cortex set is exactly the seven named tasks
    (JSON in `redesign_phase4_final_probe.out`); no write/edit/delete/
    copy/patch/precise_edit/python/ruby/r/tsv task present (G4–G7); no
    bare `tool: Workspace` line remains (G8).
- **Status: validated** (hermetic probe, no model turns).

### MC5 — ScientificLead endpoint (decision: add NO endpoint; deferral recorded)

- **Decision:** ScientificLead gets **no `endpoint:` line** this phase.
  The decision is recorded here with evidence; revisit when a judgment
  endpoint is actually provisioned.
- **Evidence** (`tmp/redesign-probes/redesign_phase4_endpoint_semantics.{rb,out}`):
  1. An `endpoint: X` line in a start_chat parses to a chat message
     `{role: "endpoint", content: X}` and surfaces as the chat option
     `endpoint=X` (probe output: `chat_options: {"endpoint"=>"consultant"}`).
  2. `LLM.ask` (scout-ai 2.1.0 `lib/scout/llm/ask.rb` lines 31–44) resolves
     the endpoint name against `Scout.etc.AI[<name>]`; a missing
     definition **raises** `Endpoint not found` — probe reproduced the
     exact branch: `llm_ask_branch: {"endpoint"=>"consultant",
     "outcome"=>"raise \"Endpoint not found consultant\""}`.
  3. The resolution directory `Scout.etc.AI` =
     `/home/mvazque2/.scout/etc/AI` is **empty today**
     (`etc_AI_entries: []`); `consultant` and `visual` definitions exist
     **only** inside 52 FitAgent job-sandbox copies
     (`FitAgent/etc/AI/{glm53,qwen}` are the only repo-tracked endpoint
     files, and neither is named consultant/visual).
  4. Consultant's `endpoint: consultant` is therefore **special-cased by
     an environment that is not currently provisioned**: an agent whose
     chat carries it would raise `Endpoint not found consultant` on any
     live ask today. `Scout::Config.get('endpoint', <agent>)` is nil for
     Consultant, Visualizer, and ScientificLead (agent.rb line 193 is a
     separate, unused mechanism here).
  5. Endpoints add **no tools** — they are an LLM-config selector, so the
     count invariant would hold either way (verified indirectly: the only
     two endpoint carriers, Consultant and Visualizer, hold 3 and 5 tools
     from their tool lines alone).
- **Verdict per the MC5 rule:** endpoint semantics are now clear, but
  Consultant's endpoint is *not* a working judgment-grade endpoint to
  inherit — it resolves to a definition that does not exist in this
  environment. Adding it to ScientificLead would create a start_chat that
  fails on every live ask. No endpoint added; deferral recorded.
- **Status: validated** (hermetic probe + source read of
  `lib/scout/llm/ask.rb` 31–44, `agent.rb` 193, and
  `chat/process/options.rb` 29).

### MC6 — Searcher "Relevant skills" field (applied as prose)

- **Decision:** keep the field informational; no tool behind it;
  "none identified" valid; do not restore match_skills.
- **Evidence:** the added line is in `Searcher/start_chat` (Output-format
  section, immediately after the `# Search brief` template); Searcher's
  effective count is unchanged at 15 (probe G11), proving the change is
  prose-only and adds no tooling.
- **Status: validated**.

## 4. Research → EvidenceCurator rename inventory (inventory only; nothing renamed)

Method: `git ls-files` (147 tracked files) grepped for `\bResearch\b`,
each hit classified by file role.
Script + raw output:
`tmp/redesign-probes/redesign_phase4_rename_inventory.{rb,out}`.

| Class | Files | Refs | Members |
|---|---|---|---|
| agent-definition | 1 | 2 | `Research/start_chat` (self-identification "You are Research"; working-directory mention) |
| orchestration | 2 | 3 | `society` (roster entry `## Research` + routing line 25), `Manager/start_chat` (routing line 46) |
| documentation | 4 | 20 | `Research/README.md` (13), `Reader/README.md` (3), `Workspace/README.md` (2), `scout` (2 — routing prose lines 333, 337) |
| historical-record | 2 | 3 | `research/agent-cortex-capabilities.md` (1), `.vimproject` (2, editor file, no runtime effect) |
| workflow-collision | 19 | ~250 | the **Research workflow** directory (`Research/` code, tests, research notes: path_kinds, records, workflow.rb, 8 test files) plus `Reader/lib/Reader/tasks/web.rb` (User-Agent string `Scout-Research/1.0`, cosmetic) |

- **Risk verdict: LOW–MEDIUM.** The agent rename itself touches 3 files
  (1 definition, 2 orchestration) plus 4 documentation files and 2
  historical records — small and greppable. The dominant risk is **name
  collision with the Research *workflow*** (19 tracked files inside
  `Research/`, and the agent currently shares the workflow's directory
  name). Any rename must decide whether the workflow directory/name is
  also touched; if not, the agent-name references in READMEs and routing
  prose must be disambiguated word-by-word (e.g. "Research agent" vs
  "Research workflow"), which is manual, not mechanical. No `.gitmodules`/
  subagent-name reference exists in orchestration code beyond `society`
  and the two routing texts.
- Nothing was renamed this phase (contracts §5: rename decision deferred).

## 5. Verified configuration (final state)

Full 19-agent re-probe through the production pipeline, hermetic (no
model turns): `tmp/redesign-probes/redesign_phase4_final_probe.{rb,out}`.
Checks G1–G13 all true:

- all 19 imports resolve with zero leftover `import` messages (G1);
- §3 doctrine memberships intact (G2); 7 `Agent/society` importers (G3);
- Critic exactly 10 effective, 7 named non-cortex tasks, no write-class
  tasks, no bare `tool: Workspace` (G4–G8);
- ScientificLead 3 effective, no endpoint (G9–G10); Searcher 15 effective
  (G11); all other agents match the expected final state and only Critic
  changed this phase (G12–G13).

Final counts (cortex / non-cortex / total): Basic 3/0/3, ChatAnalyst
5/39/44, Clean 0/0/0, ComputerUse 3/0/3, Consultant 3/0/3, Cortex 10/29/42,
**Critic 3/7/10**, FitAgent 3/0/3, Manager 5/0/5, Planner 3/5/8, Reader
10/27/40, Research 10/26/36, ScoutCoder 5/40/45, Searcher 5/10/15, User
3/0/3, Visualizer 5/0/5, Worker 10/23/36, **ScientificLead 3/0/3**,
**Investigator 5/23/28**.

## 6. Compatibility

- Critic's surface shrank (26 → 10): anything that relied on Critic
  holding write/edit/delete/patch/python/ruby/tsv no longer holds. The
  contracts anticipated this (§2.8 "target total ≈10 effective vs 26
  today"); execution-style checks now route through Manager delegation,
  exactly as the contract's "Delegates to" clause states.
- No other agent's effective tooling changed (probe-verified, G13).
- Start_chat format unchanged elsewhere; the Searcher edit is inside the
  agent's own prose, no consumer of the brief format is affected ("none
  identified" was already valid usage).

## 7. Next work

- **Phase 5 route document**: the operating route over the finished
  roster (how a user request flows User → Searcher/Planner → Manager →
  Investigator/Worker → Critic → Consultant/ScientificLead → Research
  record), with the final matrix as its capability appendix. Owner:
  packet manager (this worker executes a step, not the route design).
- **Research rename execution** (deferred, §5): use the inventory above;
  decide workflow-directory co-rename first, then mechanical edit of the
  3 orchestration/definition files, then documentation disambiguation.
- **Endpoint provisioning** (MC5 follow-up): if a judgment endpoint is
  provisioned under `Scout.etc.AI` (and Consultant's `consultant`
  definition restored outside FitAgent job sandboxes), revisit
  ScientificLead's endpoint; the probe in
  `tmp/redesign-probes/redesign_phase4_endpoint_semantics.rb` is the
  ready-made verification for that day.

## 8. Drift check

Bout-start drift snapshot:
`tmp/redesign-probes/redesign_phase4_drift_start.txt` — branch
`ags-redesign`, working tree already carried the Phase 3 modifications
(17 start_chats, `doctrine`, `society`, FitAgent README) and untracked
`new_doctrine/`; nothing unexpected appeared before this phase's edits.
This phase added the modifications listed in §1 plus the untracked
`new_doctrine/work/redesign-matrix-final.md` and this report; probe
scripts and outputs live under `tmp/redesign-probes/` (disposable probe
area, per doctrine §4).

Verification labels: MC4 and MC6 **validated** by hermetic probe; MC5
**validated** as a negative result (the would-be endpoint does not
resolve in this environment); rename inventory **validated** by script
over `git ls-files`; nothing independently reviewed yet — that is the
Critic gate's job, and Critic itself just became read-only by design.
