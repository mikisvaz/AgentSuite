# Phase 3 — role implementation (AgentSuite redesign)

- **Date:** 2026-11-01 (Phase 3, four bouts: new agents ~16:10, research
  line ~16:21, coordination roles ~16:31, roster + report ~16:45 +0100)
- **Repo:** `/bulk/mvazque2/git/AgentSuite`, branch `ags-redesign`,
  drift baseline `1116c9a`.
- **Authority:** `new_doctrine/work/redesign-role-contracts.md` (frozen;
  §1 role map, §2 authority boundaries, §3 import sets). Phase 2's shared
  instruction layer (`doctrines/`, doctrine §10) is the context Phase 3
  built on; this phase changed agents and the roster only.
- **Status:** all probe checks pass; nothing independently reviewed yet —
  the Critic gate and Phase 4 re-probe remain.

## Files changed

| File | Before | After | Bout |
|---|---|---|---|
| `ScientificLead/start_chat` | — | 3,213 B (new) | 1 |
| `Investigator/start_chat` | — | 5,779 B (new) | 1 |
| `Research/start_chat` | 13,035 B | 7,195 B (−45%) | 2 |
| `Searcher/start_chat` | 2,365 B | 2,634 B | 2 |
| `Manager/start_chat` | 4,976 B | 6,126 B | 3 |
| `ScoutCoder/start_chat` (submodule) | 6,112 B | 6,866 B | 3 |
| `Critic/start_chat` | 6,453 B | 6,906 B | 3 |
| `Consultant/start_chat` | 1,611 B | 1,546 B | 3 |
| `society` (roster) | 6,954 B | 8,944 B | 4 |

## Files deliberately not changed

- `Worker/start_chat`, `Planner/start_chat`, `User/start_chat` —
  contracts D9 "untouched" for identity, boundary, and tooling: verified
  unchanged against baseline in role text and tool lines. Their import
  lines were later completed per §3 by the Critic-gate repair bout
  (MC3 ratification: import-only wiring does not violate D9's
  "untouched"; see Verification summary).
- `doctrines/*`, `doctrine` — Phase 2 artifacts; Phase 3 has no shared-doc
  authority. The advice-appendix pointer stays pending retirement.
- Agent rosters other than `society`; every other workflow file.
- Note: `ScoutCoder/README.md` (submodule) carries a pre-existing two
  trailing-blank-lines diff from before Phase 3; left as-is.

## Role/context changes per agent

- **ScientificLead (new):** tool-less scientific-direction owner — question
  decomposition, hypothesis framing, evidence-review standards, branch
  go/no-go, sufficiency close. Consumes evidence summaries from durable
  paths; R3 (3 doctrine-footer tools); imports doctrine, society,
  collaboration, investigation, discipline, handoff.
- **Investigator (new):** Worker-derived question-owning executor — one
  assigned question → evidence chain → bounded conclusion; packet executor,
  no onward delegation. Full Worker surface + explicit Cortex A5 (no bare
  `tool: Cortex`, no continue/brief, no rename/move/remove); imports
  doctrine, society, collaboration, investigation, handoff (discipline
  deliberately excluded per contracts §3).
- **Research:** evidence curator (contracts §2.3) — record registration,
  lifecycle, traceability; delegates acquisition to Reader; direction from
  Lead; does not own scientific questions. The fused 7-step protocol is
  gone. Cortex C10 explicit; Semantics trio + full Workspace retained;
  no-op `tool: Research` removed.
- **Searcher:** de-bound from Planned — generic narrow targeted-discovery
  role; NO_SEARCH_NEEDED semantics stated inline (Searcher does not import
  handoff); dangling `match_skills` reference dropped, `- Relevant skills`
  format field kept (no backing tool — Phase 4 decision pending).
- **Manager:** AGS-route duties added (Lead outline → work orders and
  Investigator packets; review routing; never substitutes scientific
  judgment; may stop/re-scope on budget/authority, recorded as such).
  Imports +collaboration, +handoff; investigation deliberately excluded
  (D5). Budget policy, packet structure, output discipline, Cortex policy
  untouched.
- **ScoutCoder:** computational-planning authority framing (scientific
  direction and execution routing explicitly not its lanes); unit-test
  placement convention absorbed from the pending advice appendix
  (`./lib/scout/dir/file.rb` → `./test/scout/dir/test_file.rb` + template),
  closing audit A's migration flag. No import changes.
- **Critic:** text aligned to §2.8 verifier-not-re-executor; narrow
  provisioning stated in words (read-oriented Workspace tasks + bash for
  probes; no write/edit/delete) so Phase 4 wiring matches; imports
  +collaboration, +discipline. Tool lines untouched this phase.
- **Consultant:** scientific-methodology use-for bullet deleted
  (hypotheses, discriminating experiments → ScientificLead);
  architecture/strategy identity unchanged; no import changes.
- **society:** ScientificLead + Investigator entries added;
  Research/Manager/Searcher/ScoutCoder/Consultant entries updated; Critic's
  "Not for" sharpened (no writing files); routing-in-one-line now shows the
  scientific split; Planner/User/Worker/Reader/ChatAnalyst/Planned entries
  unchanged. Structure (heading + Use for / Not for) preserved throughout.

