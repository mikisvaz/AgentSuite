# v9 evidence register — consolidated (step 2 of 7)

Sole evidence base for the v9 change ledger. Merges d6/d7/d8 process_xray
remediation backlogs + friction registers + persistent repo frictions
(v9-baseline.md). Every row carries citation and disposition; dispositions
follow Manager guidance, not re-litigated here. No change ledger written.

Run roots (read-only, verified readable; d7 set verified COMPLETE 22/22 files
by Reader — `new_doctrine/work/v9-extraction-notes.md` §1.2):
- d6 `~/git/sandbox/Scenarios/runs/AGS.full.scout.glm5.doctrine6_d9232750ed4670c4e8e7c7c626766e1a/AGS/process_xray/`
- d7 `~/git/sandbox/Scenarios/runs/AGS.full.scout.glm5.doctrine7_21c70f5c34f5e8792cc5cf39ba6f97f1/AGS/process_xray/`
- d8 `~/git/sandbox/Scenarios/runs/AGS.full.scout.science.v2.doctrine8_66c09b60223d3f876df84a64ab42584c/AGS/process_xray/`
Citations below abbreviate `<run>/process_xray/<file>` to `<run>/<file>`.

Disposition legend (applied, not adjudicated): **fix-here** = doctrine files,
start_chats, society roster, mission template, tool-wiring lines, repo
scripts/symlinks, gitignore; **delegate** = scout-ai base repo, epistemic-API
owner, domain tooling (Boolean/Gene/…), or environment/user; **accept(-with-
reason)** = genuine tradeoff or documented environment property. `ledger?` Y =
accepted Manager decision / named ledger row for the next bout.

## 1. Cross-run trend table (each cell cited)

| Metric | doctrine6 | doctrine7 | doctrine8 |
|---|---|---|---|
| Inferences (dedup) | 2,728 [d6/resource_breakdown.tsv TOTAL] | 2,923 [d7/resource_breakdown.tsv TOTAL] | 1,299 [d8/resource_breakdown.tsv MISSION-TOTAL; report.md FINAL_TOTALS] |
| Prompt tokens pt | 252,072,162 [d6/resource_breakdown.tsv TOTAL] | 251,252,223 [d7/resource_breakdown.tsv TOTAL] | 116,811,506 [d8/report.md §3] |
| Cached pt (cct) | 245,632,448 (97.4%) [d6 TSV TOTAL] | 243,841,728 (97.0%) [d7 TSV TOTAL] | 112,380,096 (96.2%) [d8/report.md §3] |
| Total tokens tt | 253,446,818 [d6 TSV TOTAL] | 254,250,448 [d7 TSV TOTAL] | 117,772,452 [d8/report.md §3] |
| Wall-clock | 8.20 h (29,528 s) [d6/baseline_deltas.md wall row] | 18.04 h [d7/timeline.md line 3] | ~13.45 h [d8/report.md FINAL_TOTALS wall row] |
| ScoutCoder share of pt | 135,308,385 = 53.7% [d6/resource_breakdown.tsv ScoutCoder row] | 71,808,660 = 28.6% pt / 28.43% tt [d7/resource_breakdown.tsv ScoutCoder row] | 6,535,482 = 5.6%, diagnosis-only [d8/resource_breakdown.tsv; doctrine8_process_xray §1] |
| Substrate-interface consumption | 1/22 ops via built interface (W19); 19 via frozen-file fallback [d6/scoutcoder_operation_audit.tsv TOTAL] | 0/18 via task/CLI; 18/18 via AGS::FrozenSources helper (161 calls); boolean stream raw files [d7/workstreams/B_scoutcoder_investment.md §2; d7/doctrine6_vs_doctrine7_delta.md item 3] | native Boolean route zero H-004 quantities; science on 121 staged files + 878 bash calls [d8/doctrine8_process_xray §8] |
| Epistemic record consumption | 45/46 OBS cited; 2 defect batches caught pre-consumption [d6/remediation_backlog.md RB-7 evidence; d6/workstreams/E_epistemic_surface.md E2] | 57/57 record IDs resolve in final report; inventory defects caught at gates, not registration [d7/epistemic_value_trace.md tail; d7/remediation_backlog.md RM-11] | 49/49 cited; 11/11 corrections pre-consumption; ≥4 adjudication outcomes changed; 5 schema defects VERIFIED [d8/doctrine8_process_xray §8] |
| Cortex verdict | make-optional; 32 calls, 4 write-only pointers, 2 consumed reads [d6/workstreams/E_epistemic_surface.md E3] | net-positive but compensating a role-context defect (Lead read surface) [d7/workstreams/E_surface_value.md E-3] | net-neutral; 1 brief 550 B + 1 probe conversation, no other consumers [d8/doctrine8_process_xray §8 Cortex] |

