# Research advisory — doctrine v9 scientific-role boundaries

From: Research (investigator seat). Advisory only; Manager decides. Process architecture, not a
scientific claim — no records registered.

**Evidence base.** I could read the run trees read-only: the doctrine-8 `process_xray/` tree of the
science.v2 AGS run (`AGS.full.scout.science.v2.doctrine8_66c09b60…/AGS/process_xray/`) and the d7
delta files. I spot-verified the supplied figures rather than taking them on trust: 8 × 3600 s
SIGTERMs 22:31–05:49 (`h004_branch_analysis.md` §1); 50-node ~0.4 s spot-check vs 351/401-node
target, batch-1 dispatch 21:31 after ~20:30 spec freeze (§1–2); Research 400 inf/51.17M pt +
Analyst 467/34.88M pt = 73.7 %, pt/inf 102k→170k (F-A7); Lead 6 inf/122k pt, Gate-5 header
"digest … NOT treated as verified" (D §packet quality); d7 Lead surface Cortex-only with 16
zero-match searches and a stale record-summary mirror (d7 `context_delivery_matrix.md`,
`doctrine6_vs_doctrine7_delta.md`); d7 18/18 via `AGS::FrozenSources`, 161 calls (d7 delta §30).

## 1. Lead evidence access — recommend option (a): tool-less Lead + mandatory Critic correspondence check

The Lead was the run's thinnest, highest-value role: 6 inferences / 122k pt carried five gates.
Option (b)'s premise was effectively tested in d7 — a minimal read surface (Cortex-only) on the
adjudicator — and it performed poorly: 16 zero-match `cortex_search` calls and adjudication over a
stale mirror. A small tool surface on the adjudicator did not close the gap; it added noise. Option
(a) puts verification where the control structure wants it: an adversarially-oriented verifier
checks the curator's packet; the adjudicator adjudicates.

**Rule text I would follow as investigator:**
- Before every gate ruling, Critic runs a packet-correspondence check: each load-bearing number,
  record id, status and quoted clause in the packet is matched against the record store and cited
  artifacts; the verdict (`corresponds` / `diverges` + the divergence list) is appended to the gate
  file and is a precondition of the ruling.
- The Lead stays tool-less, but may pull through Research one targeted record digest per gate
  (id, statement, status, assessment, links) when it wants first-hand content of a specific record.
- Escalation to (b) is evidence-triggered, not default: if two consecutive gates surface
  divergences a packet-vs-record check could not have caught without direct reads (e.g. a record
  title contradicting a ruling), give the Lead a minimal read-only record *lookup by id* — not a
  search surface.

**Costs.** (a): one bounded Critic round per gate (Critic's mission total was 16.9M pt; a
correspondence check is a fraction of it), serial latency before each ruling, and sampling —
coverage is not exhaustive. (b): tool maintenance on the thinnest role, demonstrated creep and
misuse risk (d7), and it fixes no schema defect. Neither option fixes the verified defects
(missing `supported_qualified`, `evidence_tier` conflation, no retire); those are schema work
(P1-3) — do not buy Lead tooling to solve a schema problem.

## 2. Research/Analyst bout contracts

Decisive detail from F-A7: each new Manager turn already hard-resets context (pt 134k→61k; cache
mostly lost), so carrying full history across bouts buys almost no cache benefit — accumulation is
nearly pure cost, which is what the 102k→170k pt/inf climb measures.

**When a conversation must split.** A conversation must not span more than one named deliverable.
Split mandatorily on: (1) any new work order or objective; (2) any Lead gate crossing; (3) any
phase boundary — scoping vs computation vs record curation vs packet writing. Soft trigger:
>~60–80 inferences in one conversation, or mean pt/inf ≥1.5× that conversation's early mean (the
measured climb was 1.67×). Analyst: one conversation per staged package — the run's 8 bouts in one
conversation should have been 8 conversations.

**Durable anchors each new bout starts from.** Research: the scope brief; record ids with versions
(the 48-record store already carried the reusable state — F-A7's own counterfactual); the
frozen-input manifest with digests; prior gate/packet files. Analyst: the staged package (read-only
inputs, manifest, checksums, results area + result manifest) and the computation spec (universe,
denominators, missingness semantics), plus a resume packet (done / shown / changed / remains /
unresolved / paths).

**Continuity rule.** The new conversation's opening message is the resume packet + record ids +
digests; everything else is re-derived by reading cited files. Packets cite record ids, never
transcript memory. Acceptance: P1-5's own test — one mission phase run as bounded conversations,
mean pt/inf and end-to-end tokens compared against the long-conversation baseline and reported;
the 27.2M pt saving is derived/low-confidence, and the pilot settles it.

## 3. Scale-probe rule — both, with distinct duties

The audit's own diagnosis of H-004 was protocol (no scale-risk review at spec freeze), not agent
error (C-2). So the rule needs an authorizing half and an enforcing half.

**Manager pre-dispatch check (the operative control, a dispatch blocker):** "No batch is dispatched
when the largest item's workload dimension is ≥10× the largest completed, timing-verified item,
unless the dispatch order carries the result of one capped, wrapper-free, single-item probe at
target scale on the frozen input (timeout ≤ 20 min, sha-cited), or a Lead-granted waiver with a
pre-registered decision rule. Timeout is an explicit input to every dispatched computation."

**Lead spec-freeze condition (makes the probe planned, not improvised):** "Spec freeze for any
computational branch includes a scale-risk review: largest-item size, largest validated item,
their ratio, and either a target-scale timing datapoint or a pre-registered capped-probe plan with
a T_slice rule (e.g. if one full-scale item exceeds 20 min, route to staged-file analysis before
any batch dispatch)."

**H-004 replay.** At ~20:30 freeze the checklist exposes 50-node-validated vs 351/401-node target
×111 configs, and the ~85-regulator SP1 rule sitting unexamined in the frozen text (C-2). The ≤
1500 s capped probe runs before batch 1 (21:31); non-completion inside T_slice answers feasibility
with zero kills; the route decision moves from 07:41 to ~21:00–22:00, avoiding the measured
8.3–9.3M tt / ~7 h cascade. Honest limit, the audit's own: the probe could not have revealed the
external 3600 s killer's existence — it did not need to; T_slice failure suffices for the route
decision. The timeout-as-explicit-input half is harness work (P0-1's second root cause).

## 4. Three further role-boundary lessons

1. **Adjudication vocabulary and record schema must be co-designed before Gate-1.** Evidence: all
   5 user-suspected defects verified — no `supported_qualified` enum (5/10 decision records split
   top-level vs assessment status), a ruling could not force the C-005 title edit, `evidence_tier`
   conflated measured RNA with derived TF quantities (16/39 OBS), tautological falsifier text, no
   delete/retire. The Lead's ruling vocabulary is a contract input to the epistemic store
   (ScoutCoder), agreed with Research pre-mission — not discovered mid-adjudication.
2. **Computation authority defaults to the Analyst staged-file route; native routes earn keep by
   demonstrated consumption.** Evidence: d7 0/18 via interface, 18/18 via the `FrozenSources`
   helper (161 calls); d8's native Boolean route produced zero scientific quantities while 121
   staged files + 878 bash calls carried all science — the native route ended a maintenance
   liability, retired only post-hoc by the audit.
3. **Verification packets are seeded with established facts; Critic verifies, it must not re-derive
   the environment.** Evidence: counterfactual S7 — Critic re-derived preflight-established
   environment facts, an estimated 5–10 % of its 16.9M pt (low confidence). Seeding costs ~nothing
   and keeps the verifier adversarial rather than exploratory.
