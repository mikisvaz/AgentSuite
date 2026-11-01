# Agent effective-capability matrix — Phase 4 final state (AgentSuite redesign)

- **Date:** 2026-11-01 (Phase 4 final re-probe, after MC4–MC6 wiring)
- **Repo:** `/bulk/mvazque2/git/AgentSuite`, branch `ags-redesign`
- **Status:** **Phase 4 final state. Supersedes** the Phase 0 matrix
  `new_doctrine/work/redesign-audit-c-matrix.md` (2026-11-01 audit C) and
  the historical 2026-09-05 matrix `research/agent-cortex-capabilities.md`
  (§7 extension included).
- **Method:** hermetic runtime probe, no model turns — all 19 start_chats
  parsed through the production `Chat` pipeline (imports resolved by
  `Chat.imports`, effective tools by `Chat.tools`) with the suite's
  workflows preloaded, doctrine/society/scout/doctrines copied into a
  scratch `Agent/` tree. Probe script and raw output:
  - `tmp/redesign-probes/redesign_phase4_final_probe.rb`
  - `tmp/redesign-probes/redesign_phase4_final_probe.out` (checks G1–G13,
    all true; per-agent JSON summary at the end)
- **Supporting probes this phase:**
  - Workspace task spellings (MC4 precondition):
    `tmp/redesign-probes/redesign_phase4_workspace_task_spellings.{rb,out}`
  - endpoint semantics (MC5 evidence):
    `tmp/redesign-probes/redesign_phase4_endpoint_semantics.{rb,out}`
  - rename inventory (MC5/§5 precondition):
    `tmp/redesign-probes/redesign_phase4_rename_inventory.{rb,out}`

Tier vocabulary (contracts §3): **R3** = doctrine footer Cortex read set
(list/search/read, 3 tasks); **A5** = R3 + `cortex_write` + `cortex_edit`;
**D5** = R3 + `cortex_continue` + `cortex_brief`; **C10** = all ten Cortex
tasks. "Effective" = distinct tools visible to the loaded agent after
import resolution and duplicate-key collapse.

## 1. Final matrix (all 19 agents)

