# v8 change ledger (step 2 + step 3, 2026-11-03)

Branch doctrine-v8 @ c85587c (parent). All changes below are uncommitted in
the working tree; nothing was committed, pushed, or merged this bout, per
constraints. Baseline for diffs: 509ba7f (planned v7 baseline; actual branch
parent c85587c adds the Agent/-deletion commit — see v8-baseline.md drift
item 1). Draft baseline: `tmp/chat/scout_scientific_agent_design/`.

## Files changed (parent repo, tracked)

| File | Rationale | Diff size vs HEAD |
|---|---|---|
| `Manager/start_chat` | v8 prose from draft + W2 wiring restore (socialize, cortex_continue/brief, society import) + D-W1 import | +28 -126 |
| `ScientificLead/start_chat` | v8 prose from draft; imports = doctrine/society/collaboration/scientific_investigation/discipline/handoff | +22 -67 |
| `Research/start_chat` | v8 prose from draft (scientific investigator + epistemic centre); full Cortex block, Semantics/Workspace/Research introduces, exec_task pwd, socialize, path_kind: Research all retained (D-W7) | +48 -143 |
| `Analyst/start_chat` | v8 prose from draft; 8 Workspace task lines restored (W3) | +45 -52 |
| `Reader/start_chat` | v8 prose from draft; bare tool: Cortex kept (D-W8), Reader/Workspace/Cortex wiring unchanged | +24 -64 |
| `Critic/start_chat` | v8 prose from draft; narrowed 7-task Workspace surface kept (W4) | +17 -122 |
| `society` | Research entry rewritten as scientific investigator + evidence-curation centre; Manager routing lines updated (Investigator -> Research, Worker for execution); Investigator marked DEPRECATED (retained, not recruited); Planner + Searcher marked pipeline-internal (kept for Planned); Analyst "Not for" line updated | see diff below |
| `doctrines/investigation` | supersede note appended: remains reference for non-scientific investigations; scientific work -> doctrines/scientific_investigation | +11 lines |

## Files created (parent repo, untracked)

| File | Rationale |
|---|---|
| `doctrines/scientific_investigation` | D-W1: installed from tmp/v8-step2/scientific_investigation (byte-identical to draft Agent/investigation) with collaboration/discipline trims: gate-state list in 4.3 and branch-consumption template in 6 replaced by one-line pointers; section 7 numerical rules replaced by pointer to discipline guide |
| `new_doctrine/work/v8-wiring-review.md` | step-2 deliverable: per-draft-file defect table, D-W1/D-W7/D-W8 confirmations with FACT citations, submodule deviations, gaps |
| `new_doctrine/work/v8-change-ledger.md` | this file |
| `tmp/v8-step3/parse_probe.rb` | step-3 parse probe (adapted from tmp/v8-step2/parse_probe.rb; Chat.parse + Chat.imports over all 8 role start_chats, leftover-import and unknown-role checks, wiring-leak scan inside system body) |
| `tmp/v8-step3/parse_probe_output.txt` | probe output; all 8 roles: leftover_imports=0, unknown_roles=[], no wiring leak |
| `tmp/v8-step3/chats/` | scratch chat dir the probe used (disposable) |

## Files changed (submodule worktrees, uncommitted inside submodules)

| File | Rationale | Workaround |
|---|---|---|
| `ScoutCoder/start_chat` (submodule worktree, pointer dd19a83) | v8 prose from draft; restored import: Agent/scout, tool: Cortex cortex_write/cortex_edit, exec_task: Workspace pwd; path_kind: ScoutCoder kept (FACT-3/7) | File tracked by the submodule; edited in place in the worktree. The submodule already had the uncommitted reload-build changes (FACT-6); not committed, not discarded. Parent shows `m ScoutCoder`. |
| `ChatAnalyst/start_chat` (submodule worktree, pointer 25f423a) | v8 prose from draft; tool block restored (introduce/tool Workspace, cortex_write/edit, introduce/tool ChatAnalyst) (W6) | File tracked by the submodule; edited in place. Pointer stays 25f423a; parent now shows `m ChatAnalyst` (new dirty marker caused by this edit). Not committed. |

Committing the two submodule start_chats is deliberately left to a
submodule-maintenance decision (Manager/ScoutCoder); recording them here is
the handoff.

## Regenerated

- `doctrine_bundle/` regenerated in place via `bash bin/bundle_doctrine.sh`
  (same mechanism as v7). Verified: doctrine, society, scout, all 7
  doctrines (incl. new scientific_investigation), and all role start_chats
  present and identical to working-tree sources (`diff -q` clean for all
  changed files). The script prints cp errors for directories that have no
  start_chat (e.g. Branched/, bin/) — same behavior as v7, not a failure.
  doctrine_bundle/ remains untracked, as in v7.

## D-W* outcomes

- D-W1 CONFIRMED — FACT-1: `import: Agent/investigation` raises "Import
  not found"; `Agent/doctrines/scientific_investigation` resolves.
- D-W7 CONFIRMED — current full Cortex block retained in Research
  (evidence-current-wiring.txt); FACT-4 keeps path_kind: Research.
- D-W8 CONFIRMED — Reader keeps bare tool: Cortex (current wiring; draft
  agrees).
- No amendments needed.

## Validation

- Parse probe `tmp/v8-step3/parse_probe.rb` (Chat.parse + Chat.imports with
  the new doctrines in a scratch Agent/ chat dir): all 8 roles parse with
  leftover_imports=0, unknown_roles=[], no wiring-like lines inside the
  system body. Full output: `tmp/v8-step3/parse_probe_output.txt`.
- Bundle identity: `diff -q` between every changed source and its
  doctrine_bundle copy returned clean for doctrine, society,
  doctrines/scientific_investigation, doctrines/investigation, and all 8
  role start_chats.
- society grep checks: Investigator entry marked DEPRECATED; Planner and
  Searcher carry "pipeline-internal, not part of the scientific route";
  Manager routing lines reference Research (not Investigator).

## Harness/role-file distinction

- Role files (the durable doctrine): the 6 parent-repo start_chats, the 2
  submodule-worktree start_chats, society, doctrines/scientific_investigation
  (new), doctrines/investigation (supersede note). These are the v8
  configuration install.
- Harness/work files (untracked, bout-scoped): new_doctrine/work/v8-*.md,
  tmp/v8-step2/, tmp/v8-step3/, share/probes/, doctrine_bundle/.
- Nothing in this bout touched: main, ags-redesign, .vimproject (pre-existing
  dirty), the ScoutCoder reload-build files, FitAgent, workflows/ symlinks.