## Verified configuration (probe evidence)

- Bout 1 (new agents): `tmp/redesign-probes/redesign_phase3_new_agents_probe.out`
- Bout 2 (research line): `tmp/redesign-probes/redesign_phase3b_research_line_probe.out`
- Bout 3 (coordination roles): `tmp/redesign-probes/redesign_phase3c_four_agents_probe.out`
- Bout 4 (final snapshot, all 19 agents): `tmp/redesign-probes/redesign_phase3_final_snapshot.out`
  (script: `redesign_phase3_final_snapshot.rb`; checks F1–F9 all true; after
  the Critic-gate repair the same script checks F1–F12, all true)

## Verification summary

- **Imports resolve, zero leftovers, all 19 agents** (F1): production
  Chat.parse → Chat.imports → Chat.tools over a staged scratch mirror;
  hermetic workflow preload; no model turns.
- **Effective tools (final snapshot, cortex/non-cortex):** Basic 3/0,
  ChatAnalyst 5/39, Clean 0/0, ComputerUse 3/0, Consultant 3/3,
  Cortex 10/29, Critic 3/23, FitAgent 3/0, Manager 5/0, Planner 3/5,
  Reader 10/27, Research 10/26, ScoutCoder 5/40, Searcher 5/10, User 3/0,
  Visualizer 5/0, Worker 10/23, ScientificLead 3/0, Investigator 5/23.
- **No bare `tool: Cortex`** on Investigator or Research (F9); both carry
  explicit per-task lines (A5 / C10 respectively).
- **Text-only bout identity (bout 3):** Manager 5, Critic 26, Consultant 3,
  ScoutCoder 45 — all equal to Phase 0 baselines, verified per-bout and in
  the final snapshot (F8).
- **Untouched agents equal Phase 0 baselines** (F3): Basic, ChatAnalyst,
  Clean, ComputerUse, Cortex, FitAgent, Planner, Reader, User, Visualizer,
  Worker. Phase 0 baselines re-read from the packet-C probe rather than
  the earlier mis-typed matrix row (see Notes).
- **Roster edit reaches every society importer** (F2): agents importing
  `Agent/society` resolve the updated roster — 7 importers across the 19
  probed: Cortex, Manager, Planner, Research, User, ScientificLead,
  Investigator (snapshot import arrays,
  `tmp/redesign-probes/redesign_phase3_final_snapshot.out`). The earlier
  "16 importers" figure in this report was wrong and is corrected here;
  the Critic gate caught it.

## Critic-gate repair (MC3, 2026-11-01 ~16:50 +0100)

The gate found the §3 import wiring implemented only for the roles Phase 3
touched; 11 memberships were missing. Repair bout (mechanical, import-only):
Planner +collaboration +handoff; User +collaboration +handoff; Worker
+collaboration +handoff; Searcher +investigation; Reader +investigation
+catalogue; Critic +investigation; Consultant +catalogue. No role text,
tool line, or roster line changed. Verification: all five §3 membership
sets now match the contracts exactly, importers-per-doc counts match,
imports resolve with zero leftovers, and every effective tool count is
unchanged from the Phase 3 snapshot (F10/F11/F12). Manager ratification
(MC3): D9/D10/D11 labels were invented in this report — the contracts
define D1–D9 only; Planner and User are covered by D9's "untouched" plus
this repair bout's ratification. Reconciliation reading: adding the
§3-mandated import lines does not violate "untouched", because D9 governs
identity, boundaries, and tooling — no agent's self-definition changed.

## Compatibility notes

- `society` is imported by 7 agents as `Agent/society` (Cortex, Manager,
  Planner, Research, User, ScientificLead, Investigator); the roster edit
  changes what each of them sees at parse time. No import set changed
  as a result of the roster edit itself (verified: import lists in the
  final snapshot equal the intended per-contract sets).
- Investigator's A5 (5 Cortex tasks, no continue/brief) was a
  contracts-over-prompt ratification this phase (bout 1, confirmed by the
  packet owner in bout 2's instructions).
- Research keeps `socialize: true` and `exec_task: Workspace pwd`;
  Consultant keeps `endpoint: consultant`. Critic's `tool: Workspace` line
  is intentionally still broad — Phase 4 replaces it.

## Next work (Phase 4)

1. Critic tool-line wiring: replace `tool: Workspace` with the explicit
   seven-task set (read, list_directory, file_stats, search, sandbox_paths,
   pwd, bash) → target ≈10 effective; text already states the intent.
2. Endpoint decisions: ScientificLead's `endpoint:` line remains open
   (deferred since §2.1); revisit per Phase 2 report.
3. Searcher `match_skills` / "- Relevant skills" field: point at a real
   capability or retire the field (contracts §2.6 Phase 4 note).
4. Rename inventory precondition (contracts §5): the "Research" name
   retention is pending the rename decision.
5. Re-probe all agents after the wiring change and extend the capability
   matrix.