| Agent | imports | own tool lines (condensed) | other directives | Cortex (distinct) | non-Cortex effective | total | Δ vs Phase 0 | tier |
|---|---|---|---|---|---|---|---|---|
| Basic | doctrine | none | — | 3 | 0 | 3 | 0 | R3 |
| ChatAnalyst | doctrine | `tool: Workspace`; `tool: Cortex cortex_write/edit`; `tool: ChatAnalyst` (+introduce ×2) | — | 5 | 39 | 44 | 0 | A5 |
| Clean | none | none | — | 0 | 0 | 0 | 0 | none |
| ComputerUse | doctrine | `introduce: ComputerUse` | `exec_task: ComputerUse pwd` | 3 | 0 | 3 | 0 | R3 |
| Consultant | doctrine, doctrines/catalogue | none | `endpoint: consultant` | 3 | 0 | 3 | 0 | R3 |
| Cortex | doctrine, society | `tool: ComputerUse` (+introduce); `tool: Cortex` (bare) | — | 10 | 29 | 42 | +3 | C10 |
| **Critic** | doctrine, doctrines/investigation+collaboration+discipline | `tool: Workspace read/list_directory/file_stats/search/sandbox_paths/pwd/bash` (+introduce Workspace) | — | 3 | **7: read, list_directory, file_stats, search, sandbox_paths, pwd, bash** | **10** | **−16 (26→10)** | R3 (+read-only Workspace) |
| FitAgent | doctrine | none | — | 3 | 0 | 3 | 0 | R3 |
| Manager | doctrine, society, doctrines/collaboration+handoff | `tool: Cortex cortex_continue`, `cortex_brief` | `socialize: true` | 5 | 0 | 5 | 0 | D5 |
| Planner | doctrine, society, doctrines/collaboration+handoff | `tool: ScoutCoder help_*` ×5 (+introduce) | — | 3 | 5 | 8 | 0 | R3 (+docs) |
| Reader | doctrine, doctrines/investigation+catalogue | `tool: Reader`, `tool: Workspace`, `tool: Cortex` (bare) (+introduce ×3) | — | 10 | 27 | 40 | +3 | C10 (deferred C-1) |
| Research | doctrine, society, doctrines/investigation+discipline+handoff+catalogue | `tool: Semantics`, `tool: Workspace`, `tool: Cortex cortex_list/search/read/write/edit/continue/brief/rename/move/remove` (nine explicit lines) (+introduce Semantics, Workspace) | `exec_task: Workspace pwd`, `socialize: true` | 10 | 26 | 36 | 0 (36 in both probes; the Phase 0 matrix recorded 31 under its older counting — see §3.1) | C10 (name retained pending §5 rename) |
| ScoutCoder | doctrine, scout | `tool: Cortex cortex_write/edit`, `tool: Workspace`, `tool: ScoutCoder` (+introduce ×2) | `exec_task: Workspace pwd` | 5 | 40 | 45 | 0 | A5 |
| **Searcher** | doctrine, doctrines/investigation | `tool: Workspace list_directory/search/read`, `tool: Reader searxng/html2md`, `tool: ScoutCoder help_*` ×5, `tool: Cortex cortex_write/edit` (+introduce ×3) | — | 5 | 10 | 15 | 0 | A5-narrow |
| User | doctrine, society, doctrines/collaboration+handoff | none | — | 3 | 0 | 3 | 0 | R3 |
| Visualizer | doctrine | `tool: Cortex cortex_write/edit` | `endpoint: visual`, `attachments: true` | 5 | 0 | 5 | 0 | A5 |
| Worker | doctrine, doctrines/collaboration+handoff | `tool: Workspace`, `tool: Cortex` (bare) (+introduce ×2) | — | 10 | 23 | 36 | +3 | C10 |
| **ScientificLead** (new) | doctrine, society, doctrines/collaboration+investigation+discipline+handoff | none | — | 3 | 0 | 3 | new | R3 (tool-less, Consultant's shape; no endpoint — MC5) |
| **Investigator** (new) | doctrine, society, doctrines/collaboration+investigation+handoff | `tool: Workspace`, `tool: Cortex cortex_list/search/read/write/edit` (explicit 5) | — | 5 | 23 | 28 | new | A5 (explicit list; no continue/brief/rename/move/remove) |

Totals: 19 agents; 18 import `Agent/doctrine` (all but Clean), 7 import
`Agent/society` (Cortex, Manager, Planner, User, Research, ScientificLead,
Investigator — probe check G3), 1 imports `Agent/scout` (ScoutCoder).

## 2. Probe checks (all true, `redesign_phase4_final_probe.out`)

- **G1** imports resolve for all 19, zero leftover `import` messages
- **G2** §3 doctrine memberships intact (collaboration ×7, investigation
  ×6, discipline ×3, handoff ×7, catalogue ×3)
- **G4–G8** Critic: exactly 10 effective; cortex 3 + non-cortex 7; the
  non-cortex set is exactly `bash, file_stats, list_directory, pwd, read,
  sandbox_paths, search`; no write-class task present; no bare
  `tool: Workspace` line remains
- **G9–G10** ScientificLead: 3 effective, no endpoint line added (MC5
  outcome)
- **G11** Searcher: 15 effective, unchanged (MC6 is prose only)
- **G12–G13** every other agent matches the expected final state; Critic
  is the only agent whose count changed this phase

## 3. Notes

1. **Cortex/Worker/Reader totals** are probe-counted distinct tools; the
   Phase 0 matrix recorded effective totals of 39/33/37 for the same
   wiring (its §2 explains the arithmetic: full Workspace 23 + ComputerUse
   29 for Cortex counted differently). The +3 deltas on those rows are
   probe-count differences, not wiring changes — no `tool:` line changed
   for them since Phase 3 (G13).
2. **Research row** keeps the agent name; the rename decision is deferred
   with the Phase 4 inventory as its precondition (§5 of the contracts).
3. **Critic's bash** is deliberate (contracts §2.8): probes, cold-process
   checks, hermetic scripts. All other Workspace tasks it holds are
   read-only.
4. **Endpoints** (Consultant `consultant`, Visualizer `visual`) are
   chat-option directives selecting an LLM config under
   `Scout.etc.AI/<name>`; they add no tools and are orthogonal to the
   tier column.4. **Endpoints** (Consultant `consultant`, Visualizer `visual`) are
   chat-option directives selecting an LLM config under
   `Scout.etc.AI/<name>`; they add no tools and are orthogonal to the
   tier column.

## Errata (applied per the Phase 4 Critic gate)

Four corrections to this artifact's first draft, made after the Critic
gate reviewed it; the probe evidence itself was never wrong (the JSON
`own_tool_lines` in `redesign_phase4_final_probe.out` was and remains the
source of truth):

1. **Research row, tool-line cell:** the draft copied the Phase 0
   lines (four cortex tasks plus the removed no-op `tool: Research`).
   Corrected to the current nine explicit cortex lines
   (list/search/read/write/edit/continue/brief/rename/move/remove), no
   `tool: Research`.
2. **Investigator row, tool-line cell:** the draft asserted
   `tool: Semantics` and `tool: Research`. The agent holds neither;
   corrected to `tool: Workspace` + the five explicit cortex lines
   (list/search/read/write/edit).
3. **Doctrine-importer count:** "16 import `Agent/doctrine` (all but
   Clean)" corrected to **18** (only Clean does not import it).
4. **Research Δ cell:** the draft's "0 (33→36 on new probe)" was
   self-contradictory; tidied to state 36 in both Phase 3 and Phase 4
   probes, with the Phase 0 matrix's 31 attributed to its older counting
   (§3.1).

