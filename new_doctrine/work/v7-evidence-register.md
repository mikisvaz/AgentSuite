# v7 evidence register — staging header

Provenance:
- Produced by: Reader bout (Manager-routed, Planned pipeline), staged into the repo by Worker (v7 instruction editor) on 2026-11-02.
- Source carriers (the register's own SRC-A/SRC-B; the primary audit/pilot trees are unreachable from the agent sandbox):
  - SRC-A: /home/mvazque2/.scout/var/jobs/Planned/request/Default_d677f25a46c831a377a9c295783ced8a.chat.files/User.chat (raw user request, embeds the Critic-verified audit and pilot evaluation verbatim)
  - SRC-B: new_doctrine/work/v7-mandate.md — mandate body sha256 689247069120ca9ffae8e17db4474a918392a549efee277344fc28a64f2ed2ab
- Original location: /home/mvazque2/.scout/var/jobs/Planned/work/Default_438072825bc23566a6931a681de450f3.chat.files/v7-evidence-register.md (sha256 81c639f0dd5856b17520d65f4da6f277414836e063ae4c3d225ab3cb23eb8b3a; 248 lines / 36107 bytes)
- Reachability finding (Reader): the original process_xray tree and pilot job trees are NOT visible from the agent sandbox; every entry is sourced from the embedded carriers above. This is a provenance limitation, recorded here rather than hidden.
- Numbers discipline: audit and pilot numbers are cited AS PRINTED in the carriers, never recomputed by Reader or by this staging.

Reader's body follows byte-identically (verified: sha256 of body below equals 81c639f0dd5856b17520d65f4da6f277414836e063ae4c3d225ab3cb23eb8b3a).

---

# Doctrine v7 — Evidence Register

**Role:** Reader (evidence intake). This register distills the Critic-verified
doctrine6 process X-ray audit and the AGS Stage-1 integration pilot evaluation
into a single citable evidence register for the v7 mandate. It extracts and
locates; it does not adjudicate what the evidence warrants — that belongs to
the Research agent consuming this register.

**Reachability verdict (both audit copies):**
- **COPY 1 (job run root)** `/home/mvazque2/.scout/var/jobs/FitAgent/use_case/AGS.full.scout.glm5.doctrine6_d9232750ed4670c4e8e7c7c626766e1a` and its `.files/AGS` mission-files copy: **NOT REACHABLE** from this sandbox (`No such file or directory`; the `/home/mvazque2/.scout/var/jobs` tree contains only a `Planned/` subtree).
- **COPY 2 (sandbox scenario copy)** `/home/mvazque2/git/sandbox/Scenarios/runs/AGS.full.scout.glm5.doctrine6_d9232750ed4670c4e8e7c7c626766e1a/process_xray/`: **NOT REACHABLE** (`/home/mvazque2/git` is not present in this sandbox at all; a `find` over `/home/mvazque2` returned no `process_xray`, `doctrine6_process_xray.md`, or `remediation_backlog.md` anywhere).

Because neither primary audit copy is reachable, this register does not re-derive
or recompute anything. Instead it sources every entry from the two **reachable,
authoritative, embedded** carriers of the same Critic-verified content, both of
which are the audit's own words as passed forward into the v7 pipeline:

- **SRC-A** — the full raw user request, which embeds (i) the final Critic-verified
  audit report in full, (ii) the Workstream C (friction register) and Workstream D
  (role/Manager) findings in full, (iii) the pilot evaluation report in full (twice),
  (iv) the Stage-1 `research_request.md` in full, (v) the post-pilot architecture
  discussion, and (vi) the v7 mandate.
  - Path: `/home/mvazque2/.scout/var/jobs/Planned/request/Default_d677f25a46c831a377a9c295783ced8a.chat.files/User.chat`
  - Size: 6,682 lines / 513,238 bytes. Locators below are 1-based line numbers in this file.
- **SRC-B** — the v7 mandate, extracted verbatim from SRC-A's `WritingBlock id="73184"`
  and pinned to disk (sha256-attested in its provenance front-matter).
  - Path: `/bulk/mvazque2/git/AgentSuite/new_doctrine/work/v7-mandate.md`
  - Size: 452 lines. Locators below are 1-based line numbers in this file.

The prior redesign reports under `/bulk/mvazque2/git/AgentSuite/new_doctrine/work/redesign-*.md`
were located and available for orientation but are **deliberately excluded** from this
register's scope (the task says skim only to avoid duplication; they are not the
audit backlog or the pilot evaluation).

**Verification-status legend used in entries (mandate §1, SRC-B lines ~60–70):**
`implementation verified` / `runtime tested` / `observed in a mission` /
`proposed` / `estimated`. Where the audit itself labels a figure (FACT /
INTERPRETATION / ESTIMATE, or "validated", "labeled estimate"), that label is
preserved verbatim and the register's own status is derived from it.