**Comparability caveat [VERBATIM from d8/cross_run_comparison.md reading note (2)]:**
"total mission volume is NOT lower in doctrine8 (116.81M pt) — the savings
moved into conversation architecture and verification, which is where the next
remediation aims." d8's mission scope differs (1,299 vs 2,923 inferences; ~13.45
vs 18.04 h; science.v2 pipeline vs glm5, different mission design) — cross-run
pt totals are NOT a like-for-like efficiency measure; deltas indicative, not
controlled [d8/cross_run_comparison.md header; extraction notes Part 3 item 1].

**d7 sibling-audit accounting gap:** the aborted sibling pipeline cost pt ≈
515.5M *unduplicated* (includes receipt copies), recorded only in
d7/RECONCILIATION.md and never deduplicated ("Deduplicated figure: unknown") —
excluded from the d7 column above; unresolved upstream [extraction notes §1.3].

Counting-basis notes (carried conflicts; extraction notes Part 3): Boolean job
counts 3 bases (40 .info-only / 77 jobs / 8 kill-chain) — not resolved
[d8/h004_branch_analysis.md §5]; Cortex probe calls: foundation count 7
preferred over E's 17 [d8/context_delivery_matrix.md note]; d7 consumer slice
13/13 (not 12/12) [d7/doctrine6_vs_doctrine7_delta.md item 2]; kill-visibility
anchors: first kill 22:31/22:48:56, Manager 03:49, Lead 05:59–06:01 [d8/
h004_branch_analysis.md §4]; backbone (inference_id dedup) authoritative over
per-census sums [d7/doctrine6_vs_doctrine7_delta.md item 4; d8 F-D5].

## 2. Merged item table

### 2.1 d6 remediation backlog (RB-1..RB-7)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| RB-1 | d6 | No plan-premise revision trigger; wave-2 60.6M pt dispatched on contradicted premise | d6/remediation_backlog.md RB-1 | fix-here (forwarding duty + consumption citation) | doctrine | N |
| RB-2 | d6 | No consumer-environment verification; 135.31M pt built, 1/22 consumed | d6/remediation_backlog.md RB-2 | fix-here (slice rule) + delegate (probe task) | doctrine + scout-ai | N |
| RB-3 | d6 | Declared Lead-endorsement gate waived 1 min after design return | d6/remediation_backlog.md RB-3 (= RM-04 extends) | fix-here | doctrine | N |
| RB-4 | d6 | Packet norms: inline evidence, shared briefs, capped returns, reporter access | d6/remediation_backlog.md RB-4 | fix-here | doctrine + start_chats | N |
| RB-5 | d6 | Exec-failure opacity: 62 bwrap −1, no write receipts, mirror-chat traps | d6/remediation_backlog.md RB-5 (= RM-03 extends) | delegate + fix-here (retry line) | scout-ai + doctrine | N |
| RB-6 | d6 | Interface scope discipline; frozen-file default + consumption accounting | d6/remediation_backlog.md RB-6 (= RM-01, RM-16 extend) | fix-here | mission template | N |
| RB-7 | d6 | Preserve epistemic record discipline; uncited-record report; error job families | d6/remediation_backlog.md RB-7 (= RM-11/12/18, P1-3 extend) | fix-here | research procedure | N |

