# v8 wiring plan (step-1 artifact: defect table, planning defaults, step list)

Date: 2026-11-03. Repo: /bulk/mvazque2/git/AgentSuite, branch `doctrine-v8` (cut this bout from c85587c; see `v8-baseline.md`).
Mandate pinned at `new_doctrine/work/v8-mandate.md`, sha256 `bc7ef6c0827f7cf58b9364ce41d4435f6a41343c05978b2b24eb02eca38d7bcb`.
This file records the defect table verbatim, the three planning defaults (each pending step-2 confirmation), and the plan step list. No corrections are applied in this step.

## Defect table (verbatim)

W1: All 8 drafts import: Agent/investigation targets a root-level file that does not exist; repo convention puts shared docs under doctrines/; a generic doctrines/investigation already exists (imported by Critic, Investigator).
W2: Manager draft has no tool lines, no socialize: true, no import: Agent/society. Current Manager carries socialize: true + tool: Cortex cortex_continue + tool: Cortex cortex_brief.
W3: Analyst draft has no tool lines. Current Analyst carries 8 Workspace lines (bash python ruby r read write list_directory file_stats).
W4: Critic draft would re-expand to whole-workflow Workspace, losing the deliberately narrowed 7-task read/probe surface.
W5: ScoutCoder draft prose mentions path_kind: ScoutCoder but file carries no path_kind declaration and no tool lines; would lose all authoring tooling.
W6: ChatAnalyst draft has no tool lines; ChatAnalyst is a submodule; current wiring is tool: Workspace, tool: Cortex cortex_write/edit, tool: ChatAnalyst + 2 introduces; any edit needs a submodule commit.
W7: Research draft drops the 10 Cortex task lines, socialize: true, and exec_task: Workspace pwd that current Research carries; keeps introduce/tool: Semantics, adds introduce/tool: Research and path_kind: Research; whether tool: Research and path_kind: Research resolve in a fresh context is unverified (no workflows/Research symlink observed).
W8: Reader draft narrows Cortex from bare tool: Cortex to nothing; keeps Reader+Workspace.

## Planning defaults (each: default, pending step-2 confirmation)

- **D-W1** (default, pending step-2 confirmation): install the draft shared doctrine as `doctrines/scientific_investigation`, leave the existing generic `doctrines/investigation` in place with a supersede note, and rewrite the draft `import: Agent/investigation` lines to the new `doctrines/scientific_investigation` path.
- **D-W7** (default, pending step-2 confirmation): Research keeps its full current Cortex block (the 10 task lines), `socialize: true`, and `exec_task: Workspace pwd`, plus the draft's `introduce:`/`tool: Semantics`, `introduce:`/`tool: Research`, and `path_kind: Research` — resolving per the hermetic probe rather than trusting either source alone.
- **D-W8** (default, pending step-2 confirmation): Reader keeps its current bare `tool: Cortex` rather than narrowing to nothing.

## Plan step list (titles only, steps 1-8)

1. Baseline pin and branch cut (this step).
2. Wiring review: reconcile every tool:/import:/introduce:/path_kind: line in the 8 drafts against verified mechanisms; confirm or amend defaults D-W1/D-W7/D-W8.
3. Implement shared doctrine + role start_chats from the drafts, wiring-corrected.
4. Society roster update and import/bundle regeneration (doctrine_bundle/); disposition of Investigator/Planner/Searcher.
5. Integration check A: Research evaluates a known entity property through the actual Semantics surface.
6. Integration check B: Research registers/retrieves/updates one disposable record through the actual epistemic API; integration check C: Analyst completes a known computation via staged package + general tools only.
7. Hermetic delivery matrix (fresh-agent parsed contexts) for all changed roles.
8. v8 work-file set completion + one-page ready-to-launch statement (incl. migration note and optional/required spot checks disposition).
