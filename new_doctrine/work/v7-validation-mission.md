# v7 validation mission (follow-on)

Definition of the AGS-class validation mission that gates merging
doctrine-v7 into ags-redesign and main (redesign-closure §8). The
mission is NOT run by the v7 pipeline; it is staged for the user /
ScientificLead to launch.

## Launch package

Scenario: AGS.continue/01_research_scope — staged in the user-side
scenario tree at ~/git/sandbox/Scenarios/scenarios/AGS.continue/
01_research_scope/ (NOT visible from the agent sandbox; confirmed by
the Reader bout). Launch procedure (user-side): stage the scenario
package into the mission workspace, then run the AGS pipeline under the
doctrine-v7 checkout (the live working tree since bout 1; closure
commit marks the operative configuration).

Mission shape: one full-scale mission end-to-end (request → search →
plan → work → report), full roster under v7 instructions including the
new Analyst.

## Accounting methodology (comparable to doctrine6)

- Inference/token accounting per phase (request/search/plan/work/ask)
  and per role invoked, from job meta records; same capture points as
  the doctrine6 audit so the comparison table is like-for-like.
- Consumption counts for built interfaces: for every interface
  consumed or proposed, record who consumed it, how often, and whether
  the consumption was demonstrated-need-driven (ScoutCoder engagement
  log, branch-consumption reports).
- Gate-state compliance log: at each consequential boundary, the gate
  state before and after, who transitioned it, and whether a completed
  deliverable was (wrongly) treated as a transition — the T-1 failure
  mode.

## Success criteria (changed decisions, not just token reduction)

1. Gate states honored at every consequential boundary; no pending→
   approved transition by task completion (T-1, RB-3).
2. Deviations and fallbacks reach the Lead/decision authority before
   the dependent investment proceeds (T-2, RB-4, P-1).
3. Computation is routed to Analyst with manifest-cited results
   (result address + manifest version) rather than inline by Research
   (PR-5, ROLE-1).
4. ScoutCoder engaged only on recorded demonstrated need (named
   consumer + recurrence), never prospectively (RB-2, RB-6).
5. Validated-labels attach per statement actually checked this bout;
   no blanket labels; numerical claims carry precision and
   consistent-with wording (PR-2, P-4, T-8).

Token/cost comparison vs doctrine6 headline numbers is reported as
context, not as a pass condition.

## Comparison table (to be filled by the mission report)

| Metric | doctrine6 audit | v7 validation mission |
|---|---|---|
| Inferences (total / per phase) | (from SRC-A audit numbers) | — |
| Token spend (total / per phase) | (from SRC-A) | — |
| Gate-state violations | 2 observed (RB-3 class) | — |
| Deviations not forwarded | 1 (RB-4 class) | — |
| Interfaces built / actually consumed | per audit ratios | — |
| Analyst-routed computations (manifest-cited) | n/a (role absent) | — |

## Rollback / close procedure

- Rollback point: fa843de (ags-redesign tip; main e6ead1b), per
  v7-baseline-drift.md; checkout restores the pre-v7 state with no
  resets or deletions.
- On mission failure against any criterion: record the failure with its
  job evidence in new_doctrine/work/, route the failing rule row in
  v7-change-ledger.md back to its owning document, and leave
  doctrine-v7 unmerged.
- On mission success: merge doctrine-v7 → ags-redesign → main (after
  submodule state closure: pushing 667d1e2 / 25f423a or recording the
  local-only limitation), regenerate doctrine_bundle/, and archive the
  mission report under new_doctrine/work/.