### 2.2 d7 remediation backlog (RM-01..RM-18 — note: 18 items exist, work order named 11)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| RM-01 | d7 | Mandate entity enumeration built 0-consumed surfaces; 46.34M pt authoring | d7/remediation_backlog.md RM-01 | fix-here (helper-first mandate text) | mission template | N |
| RM-02 | d7 | Consumer slice passed in builder env; dead in consumers 66 min later | d7/remediation_backlog.md RM-02 | fix-here (template) + delegate (probe task) | mission template + scout-ai | N |
| RM-03 | d7 | bwrap −1 wrapper hides inner exit/stderr; 107 raw failures (= FR-03, FR-04 family) | d7/remediation_backlog.md RM-03 | delegate | scout-ai | N |
| RM-04 | d7 | Scope endorsement gate absent; Lead first inference 2.6 h post-handoff | d7/remediation_backlog.md RM-04 | fix-here | doctrine | N |
| RM-05 | d7 | Lead/Manager read surfaces: stale-mirror adjudication, spec-paste relay | d7/remediation_backlog.md RM-05 | fix-here via P2-6 path (advisory option (a): tool-less Lead + Critic check; Manager artifact reads) | society/launch config + doctrine | N |
| RM-06 | d7 | Lead decisions unregistered 6.75 h; authority lived in chat text | d7/remediation_backlog.md RM-06 | fix-here (registration-before-dependent-bouts) | Manager procedure | N |
| RM-07 | d7 | No per-chat failure memoization; identical −1 bursts across 14 h (= FR-11/FR-12) | d7/remediation_backlog.md RM-07 | fix-here (role hint; read-before-edit) | start_chats | N |
| RM-08 | d7 | Phase-0 verdict lacks sandbox-visible workflow resolution row (P4) | d7/remediation_backlog.md RM-08 | fix-here | mission template | N |
| RM-09 | d7 | Serial Part II lanes doubled wall (18.04 h) at flat tokens | d7/remediation_backlog.md RM-09 | accept-with-reason (plan structure, not doctrine mandate; guidance names this) | Manager plan practice | N |
| RM-10 | d7 | Ungated mega-bout: 3 HYP / 508 inf / 48.2M tt / 4.5 h, no abort | d7/remediation_backlog.md RM-10 | fix-here (2-HYP/~2 h cap; folds into P1-5) | doctrine + Manager | N |
| RM-11 | d7 | Inventory reconciliation only at gates; 42 vs 43 rows two bouts | d7/remediation_backlog.md RM-11 | fix-here (registration-bout checklist) | research procedure | N |
| RM-12 | d7 | Transcribed-value clause removed in d7; 7/44 OBS attribution ambiguity | d7/remediation_backlog.md RM-12 | fix-here (restore clause) | research role text | N |
| RM-13 | d7 | Two-half protocol: registered artifacts not staged Manager-readable | d7/remediation_backlog.md RM-13 | fix-here (staging at pre-registration) | protocol template | N |
| RM-14 | d7 | MaBoSS cfg dialect undocumented; dangling symlink blocks re-run (= FR-06) | d7/remediation_backlog.md RM-14 | delegate (docstring) + environment (symlink) | Boolean workflow | N |
| RM-15 | d7 | Gene literature/identifier stack broken; quarantined by instruction (= FR-07) | d7/remediation_backlog.md RM-15 | delegate | Gene workflow | N |
| RM-16 | d7 | Fallback ladder walked down, never back; no dead-surface decision record | d7/remediation_backlog.md RM-16 | fix-here (decision-record rule) | Manager procedure | N |
| RM-17 | d7 | ScoutCoder probe-iteration churn; pin-first testing adopted late | d7/remediation_backlog.md RM-17 | fix-here (pin-first; ≤3 iterations) | ScoutCoder/start_chat | N |
| RM-18 | d7 | OBS Author field defaults Investigator; Analyst rows mislabeled | d7/remediation_backlog.md RM-18 | fix-here (author enum) | record template | N |

### 2.3 d8 remediation backlog (P0-1..P3-8)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| P0-1 | d8 | Pre-dispatch scale-probe rule absent; H-004 8 kills ~7 h, 8.3–9.3M tt avoidable | d8/remediation_backlog.md P0-1 (h004_branch_analysis.md §3–4) | fix-here (gate/spec template; advisory §3 two halves) + delegate (timeout-as-input) | doctrine + Boolean workflow | **Y** |
| P0-2 | d8 | Exec-failure surfacing: 70 .info-only jobs; kills reached Lead 7.5 h late | d8/remediation_backlog.md P0-2 (C-4, F1, F5, F6) | delegate | scout-ai | N |
| P1-3 | d8 | Epistemic schema: supported_qualified, tier vocabulary, retire, title-vs-ruling | d8/remediation_backlog.md P1-3 (E open checks 1–5, all VERIFIED) | delegate (API) + fix-here (correction-propagation checklist; advisory §4.1 co-design) | epistemic-API owner + research procedure | **Y** |
| P1-4 | d8 | Brief/attachment provisioning assertions; receipts archived in-run | d8/remediation_backlog.md P1-4 (F-B2/D1/F8; F-B5) | delegate | scout-ai | N |
| P1-5 | d8 | Long-conversation accumulation: 2 conversations = 73.7% of pt; pt/inf 102k→170k | d8/remediation_backlog.md P1-5 (F-A7) | fix-here (bout-split norm + record anchoring; advisory §2) | doctrine + role procedures | **Y** |
| P2-6 | d8 | Lead evidence-blind: 6 inf / 100% curated inputs; packet digest unverified | d8/remediation_backlog.md P2-6 (F-D1) | fix-here (Critic packet-correspondence check as gate precondition; advisory §1) | doctrine gate protocol | **Y** |
| P2-7 | d8 | Gate/ledger mechanics: dual timestamps, append-on-discovery, content-inlined gates | d8/remediation_backlog.md P2-7 (F-D2, F-D3) | fix-here | doctrine | **Y** |
| P3-8 | d8 | Planner stage unconsumed (1 inf / 36.7k pt; 0 citations; plan header PROPOSED) | d8/remediation_backlog.md P3-8 (F-D4) | fix-here (disable or consumption contract) | Planned config / mission template | **Y** |