**Mandate mapping note.** The v7 mandate (SRC-B §2) organizes the lessons as
A–H and explicitly names which RB item each addresses: RB-1→§2.A, RB-3→§2.B,
RB-2→§2.C, RB-4→§2.D, RB-5→§2.H, plus RB-6/RB-7 as the P2/P3 scope-discipline and
epistemic-preservation items (SRC-A line 5886). The register's entries are grouped
to match those concerns.

---

## PART 1 — Audit remediation backlog (RB-1 … RB-7)

The seven RB items are named with their priority and one-line definition in the
Critic-verified final report (SRC-A line 5886), and the backlog item *schema*
(evidence citation, root-cause category, owner class, effort, risk, runnable
acceptance test) plus the P0–P3 grouping definitions are in the audit charter
(SRC-A lines 3327–3356). Per-item observed episode, diagnosis, and
counterfactual/remediation follow.

> **Close-reading limitation:** `remediation_backlog.md` itself (RB-1..RB-7 as
> individual blocks with per-item effort/risk/acceptance-test fields) lives in the
> unreachable `process_xray/` tree. The register therefore cites the final
> report's per-item statements (which the report says "independently reviewed —
> Critic gate PASS, all 7 spot-checked findings supported", SRC-A line 5886) and the
> post-audit discussion of each mechanism, rather than transcribing the backlog file.
> No per-item effort/risk fields are reproduced because they could not be read.

### RB-1 — Planning-revision trigger when consumption evidence contradicts the build plan (P0, small)
- **Source / locator:** SRC-A line 5886 (item definition + priority); line 5858 (item (iii) of the four compounding failures); line 5933 (§2 "the dominant failure was a missing feedback loop"); SRC-B §2.A lines 66–82 ("This is the central lesson of RB-1.").
- **Quote (tight paraphrase, labeled):** The final report states "wave 2 (60.6M pt, the single largest phase) was dispatched after branches B and C had already reported falling back to frozen files, and that contradicting evidence never triggered a strategy revision" (SRC-A line 5858, item iii). The discussion adds: "the largest build wave began after contradictory consumption evidence was already available" and that "RB-1 makes the mismatch consequential. When consumption evidence contradicts the build assumptions, stop the next wave and require an explicit strategy decision" (SRC-A lines 5933–5940).
- **Observed episode:** Branches B and C reported frozen-file fallbacks (23:19, 23:54, SRC-A line 4691) before wave 2 was dispatched.
- **Diagnosis (mechanism):** no protocol/planning revision trigger existed for contradicting consumption evidence; a completed design/implementation task was treated as continuation authorization.
- **Counterfactual / remediation:** a planning-revision trigger that stops the next dependent wave and requires an explicit Lead strategy decision; SRC-B §2.A ("Do not continue a large implementation wave simply because the preceding design or implementation task completed.").
- **Verification status:** `observed in a mission` (episode) + `proposed` (the trigger control itself, since it was not implemented in doctrine6).

### RB-2 — Consumer-environment verification slice + probe before build waves (P0, medium)
- **Source / locator:** SRC-A line 5886 (definition); line 5858 (item i: "loadability was probed only in ScoutCoder's own environment, never in a consumer-representative sandbox"); lines 5929–5931 ("RB-2 must test consumer suitability, not merely loadability"); SRC-B §2.C lines 101–124 ("This is RB-2.").
- **Quote (tight paraphrase, labeled):** "It should not merely verify that an interface *loads*. It should verify that it is **usable and appropriate for a representative consumer workload**, including performance. Otherwise we risk passing a loadability test and still building an interface that consumers reasonably bypass" (SRC-A line 5931).
- **Observed episode:** Branch B preferred streaming for performance over the entity-property interface; a loadability-only gate would have missed it (SRC-A lines 5882, 5929).
- **Diagnosis (mechanism):** the substrate was validated by its own tests in the builder's environment, not by a consumer-facing vertical slice exercising availability, representative operations, and performance.
- **Counterfactual / remediation:** a representative consumer-facing vertical slice before any substantial build wave; SRC-B §2.C enumerates the five checks (available / operation performable / outputs correct / performance acceptable / fallback understood) and the five distinct interface-failure classes, and "Do not call all these cases 'loadability failure'" (SRC-B line 122).
- **Verification status:** `observed in a mission` (the bypass episode) + `proposed` (the slice control).

### RB-3 — Declared gates exercised or renegotiated, never silently waived (P1)
- **Source / locator:** SRC-A line 5886 (definition); line 5858 (item ii: gate waived, "implementation was dispatched one minute after the design returned 'PROPOSED'"); line 5882 (gate quote "PROPOSED — awaiting Lead endorsement" never closed; "zero Lead messages between design (21:45) and the implementation ask (21:46)"); line 4717 ("Step 4 of the plan required Lead endorsement, the Manager repeated it in the design packet, and then dispatched implementation without satisfying it"); line 5970 (gate-state framing); SRC-B §2.B lines 84–99 ("This is RB-3.").
- **Quote (tight paraphrase, labeled):** "A gate has a state, and a declared pending state cannot silently become approved because the delegated design task finished" (SRC-A line 5970).
- **Observed episode:** the design returned `PROPOSED — awaiting Lead endorsement`; implementation was dispatched 21:46, one minute later, with zero Lead messages in between.
- **Diagnosis (mechanism):** a `PROPOSED — awaiting approval` status was treated as descriptive text rather than an enforceable precondition; task completion was conflated with gate approval.
- **Counterfactual / remediation:** gates with enforceable states (approved / rejected / returned / explicitly waived / pending); a completed delegated task does not imply approval, and a Manager cannot silently waive a ScientificLead decision; SRC-B §2.B.
- **Verification status:** `observed in a mission` (the waiver) + `proposed` (the enforceable-state rule).

