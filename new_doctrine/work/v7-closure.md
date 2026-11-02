# v7 closure

Date: 2026-11-02. Branch: doctrine-v7. Editor role: Worker (instruction
editor for the v7 pipeline). Critic gate: PASS with three non-blocking
advisories — all applied in this closure bout.

## Final configuration summary

Instruction commit: 91919a8 on doctrine-v7 — "v7: doctrine, shared
guides, role start_chats, Analyst role, work files (ledger-driven)",
21 files (+2288/−139): doctrine, doctrines/{collaboration,discipline,
handoff}, 8 role start_chats, new Analyst/start_chat, society, 9 work
files. Closure commit (this bout, sha in §Commits) adds
v7-migration.md, v7-closure.md, v7-validation-mission.md,
v7-behavioral-results.md, the two doc fixes, and the updated submodule
pointers.

Submodule commits (advisory 3ii applied): ScoutCoder 667d1e2 (start_chat
execution-stance block, 66+/9−; its unrelated pre-existing README dirt
remains uncommitted inside the submodule); ChatAnalyst 25f423a (return
contract, +5). Parent pointers updated in the closure commit.

Commit topology note (resolved discrepancy): the original v7 commit was
21ee0dd; it was amended once (to fold the deployment-verification
Commit section carrying its own sha) before being shared, producing
91919a8, same parent fa843de. Both Critic (21ee0dd) and Worker (91919a8)
were correct about different moments of the same single logical commit;
neither is a duplicate or missing commit. doctrine-v7 tip carries only
91919a8 beyond the ags-redesign tip.

## Verification status per deliverable

| Deliverable | Status |
|---|---|
| v7-baseline-drift.md (rollback point, drift, decision) | validated (git facts reproducible) |
| v7-mandate.md (verbatim extraction) | validated (sha256 68924706…, cmp-verified, header notes boundaries) |
| v7-evidence-register.md (16 entries, corrections logged) | independently reviewed (ChatAnalyst verdicts; citations spot-checked to SRC-A) |
| v7-change-ledger.md (33 rows + decisions) | validated vs register + mandate; independently reviewed (Manager decisions recorded) |
| v7-diffs-shared.md / v7-diffs-roles.md | validated (diffs regenerated from files; roles change records — submodule correction applied) |
| v7-matrix.md (14/14 hermetic probe PASS) | validated (script + raw output cited) |
| v7-deployment-verification.md | validated; behavioral line refreshed (10 PASS) |
| v7-behavioral-results.md (T-1..T-10) | validated (one inference per test; every decisive quote grep-verified against raw output) |
| Analyst role, society entry | validated (probe) + T-6 behavioral PASS (preventive row: first direct evidence, single-mission caveat) |
| concept-catalogue evaluation (EVAL-1) | unverified — retained as-is, not rerun |

## Advisories applied

1. Consolidated migration note → new_doctrine/work/v7-migration.md
   (per-file REMOVED/RETAINED/TIGHTENED/NEW + roster addition +
   deliberately-untouched list; pointers into v7-diffs-*.md).
2. Stale behavioral line in v7-deployment-verification.md replaced:
   now cites v7-behavioral-results.md, 10 PASS / 0 FAIL / 0 INCONCLUSIVE.
3. (i) The 3 one-character punctuation edits in doctrine (colon→em-dash,
   lines 13/106/231) were probing residue — REVERTED via
   `git checkout -- doctrine`; diff against HEAD now empty; committed
   doctrine text stands. (ii) Submodule strategy applied: v7 start_chat
   edits committed inside both submodules (667d1e2, 25f423a), parent
   pointers updated here. (iii) overstated "untracked" claim in
   v7-diffs-roles.md corrected (files ARE tracked in submodules; edits
   were uncommitted M).

## Promotion recording

The checkout's live working tree has been on doctrine-v7 since bout 1
(branch created at the fa843de baseline with working files intact).
The closure commit therefore marks the v7 state as the operative
configuration of this checkout. Merging doctrine-v7 into ags-redesign
and main remains gated on the validation mission defined in
v7-validation-mission.md (per redesign-closure §8: full-scale mission
+ submodule state closure). Rollback point: baseline fa843de (ags-
redesign tip; main at e6ead1b), recorded with drift evidence in
v7-baseline-drift.md; no resets or deletions are needed to roll back —
checkout fa843de and the pre-v7 state is restored.

## Known limitations

- Submodule topology: ScoutCoder and ChatAnalyst are git submodules;
  their v7 commits are local (no push performed — remote update is a
  user action). ScoutCoder carries unrelated pre-existing README dirt,
  left uncommitted inside the submodule.
- doctrine_bundle/ remains untracked (redesign-closure §8 policy);
  bin/bundle_doctrine.sh exits 1 on pre-existing noise for non-agent
  top-level entries (script shape, not v7) — bundle regeneration was
  byte-verified for all 35 v7 entries.
- workflows/ staged start_chats use machine-absolute symlink targets
  (pre-existing §7.4 state) — unchanged by v7.
- Original audit (process_xray) and pilot job trees are unreachable
  from the agent sandbox; evidence provenance rests on the verbatim
  carriers SRC-A (Planned request job sidecar) and SRC-B
  (v7-mandate.md, sha256 68924706…).
- T-6 (Analyst no-construction) evidence is one behavioral smoke run,
  not an observed mission; preventive row carries its caveat.
- EVAL-1 concept-catalogue evaluation was retained, not rerun.

## Commits (this bout)

Submodules: ScoutCoder 667d1e2; ChatAnalyst 25f423a.
Parent closure commit: f8a5a42 (8 files, +431/−5: the three new docs,
v7-behavioral-results.md, the two doc fixes, both submodule pointers).