### 2.4 d8 audit-section findings (named ledger rows)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| F-B3 | d8 | Preflight row 7 overstated Boolean breadth; 2/6 tools defective mid-run | d8/workstreams/B_capability_lifecycle.md F-B3 | fix-here (preflight must enumerate every tested op) | mission template | **Y** |
| F-B5 | d8 | Gate-4 scale-blocker receipt lives outside run archive (broken symlink) | d8/workstreams/B_capability_lifecycle.md F-B5 | fix-here (mirror receipts into run root) | mission template | **Y** |
| F-B6 | d8 | Preflight report date defects (wrong date/year); mixed scribe duties | d8/workstreams/B_capability_lifecycle.md F-B6 | fix-here (dates from receipts; Manager write path) | mission template | **Y** |
| F7 | d8 | Boolean/Gene tools Manager-only; Worker route dead; route (c) informed choice | d8/friction_register.tsv F7; WORKER#40 | fix-here (society roster declares asymmetry as standing constraint) | society roster | **Y** |

### 2.5 d7 friction register (FR-01..FR-14)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| FR-01 | d7 | Expected negative test: data/ absent probe (purpose was the test) | d7/friction_register.tsv FR-01 | accept | environment | N |
| FR-02 | d7 | Expected probe exits 1 with PASS lines in output; caught 2 wiring bugs | d7/friction_register.tsv FR-02 | accept | harness+agent | N |
| FR-03 | d7 | 107 raw / 26 dedup −1 wrapper failures, ~4.2M tt (→ RM-03) | d7/friction_register.tsv FR-03 | delegate (canonical at RM-03) | scout-ai | N |
| FR-04 | d7 | 9 bwrap `-c` quoting failures; write-script-then-run avoids | d7/friction_register.tsv FR-04 | fix-here (role hint) | start_chats | N |
| FR-05 | d7 | SaezLab symlink rediscovery by Worker; ~2.5M tt (→ RM-02/RM-08) | d7/friction_register.tsv FR-05 | environment (mounts) + fix-here (P4 row) | environment/user | N |
| FR-06 | d7 | MaBoSS cfg dialect 2 failures then converged (→ RM-14) | d7/friction_register.tsv FR-06 | delegate (canonical at RM-14) | Boolean workflow | N |
| FR-07 | d7 | Gene entrez/literature stack failures; quarantined (→ RM-15) | d7/friction_register.tsv FR-07 | delegate (canonical at RM-15) | Gene workflow | N |
| FR-08 | d7 | 5 agent ordering/path-assumption failures | d7/friction_register.tsv FR-08 | fix-here (role hint) | start_chats | N |
| FR-09 | d7 | SIGNOR HTTP 400 transient; in-script retries absorbed | d7/friction_register.tsv FR-09 | accept | environment | N |
| FR-10 | d7 | 57 script errors from in-mission development iteration | d7/friction_register.tsv FR-10 | fix-here (iterate-in-tmp norm) | start_chats | N |
| FR-11 | d7 | Identical −1 bursts 27×/19×/7×/5×; ~1.5M tt (→ RM-07) | d7/friction_register.tsv FR-11 | fix-here (canonical at RM-07) | start_chats | N |
| FR-12 | d7 | 12 precise_edit precondition failures from stale selectors (→ RM-07) | d7/friction_register.tsv FR-12 | fix-here (canonical at RM-07) | start_chats | N |
| FR-13 | d7 | Gem source not mounted; doctrine's source-inspection exception unexercisable | d7/friction_register.tsv FR-13 | accept-with-reason (documented env gap) | environment | N |
| FR-14 | d7 | Installed-gem mount gap, single occurrence | d7/friction_register.tsv FR-14 | accept-with-reason | environment | N |

