# Doctrine-v9 gate closure record (step 6b of 7)

Date: 2026-11-05 · Branch: `doctrine-v9` · Executor: Worker (v9 pipeline) ·
Critic gate under review: step-5 gate over 5a (hermetic delivery verification)
+ 5b (behavioral spot checks) + step-4 implementation.

## (a) Critic gate review — verbatim transcription

Attribution: transcribed from the step-6b work order issued by the v9
coordinating session (Manager → Worker) on 2026-11-05, quoting the Critic's
gate review in full. The review examined commits 46433830..HEAD on branch
doctrine-v9.

---BEGIN CRITIC REVIEW---
Verdict: NEEDS_WORK.

Executed checks: git log/diff/show over 46433830..HEAD; re-ran
tmp/v9-probes/parse_probe.rb and import_match.rb; re-ran
bin/bundle_doctrine.sh; ruby -c Planned/workflow.rb; submodule ancestry
verified (488afcf and 667d1e2 both ancestors of 7da7ab8; 25f423a ancestor of
2bbc1e9).

Criterion verdicts:
1. Traceability — PASS with exception N-1: a garbled duplicate "Use for"
   line in `society` (ScoutCoder entry, from commit 6c54a97) sits ahead of the
   original clean line.
2. Register completeness — PASS with exception N-2: row count stated as 81 in
   one place; actual count is 79 (RB 7 + RM 18 + P 8 + F 4 + FR 14 + C 22 +
   BF 6).
3. Deviations and decisions — PASS: CL-18 deviation accepted as recorded;
   D2/7da7ab8 sound — exactly one commit in 488afcf..7da7ab8 touching one
   start_chat line.
4. Verification validity — PASS: 5a independently reproduced; 5b receipts
   read; single-sample caveat carried. Exception N-3: stale ChatAnalyst
   submodule description in v9-migration.md.
5. Scope/hygiene — PASS: 19 commits linear, 0 merges, read-only surfaces
   untouched.

Rulings: CL-18 accepted. Findings 1, 2, 4, 5 (of the original opportunity
list) left unfixed by design; finding 3 upgraded. ChatAnalyst: no v9 action.
The not-testable list is accurate and to be carried verbatim.

Smallest next actions: (1) remove the garbled society line; (2) correct the
81→79 count wherever stated; (3) refresh the ChatAnalyst submodule
description; (4) fix the "C06–C12" range notation in the ledger so it does
not sweep in C07/C09.

Re-test scope: only the society line and the corrected count.
---END CRITIC REVIEW---

(Transcriber's note on N-2: a repo-wide grep over `new_doctrine/work/v9-*.md`
found **no occurrence of 81 as a register row count** — see fix log below. The
count correction therefore applies only to downstream report drafting, already
noted by Manager.)

## (b) Fix application log

| Finding | Action | Result |
|---|---|---|
| N-1 garbled duplicate "Use for" line in `society` ScoutCoder entry (~line 183, introduced by 6c54a97/CL-19) | Deleted the single corrupted line via `sed -i '183d' society`; verified exactly one "Use for" line remains in the ScoutCoder entry and the F7 standing-constraint note is intact; `bin/bundle_doctrine.sh` re-run (exit 0) with `diff -q society doctrine_bundle/society` clean. Updated v9-migration.md opportunistic finding #3 to record the garbled duplicate. | Commit **a8d2f52** ("v9 gate N-1 (CL-19): remove garbled duplicate ScoutCoder Use-for line in society…") |
| N-2 count 81 → 79 | `grep -rn '\b81\b'` over all `new_doctrine/work/v9-*.md` (also targeted greps for "81 row", "81 registered", "rows total", "row count"): **zero matches using 81 as the register row count** (only token figures like 252,072,162 / 116.81M pt matched the raw grep). No file edit required; fact recorded here per the work order's fallback instruction. | No commit (nothing to correct in-repo) |
| N-3 stale ChatAnalyst submodule description in v9-migration.md | Replaced the step-4 ChatAnalyst section with both the original verification and the refreshed state: submodule now CLEAN at 2bbc1e9 ("Improved ChatAnalyst start_chat", authored after the last v9 commit, absorbs the previously-uncommitted start_chat edit, adds `import: Agent/doctrines/scientific_investigation`); parent gitlink unchanged at 25f423a (ancestor of 2bbc1e9); no v9 row owns ChatAnalyst; no v9 action required. Verified live: `git submodule status` → `+2bbc1e91… ChatAnalyst`, `git -C ChatAnalyst log --oneline` shows 2bbc1e9 atop 25f423a. | Included in docs/closure commit below |
| N-4 (optional) "C06–C12" range in v9-change-ledger.md accept-rows line | Replaced with explicit ids "C06, C08, C10, C11, C12" plus a bracketed correction note that C07 = environment and C09 = delegate (scout-ai), not accept rows. | Included in docs/closure commit below |
| Gate record persistence | This file (v9-closure.md) created with the verbatim review, the fix log, and the gate state below. | Included in docs/closure commit below |

## (c) Gate state

NEEDS_WORK → **corrections applied** (N-1 committed a8d2f52; N-3/N-4 in the
docs/closure commit; N-2 verified not present in any v9 file). PASS is
**contingent on Critic re-test** of exactly two things: (1) the society
ScoutCoder entry now has one clean "Use for" line with the F7 note intact and
the bundle copy diff-clean; (2) no v9 file states 81 as the register row count
(79 is the actual: RB 7 + RM 18 + P 8 + F 4 + FR 14 + C 22 + BF 6). Re-test
dispatched separately; this file does NOT mark the gate PASS — only Critic's
re-test can.

Post-fix invariants: branch linear (no merges introduced; verified after
fixes), 21 commits from rollback 46433830, bundle exit 0 with society copy
byte-identical, no edits outside `society`, `new_doctrine/work/` and the two
files named by N-3/N-4.
