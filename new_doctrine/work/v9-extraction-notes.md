# v9 extraction notes — doctrine-9 evidence register (step 2 of 7)

Reader extraction + completeness verification over the three process_xray audit trees.
Process evidence only; no adjudication of scientific claims. Every finding cites
`<run-root-short>/process_xray/<file>` plus a section/heading anchor. Statements marked
[quote] are verbatim from the cited file; unmarked items are faithful condensations.

Run roots (abbreviated below as d6/ d7/ d8/):
- d6: `~/git/sandbox/Scenarios/runs/AGS.full.scout.glm5.doctrine6_d9232750ed4670c4e8e7c7c626766e1a/AGS/process_xray/`
- d7: `~/git/sandbox/Scenarios/runs/AGS.full.scout.glm5.doctrine7_21c70f5c34f5e8792cc5cf39ba6f97f1/AGS/process_xray/`
- d8: `~/git/sandbox/Scenarios/runs/AGS.full.scout.science.v2.doctrine8_66c09b60223d3f876df84a64ab42584c/AGS/process_xray/`

All trees readable from this environment (Workspace `read`, `list_directory`, TSV tasks,
and sandboxed bash). No path-map fallback was needed.

---

## PART 1 — d7 completeness verdict (file-by-file)

### 1.1 Method

Full listing of `d7/process_xray/` + `workstreams/` (recursive, with sizes) and of the
run root; per-file line counts (`wc -l`) and tail inspection to detect truncation; the
sibling-audit story was read from `d7/process_xray/RECONCILIATION.md` (47 lines, whole
file) and cross-checked against the delivered files' mtimes and content. Note that the
two "final assembly" deliverables live at the **AGS run root**, not inside
`process_xray/` — a locator nuance worth keeping for the doctrine-9 register.

### 1.2 Completeness table

| # | File (relative to `AGS/`) | lines | State | Content verdict | Error affected? |
|---|---|---|---|---|---|
| 1 | `process_xray/RECONCILIATION.md` | 47 | **present, complete** | Sibling-audit chain identity + adoption table + gap list; authored 11-04 10:58 by the continuation chain | This file *documents* the error; not itself affected |
| 2 | `process_xray/timeline.md` | 54 | **present, complete** | 32 numbered entries, span 21:49Z→15:51Z (18.04 h); adopted from sibling; RECONCILIATION (c) PASS (32/32, span matches) | produced pre-error (09:30-09:46 mtimes); adopted, not affected |
| 3 | `process_xray/conversation_topology.md` | 34 | **present, complete** | 31 chat files / 10 jobs closure, 2,923 inf dedup; ScoutCoder phase split 45+385+177+7=614 reconciles; RECONCILIATION (d) PASS; notes FitAgent artifact absent | adopted; not affected |
| 4 | `process_xray/context_delivery_matrix.md` | 25 | **present, complete** | Ends with 4 numbered cross-cutting observations (§"Handoff audit summary"); substantive despite short length | adopted; not affected |
| 5 | `process_xray/job_classification.md` | 40 | **present, complete** | Job-tree census (Cortex 40, Boolean 57, Gene 16 …) with basis notes | adopted; not affected |
| 6 | `process_xray/resource_breakdown.tsv` | 18 | **present, complete** | TOTAL row = 2,923 / 251,252,223 pt / 254,250,448 tt; per-role rows sum exactly (RECONCILIATION (a) PASS); spot-verified here via tsv_read | adopted; not affected |
| 7 | `process_xray/friction_register.tsv` | 15 | **present, complete** | header + FR-01..FR-14 contiguous, 9 data columns populated (raw/dedup counts, first/last seen, chats, evidence path, tokens-wasted est, root-cause owner, alternative) | adopted; not affected |
| 8 | `process_xray/workstreams/A_execution_and_context.md` | 124 | **present, complete** | F1–F8 findings + compliance note; adopted from sibling (09:47 mtime) | adopted; not affected |
| 9 | `process_xray/workstreams/C_harness_friction.md` | 216 | **present, complete** | Method (2,871 calls parsed), 7-category table, comparison-vs-d6 table, F-1..F-6, Task-4 answer, unverified list; ends cleanly | adopted; not affected |
| 10 | `process_xray/workstreams/B_scoutcoder_investment.md` | 300 | **present, complete (re-produced)** | §1 gate timeline, §2 consumption matrix, §3 costed counterfactual, §4 findings F-B1..F-B5+, §5 unverified; tail shows a proper "Unverified / limits" section — not the 36,619-B abort | **AFFECTED then COMPLETED** (see §1.3) |
| 11 | `process_xray/workstreams/D_planning_and_roles.md` | 251 | **present, complete (new)** | §1 doctrine delta, §2 wall-clock decomposition (Gantt + 5 contributors), §3 role-boundary audit, §4 RB-1..7, §5 findings, unverified | **AFFECTED then COMPLETED** |
| 12 | `process_xray/workstreams/E_surface_value.md` | 259 | **present, complete (new)** | E-1/E-2/E-3 three-surface verdicts + cross-surface summary + remediation hooks | **AFFECTED then COMPLETED** |
| 13 | `process_xray/scoutcoder_operation_audit.tsv` | 25 | **present, complete (new)** | header + T01.. rows + TEST + R01 + LEGEND row; consumption-status per op; LEGEND states the tally basis | **AFFECTED then COMPLETED** |
| 14 | `process_xray/role_decision_audit.md` | 37 | **present, complete (new)** | D7-01..D7-25+ rows, gate states explicit, closing notes (2 round-trip repairs, D7-18 only boundary crossing) | **AFFECTED then COMPLETED** |
| 15 | `process_xray/epistemic_value_trace.md` | 176 | **present, complete (new)** | record-store mechanism + citation-resolution 57/57 narrative episodes; tail ends with the 57/57 + 18/19 paths sentence (complete thought) | **AFFECTED then COMPLETED** |
| 16 | `process_xray/optimal_inference_anatomy.md` | 352 | **present, complete (new)** | Stages 0–12, aggregate counterfactual total table, "what the optimal run does NOT change", fidelity statement, conflicts-resolved section | **AFFECTED then COMPLETED** |
| 17 | `process_xray/friction_doctrine6_vs_doctrine7.md` | 141 | **present, complete (new)** | d6-vs-d7 friction comparison incl. §5 counting-basis disputation of the "110 jobs" figure | **AFFECTED then COMPLETED** |
| 18 | `process_xray/doctrine6_vs_doctrine7_delta.md` | 185 | **present, complete (new)** | §1–§4 with the 7 explicit reconciliation items (13/13 vs 12/12; 0/18 vs "consumption is real"; etc.), ends with the achieved/did-not-achieve verdict | **AFFECTED then COMPLETED** |
| 19 | `process_xray/rb_backlog_status.md` | 251 | **present, complete (new)** | RB-1..RB-7 sections + cross-row summary table (7 rows) + closing "no status upgrades" note | **AFFECTED then COMPLETED** |
| 20 | `process_xray/remediation_backlog.md` | 536 | **present, complete (new)** | P0..P3 backlog; tail is a proper closing paragraph ("All figures except the backbone totals are stream-labeled estimates…") | **AFFECTED then COMPLETED** |
| 21 | `AGS/doctrine7_process_xray.md` | (root) | **present, complete (new)** | 29,494 B; §1 executive … §12 self-accounting; ends with the workstream-F provenance block citing the whole tree | **AFFECTED then COMPLETED** |
| 22 | `AGS/doctrine7_organization_brief.md` | (root) | **present, complete (new)** | 4,811 B one-slide condensation incl. d6-vs-d7 table + "five decisions that mattered" | **AFFECTED then COMPLETED** |