### RB-4 — Delegation-packet assembly norms; decision-relevant information must reach the Lead (P1)
- **Source / locator:** SRC-A line 5886 (definition: "shared briefs instead of boilerplate re-send"); lines 4684–4730 (Workstream D Manager finding, "the most important new finding"); line 5884 (handoff-quality figures); SRC-B §2.D lines 126–136 ("This addresses RB-4 and the observed Lead information-starvation problem.").
- **Quote (tight paraphrase, labeled):** "Branch B reported that it was using streaming rather than the entity-property interface at 23:19. Branch C reported a similar deviation at 23:54. The Manager received those returns. The mid-flight Lead packet at 00:25 contained no mention of fallback, deviation, sandbox, streaming or the substrate surface. The subsequent D4 and D5 review packets also contained none of those terms. The report attributes **146 occurrences of fallback/deviation in the Manager's own function outputs, while finding none in the three Lead review packets**" (SRC-A lines 4684–4697).
- **Observed episode:** the Manager filtered deviations out of every ScientificLead packet; the report's own framing is "ScientificLead was not failing to reconsider the strategy. It wasn't given the relevant information" (SRC-A line 4703).
- **Diagnosis (mechanism):** packets described where evidence supposedly existed instead of carrying it; a self-contained packet must contain the decision-relevant evidence, not a pointer; ~130k chars (audit's character-count estimate) of boilerplate were re-sent across packets — 23/27 delegations were self-contained, the failure was specific to the Lead-facing packets — while the load-bearing deviations were dropped (SRC-A line 5884; SRC-B line 132).
- **Counterfactual / remediation:** "A Manager must not only summarize progress; it must preserve information that could invalidate the current plan" (SRC-A line 4705); do not omit a fallback because it makes a branch report look cleaner; SRC-B §2.D and the Manager "Must/Must not" list.
- **Verification status:** `observed in a mission` (the 146-vs-0 count, "The report attributes…") + `proposed` (the forwarding obligation as a doctrine rule).

### RB-5 — Exec-task failure transparency (surface sandbox failures to the Manager, not just the executing agent) (P1)
- **Source / locator:** SRC-A line 5886 (definition); Workstream C, SRC-A lines 4546–4650 (friction register C01–C22, esp. C01/C02); SRC-B §2.H line 191 ("RB-5 should be addressed in the relevant harness/tooling documentation and failure-reporting contract, not hidden in general doctrine.").
- **Quote (tight paraphrase, labeled):** "All 62 are exec-tool launch failures: bash 55, ruby 5, python 2. Every stderr reads `Process failed - bwrap /usr/bin/bwrap --unshare-all ... [full argv elided]`, exit_status −1" and "Verdict: **harness defect (4c)** — behavior contrary to documented intent; the exec task documents sandboxed execution, not silent launch failure with the cause elided" (SRC-A lines 4560, 4569).
- **Observed episode:** 62 raw / 61 deduplicated bwrap exit −1 failures across the run; the failure cause was elided and invisible to the agents, so they blind-retried or adapted on the next call (SRC-A lines 4560–4573).
- **Diagnosis (mechanism):** the failure was a harness/launch defect, but the error surface did not distinguish it from a scientific/computational failure, and the information did not propagate to the Manager.
- **Counterfactual / remediation:** surface sandbox/launch failures to the Manager, not just the executing agent, so tool failures can be separated from failed assumptions; kept as a harness/tooling contract item, not general doctrine; SRC-B §2.H.
- **Verification status:** `observed in a mission` (the 61 failures, FACT) + `independently reviewed` (the defect classification is the audit's own "confidence high" verdict; the transparency control itself is `proposed`).

### RB-6 — Interface scope discipline with post-mission consumption accounting (P2/P3)
- **Source / locator:** SRC-A line 5886 (definition: "RB-6 interface scope discipline with post-mission consumption accounting"); line 5862 (computational-surface verdict); line 5880 (recomputed accounting basis); line 5957 ("a well-tested interface is not necessarily a useful interface").
- **Quote (tight paraphrase, labeled):** "The **computational surface did not** (simplify): branches used the substrate's path resolver as plumbing 17× but bypassed its operations; it proved its own correctness by test, not by use" (SRC-A line 5862).
- **Observed episode:** the substrate's own tests passed while real downstream adoption of its operations was minimal (scientific branches consumed only 1 of 22 operations through the substrate interface — SRC-A line 5858).
- **Diagnosis (mechanism):** scope was not held to demonstrated consumer need; interface value was judged by the builder's tests rather than by measured consumption.
- **Counterfactual / remediation:** interface scope discipline plus post-mission consumption accounting; promote computations to reusable infrastructure only on recurring need and consumer value; SRC-B §2.E.
- **Verification status:** `observed in a mission` (the low-consumption figure, from the validated reconstruction) + `proposed` (the accounting discipline).

### RB-7 — Preserve epistemic-record discipline with a sampling check (P2/P3)
- **Source / locator:** SRC-A line 5886 (definition: "RB-7 preserve epistemic-record discipline with a sampling check"); line 5862 (epistemic-surface verdict); SRC-B §2.E lines 155–167 (preserve the epistemic behaviors; do not mandate a specific API/Cortex/storage mechanism).
- **Quote (tight paraphrase, labeled):** "The **epistemic record surface earned its keep** (preserve): 46 observations with a dense cross-agent citation graph — branch packets quoted D1 acceptance criteria verbatim, Lead adjudications cited specific O-records, the curator's own controls caught two registration-defect batches before consumption" (SRC-A line 5862).
- **Observed episode:** 46 observations with a dense cross-agent citation graph; the curator's own controls caught two registration-defect batches before consumption.
- **Diagnosis (mechanism):** [interpretation, the audit's inference — mechanism-independence was not tested] the value came from the discipline and the relationships between records, not from any specific Path-kind/Cortex/storage implementation; the value should be preserved while the mandated mechanism is made optional (SRC-A line 5955).
- **Counterfactual / remediation:** preserve the epistemic-record discipline (observations linked to evidence, claims separated from observations, status authority, falsifiers) and add a sampling check; do not make a particular API/Cortex resource/storage mechanism mandatory; SRC-B §2.E.
- **Verification status:** `observed in a mission` (the 46-observation / two-defect-batch evidence) + `proposed` (the sampling check as a control).

### RB-CX — Cortex net-neutral verdict: optional infrastructure (supports mandate §2.F)
- **Source / locator:** SRC-A line 5862 (surface verdicts); SRC-B §2.F lines 155–164.
- **Quote (as printed):** "**Cortex was net-neutral** (make optional): its entire realized value was one evidence-digest recovery read and one process-diagnostic block; four pointer artifacts were written and never read" (SRC-A line 5862).
- **Observed episode:** across the doctrine6 mission, Cortex use realized one recovery read and one diagnostic block of value, while four pointer artifacts were written and never read.
- **Diagnosis (mechanism):** a persistence layer invoked as a default routing step produced write-without-consumer artifacts; net value ≈ zero.
- **Counterfactual / remediation:** mandate §2.F — Cortex is optional; use it for genuine cross-session/cross-project persistence, retrieval and reuse; do not create pointer artifacts nobody consumes or route evidence through Cortex when ordinary project files suffice.
- **Verification status:** `observed in a mission` (the one-mission verdict, as printed in the Critic-verified audit) — single-mission basis; not a cross-mission measurement.

### RB-CR — Critic mis-scoping episode: environment failure scoped "Critic sandbox only" (supports mandate §2.H and §4 Critic)
- **Source / locator:** SRC-A line 5858 (item iv of the four compounding failures); SRC-B §2.H lines 181–192; SRC-B §4 Critic ("It must not treat a failure in its own environment as proof that the consumer will fail, or proof that the consumer will succeed.").
- **Quote (as printed):** "the Critic observed the load failure in a fresh process, correctly caught it, but mis-scoped it as 'Critic sandbox only' and advised proceeding" (SRC-A line 5858, item iv).
- **Observed episode:** the Critic correctly detected the substrate load failure in a fresh process (a real signal), but scoped its conclusion to its own sandbox and advised proceeding — which contributed to wave 2 launching on a bypassed interface.
- **Diagnosis (mechanism):** a correct detection was paired with an unsupported generalization and an unscoped recommendation; a failure observed in one environment licenses neither "the consumer will fail" nor "only my sandbox fails".
- **Counterfactual / remediation:** mandate §2.H / §4 Critic — an environment-specific finding must be scoped and its transferability stated; the Critic must not give proceed/stop advice that its evidence does not support; report the exact environment and operation tested.
- **Verification status:** `observed in a mission` (the episode itself); the scope-and-limitation rule is `proposed`.

### Cross-cutting audit headline numbers (cited as printed, not recomputed)
- **Source / locator:** SRC-A line 5880 ("Recomputed accounting … validated; from `resource_breakdown.tsv`, deduplicated by `inference_id`"); line 5882 ("ScoutCoder reconstruction … validated; findings F-B1..F-B5 in `_B_summary.md`, verified from chats"); line 5862 (surface verdicts); line 5894 (Caveats).
- **Quote (as printed):** 2,728 inference events; 253.45M total tokens, 97.45% of prompt tokens cached; wall clock 8.20 h; 27 logical Manager delegations. ScoutCoder substrate program = 1,198 inferences / 135.31M prompt tokens = 53.7% of mission prompt volume. Phase split: probes 24.84M / design 4.78M / wave-1 45.09M / wave-2 60.60M pt. Counterfactual minimal-substrate path 45–65M pt vs 135.31M actual = "~70-90M pt of 253.1M mission tt (28-35%), roughly half of ScoutCoder volume; dollar saving ~10x smaller due to ~98% cache rates." Corrected evaluator figures: "Critic 538 inferences" → 269; "85 sandbox −1 failures" → 61 (deduplicated); wall clock 8.20 h (after the 8.04 h endpoint-only figure was corrected at the gate). Audit's own cost: 10 named conversations, 829 inferences, 82.3M tt (F-integration conversation uncounted, stated in the report).
- **What it evidences:** the dominant waste is a protocol/planning failure (the missing revision trigger + the waived gate), not tooling; the harness defect (61 bwrap exit −1) is real but ~10× smaller in cost than one ScoutCoder wave.
- **Verification status:** the accounting and ScoutCoder reconstruction are labeled **validated** by the audit (recomputed from provenance, Critic-checked); the 28–35% saving is a **labeled bounded estimate** (SRC-B line 448: "Treat the doctrine6 counterfactual saving of 28-35% as a bounded estimate, not an expected guaranteed saving"); the "~10x smaller dollar saving" is likewise estimate-grade (its premise, the ~98% cache rate, comes from the counterfactual quote — a different basis than the 97.45% accounting figure; cite one basis per use).

---

## PART 2 — Pilot (Stage 1) evaluation and deliverables

**Source / locator (all of Part 2):** SRC-A lines 5091–5239 (first copy of the evaluation report, "Evaluation Report — AGS Integration Pilot, Stage 1 (Research scoping bout)"; a second, identical copy begins at line 5510 — the two were diffed and are byte-identical except for a trailing shell prompt on the second copy), lines 5215–5240 (the pilot session report and its `cat` of the three deliverables), lines 5241–5508 (`research_request.md` in full), and lines 5634–5847 (post-pilot discussion). Run under evaluation: FitAgent use case `Default_2916f5207a29c649a9f157189ad3f8d0`, chat `…/main.chat` (197 messages, 62 inferences, glm-5.3); evaluation at `analyze/Default_153e51b008af27be4b4145795a0f9e35.md`; deliverables `integration_pilot/01_research_scope/{research_request.md, bundle_manifest_request.tsv, lead_review_packet.md}` (SRC-A line 5093, 5233).

> **Location limitation:** the three pilot deliverable files themselves live under
> the unreachable `Default_2916f5207a29c649a9f157189ad3f8d0.files/AGS…/integration_pilot/`
> tree. `research_request.md` IS embedded verbatim in SRC-A (lines 5241–5508) and is
> quoted below from there; `lead_review_packet.md` and `bundle_manifest_request.tsv`
> are not reproduced in full in SRC-A — they are referenced through the evaluator's
> findings and the session report (SRC-A lines 5226–5233), which is how the two
> evidence-propagation defects are documented.

### P-1 — Evidence-propagation defect #1: false cutoff-variant claim presented as *validated*
- **Source / locator:** SRC-A line 5103 (defect 1 in §A Executive assessment); line 5149 (the "(Error)" row of §D Critical scientific audit table); line 5229 (the false sentence as it appeared in the session report); line 5130 (P4 provenance deduction).
- **Quote (tight paraphrase, labeled):** "the lead-review packet and the session report state as *validated* one claim that is **false** — that the FOXO1/RFX1 identical value persists in both cutoff-variant columns of `tf_predictions_extended.tsv` (my verification: cutoff_0.5 has FOXO1 empty and RFX1 = −3.1849155; cutoff_1 both empty; the trio, not the pair, is what persists across variants — the research_request.md states this correctly, so the error is confined to the packet/report)" (SRC-A line 5103).
- **Observed episode:** session-report sentence "the identical value also persists in both cutoff-variant columns of `tf_predictions_extended.tsv`" (SRC-A line 5229) is false; the evaluator's direct scan shows the pair does NOT persist (only the trio does).
- **Diagnosis (mechanism):** a check explicitly deferred mid-bout ("whatever — the Analyst will check", main.chat line 288) was then asserted as validated in the decision-facing packet — a `validated` label applied to an unchecked statement.
- **Counterfactual / remediation:** reconciliation-before-handoff rule — "Before handing evidence to another role, reconcile the final packet against the authoritative request and the evidence table. Every statement marked validated must have been checked" (SRC-A line 5675); "every statement marked validated must actually have been checked, reconciled against the authoritative request before handoff" (SRC-A line 6612, the restated-request guidance).
- **Verification status:** the underlying data check is `runtime tested` (evaluator's independent scan); the defect is `observed in a mission`; the remediation rule is `proposed`.

### P-2 — Evidence-propagation defect #2: mid-bout magnitude correction never carried into deliverables
- **Source / locator:** SRC-A line 5103 (defect 2); line 5131 (P5 regression note); line 5150 (the "(Error)" row, rank computation); line 5667–5669 (discussion §2).
- **Quote (tight paraphrase, labeled):** "the importance framing 'among the largest early signals in that column' for the NF-κB score −32.138268 — it is exactly the **median** |score| of the 65 called FiveZ-T1 TFs (rank 33/65); the session's own mid-bout reasoning identified this ('middle of the pack by magnitude… "largest early signal" is wrong', main.chat line 288) and the deliverables still inflated it" (SRC-A line 5103). The evaluator's rank computation: "|score| rank 33/65 = exact median; 56/716 T1 cells (7.8%) have |score| ≥ 32.138268" (SRC-A line 5150).
- **Observed episode:** the agent caught the magnitude over-claim in its own reasoning (main.chat line 288) but the deliverables still carried "one of the largest early signals in the whole matrix" (SRC-A line 5275).
- **Diagnosis (mechanism):** a correction identified mid-bout did not propagate into the final artifacts — the session "was capable of correcting itself, but the correction did not reliably propagate into its final artifacts" (SRC-A line 5669).
- **Counterfactual / remediation:** the same reconciliation-before-handoff rule (SRC-A lines 5675, 6612) and the NF-κB magnitude reframing to "median in-column, not 'largest'" (SRC-A line 6612).
- **Verification status:** `runtime tested` (evaluator's recomputation) / `observed in a mission` (the uncarried correction) / `proposed` (the rule).

### P-3 — Injectivity / scalar-collision fallacy (FOXO1 vs RFX1, same scalar under a non-injective statistic, 7-significant-digit rounding)
- **Source / locator:** SRC-A line 5227 (the claim as it stood in the session report); lines 5293–5330 (`research_request.md` §Current evidence item 2, the injectivity assertion); lines 5679–5744 (discussion §3, the mathematical correction); line 5163 / 5582 (evaluator's §E framing, "injectivity argument" accepted with a TF-identity-normalization caveat); SRC-B §2.G line 175 ("Do not mistake an exact scalar collision for proof that two inputs are identical. Different input vectors can yield the same scalar under a non-injective statistic. Rounded equality is weaker still.").
- **Quote (tight paraphrase, labeled):** The request argued "Two distinct ±1 weight vectors of different lengths over different targets cannot yield the same statistic to 7 significant digits under any per-TF computation" (SRC-A line 5227; also lines 5322–5326). The correction: "There is no reason to assume that $f$ is injective… $X_1 \neq X_2 \not\Rightarrow f(X_1) \neq f(X_2)$… Scalar summaries of high-dimensional data are inherently many-to-one. Rounding to seven significant digits makes the argument weaker still, because values need only fall into the same rounding interval… I would therefore remove the phrase *impossible under any per-TF statistic*" (SRC-A lines 5687–5742).
- **Observed episode:** FOXO1 (178 dynamic rows) and RFX1 (17 dynamic rows) share exactly 1 row of 194 (Jaccard ≈ 0.005, shared row ID2 w=1.0 FC1 −0.8134585) yet carry a bit-identical score −1.9719417 to 7 significant digits.
- **Diagnosis (mechanism):** treating an exact scalar collision as proof of input identity is mathematically invalid for a non-injective statistic; rounding to 7 significant digits weakens it further. The evaluator had accepted the injectivity argument with only a TF-specific-normalization caveat, but "even a common scoring function applied identically to every TF need not be injective" (SRC-A lines 5709–5716).
- **Counterfactual / remediation:** remove the "impossible under any per-TF statistic" framing; investigate the collision as an anomaly, not a proof; the inference-validity rule goes into Research and Critic instructions (SRC-A line 6612); SRC-B §2.G.
- **Verification status:** the collision data are `observed in a mission` (independently reproduced by the evaluator); the injectivity argument as it stood was **mathematically invalid** (identified by the post-pilot discussion); the corrected rule is `proposed`.

### P-4 — Sequencing defect: Lead authorization deferred until after the Analyst-side execution
- **Source / locator:** SRC-A lines 5763–5812 (discussion §5 "The next stage should be ScientificLead, not Analyst"); SRC-A line 6613 (restated-request guidance: "ScientificLead authorization (go/no-go, scope) must occur before the Analyst executes, not after"); SRC-A lines 5241–5248 (`research_request.md` header, "Status: scoping only"); SRC-B §2 (the flexible scientific work cycle places ScientificLead approval before Analyst computation).
- **Quote (tight paraphrase, labeled):** "The research request explicitly says that the Lead owns three decisions: 1. Whether to authorize the investigation. 2. Whether the constant search should include the relevant variant columns. 3. How the previous contradiction-register entry should be amended depending on the result. Those are decisions required to define the computational work. They should happen before the Analyst executes it… This means the ScientificLead stage in the original pilot should be brought forward as a preliminary authorization stage. Its later adjudication remains necessary after Research interprets the Analyst's results" (SRC-A lines 5765–5812).
- **Observed episode:** the pilot's own framing placed the ScientificLead stage *after* the Analyst would execute, even though the Lead's three decisions are what define the computational work.
- **Diagnosis (mechanism):** the authorization gate was sequenced after the execution it is supposed to authorize — the Lead's go/no-go and scope decisions were deferred until after Analyst-side execution rather than preceding it.
- **Counterfactual / remediation:** bring ScientificLead forward as a preliminary authorization stage (go/no-go, scope, interpretation boundaries, and the corrected false implication) before the Analyst executes; later adjudication remains a separate step; SRC-B §2 work cycle and line 6613.
- **Verification status:** `observed in a mission` (the pilot's sequencing) / `proposed` (the corrected Lead-before-Analyst gate).

### P-5 — "Validated" labels applied to unchecked statements (the general defect)
- **Source / locator:** SRC-A line 5130 (P4: "the unvalidated cutoff-propagation claim presented as 'validated, direct file scans' in packet item 3"); line 5134 (P8: "the session report's 'all validated by direct file scans' is contradicted by one false sub-claim"); line 5226 (the session report's blanket claim "**Evidence established this bout (all validated by direct file scans, cited in the request):**"); line 5173 / 5592 (F: "the only place where the run's normally disciplined evidence labeling broke").
- **Quote (tight paraphrase, labeled):** the session report asserts a blanket "all validated by direct file scans" (SRC-A line 5226), but the evaluator found one false sub-claim inside it (SRC-A line 5134) and an explicitly-deferred check asserted as fact (SRC-A line 5131).
- **Diagnosis (mechanism):** a blanket validation label over a packet lets one unchecked/false sub-claim ride along with the validated ones; the defect belongs to the evidence-labeling discipline, and "both are the kind of defect an acceptance-gated downstream stage would catch — which is itself evidence the run's handoff design works" (SRC-A line 5199/§I).
- **Counterfactual / remediation:** the reconciliation-before-handoff rule (every `validated` statement actually checked, reconciled against the authoritative request) — SRC-A lines 5675, 6612; SRC-B §2.G line 179 ("Corrections made during a work session must propagate into final artifacts and handoff packets. Do not let a mid-bout correction disappear from the final report.").
- **Verification status:** `observed in a mission` (the label-vs-reality mismatch) / `proposed` (the rule).

### Pilot context figures (cited as printed, not recomputed)
- **Source / locator:** SRC-A lines 5093, 5119 (§B total), 5135 (§C total), 5177–5187 (§G resource assessment).
- **Quote (as printed):** 62 inferences, single model glm-5.3, single session/agent, no delegation. Tokens (deduplicated, root chat): pt 4,848,581; ct 132,888; tt 4,981,469; cache-read 4,671,040 (96.3% of prompt tokens); fresh spend ≈ 423k tokens. 64 unique tool calls (43 bash, 8 read, 5 list_directory, 3 write, 2 tsv_info, 1 pwd, 1 CollecTRI_association_details, 1 CollecTRI — failed >100k char cap, 1 bash non-zero exit); 2 failures total, both recovered. Wall clock ≈ 36.7 min producing. Scientific quality score 67.5 (75.0/90 excluding out-of-scope S6); Research-process score 82.5. Primary results independently reproduced in full by the evaluator; one moderate false secondary claim (cutoff propagation) and a minor-to-moderate magnitude inflation; no critical or major errors.
- **What it evidences:** the Stage-1 scoping bout was high quality and its primary findings reproduce; the defects are confined to evidence-propagation/labeling, which is exactly the class the v7 reconciliation rule targets.
- **Verification status:** `runtime tested` (evaluator's independent reproduction) for the primary numbers; `observed in a mission` for the scoring; `estimated`/labeled for the rubric-based ratios.

---

## PART 3 — Pilot `research_request.md` (Stage 1 deliverable, embedded verbatim in SRC-A lines 5241–5508)

Included because the register's task is to extract the pilot deliverables with
citations and this is the one deliverable present in full. Its role: the
authoritative contract against which the evaluation found the packet/report
deviated. (Per the task's "extract only what maps to the mandate's concerns", only
the sections that map to the v7 lessons are extracted.)

- **Question (SRC-A line 5249):** whether the three bit-identical TF-score groups (NFKB2/RELA/RELB at FiveZ-T1 & PD-T1; FOXO1/RFX1 at FiveZ-T24) are explainable from identical recorded substrates (legitimate) or carry a score no per-TF statistic can produce (artifact). This is the "impossible-if-distinct" framing that P-3 later had to correct.
- **Current evidence item 2 — the injectivity assertion (SRC-A lines 5320–5330):** "Two distinct ±1 weight vectors of different lengths over different targets cannot yield the same statistic to 7 significant digits under any per-TF computation; measure-zero coincidence aside, this pair is effectively proof of non-per-TF provenance for that score." (This is the claim P-3 removes.)
- **Current evidence item 4 — propagation (SRC-A lines 5336–5348):** states the trio (correctly) propagates to both cutoff variants; the *pair* propagation sentence is absent here — which is why the evaluator notes "the research_request.md states this correctly, so the error is confined to the packet/report" (SRC-A line 5103).
- **Interpretation boundaries (SRC-A line 5471):** "An `impossible-if-distinct` verdict establishes non-per-TF provenance of that score value; it does not locate the defect… Failure to reproduce the score with candidate statistics does not prove the pipeline wrong."
- **Reuse assessment (SRC-A line 5491):** "Preliminary judgment, not implementation approval… whether it becomes a permanent workflow task (ScoutCoder's domain) is a decision for later stages, not this bout."
- **Appendix (SRC-A line 5503):** reference cells for reconciliation detail.
- **Verification status:** the request's figures are labeled "validated this bout by direct scans of the named files" by the request's own header (SRC-A line 5295); the register does not independently re-run those scans.

---

## PART 4 — Mandate concerns (SRC-B) that the register must map to

The v7 mandate (SRC-B) is the authority on what maps. The register above is
organized to these; the explicit RB→mandate-section mappings are:
- RB-1 → SRC-B §2.A (lines 66–82)
- RB-3 → SRC-B §2.B (lines 84–99)
- RB-2 → SRC-B §2.C (lines 101–124)
- RB-4 → SRC-B §2.D (lines 126–136)
- RB-6/RB-7 → SRC-B §2.E (lines 155–167, epistemic preserve / computational simplify)
- RB-5 → SRC-B §2.H (line 191)
- Pilot injectivity → SRC-B §2.G line 175; corrections-propagation → SRC-B §2.G line 179
- 28–35% bounded-estimate treatment → SRC-B line 448

Workstreams A and C were not extracted as their own entries (per the task: "Workstreams
A and C only if RB items cite them"). Workstream D (the 146-vs-0 Manager finding) is
extracted inside RB-4 (Part 1) because RB-4 cites it. Workstream C's bwrap exit −1
findings are extracted inside RB-5 (Part 1) because RB-5 cites them.

---

## Register limitations and extraction caveats
1. **Neither primary audit copy is reachable** (see top verdict). All audit content is
   sourced from SRC-A (the embedded final report + Workstream C/D + pilot evaluation)
   and SRC-B (the pinned mandate), which are the same Critic-verified content carried
   forward into the v7 pipeline. The register does not re-derive or recompute any number.
2. **`remediation_backlog.md` (the per-RB block file) is not reachable.** Per-item
   effort/risk/acceptance-test fields could not be read; only the final report's
   per-item statements and the post-audit discussion are cited. The report states the
   backlog was "independently reviewed — Critic gate PASS, all 7 spot-checked findings
   supported" (SRC-A line 5886).
3. **Pilot deliverables `lead_review_packet.md` and `bundle_manifest_request.tsv` are not
   reproduced in full in any reachable source.** They are referenced through the
   evaluator's findings and the session report (SRC-A lines 5226–5233), which is how the
   two evidence-propagation defects (P-1, P-2) are documented.
4. **The two pilot-evaluation copies (SRC-A lines 5091–5214 and 5510–5633) are
   byte-identical** apart from a trailing shell prompt on the second; locators cite the
   first copy (5091–5239) for the report and the second copy (5510–5633) where a line
   only appears there.
5. **Prior redesign reports** (`/bulk/mvazque2/git/AgentSuite/new_doctrine/work/redesign-*.md`)
   were available but intentionally excluded (out of scope for this register; skim-only).
6. **Workstreams A and C** are cited only insofar as RB items cite them (A via the
   handoff/boilerplate figures in RB-4; C via the bwrap/ExTRI2 friction in RB-5). No
   independent A/C entries were produced.

7. **Post-staging corrections (applied 2026-11-02 by Worker, from the ChatAnalyst register review — recorded here, not applied silently):**
   - RB-2 heading: dropped the embedded "~70–90M pt fix" estimate from the item name (the body keeps it labeled as bounded estimate; the heading is no longer the one place an estimate read as fact).
   - RB-5 verification status: `implementation verified` → `independently reviewed` for the defect classification (the legend reserves the former for verified implementations; the audit's own wording is "confidence high for the defect classification").
   - RB-4 diagnosis: dropped "across 27 packets" precision (source says boilerplate "across packets", ≈130k character-count estimate; the 27 is the delegation count, and 23/27 delegations were self-contained — the failure was specific to Lead-facing packets).
   - RB-7 diagnosis sentence labeled `[interpretation]` — the audit's mechanism-independence inference was never tested, so it is stated as inference, not fact.
   - Headline numbers: both cache figures noted — 97.45% (accounting) vs "~98%" (inside the counterfactual quote); the "~10x smaller dollar saving" flagged estimate-grade with its differing basis.
   - TWO MISSING ENTRIES ADDED: **RB-CX** (Cortex net-neutral verdict — one recovery read, one diagnostic block, four pointer artifacts written and never read; SRC-A 5862) and **RB-CR** (Critic mis-scoping — load failure caught in a fresh process but scoped "Critic sandbox only" and advised proceeding; SRC-A 5858 item iv). Both were carried by the audit but never extracted; they supply the direct evidence for mandate §2.F / test 9 and §2.H / test 4 respectively.