### 2.6 d6 friction register (C01..C22; cross-refs where covered above)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| C01 | d6 | 62 raw bwrap −1 launch failures, cause-blind (→ RB-5) | d6/friction_register.tsv C01 | delegate (canonical at RB-5/RM-03) | scout-ai | N |
| C02 | d6 | Heredoc-correlated launch failures (14/62; 11% vs 3%) | d6/friction_register.tsv C02 | delegate (CI repro of bwrap argv/stdin) | scout-ai | N |
| C03 | d6 | 9 identical immediate retries after failure | d6/friction_register.tsv C03 | fix-here (doctrine line; = RB-5(e)/RM-07) | doctrine | N |
| C04 | d6 | 9 consecutive-failure storms, all ended by 2nd attempt | d6/friction_register.tsv C04 | fix-here (cap-2-then-switch rule) | doctrine | N |
| C05 | d6 | SaezLab/ExTRI2 mount absence; 71 load-failure mentions (→ RB-2) | d6/friction_register.tsv C05 | environment (mounts) | environment/user | N |
| C06 | d6 | Probe/test "executed-raised" exit-1 = normal test-loop cost | d6/friction_register.tsv C06 | accept | project code | N |
| C07 | d6 | Share-path invisibility: ~/.scout vs run-copy two path maps | d6/friction_register.tsv C07 | environment (mount/symlink or run-copy-relative emission) | environment/user | N |
| C08 | d6 | list_directory on host ~/.scout job paths → not-found | d6/friction_register.tsv C08 | accept-with-reason (documented map) | environment | N |
| C09 | d6 | "Unknown Path kind" error lacks accepted-kind list | d6/friction_register.tsv C09 | delegate (exception message) | scout-ai | N |
| C10 | d6 | search max-files 200 limit; agents re-scoped next call | d6/friction_register.tsv C10 | accept-with-reason | — | N |
| C11 | d6 | read/list 100k-char cap refusals; all adapted in one call | d6/friction_register.tsv C11 | accept-with-reason | — | N |
| C12 | d6 | Cortex resource-name misses; resolved by list-first | d6/friction_register.tsv C12 | accept | — | N |
| C13 | d6 | path_write compaction-tag guard rejects legitimate quoted content | d6/friction_register.tsv C13 | delegate | scout-ai | N |
| C14 | d6 | patch hunk-context failure; switched to precise_edit | d6/friction_register.tsv C14 | accept (doctrine already prefers precise_edit) | — | N |
| C15 | d6 | /tmp heredoc to missing dir; recovered via write tool | d6/friction_register.tsv C15 | accept | — | N |
| C16 | d6 | Boolean workflow symlink unmounted; ~8 calls via job dirs (→ C05) | d6/friction_register.tsv C16 | environment (canonical at C05) | environment/user | N |
| C17 | d6 | Single-line large outputs resist line pagination (→ RB-5(d)) | d6/friction_register.tsv C17 | delegate (char-based pagination) | scout-ai | N |
| C18 | d6 | Result-mirror chats carry 0 canonical inferences; naive sums mislead | d6/friction_register.tsv C18 | delegate (mirror-chat labeling) | scout-ai | N |
| C19 | d6 | 225 write-family jobs, zero persisted result receipts (→ RB-5(b)) | d6/friction_register.tsv C19 | delegate (canonical at RB-5) | scout-ai | N |
| C20 | d6 | Run-copy status fields frozen mid-run ('start' with both timestamps) | d6/friction_register.tsv C20 | accept-with-reason (timestamp-based reconstruction documented) | environment | N |
| C21 | d6 | Serialized one-call-per-inference tool loops (Critic 265/271) | d6/friction_register.tsv C21 | fix-here (parallel-call role line) + delegate (harness prompt batching) | start_chats | N |
| C22 | d6 | Lead read-surface constraint forced inlining; 1 delivery loss (→ RB-4/RM-05/P2-6) | d6/friction_register.tsv C22 | fix-here (packet checklist; canonical at RB-4) | doctrine | N |

### 2.7 Persistent repo frictions (v9-baseline.md; BF-1..BF-6)