No truncation detected in any file. Long files end with complete sections and closing
notes; the TSVs have LEGEND/TEST rows and consistent column counts; `resource_breakdown.tsv`
internally sums to its TOTAL.

### 1.3 Resolving the mid-flight error

The sibling-audit error chain (`d7/process_xray/RECONCILIATION.md`, whole file):

- The aborted sibling is a *different* pipeline job (`var/jobs/Planned/work/Default_a694564a00dbbfe3b3d1afe37298603b.chat`, status `error`), killed by
  `Faraday::ConnectionFailed … api.z.ai:443 (Temporary failure in name resolution)`.
  Last activity under its sidecar: 2026-11-04 10:28:23, at
  `Manager.society/ChatAnalyst/ca-xray7-substrate/agent.chat` — the **B (ScoutCoder
  investment) workstream executor**, aborted with "only its prompt recorded"
  (partial chat 36,619 B). Its completed siblings: `ca-xray7-backbone` (09:31),
  `ca-xray7-friction` (09:47), `ca-xray7-anatomy` (09:48).
- RECONCILIATION's gap list names 12 absent deliverables: `workstreams/B_*`, `D_*`, `E_*`,
  `scoutcoder_operation_audit.tsv`, `role_decision_audit.md`, `epistemic_value_trace.md`,
  `optimal_inference_anatomy.md`, `remediation_backlog.md`, `doctrine6_vs_doctrine7_delta.md`,
  `rb_backlog_status.md`, `doctrine7_process_xray.md`, `doctrine7_organization_brief.md`.
- **All 12 gap items now exist** (table above, rows 10–22). Mtimes cluster 11-04
  11:25–13:44, i.e. a continuation chain re-produced B and produced D/E and all
  consolidated artifacts. `doctrine7_process_xray.md`'s closing provenance block
  cites "workstreams A–F" and a Critic gate record under a third pipeline job
  (`Default_f333ecb6….chat.files/Manager.society/Critic/`) — evidence of a completed
  assembly + verification pass, not just file-creation.
