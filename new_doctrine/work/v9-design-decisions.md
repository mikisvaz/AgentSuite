# v9 design decisions (step 3 of 7)

Owner of record for every decision below: **Manager**. Decided items are
recorded, not re-argued. D1/D2 carry this bout's recommendation and are marked
"Manager to confirm before implementation bout" — the implementation bout
executes D2-dependent rows (CL-14, CL-22) only after confirmation.

## Decided (Manager, prior to this bout — recorded with rationale)

### DD-1. Lead stays tool-less; Critic runs the packet-correspondence check (advisory rec 1)

**Decision.** ScientificLead remains tool-less. Before every Lead gate ruling,
Critic performs a packet-correspondence check (each load-bearing number,
record id, status and quoted clause matched against the record store and cited
artifacts; verdict `corresponds`/`diverges` + divergence list appended to the
gate file) as a precondition of the ruling. One targeted record digest per
gate may be pulled through Research. Escalation to a minimal Lead read surface
is evidence-triggered (two consecutive gates with divergences a correspondence
check could not catch), never default.

**Rationale.** The Lead was the run's thinnest, highest-value role: 6
inferences / 122k pt carried five gates (d8, advisory §1). Option (b)'s
premise was effectively tested in d7 — a minimal read surface (Cortex-only) on
the adjudicator — and performed poorly: 16 zero-match `cortex_search` calls,
adjudication over a stale mirror (d7 `context_delivery_matrix.md`,
`doctrine6_vs_doctrine7_delta.md`). A small tool surface added noise, closed
no gap, and fixes no verified schema defect. Ledger row: CL-11.

### DD-2. Scale-probe rule, dual halves (advisory rec 3)

**Decision.** Manager pre-dispatch blocker: no batch is dispatched when the
largest item's workload dimension is ≥10× the largest completed,
timing-verified item, unless the dispatch order carries a capped,
wrapper-free, single-item probe at target scale on the frozen input (timeout
≤ 20 min, sha-cited) or a Lead-granted waiver with a pre-registered decision
rule. Timeout is an explicit input to every dispatched computation. Lead
spec-freeze duty: every computational branch's spec freeze includes a
scale-risk review (largest item, largest validated item, ratio, target-scale
timing datapoint or pre-registered capped-probe plan, T_slice rule: full-scale
item > 20 min ⇒ staged-file analysis before any batch dispatch).

**Rationale.** H-004: 8 × 3600 s SIGTERMs, ~7 h and 8.3–9.3M tt avoidable;
audit diagnosis was protocol (no scale-risk review at spec freeze), not agent
error (C-2). The rule needs an authorizing half (Lead, planned) and an
enforcing half (Manager, dispatch blocker) — replay shows the ≤1500 s capped
probe exposing the ×111-config batch before dispatch at 21:31, moving the
route decision from 07:41 to ~21:00–22:00. Timeout-as-input remains harness
work (P0-1 second root cause, delegated). Ledger row: CL-10.

### DD-3. Computation authority defaults to the Analyst staged-file route (advisory rec 4.2)

**Decision.** For bulk computation, the default planned route is the Analyst
staged-file package. Native task/property routes earn keep only by
demonstrated consumption (consumer role, run, artifact receipt). Helper-first
mandate wording for surface enumeration.

**Rationale.** d7: 0/18 operations via task/CLI interface, 18/18 via the
`FrozenSources` helper (161 calls) — the interface slice was dead in
consumers. d8: native Boolean route produced zero scientific quantities
(H-004 work) while 121 staged files + 878 bash calls carried all science;
the native route became a maintenance liability retired only post-hoc. The
d6 blanket "simplify" verdict is superseded by this earn-keep rule (register
§3, verdict re-test). Ledger row: CL-01.

## Open decisions (recommendation + reversibility; Manager to confirm before implementation bout)

### D1. Delegation mechanism for shared briefs

**Question.** When several packets would repeat the same substantial brief,
is the mechanism (i) one shared brief + pointer (after verifying every
recipient can read it), or (ii) per-packet self-containment (inline the brief
in each packet)?

**Recommendation.** **Hybrid, pointer-first with verified access, inline as
fallback**: default to one shared brief referenced by path, but the sender
must first verify recipient access to the exact path (or be the one who
staged it), and must inline the decision-relevant essentials in each packet
anyway — the shared brief carries the long background, never the only copy of
a decision-critical fact. Additionally, a **standing environment-facts header
in work orders** (CL-17) covers the most common repeated material (root,
mounts, sandbox scope, key paths with digests), which is exactly what d8
showed being re-derived (Critic's pwd/sandbox rediscovery, `find /`
CollecTRI2 hunt; est. 5–10% of 16.9M pt, low confidence).

**Rationale.** Collaboration guide already binds both halves: "keep one
shared brief and point to it only after confirming that every recipient can
read it" AND "a decision packet carries the essential facts… paths do not
replace inaccessible decision-critical content" — pure (ii) contradicts the
first clause, pure (i) the second. d8's rediscovery tax shows the concrete
failure mode of under-seeded packets; F-A7's pt/inf climb shows the cost of
over-stuffed contexts. The hybrid spends the shared brief on background and
the packet on facts.

**Reversibility.** High: it is a norm expressed in two short additions
(`doctrines/handoff` "Work-order format" seeded-facts field;
`Manager/start_chat` delegation-discipline sentence). Reverting is a one-line
edit per file; no schema or code depends on it.

**Decision owner.** Manager to confirm before implementation bout.

### D2. ScoutCoder submodule pointer — 488afcf vs dd19a83

**Facts.** `git submodule status`: `+488afcf` — the checkout has moved past
the parent's pinned `dd19a83` and is dirty only in `.vimproject`. 488afcf
contains `667d1e2` ("v7: ScoutCoder start_chat execution-stance block
(RB-1, RB-2, RB-CR…)" — the start_chat edit the v8 ledger reported as
uncommitted; it is now committed inside the submodule) plus `dd19a83` ("New
documentation… Chat role path_kind"). The d7/d8 runs consumed the
488afcf checkout (d8 run tree ships `.save/Agent/ScoutCoder.start_chat`
from it).

**Recommendation.** **Bump the parent to 488afcf** (`git add ScoutCoder`,
commit on doctrine-v9). Rationale: (a) it is what the runs actually consumed
— pinning back to dd19a83 would record a start_chat state the science runs
never used, breaking the consumption-provenance chain that DD-3/CL-01
require; (b) dd19a83's documentation addition is innocuous; (c) carrying the
start_chat edit as an AgentSuite-local patch (the alternative) creates a
permanent divergence between the submodule's committed start_chat and the
repo-local patch, exactly the silent-drift problem BF-5 was cut to close.

**Reversibility.** High: a submodule gitlink is one commit; revert is
`git update-index --cacheinfo 160000,<dd19a83-sha>,ScoutCoder` + commit. No
data is destroyed by either choice; the only cost of a wrong choice is one
revert commit.

**Decision owner.** Manager to confirm before implementation bout (CL-22 is
blocked on this; CL-14 edits `ScoutCoder/start_chat` inside the submodule and
inherits the same gate).
