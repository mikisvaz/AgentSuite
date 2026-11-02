# v7 migration note (consolidated)

Consolidation of the v7 instruction changes into one per-file migration
view, per Critic advisory 1. Sources: v7-diffs-shared.md (unified diffs
for the shared documents), v7-diffs-roles.md (change records for role
start_chats), v7-change-ledger.md (row ids), v7-matrix.md (effective
surfaces). Categories: REMOVED / RETAINED / TIGHTENED / NEW.

Baseline: ags-redesign tip fa843de (main e6ead1b). Instruction commit on
doctrine-v7: 91919a8 (amended from 21ee0dd; see v7-closure.md for the
topology note). Submodule commits: ScoutCoder 667d1e2, ChatAnalyst
25f423a.

## doctrine (root) — 260 → 254 lines, diff in v7-diffs-shared.md §1

- REMOVED: none wholesale.
- TIGHTENED: §1 classify/scale wording; §3 sandbox note now covers
  failure-scoping (RB-CR); §4 acts-of-work now carries plans-provisional
  + explicit reconsideration of the next dependent investment when
  execution evidence contradicts assumptions (RB-1), consumer-validated
  slice before substantial build + promote-only-on-demonstrated-need
  (RB-2, RB-6); §5 evidence — optional-infrastructure wording, no
  write-grant implication (RB-CX); §6 delegation — packets carry
  evidence itself, not descriptions of evidence (RB-4); §7 invariants —
  decision states with owning authority, "missing response does not
  imply approval" (RB-3, preventive label).
- RETAINED: structure, all ten sections, footer directives
  (import Agent/doctrines/advice, introduce: Cortex, 3 read-only tool
  lines) untouched per Manager decision (b).
- NEW: none (no new sections; all integrated by revision).

## doctrines/collaboration — 42 → 72 lines, diff §2

- NEW: enforceable gate-state definitions (approved / rejected /
  returned / explicitly-waived / pending; who may transition; a
  completed deliverable does not transition a gate) [RB-3, T-1];
  evidence-bearing packet rule (packet contains the evidence it claims;
  deviation/fallback reporting reaches the decision authority) [RB-4,
  T-2, T-5]; branch-consumption report template — 11 fields, one
  definition [decision (c), T-3]; flexible work-cycle default
  (scope → approve → compute → interpret → adjudicate → consolidate on
  need → verify; gates only on consequential direction or scope change)
  [PR-1].
- RETAINED: bout/work-order/packet discipline, ownership, verification
  gates, resume packets, NO_SEARCH_NEEDED sentinel.
- REMOVED: none.

## doctrines/discipline — 40 → 59 lines, diff §3

- NEW: "Numerical and inferential claims" section (non-injective
  statistics license at most "consistent with the same input"; identity
  needs input-level comparison; digit-equality weaker than exact, state
  precision; "validated" attaches only to statements actually checked
  this bout) [PR-2, P-4, T-8].
- RETAINED: epistemic-record discipline (RB-7 success — keep), now
  substrate-neutral; probe discipline, persistence ladder.
- REMOVED: none.

## doctrines/handoff — 57 → 66 lines, diff §4

- NEW: "Reconciliation before handoff" section (trigger: mid-bout
  correction + decision-facing deliverable/packet about to leave;
  behavior: reconcile against authoritative request and final corrected
  state, propagate into every artifact carrying the pre-correction
  statement; scope: decision-facing deliverables and packets only)
  [PR-3, T-10].
- RETAINED: packet shape, context rules, work-order format, sentinel.
- REMOVED: none.

## Role start_chats (change records in v7-diffs-roles.md)

- Manager 131→148: gate-state discipline, RB-1 pause-and-forward
  routing, consumer-slice rule, incomplete-packet return, Analyst
  routing, relay role. [RB-1..4, RB-CR, T-1, T-2]
- ScientificLead 66→86: decision-consumption registration trigger,
  preliminary-vs-final distinction, result-that-would-move-interpretation
  flag, packet-completeness check, work-cycle approval hook. [PR-1, P-2,
  T-5, T-7]
- Research 160→175: scoping/interpretation judgment (not
  bookkeeping-only), Analyst routing + manifest-version citation,
  substrate-neutral "Where things live", decision-consumption trigger,
  locator sample check, numerical-claims binding. [PR-2, PR-4, PR-5,
  RB-CX, T-7, T-8]
- ScoutCoder 145→180 (submodule commit 667d1e2): NEW execution-stance
  block — on-demand trigger, consumer slice (incl. two-party form), RB-1
  pause (one-directional; Manager owns forwarding), engaged
  surfaces/failure classes, ownership-until-consumed, return contract
  with branch-consumption emission; duplicate stewardship text
  deduplicated. [RB-1, RB-2, RB-CR, T-3]
- Critic 136→146: blanket-label check, numerical/inferential checks,
  environmental-scoping check (scope failures to the environment
  actually probed). [RB-CR, PR-2, T-4]
- Investigator 130→136: branch-consumption emission line + return
  contract. [decision (c)]
- Worker 91→100: return contract (result, evidence, tools/surfaces,
  deviations, limitations, unresolved) [T-9, T-10]; Cortex-optional
  wording (RB-CX).
- Reader 79→86, ChatAnalyst 91→96 (submodule commit 25f423a): return
  contract. [mandate deliverable 3]
- Analyst 75 lines NEW: Scout-agnostic computational role — manifest,
  read-only inputs, designated results area, reproducible
  transformations, missing-input reporting, never initiates
  investigation, interpretation deferred to Research/Lead, no
  Scout/agent-layer construction, return contract + branch-consumption
  emission; tool block = 8 general-purpose Workspace lines (bash,
  python, ruby, r, read, write, list_directory, file_stats), zero
  Cortex/Scout/domain lines. [ROLE-1, T-6]
- society 181→196: Analyst roster entry (Use for / Not for), routing
  one-liner, Manager paragraph names Analyst for staged computation.

## Roster addition

Analyst — new role directory `Analyst/start_chat`, society entry,
Manager/Research/ScientificLead routing hooks. Drawn per Manager
decision (a)/(d): Investigator keeps question ownership and evidence
chains; Analyst owns computation packages and never initiates
investigation.

## Deliberately untouched

doctrines/investigation, doctrines/catalogue (no ledger row names
them); Searcher/, Planner/, User/, Consultant/ start_chats (no ledger
row; not execution roles); tooling; workflows/; etc/. doctrine_bundle/
left untracked by standing policy (redesign-closure §8); its
regeneration output is machine-generated staging, not v7 content.