- Adoption integrity: the continuation followed a stated collision rule ("all existing
  files were treated read-only; only this file [RECONCILIATION.md] was written after
  confirming it was absent") and its consistency checks (a)–(d) PASS.

**Verdict: the d7 audit set is COMPLETE.** The api.z.ai DNS failure aborted exactly one
deliverable in production (workstream B) and left 11 more undispatched; all 12 were
subsequently completed, and the adopted-from-sibling files (timeline, topology, context
matrix, resource_breakdown, friction_register, job_classification, workstreams A and C)
are intact. Residual caveats for the register: (i) B is a **reproduction, not the
original** — its evidence re-derivation path differs from the dead sibling's prompt,
so cross-references to "the sibling's B" should cite `d7/process_xray/workstreams/B_scoutcoder_investment.md`;
(ii) the sibling's raw cost (pt ≈ 515.5M *unduplicated*, includes receipt copies) is
recorded only inside RECONCILIATION.md and was never deduplicated ("Deduplicated figure:
unknown (no chat_accounting run)") — an unresolved accounting gap, not a content gap.

---

## PART 2 — Mechanism-level findings BEYOND the three backlogs

Ordered by work-order priority (d8 first, then d7, then d6). Backlog items themselves
(RB-1..7, RM-01..11, P0-1..P3-8) are not re-derived.

### 2.A d8 — H-004 branch mechanics (`d8/h004_branch_analysis.md`, whole file)

1. **Kill-cascade mechanics with exact timestamps (sec.1 chain table).** Kill #1
   (job `b377b6ec`) issued 21:31:18Z, ended 22:48:56Z `return_code=-15` after **4,666 s**;
   six chained retries each ~3,604 s ending 23:48:56Z, 00:49:01Z, 01:49:05Z, 02:49:10Z,
   03:49:14Z, 04:49:27Z; 8th kill = scale-test `a880f768` (351-node WCC) ending 05:56:31Z.
   Cascade wall 6.0 h (7.1 h with the scale test). Retries were **auto-issued on
   retrieval**, i.e. the harness re-issued each killed job without an agent decision.
   Manager chat only resumed at 03:49 — Manager was idle-blocked ~6 h on the first
   config's cascade. [source: sec.1 rows 8–9; d8/workstreams/C_harness_friction.md F1 note]
2. **Visibility latency numbers (sec.4).** Kill #1 (22:31 UTC per sec.2; 22:48:56 end
   per F1) became visible to Manager at 03:49 ("6.5 h later — blocked on the chained
   kills, not on reporting") and reached ScientificLead at 05:59–06:01 via the Gate-4
   packet: ~2 h after Manager saw it, ~7.5 h after the kill. Pause decision:
   PAUSE-AND-RETURN 04:50:45 (OBS-027(d)); D records 04:53 (R:3970) — both anchors carried.
3. **Knowability staging (sec.2).** "available early (design time), demonstrated mid
   (first kill), quantified late (route C)". Design-time facts in hand at 21:31:
   401 rules / 2,386 edges / 351-node WCC + 50-node ~0.4 s PASS. Strongest a-priori
   signal — the ~85-regulator SP1 rule — "sat unexamined in the frozen spec"; the Lead's
   super-linearity anticipation is dated Gate-4 (06:01), after the kills. Diagnosis:
   doctrine/protocol (scale-risk review not part of spec-freeze gate), not agent error.
4. **Counterfactual with labeled basis (sec.3 + foundation TSV).** One 351-node capped
   (1500 s) wrapper-free probe at spec freeze ≈ ≤30 min wall / ~100–200k tt (or zero LLM
   tokens via a bash `timeout 1500` on the frozen file). Foundation rows:
   `h004_pre-dispatch_scale_probe_measured_direct` = **7,438,677 tt avoidable (MEASURED)**
   = Manager work-root window 874,248 tt + ScoutCoder bout 6,564,429 tt; wall 1.15 h
   measured for the ScoutCoder bout; kill-hunt turns 1–2M tt ESTIMATED; net 8.3–9.3M tt /
   1.5–2.0 h DERIVED. Note the reconciliation: C's earlier "~7 h wall" is the measured
   kill-chain interval and is retained for the cascade itself; the foundation net row
   supersedes the token figure.
5. **Honesty caveat worth preserving verbatim (sec.3):** a pre-dispatch probe could not
   have known the external 3600 s killer existed (harness property, discovered only by
   being killed); but for the feasibility question the probe's non-completion + the
   50-node datapoint suffices to fail T_slice-style bounds without any kill.
6. **SIGTERM classification split (sec.5 table).** Who kills = **unknown** (no timeout
   in `workflows/Boolean/workflow.rb`; ScoutCoder grep + `grep_hourly_kill` /
   `session_scope_kill_hunt` probes found no framework reaper; no cgroup/OOM/rlimit
   evidence; `pid_hostname: turbo`, `batch_system: slurm`, `batch_job: null`). Why it
   never finishes = intrinsic cost (b), per wrapper-free 1500 s non-completion on a
   sha-verified copy with zero primes. The audit explicitly keeps "classification of
   who kills = unknown" as an honest unknown.
7. **Pre-adjudicated A-branch device (sec.1 row 06:01 + sec.4).** Lead authored the
   A-branch disposition at Gate-4 ("activates without further round-trip", quoted back at
   R:4406); route-C failure (~07:00–07:12) then needed **no new Lead round-trip** —
   exercised 07:16, confirmed at Gate-5 07:40:22Z. A quantified instance of
   pre-registration cutting escalation latency to zero.
8. **Cost asymmetry of the diagnosis itself (sec.6, B sec.5).** ScoutCoder diagnosis
   6.54M pt (5.6% of mission) = **16× the entire specialist preflight** (≤1.8M pt
   divided across 3 conversations), under time-bounded but token-unbounded fail-fast
   rules; produced a correct stop decision saving a ≥46.7 h battery. Judgment "likely
   net-positive" is an assessment, not a measured net (F-B4).
9. **Provenance hole (B F-B5; sec.6).** `workflows/Boolean/GATE4_SCALE_BLOCKER_RECEIPT.md`
   (sha 81de5350…) resolves to the live developer checkout; inside the run archive
   `ROOT/workflows/Boolean` is a **broken symlink** — the central infrastructure
   decision is evidenced in-archive only via ScoutCoder chat text + sha citation.
10. **Zero-yield statement (sec.7).** All 8 dispatched full-size runs SIGTERMed with no
    output; the 25 completed Boolean jobs were small-network validations; every
    H-004-relevant conclusion rests on staged-file analyses + timing probes. Critic
    negative scan: "Zero H-004 scientific evidence exists" (final_report.md §3).

### 2.B d8 — capability/preflight + ScoutCoder lifecycle (`d8/workstreams/B_capability_lifecycle.md`)

1. **Preflight cost anatomy (sec.1).** Analyst preflight: 68 s, 10 inf / 167,151 pt.
   Worker preflight: 9 m 19 s, 8 inf / 239,021 pt, **zero Boolean tool calls possible**
   (row-7 evidence). Research probes were interleaved with scoping → only an upper bound
   ≤1.38M pt for that window ("cannot be exactly isolated … stated as bound, not exact").
   Manager window 0.20M pt. Total ≤ ~1.8M pt ≈ 1.5%; the work-order's "~0.4 M" counted
   only the two specialist conversations — a denominator convention that the register
   should keep explicit.
2. **Row-level consumption trace (sec.3), i.e. which preflight rows actually gated a
   decision:** (i) Boolean asymmetry → CONSUMED (Gate-1/2 routing to route c);
   (ii) web-dead → consumed as a standing constraint, not a plan change; (iii) Reader
   row → "NO EVIDENCE OF CONSUMPTION of the row itself" (avoidance attributable to ii);
   (iv) non-deletable OBS-001 → weakly consumed (hygiene rule); (v) Analyst-env
   verification → "enabling condition, NO EXPLICIT CONSUMING MESSAGE" — implicitly
   consumed, not decision-cited. This is the granular anatomy behind "3/11 rows
   decision-forcing".
3. **cortex_brief provisioning defect — exact mechanics (sec.4 trigger; C F8).** Brief
   created with `introduce: Boolean` + `tool: Boolean`; the Worker conversation was
   launched **without the brief attached**; probe (`cortex_continue` M#143, 21:14–21:20)
   confirms brief exists yet spawned Worker has neither Boolean tools nor filesystem
   ("Boolean tools: NOT PRESENT … file access: NOT PRESENT. I am stopping here and not
   improvising alternatives" — probe's own stop). Cost: 1 wasted Worker conversation +
   2 probes; "decision-relevant: removed last chance of Worker execution."
4. **Pre-registered fail-fast contract text (sec.4 packet).** T_slice = 20 min per
   probe; mandatory (a)-vs-(b) diagnosis; fix only if (a); no scientific-file changes;
   consumer-facing vertical slice pre-specified (Manager runs 351-node
   trap_space_analysis end-to-end); receipts requirement. Outcome: classification (b);
   workflow untouched (sha 2f2dda5e, mtime 2026-07-21); **acceptance slice correctly
   NOT executed** ("N/A — pre-registered stop branch. Do not execute the slice") — a
   clean instance of a stop branch being honored rather than scope-crept.
5. **RB-1 honoured instance (sec.4).** The plan's pre-registered failure branch fired on
   evidence; no build waves past contradiction; receipt consumed by the adjudication
   chain (sha cited in final defect inventory, Manager line 1736).
6. **Report-hygiene divergences (sec.2 table):** capability_preflight.md header date
   "2026-10-20" (wrong vs mission 11-03) and analyst_env.md "Date: 2025-11-03" (year
   off by one) — content unaffected; a date-discipline failure mode in preflight
   deliverables.
7. **Row 7 contradiction surfaced mid-run (sec.2):** preflight's "Boolean workflow" row
   overstated breadth — phenotype_probabilities + trajectory_time_clamp_analysis turned
   out defective at invocation (10 failed Manager calls, M#61–#91); recorded as OBS-014
   by Research at ~21:00 and excluded from H-004. A/F-A3's "2 identical failures then
   defect-record" rule is the proposed remedy.

### 2.C d8 — harness friction mechanics (`d8/workstreams/C_harness_friction.md`)

1. **F1 timestamps corrected by the audit itself** (file header "Correction 2026-11-04
   (post-Critic)": Boolean `.info` timestamps are local +0100; an earlier version read
   them as UTC; "no counts, token figures, or verdicts changed"). Register should use
   the corrected UTC values.
2. **F5 `.info`-only census = a visibility gap, not an execution gap.** 70 mission-window
   `.info`-only tool jobs (Boolean 40, DocID 9, Reader 7, Cortex 7, Gene 4, Planned 2,
   Semantics 1): "jobs whose invocation text is not persisted in a visible chat …
   Discovered LATE — by this X-ray's census (post-mission). Surfaced to decision owner:
   No." The Boolean-40 subset decomposes into ~24 kill-linked dirs (8 kill events ×
   3-job dependency chains) + ~16 genuine DONE dirs (spot-checks, scale tests, OBS-014
   validation, Critic re-runs). Per-call cost/dispatch attribution for those 70 must be
   reconstructed from `.info` alone.
3. **F6 stale-sidecar mechanics.** Pre-existing `.error` on the request job (64,604 B,
   mtime 11-04 09:15) written *after* the request job completed `done` (11-03 19:40) —
   "harness (sidecar written by a later stage) … misleading for future audits."
4. **F7 role asymmetry known-before-choice.** Boolean/Gene/CollecTRI/Signor present on
   Manager only; Worker surface report ~19:00; MC#35 (18:57) "All five domain tools
   work from Manager's own surface" — "route (c) was an informed choice, not a surprise."
5. **F11 Lead tool-less by design, with the Gate-5 self-admission:** "the Lead is
   tool-less and could not read the packet file"; packet digest "NOT treated as verified
   by the Lead" — adjudication rests entirely on Manager/Research-stated state.
6. **F2/F3 toy-network validation failures were pre-spec and cheap** (~2 min / ~1 min
   wall each, zero science loss, OBS-014 batch) — the register should not conflate
   these with the F1 scale kills.

### 2.D d8 — gates/roles mechanics (`d8/role_decision_audit.md` + `d8/workstreams/D_planning_and_roles.md`)

1. **Gate table with declared-vs-exercised anchors (role_decision_audit.md gate table).**
   G1 19:00:44Z, G2 19:45:33Z (thresholds frozen pre-computation), G3 20:45:43Z,
   G3-residuals 20:58:35Z, G4 06:01:29Z, G5 07:40:22Z — each with both the declaring
   artifact and the exercising Lead-inference timestamp. Silent waivers: none. The one
   lifecycle gap: **plan-endorsement gate never exercised as a document gate** — content
   inlined at G1 while `investigation_plan.md`'s header "requires ScientificLead
   authorization" stayed PROPOSED through mission end (substituted, not waived).
2. **G4's honest sequencing (F-D2).** Bounds registered **after** the triggering
   failures (04:53 pause, 05:57 scale test) but **before** the ScoutCoder probe
   (06:31 WO; T_slice fixed in M:1672) — "an authorized adaptive gate whose bounds bound
   all subsequent engineering … Not a reconstruction." Proposed rule: gate files should
   state all three anchors (event ts, gate ts, next-engineering ts); gate4_decision.md
   was written 06:02, one minute after the ruling.
3. **F-D3 deviations ledger is retrospective.** All D1–D10 written in one late burst
   (R:4443, inside 07:13–08:05); deviations were forwarded when discovered (gates/OBS)
   but "the ledger alone would overstate its own evidentiary weight." Plus one splice
   defect (D10-into-D6). Proposed: append-on-discovery, forbid splice edits.
4. **F-D4 Planner stage dead.** Manager's first user turn is only "You have been asked
   to fulfill a user request. Proceed with the plan" — no plan text, no later citation
   of any planner artifact in Manager.chat; work ran on the Gate-gated Research plan
   chain. Planner 1 inf / 36,719 pt unconsumed (foundation counterfactual row
   `planner_stage_unconsumed` 44,417 tt avoidable, measured). "Roughly 30% of measured
   planning prompt tokens went into a plan artifact with no downstream citation"
   (estimate; negative-grep evidence only).
5. **F-D5 evidence-duplication trap.** One paid Critic conversation persisted in three
   overlapping evidence locations (society 256 ids; C-B job chat 256 incl. C-A history;
   C-A job chat 158) — naive summing overcounts Critic ~60%; dedup by inference_id is
   mandatory for any cross-run accounting.
6. **F-A5/F-D1 Lead-value framing:** 5 gates + follow-up = 6 inferences / 122k pt
   decided scope, statuses, routes, optional items, sufficiency — "cheapest authoritative
   surface in mission" — while being structurally evidence-blind (100% curated inputs).
   F-D1's counterfactual (one read-only file+sha tool, or Critic correspondence check as
   standing gate item) is medium confidence, not tested in-mission.

### 2.E d8 — context delivery per stage (`d8/context_delivery_matrix.md`, whole file; source `d8/workstreams/A_execution_and_context.md` sec.2–3)

1. **The environment-rediscovery tax is now precisely located (F-A6):** Critic A
   (list_directory/pwd #17–#21, `find /` for CollecTRI2.tsv #223), Critic B (same
   recon), ScoutCoder (list_directory/pwd/sandbox_paths #22–#27), Worker (sandbox_paths
   #13) — "pattern seen in 4/4 fs-consuming conversations"; facts existed centrally in
   `reports/capability_preflight.md` but packets to Critic/ScoutCoder did not inline
   them. Proposed: standing 5-line environment-facts header in every fs-consuming work
   order (root, key paths, sandbox scope, known-broken tools).
2. **Research conversation accumulation mechanics (F-A7 + matrix row):** 400 inf /
   51.17M pt, 96.5% cache; growth +200–4,700 pt per tool step inside a turn; **hard
   reset at each new Manager turn (pt 134k→61k, cache mostly lost, cct 133.5k→15.9k at
   agent.chat#172→#175)** — i.e. each new turn re-pays a large uncached prefix. Analyst:
   8 bouts in ONE conversation (74.7k pt/inf mean). Both roles' constraints/checksums
   restated per bout (~0.6–1.5 KB) — the repetition itself is not the driver; the
   carried context is.
3. **Self-contained positive cases enumerated (A sec.3):** all five Lead gate packets
   (0.7–8.3 KB, numbers inlined, Lead never stalled), Analyst work orders (checksums,
   semantics, output contract, reply format), ScoutCoder Gate-4 order, Gate-4 packet
   carrying full kill evidence + decomposition + cost arithmetic.
4. **Manager attribution defect (F-A1/F-A8):** first accounting pass read "Manager own
   2 / 26k"; direct chat evidence = 62 events / 5,156,202 pt (200× understated) — cause:
   overlay summed `agent_meta` receipts vs `chat_meta` direct events without labeling
   evidence class; ~5M pt (4.4%) misattributed; identified by A, resolved by the
   foundation fix (report.md CHANGELOG). Rule for the register: per-conversation figures
   must state evidence class.
5. **Ask-stage convention split (context matrix row + report.md):** attribution-based =
   1 ask-unique inference (25,704 pt; 62 of the 65 file records are replays of
   work-stage Manager ids); file-based reading = 65 records / 5,236,756 pt. Both readings
   emitted; any doctrine-9 rule touching "final-answer cost" must name its basis.
6. **Session-split Critic duplication:** session B re-established context session A had
   built (separate ask-job chats); justified by different verification scopes but it
   duplicated environment recon (A sec.3, "Lossy / redundant" list).

### 2.F d8 — epistemic/Cortex mechanics beyond the backlog headline

1. **Record store mechanism is NOT Cortex/Semantics** (`d8/epistemic_value_trace.md`
   "Record store mechanism"): filesystem YAML under `var/records/{observation,claim,hypothesis}`,
   native epistemic Path kinds, version-locked edits via `{"version": N}` → history
   snapshots; API census: register 110, edit_fields 142, path_validate 52, path_read 34,
   path_edit 2, path_list 2, path_kinds 2 (+ entity_property 8 = Semantics, separate).
   Closed at 49 records; predictions embedded as YAML list fields inside HYP records.
2. **F-E6 Cortex-brief defect cost, precisely:** brief created 19:57; probe 22:14 spent
   Σtt 33,388 to learn the brief was empty (7 tool calls, 8 inference events); zero
   cortex function calls across Research/Analyst/Critic/ScoutCoder/Worker chats; all
   callers of the 4 cortex_read + 3 cortex_list = the probe chat itself. Counterfactual
   noted untested (medium confidence): "same probe via plain ask … yields the same
   signal at similar cost." Proposed harness fix: tools-attached receipt in job `.info`
   ("so the probe is one grep instead of one inference session").
3. **E's probe-call enumeration conflicts with foundation** (context matrix note; §11
   residual): E's "3 brief-probe, 6 cortex_list, 8 cortex_read" (sums 17) vs foundation
   7 calls vs E's own 7-call total — "conflict noted; foundation count preferred."
   Register should carry the foundation count with the conflict flagged.
4. **F-E4 tier-conflation mechanics:** one structured `evidence_tier` value reused for
   measured RNA and RNA-derived TF-activity/onset calls (16/39 OBS), derivation
   disclosed only in prose parentheses → "downstream filtering on the structured field
   cannot enforce the 'never upgrade the tier' rule." Smallest test given: count records
   whose tier is `measured-in-this-experiment` but prose contains "RNA-derived" → 16 hits.
5. **F-E5 no-delete mechanics:** OBS-001 occupies a permanent observation ID slot; harm
   contained by self-label + zero scientific citation (grep-verified); proposed
   disposable namespace / retire-with-tombstone.

### 2.G d7 — workstream A context/gate mechanics (beyond RM items)

1. **F1 Lead read-surface mismatch, with all four episodes quoted** (A/F1): tool block
   is exactly `cortex_list, cortex_search, cortex_read` (lead-ags L295–303); M#1177
   (03:40) instructs reading `reports/record/…` files; Lead reply M#1179: "the mission
   workspace…is not mounted in any readable Cortex map… All record f[acts came from your
   digest]." Repeats at adjudications #2 (M#1247), #3 (M#1405), #4 (M#1435). Mitigation
   invented in-run: Research staged `ags/record-summary.md` at 03:50 and every Lead
   packet since carries a provenance-limit + reopen clause ("if any summary misstates a
   branch outcome, the affected status reopens at my review", M#1247).
2. **F2 registration latency:** Lead adjudication #1 returned 04:09 (M#1191); Research
   registration only at 11:25 (M#1257) — "for 6.75 h the record's hypothesis section
   was silent on the allocations the executors were already bound by; reconstruction was
   possible only because packets happened to quote the decisions." Executors had the
   binding text (dossier-1's packet quotes Decision 2/4 verbatim, M#1223), so zero
   rework — but the audit trail's authority temporarily lived in chat text.
3. **F3 delegate-and-verify recovery instance:** Manager's packet mislabeled CLM-003
   ("temporal structure" vs the mirror's combination-non-superset); the Lead flagged the
   mismatch, Research verified ID-to-content binding at registration (M#1441) — "the
   recovery is the system working as designed"; positive finding, no wrong ruling.
4. **F4 pre-registration relay mechanics:** Manager cannot read `models/preregistered.md`,
   so M#1285 asks inv-boolean to "paste me the exact run spec verbatim"; the executor's
   return (M#1287) introduces an **[op] convention** ("operationalizations that add no
   new threshold and change no clamp; preregistered.md itself untouched") — a disciplined
   response to a provisioning gap; the interpret half later re-derived every statistic
   from receipt files (M#1399), "closing the loop empirically." ~1.6 h wall cost.
5. **F6 ungated mega-bout exposure:** inv-dossier-2 = 3 hypotheses / 4.5 h / 508 inf /
   48.2M tt (18.9% of run spend) in a single packet, "no intermediate check-in; internal
   pre-registration tables were the only brake." Diagnosis: planning scope granularity,
   not agent failure. Counterfactual (excluded from base case): two packets with a
   cheap Manager check between → est. 15–20M tt saving if HYP-002 had refuted early.
   Proposed cap: "2 hypotheses or ~2 h wall-clock absent an explicit waiver."
6. **Reciprocal surface declaration observed exactly once** (context_delivery_matrix
   obs.3): inv-boolean M#1285 "your preregistered.md sits in the workspace filesystem
   which I cannot read directly" — "the pattern existed in the tree from 14:26; the
   earlier Lead failure (03:50) could have been pre-empted by the same sentence at
   03:40." Smallest possible doctrine-9 candidate: a one-line read-surface declaration
   in every packet.
7. **F5 consumer-slice PASS count corrected to 13/13** (doctrine6_vs_doctrine7_delta
   conflict item 2): `tmp/probes/consumer_slice.out` shows "CONSUMER SLICE: 13 passed,
   0 failed"; B's "12/12 (SC:3810)" is a mis-citation of a reasoning line. Both streams'
   conclusion stands (slice ran, passed, builder-env only).
8. **Pre-implementation endorsement gate absent (delta conflict item 5 + B F-B3):** the
   00:29 substrate Critic gate is post-hoc verification; no Lead ask exists between the
   22:02:40 design artifact and the 00:02:40 implementation authorization; Lead's first
   inference in the entire mission is 03:40:51 — "2.6–2.7 h after handoff." Internally
   honest (no gate declared then violated) but the d6 lesson "the one moment a Lead
   could trim scope was skipped" repeated with the same effect.

### 2.H d7 — friction/−1 wrapper mechanics (C + friction files; beyond FR-03 headline)

1. **Failure-class composition of the 107 −1s** (C §(b) F-1): 80 are *script errors
   wrapped as −1* (SyntaxError/NoMethodError/ENOENT only at the stderr_full tail), 9 are
   `-c`-layer quoting failures, 18 remain opaque. d7 has **zero** `Read-only file
   system` / `Operation not permitted` failures (vs d6's 61 dedup denials) — "doctrine7's
   −1s are mostly self-inflicted script errors surfaced through an opaque wrapper, not
   environment denials."
2. **The environment-verdict worked, with a measured boundary (C Task-4 answer):** verdict
   written 2026-11-02T22:01:18Z (ScoutCoder L1203) preceded all 107 −1 events; 99 of 107
   occurred after 00:00Z — "not environment rediscovery but ordinary script iteration
   wrapped opaquely." Zero true denials + all hard limits found once, early. What it
   could not prevent: identical-signature repetition (inv-boolean bursts 27×/19×/7×/5×
   across 14 hours) — "a harness-opacity + agent-memoization problem."
3. **Per-chat failure memoization quantified:** per-chat known-good-command note would
   remove ~58 of 107 −1s (~1.5M tt of the 4.2M); F-2's smallest test: replay the 4
   burst groups, count how many follow an already-succeeded identical prefix.
4. **FR-05 SaezLab/symlink rediscovery cost + P4 probe proposal (F-3):** first found
   22:53Z Nov-2 by ScoutCoder; Worker **rediscovered** it at 15:05Z Nov-3 (12 more
   attempts) because the Phase-0 verdict covered `data/` and workflow resolution but
   not "the sandbox-visible status of the symlinked local workflows"; ~2.5M tt est,
   mostly Worker's closing smoke. Proposed: add P4 probe (sandbox-visible workflow
   resolution) to the Phase-0 template.
5. **FR-06 MaBoSS cfg dialect burned exactly two attempts then converged** (F-4):
   `istate = 1 0` then `istate = [1,0]` both fail "configuration syntax error at line
   #1"; done jobs at 15:32 use no cfg at all; 4 downstream error jobs are cascade, not
   extra cost (~0.2M tt). Proposed: valid cfg example in the Boolean workflow docstring.
6. **FR-07 Gene stack quarantined by instruction:** Research 05:23Z probed once
   (ParameterException passing 4609 where symbol expected; literature_summary ×3
   NoMethodError `to_hash`); then the dossier brief explicitly forbids it (inv-dossier-1
   L869: "Gene literature_summary tool is broken in this environment… Do NOT invent
   citations"). ~0.1M tt; no downstream contamination.
7. **FR-12 precise_edit precondition drift is the tool working:** 12 failed edits, 6 in
   inv-dossier-2 alone — "selectors written from memory of file state rather than a
   fresh read. The tool behaved exactly as designed (refused, no edit), so this is agent
   discipline, not tooling." ~0.4M tt est.
8. **FR-14/FR-13 mount-gap instances:** installed-gem source not mounted (sed on
   `/bulk/…/scout-gear` → −1); the doctrine's "acknowledged exception" for source
   inspection "could not be exercised."

### 2.I d7 — consumption/counterfactual mechanics (B + optimal anatomy)

1. **Three-level interface ladder quantified (B §2; scoutcoder_operation_audit.tsv):**
   task/CLI 0/18 (every attempt `Workflow SaezLab not found`); helper `AGS::FrozenSources`
   18/18 = 161 method calls across 8 consumer chats (inv-tf-activity 57, Critic 42,
   Worker 29, inv-gene-level 16, inv-dossier-2 16, Analyst 7, inv-dossier-1 6, Research 4)
   with 58 explicit `require` lines, each value returning md5+source; raw files: inv-boolean
   entirely (67 reads, 0 helper), dossiers mixed (98/16, 44/16, 32/6). Entity/property
   layer 0/32 for science (only 8 verification-echo calls, all inside verification
   scripts). The delta file's resolution (item 3) is the precise sentence: "receipts
   prove execution, not consumer-interface consumption."
2. **F-B4 fallback-ladder mechanism:** OBS-012's pre-authorized deviation named the
   *helper* as sanctioned interface; the boolean stream "slid one step further to raw
   File.foreach reads (67, zero helper calls) under the same authorization language.
   The fallback ladder (task → helper → raw files) was walked down once, in writing,
   and never walked back up." Proposed: when a pre-authorized fallback fires for every
   consumer, require a one-line decision record that fixes the environment or demotes
   the dead surface.
3. **F-B2 slice-environment gap:** slice ran 00:05:37–00:06:30 (13 PASS) in
   ScoutCoder's own environment; first consumer failure 01:12:38 — 67 min later. "The
   real check happened accidentally, by the first consumer." Smallest test: rerun
   consumer_slice.rb under a per-branch bwrap → observe `SaezLab not found` — one command.
4. **Costed counterfactual with explicit assumption ladder (B §3):** minimal substrate =
   probes 4.21M (kept) + helper authoring 6–10M + promote/slice 0.5–1M + repair 0.97M ≈
   11–15M pt vs 71.81M actual → **57–61M pt saving (~22–24% of mission tt)**; dollar
   saving proportionally smaller at ~98% cache. Basis: the helper is ~660 lines + a
   43-test suite; the churn families that would not exist (yaml_task_type_support6,
   tsv_semantics_for_frozen_readers4, final_live_check_all_tasks8/9, ptm_time_*×4) are
   named from probe files.
5. **Aggregate counterfactual (optimal_inference_anatomy "Aggregate counterfactual
   mission total", A1–A6 all labeled):** 2,923 → ≈2,400–2,600 inf; 251.25M → ≈189–194M pt;
   254.25M → ≈192–197M tt (−22 to −24%); 18.04 h → ≈8.5–10 h (serial lanes −6..−7 h,
   minimal build −~2 h, gates ~2.3 h kept); throughput 2.70 → ≈4.5–5.5 inf/min. A5
   unmeasured: per-request service time under concurrency (if provider rate limits bind,
   add queueing back). A6 excludes the speculative dossier-2 split saving (0–20M tt)
   because no loss materialized.
6. **Wall-clock decomposition attribution labels (D §2 / delta item 7):** serial Part II
   lanes ≈6–7 h **dominant** (plan-structure; no doctrine text mandates serial lanes;
   d6's lanes overlapped: AGS 22:05→02:50, Boolean 22:11→02:41, ScoutCoder 22:04→02:51);
   gates+adjudication round-trips ≈2.3 h on the critical path (mixed doctrine+plan; the
   five round-trips are individually timed: 31+46+29+13+18 min); Boolean volume
   contingency (d6 12 jobs vs d7 110; retries inside the 3.01 h inv-boolean lane); idle
   gaps ≥15 min ≈1.0–1.5 h. Net executor work 75.8 role-hours over 18.04 h ⇒ "mean ~4.2
   nominal lanes, but only ~1 heavy executor lane active at a time after 01:02."

### 2.J d6 — mechanisms (beyond RB-1..7)

1. **D-26 gate-waiver mechanics (d6/role_decision_audit.md row D-26):** the Manager
   *itself declared* a Lead-endorsement gate between design and implement (design
   artifact marked "PROPOSED — awaiting Lead endorsement"), then dispatched the
   implement wave **1 minute after design return**, relabeling the design
   "authoritative." "Declared stop condition neither exercised nor renegotiated;
   Manager substituted its own completeness judgment for the Lead's." Upstream of the
   1/22-consumption outcome.
2. **D-27 curated-contradiction mechanics:** the mid-flight review packet was composed
   "from registered observations only — zero fallback/deviation/sandbox/streaming
   content" despite 146 fallback/deviation mentions already in Manager-visible outputs;
   the Lead's D2 §2 clearance therefore "ran on a stale premise" — the input to a
   correct ruling was wrong-shaped. The Lead was "structurally unable to rule on wave-2
   interface strategy."
3. **D-29 the 60.6M pt premise-stale dispatch:** wave 2 dispatched 4 minutes after
   D3-interim, "citing its §2 clearance, with the same task+entity interface strategy,
   no consumer-sandbox probe, and no consumption citation for wave 1 (whose surface-use
   score at that moment was effectively 0). 60.6M pt later, G3's task is never consumed
   through its surface." Root cause: role-config/mission-prompt (no revision trigger on
   contradicting consumption evidence), secondarily harness (no consumer-sandbox probe
   task).
4. **D-31 Critic gate scoping defect:** at the substrate gate the Critic observed the
   entity surface fail to load in its own sandbox and attributed it to "the **Critic
   sandbox only**," advising "proceed" while the ask named Phase II Investigators
   explicitly — "a verification gate should treat an environment-dependent failure of
   the artifact under test as a property of the artifact until proven otherwise." This
   was the last cheap checkpoint before 3 branches + wave 2 inherited the unprobed
   consumer environment.
5. **D-15 the positive gate exemplar:** the Lead's D3-BLOCK is the run's best doctrine
   moment — bounded diagnostic (cortex_read/search/list: no AGS material in any
   readable map) then "I will not assign hypothesis statuses citing O### records I
   cannot read; that would fabricate citations … Routing evidence into the gate is a
   Manager-side action." Cost of the upstream defect: one ~25-min round-trip.
6. **Delivery-failure inventory (d6/context_delivery_matrix §F):** "The only delivery
   failure of the run is the D2 digest (#66)" — packet said "the digest is below" but
   contained only a description; recovery tripled the artifact (file + brief + inline
   18,093 ch) deliberately. Boilerplate re-send ≈130k chars over 27 packets (labeled
   estimate). "Latency was never the problem" — every artifact consumed within one bout.
7. **D-33 single-sourced final report:** the ask-stage User agent got a 13,988-char
   digest, 0 tool calls, never touched `records/` or `research/` artifacts; "record-faithful
   at one remove, not independently sourced"; then a ~150k-char triple transfer (labeled
   estimate) to persist H verbatim.
8. **Critic breadth note (D §1.6):** 269 inf / 262 bash calls for verification was
   "thorough verification, not re-execution" — the divergence was scoping (D-31), not
   breadth per se.

---

## PART 3 — Contradictions between audits (and what each file actually supports)

1. **"Total mission volume is NOT lower" (d8) vs the raw 116.81M vs 252/254M comparison.**
   Both statements are about *different quantities* and both are supported by their
   files. `d8/cross_run_comparison.md` reading-note (2) says exactly: "total mission
   volume is NOT lower in doctrine8 (116.81M pt) — the savings moved into conversation
   architecture and verification, which is where the next remediation aims." The raw
   comparison (116.81M pt d8 vs 251.25M pt d7 / 2,728-inf 253.45M tt d6) is the
   foundation-measured per-run accounting (`d8/report.md` totals; `d7/resource_breakdown.tsv`
   TOTAL). No contradiction inside d8; the caution is that d8's mission was a *different,
   smaller-scope mission design* (1,299 vs 2,923 inferences; ~13.45 h vs 18.04 h wall;
   science.v2 pipeline vs glm5), so **cross-run pt totals are not a like-for-like
   efficiency measure** — d8's own files never claim a 2.2× efficiency gain, only that
   its avoidable-cost categories moved. (Related, genuinely supported d7 finding:
   within d6-vs-d7 — same model, comparable mission — tokens were flat at +0.3% while
   wall doubled, per `d7/doctrine7_process_xray.md` §1.)
2. **Kill-visibility latency, three numbers in circulation:** ~7.5 h after the kill
   (d8/h004 sec.4), "6.5 h later" quoted as in source for Manager visibility
   (22:31→03:49 computes ~5.3 h — d8/h004 flags the arithmetic itself), and 03:49
   Manager resumption (A timeline row 10). d8 carries all anchors explicitly and
   marks the discrepancy rather than adjudicating it. The register should state: first
   kill 22:31/22:48:56 end (both anchors exist for start-vs-end conventions), Manager
   resumption 03:49, Lead packet 05:59–06:01.
3. **Boolean job counts, three bases:** C's census "40 `.info`-only Boolean jobs" vs
   foundation `tool_job_usage.tsv` "Boolean 77 jobs / 52 status error" vs B's "8 failing
   job `.info` records" for the kill chain. d8/h004 §5 and doctrine8_process_xray §11
   both record this as a counting-basis conflict, not resolved. Also carried from d7:
   D's "110 Boolean jobs" is disputed by `friction_doctrine6_vs_doctrine7.md` §5 as
   "not reproducible under any file-counting basis."
4. **Consumer-slice count (d7): 13/13 vs 12/12.** Resolved inside d7 itself
   (`doctrine6_vs_doctrine7_delta.md` item 2): 13/13 is correct (probe output + two
   run_probe receipts + M#1139 return all agree); 12/12 was a mis-citation of a
   reasoning line. Use 13/13.
5. **Cortex probe-call counts (d8):** E's enumeration (sums 17) vs foundation 7 calls
   vs E's own 7-call total — "conflict noted; foundation count preferred"
   (`d8/context_delivery_matrix.md` counting-basis note; §11 residual).
6. **ScoutCoder tool-call census (d8):** B's per-tool census (run_probe×50, bash×42, …)
   sums above the 54-call total of foundation and A — "conflict noted," A's breakdown
   kept (`d8/context_delivery_matrix.md` counting-basis notes).
7. **Spec-freeze timestamp not pinned (d8):** three anchors bracket it — "~20:30"
   work-order framing inside the Gate-3 packet window (20:02–20:58), C-2's
   counterfactual wording, and the 401-rule verification chat at ~21:31 (MC#152/#1575).
   d8/h004 carries all three and states "none is contradicted by the foundation TSVs."
8. **Chained-kill timestamp variants (d8):** 01:49:05 vs 01:49:06; 04:49:18 vs 04:49:26;
   05:49:27 vs 05:56:26 — src variants between C's sec.2 table and F1 note; both quoted,
   not adjudicated. (Also the +0100/UTC correction in C's header: earlier report read
   local as UTC; counts/verdicts unchanged.)
9. **C's d7 friction totals vs backbone:** C's 2,854 inf / 249.51M tt (its own census
   over 11+1 chats, chat-set boundary) vs backbone 2,923 / 254.25M (inference_id
   closure). Resolved in d7's delta item 4: backbone authoritative for mission totals;
   C's internal category counts stand as C's basis. Same class of issue as d8's F-D5
   (dedup by inference_id mandatory).
10. **d8 says d6 had "1/22 via interface"; d7 measured 0/18 via interface, 18/18 via
    helper.** Not a contradiction — different runs with different substrates; d8's
    cross_run_comparison cell for d7 is explicitly PLACEHOLDER ("merge by replacing
    PLACEHOLDER cells only"), so the d7 numbers must come from the d7 tree, as done
    here.

---

## Provenance / limits of this extraction

- Read in full or in relevant entirety: all d7 process_xray files (22 incl. two run-root
  files) and their tails for truncation; d8 h004_branch_analysis, optimal_inference_anatomy,
  context_delivery_matrix, role_decision_audit, remediation_backlog (P0-1..P3-8 headers),
  epistemic_value_trace (mechanism + checks 2.1), workstreams A (secs.1–3, 4–6, unverified),
  B (secs.1–5), C (secs.1–3), D and E (Cortex + F-E4..E6), report.md, cross_run_comparison,
  doctrine8_process_xray §1–§12; d6 workstreams A (secs.2–8 + Part I table), D (§§1.1–1.7,
  2.1, 3), E (cross-surface + remediation), role_decision_audit (D-01..D-34),
  context_delivery_matrix (whole).
- d8 `timeline.md` (255 lines) and `closure_definition.md` (1,999 lines) were listed and
  spot-referenced via the consolidated files but not read end-to-end; no finding above
  rests on them beyond what the consolidated files quote. d8 workstream D sec.1 and
  E sec.1–3 were covered via the consolidated role_decision_audit / epistemic_value_trace.
- Truncation check method: line counts + tail inspection + internal consistency (TSV
  sums, entry contiguity, closing sections). All d7 files passed; nothing was guessed
  from a truncated view.
- The d7 sibling's unduplicated raw cost (pt ≈ 515.5M) is recorded only in
  RECONCILIATION.md and was never deduplicated — flagged above, unresolved upstream.
- Bash attempts against absolute `/bulk/...` paths from sandboxed exec failed twice
  (bwrap argv error status 1, transient); the same content was re-read via the
  Workspace `read`/`tsv_read` tools, which succeeded. The `/bulk/.../new_doctrine/work`
  directory listing succeeded once (via bash) and the target write path is expected to
  resolve under the same mount as this workflow root; if the final `write` to
  `v9-extraction-notes.md` had failed, the fallback would have been the
  `~/.scout` path-map note — it was not needed.
