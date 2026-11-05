# Doctrine v9 migration note

Implementation bout (step 4 of 7). Base: doctrine-v8 @ 46433830 (rollback
point). Head after this bout: 617d0f9. 14 commits, linear (no merges:
`git log --oneline --merges 4643383..HEAD` empty). Every row below cites the
ledger row, owning file, section anchor, what changed, and commit sha.

## Old→new map (per ledger row)

| Row | Owning file / anchor | What changed | Commit |
|---|---|---|---|
| CL-01 | `doctrines/scientific_investigation` §4.4 "Select the appropriate computational route" | Computation authority defaults to Analyst staged-file route; native routes earn their place by demonstrated consumption (consumer role, run, artifact), not availability | 7ade93a |
| CL-02 | `doctrines/scientific_investigation` §4.5 "Consumer validation and infrastructure investment"; `doctrines/mission_template` preflight row | Slice must execute in intended consumer's own context/chat, not builder's; record consumer role + run id with the slice receipt; template preflight gains "Consumer-context test (role + run id)" column | cd28812 |
| CL-03 | `Manager/start_chat` "Your responsibilities" item 1; `doctrines/handoff` "Work-order format" | Item 1 extended: read newest correction/gate artifact before dependent dispatch, cite consumed version (sha/mtime); work-order list gains "artifacts consumed, with version (sha or mtime)" | c96264a (+ fix 651e9b8) |
| CL-04 | `doctrines/collaboration` "Authority and gates" | Gate state change is a recorded act: gate-file entry carries owner, decision, timestamp, decision-packet digest; late discoveries append, never overwrite; dependent work not dispatched before the ruling is registered | 7ade93a (text refined in c96264a; duplicated-block fixed in fa37b8d) |
| CL-05 | `doctrines/handoff` "Paths and durable references"; `Research/start_chat` | Registered artifacts staged at registration into the Manager-readable results area; packet returns capped with a named digest | cd28812 |
| CL-06 | `doctrine` §4 "Bounded work and adaptive plans" (diagnostics paragraph) | Memoize failures: after two consecutive identical failures a third identical attempt is prohibited; read the error, memoize, change one material variable or switch surface | 7ade93a |
| CL-07 | `Research/start_chat` "Epistemic registration discipline"; `doctrines/discipline` "Epistemic records" | Every registration bout reports record-index delta (count + ids vs prior index); record text never relies on transcribed numbers — cites result addresses; doctrine gains durable-persistence-before-compaction-boundary clause | fa37b8d (doctrine half in 7ade93a) |
| CL-08 | `Research/start_chat` item 8; `ScientificLead/start_chat` "Authority and gates"; `doctrines/scientific_investigation` §4.6/4.7 | Before Gate-1, Lead's adjudication vocabulary supplied to Research as contract input for the epistemic store; author field carries the acting role, not a default | c73e475 (vocab), 595962a (author enum), 7ade93a (sci-inv 4.7) |
| CL-09 | `doctrine` §5 "Bouts and shared surfaces"; `Manager/start_chat` "Delegation discipline"; `Research/start_chat`; `Analyst/start_chat` | One conversation = one named deliverable; mandatory split on new work order / gate crossing / phase boundary; soft triggers >60–80 inferences or pt/inf ≥1.5× early mean; role anchors (Research: scope brief, record ids with versions, manifest digests, gate files; Analyst: staged package, computation spec, resume packet) | 7ade93a (doctrine), 2e9b4bd (Manager + role anchors), c73e475 (one-conversation-per-package), Analyst resume packet 2e9b4bd |
| CL-10 | `Manager/start_chat` item 12; `ScientificLead/start_chat` "Scale-risk review"; `doctrines/mission_template` scale-plan section | Manager pre-dispatch blocker at ≥10× workload ratio: capped wrapper-free single-item probe at target scale (frozen input, ≤20 min, sha cited) or Lead waiver with pre-registered rule; Lead spec-freeze scale review + 20-min T_slice routing rule | 7a71501 (Manager), c73e475 (Lead) |
| CL-11 | `Critic/start_chat`; `doctrines/collaboration` | Correspondence check before every gate ruling: each decision word the ruling uses must be expressible by the record, each status accounted for; mismatch reported to Research, does not block | c73e475 (Critic), 7ade93a (collaboration) |
| CL-12 | `doctrines/mission_template` (new file, tracked from `tmp/chat/scout_scientific_agent_design/wiring/mission_template.md` draft) | Installed with F-B3 (preflight enumerates every tested op), F-B5 (gate-scale receipts mirrored into run root; single scribe = Manager), F-B6 (receipts recorded) hardening; consumer-context column (RM-02/RM-08); env-facts header; scale plan; gate-vocabulary section | 6c54a97, cd28812, 9ce5126 (relocated `mission/` → `doctrines/`) |
| CL-13 | `Manager/start_chat` item 13 | Fallback-ladder decisions recorded: rungs tried, chosen, why, whether walked back; no undocumented dead-surface choices | 7a71501 |
| CL-14 | `ScoutCoder/start_chat` step 4; `doctrine` §2 | Pin-first, then test; probe iterations capped at three, third-failure stops and reports divergence | submodule 7da7ab8 (edit committed there); AgentSuite `doctrine` §2 in 617d0f9 |
| CL-15 | `Worker/start_chat` "Tooling" block; `Analyst/start_chat` | Write scripts via write tool then execute (no inline `-c` quoting); no assumption of sibling-role call ordering or foreign path layouts; iterate in tmp/, ship from results; Analyst script-iteration hygiene | cd28812 (Worker), c73e475 (Analyst) |
| CL-16 | `doctrine` §4 "Choose tools by fit" paragraph | Issue independent tool calls together in one turn instead of serializing | 7ade93a |
| CL-17 | `Manager/start_chat` item 11; `doctrines/handoff` "Work-order format" header; `Critic/start_chat` seeded-facts paragraph | Standing environment-facts header on every work order (surfaces, mounts, tool availability, constraints); Critic seeds from it, re-verifies only what the verdict depends on | 7a71501 (Manager), cd28812 (phrasing), doctrines/handoff c96264a/cd28812, Critic c73e475 |
| CL-18 | `Planned/workflow.rb` work prompt; `Planned/README.md` stage list | Work-stage prompt cites the plan and logs deviations from it (consumption contract); README updated. Alternative branch of the row (disable plan stage for operational restatements) NOT implemented — see Deviations | cd28812 |
| CL-19 | `society` Manager entry (standing-constraints note) | Standing constraint recorded: Boolean/Gene domain tools provisioned to Manager only; Worker route dead by configuration (d8 WORKER#40) | 6c54a97 |
| CL-20 | `bin/bundle_doctrine.sh` | Guards on both copy loops, `mkdir -p`, explicit `exit 0`; verified: `bash bin/bundle_doctrine.sh` → exit 0, empty stderr | c32f5b7 |
| CL-21 | `.gitignore` | `doctrine_bundle/` and `doctrine_bundle.v7/` ignored; `git check-ignore doctrine_bundle/` exits 0; status clean of `??` bundle lines | c32f5b7 |
| CL-22 | ScoutCoder gitlink | Pointer dd19a83 → 7da7ab8 (superset of 488afcf: contains committed v8 start_chat edit 667d1e2 and the v9 pin-first commit 7da7ab8 made in the submodule). `git submodule status` shows no `+` | 5cec211 |
| CL-23 | `new_doctrine/work/` | v8-* (mandate, baseline, wiring-plan, wiring-review, change-ledger) + all v9-* work files committed (v7 convention) | 147d4e5 |

Commit list (sha — subject, chronological): c32f5b7, 7ade93a, 7a71501,
c73e475, 6c54a97, 5cec211, 147d4e5, cd28812, c96264a, 9ce5126, fa37b8d,
2e9b4bd, 651e9b8, 595962a, 617d0f9 (15 total; 14 v9 + 1 dedup fix folded in
above as 651e9b8).

## ChatAnalyst submodule (D2 companion instruction)

Originally verified (step 4): ChatAnalyst HEAD 25f423a ("v7: ChatAnalyst
start_chat return-contract line"), parent pins 25f423a — **equal**, with an
uncommitted in-submodule start_chat edit plus `.vimproject` dirt. No pointer
bump was made; no equivalent committed v8-era edit existed in ChatAnalyst
history at that time.

**Gate-refreshed (N-3, step 6b):** the submodule is now **CLEAN at 2bbc1e9**
("Improved ChatAnalyst start_chat", authored after the last v9 commit; it
absorbs the previously-uncommitted start_chat edit and adds an
`import: Agent/doctrines/scientific_investigation` line). Parent gitlink
remains unchanged at 25f423a (25f423a is an ancestor of 2bbc1e9). No v9 row
owns ChatAnalyst; no v9 action required — recorded for accuracy only.

## Text moved between files

- `doctrines/mission_template` (was `mission/mission_template.md` after
  initial install): relocated in 9ce5126 to the canonical doctrines dir; no
  content change beyond CL-12 hardening applied before relocation.
- CL-14's rule text appears twice by design: `ScoutCoder/start_chat` step 4
  (submodule, role-specific) and `doctrine` §2 (suite-wide generic form).

## Deviations

- **CL-18 second branch not implemented.** The row offers "work prompt cites
  the plan OR missions with operational restatement disable the plan stage".
  I implemented the first branch (prompt + README). The second would need a
  new chat option in `Planned/workflow.rb` (e.g. `use_plan false`) plus
  dependency rewiring — a code change with runtime behavior beyond a text
  contract, larger than the row's minimal-edit intent, and the first branch
  satisfies the acceptance test. Flag for the Critic gate: if the
  disable-branch is wanted, it needs its own small ledger row.
- **CL-14 ScoutCoder half done in the submodule.** Row said "execution
  contingent on D2". D2 confirmed; I committed the pin-first edit inside the
  submodule as 7da7ab8 ("v9: pin-first testing, probe iterations capped at 3")
  and bumped the parent pointer to it. This is why the parent points at
  7da7ab8 rather than the design-decision's 488afcf: 488afcf would not contain
  CL-14's ScoutCoder half.
- **Template location.** Ledger row CL-12 named `doctrines/mission_template`;
  the initial install landed at `mission/mission_template.md` (my own earlier
  commit 6c54a97), corrected to `doctrines/mission_template` in 9ce5126 via
  `git mv`.

## Bundle verification (per work order)

`bash bin/bundle_doctrine.sh` → **exit 0**, empty stderr (baseline: ~54 cp
errors, exit 1). Content diff: `diff -q` clean for `doctrine`, `scout`,
`society`, all 8 `doctrines/*`, and all 8 role start_chats in the bundle.

## History-integrity check

`git log --oneline --merges 4643383..HEAD` → empty; `git rev-list --count
4643383..HEAD` = 15. doctrine-v9 remains single-line-of-history from the
rollback point.

## Working tree left as

` M ChatAnalyst` (uncommitted in-submodule start_chat edit + `.vimproject`,
pre-existing, not owned by v9), ` M ScoutCoder` (in-submodule untracked
`.vimproject` only; gitlink committed at 5cec211). Both are content-level
submodule dirt that no ledger row owns; fixing them requires commits inside
the submodules, outside this bout's scope.

## Opportunistic findings (not fixed)

1. `doctrine_bundle.v7/` existed on disk at bout start (in addition to
   `doctrine_bundle/`); both now ignored (CL-21) — deleting the stale v7 copy
   was not authorized and not done.
2. `doctrines/advice`, `doctrines/catalogue`, `doctrines/investigation` are
   bundled but reference no v9 row; they passed the content diff, so they are
   current — noted only as unused-by-this-cycle files.
3. `society` lists `Boolean`/`Gene` under Manager "Use for" while the roster's
   standing-constraint note (CL-19) documents the asymmetry; the constraint
   note's exact placement (after the ScoutCoder paragraph) may read oddly for
   consumers expecting it adjacent to the Manager entry. **Gate follow-up
   (N-1, a8d2f52): CL-19's edit also produced a garbled duplicate ScoutCoder
   "Use for" line (commit 6c54a97) — "…framework questions, project"
   collided with the preceding sentence's tail "help tools are also
   introduced into other agents' chats." — corrupting the Use-for line.
   Now removed (a8d2f52); the clean line and the F7 note are intact.**
4. `Planned/README.md` §"Testing" still describes only the four Workspace test
   files; no v9 row covers Planned test coverage — gap, not fixed.
5. The `workflows/` symlink friction (machine-absolute targets, baseline
   disposition: delegate) remains; no row authorized touching symlinks this
   cycle.