| item_id | run | finding | citation | disposition | owner | ledger? |
|---|---|---|---|---|---|---|
| BF-1 | repo | workflows/ has 5 machine-absolute symlinks (Cortex, Reader, ScoutCoder, Semantics, Workspace); break at any other clone path | new_doctrine/work/v9-baseline.md §frictions 1 (git ls-files -s; commit 6a3ec78) | delegate (relative targets affect deployment) | ScoutCoder/Manager | N |
| BF-2 | repo | bin/bundle_doctrine.sh: no guards/exit → ~54 cp errors, exit 1; content diff-clean | v9-baseline.md §frictions 2 | fix-here (guards + exit 0) | bin/bundle_doctrine.sh | N |
| BF-3 | repo | doctrine_bundle/ and doctrine_bundle.v7/ untracked, not gitignored → permanent ?? noise | v9-baseline.md §frictions 3 | fix-here (.gitignore) | .gitignore | N |
| BF-4 | repo | Staged Agent/ namespace: every parse/deploy must stage chat dir with Agent/ copies (bundle script exists for this) | v9-baseline.md §frictions 4 (tmp/v8-step3/parse_probe.rb; .save/Agent/) | accept (works, documented); root fix delegate | — | N |
| BF-5 | repo | ScoutCoder submodule HEAD 488afcf contains start_chat commit 667d1e2; parent pins dd19a83 → pointer decision pending | v9-baseline.md §surprises 1 | fix-here (commit pointer bump on doctrine-v9; Manager decision pending) | repo | N |
| BF-6 | repo | v8-* work files exist only untracked (v8 commit excluded them, unlike v7) | v9-baseline.md §surprises 2 | fix-here (commit on doctrine-v9; Manager decision pending) | repo | N |

## 3. Verdicts re-tested (d6→d8 evidence)

**Epistemic records preserve — UNCHANGED, now conditional on schema work.**
d6: "preserve" — 45/46 cited, two pre-consumption defect catches (d6 E2).
d7: "preserve", control value shifting from API to gate, latency defects
(d7 E-2). d8: "pays" decisively — 49/49 cited, 11/11 corrections
pre-consumption, ≥4 adjudication outcomes changed — while all five user
schema suspicions were VERIFIED (d8 §8). The verdict stands but is now
predicated on P1-3 (enum, tier vocabulary, retire, title lifecycle), which is
ledger Y. No evidence in any run argues demotion.

**Computational substrate simplify — MOVED, then re-synthesized.** d6 verdict
was "simplify" (1/22 consumed; 135.31M pt). d7 flipped it to "preserve —
interface slice finally earned" via consumer-validated helper (18/18) while
the task/CLI surface stayed dead (0/18) (d7 E-1). d8 shows the staged-file
plane as the workhorse (121 files + 878 bash calls; native route zero H-004
quantities, retired post-hoc) (d8 §8). The v9 synthesis (already accepted,
advisory §4.2): staged-file route is the default; native routes earn keep by
demonstrated consumption. So "simplify" as a blanket rule is superseded by the
earn-keep rule — a genuine change driven by d7+d8 evidence, not by re-litigation.

**Cortex optional — CONFIRMED.** d6: "make-optional" (32 calls, 4 write-only
pointers, 2 consumed reads). d7: net-positive only as compensation for the
Lead read-surface defect — value disappeared once the defect is fixed (d7 E-3).
d8: net-neutral (one 550 B brief + one self-consuming probe; d8 §8; cross_run
reading note (3): "both runs' Cortex surfaces are net-neutral"). Three runs,
no case for Cortex as a default mission surface; optional stands.

## 4. Register method notes

- Source files read in full for id extraction: d6/remediation_backlog.md,
  d6/friction_register.tsv, d7/remediation_backlog.md, d7/friction_register.tsv,
  d8/remediation_backlog.md, d8/friction_register.tsv, plus consolidated
  d8/doctrine8_process_xray.md (§1–§12) and d8/workstreams B (F-B*) for the
  named audit rows; trend cells from the three resource_breakdown.tsv files,
  d6/baseline_deltas.md, d7/timeline.md, d8/report.md.
- Reader's extraction notes (v9-extraction-notes.md) supplied the mechanism
  layer and contradictions (Part 3); Research advisory (v9-research-advisory.md)
  supplied accepted recommendations mapped to ledger-Y rows (§1→P2-6,
  §2→P1-5, §3→P0-1, §4.1→P1-3, §4.2→RB-6/RM-01 family, §4.3→new packet-seeding
  practice, fix-here owner doctrine/role text).
- Discrepancy vs work order: d7 backlog contains RM-01..RM-18 (536 lines), not
  RM-01..RM-11; all 18 are registered. FR-15+ and C23+ do not exist (registers
  end at FR-14 / C22). d6 backlog ids are RB-1..RB-7 exactly.
