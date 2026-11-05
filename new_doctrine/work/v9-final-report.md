# Doctrine-v9 — final report (Manager's report, transcribed faithfully)

Branch `doctrine-v9` @ 23 commits from rollback 46433830 (doctrine-v8 tip),
linear, 0 merges. Gate: Critic PASS (prior review + re-test; see
`new_doctrine/work/v9-closure.md`). All claims below cite v9 artifacts.

## 1. Executive summary

What was asked: turn the d6→d8 evidence into a doctrine revision —
"report we can later enact" plus "fix those from here" for AgentSuite-local
items.

What was done: **doctrine-v9 was designed AND implemented** on the branch —
evidence register (81→79 rows, recount verified), 23-row change ledger,
design decisions (D1 hybrid shared-brief; D2 submodule pointer), full
implementation across doctrine/doctrines/role start_chats/society/mission
template/tooling hygiene, hermetic delivery verification (29/29), behavioral
spot checks (3/3), Critic gate NEEDS_WORK → corrections → **PASS**.
Everything outside AgentSuite ownership (scout-ai base repo, epistemic API,
Boolean tooling, environment) is delivered as enactable report content plus
four delegation packets in `new_doctrine/work/v9-packets/`.

## 2. Interpretation statement

The user's "report we can later enact" + "fix those from here" was
interpreted as: **AgentSuite-local, evidence-backed fixes implemented now on
doctrine-v9; everything else delivered as enactable report content +
packets.** The evidence base and the edit contract (register, ledger,
decisions) live in committed work files independent of the implementation:
discarding the branch would lose only the implementation, not the design —
`git checkout doctrine-v8` restores pre-v9 and the ledger/register still
specify exactly what to redo.

## 3. Cross-run trend (source: v9-evidence-register.md §1, cited there)

| Metric | d6 | d7 | d8 |
|---|---|---|---|
| Inferences (dedup) | 2,728 | 2,923 | 1,299 |
| Prompt tokens pt | 252,072,162 | 251,252,223 | 116,811,506 (96.2% cached) |
| Total tokens tt | 253,446,818 | 254,250,448 | 117,772,452 |
| Wall-clock | 8.20 h | 18.04 h | ~13.45 h |
| ScoutCoder share of pt | 53.7% | 28.6% | 5.6% (diagnosis-only) |
| Substrate-interface consumption | 1/22 via built interface; 19 frozen-file fallback | 0/18 task/CLI; 18/18 via helper | native Boolean zero H-004; 121 staged files + 878 bash calls |
| Epistemic record consumption | 45/46 OBS cited; 2 defect batches pre-consumption | 57/57 IDs resolve; defects caught at gates | 49/49 cited; 11/11 corrections pre-consumption; ≥4 adjudications changed |
| Cortex verdict | make-optional (32 calls; 2 consumed reads) | net-positive, compensating a role-context defect | net-neutral (550 B brief + self-consuming probe) |

Comparability caveat (verbatim from d8 cross-run reading note, quoted in
register §1): "total mission volume is NOT lower in doctrine8 (116.81M pt) —
the savings moved into conversation architecture and verification, which is
where the next remediation aims." d8's mission scope differs (1,299 vs 2,923
inferences; ~13.45 vs 18.04 h; science.v2 vs glm5, different mission design);
deltas indicative, not controlled. **d7 sibling-audit accounting gap:** the
aborted sibling pipeline cost pt ≈515.5M *unduplicated* (receipt copies
included), recorded only in d7/RECONCILIATION.md and never deduplicated —
excluded from the d7 column; unresolved upstream.

**Verdicts re-tested (register §3):** epistemic records **preserve** — now
conditional on P1-3 schema work; computational substrate — "simplify"
superseded by **earn-keep synthesis** (staged-file default, native routes
earn keep by demonstrated consumption); Cortex **optional** — confirmed
(three runs, no case for a default mission surface).

## 4. What changed in v9 (23 ledger rows → ~8 headline changes)

1. **Computation authority + consumer-context slices** (CL-01, CL-02; RB-2,
   RB-6/RM-01 family, advisory §4.2): staged-file route is the default;
   native routes must demonstrate consumption to keep; dispatch packets carry
   consumer-context slices and run ids.
2. **Gate mechanics** (CL-03, CL-04; RB-3, RM-04, RM-06≡P2-7): dual
   timestamps, append-on-discovery for gate files, content-inlined evidence
   instead of bare pointers.
3. **Retry caps** (CL-06; RB-5, RM-07, FR-11/12): two consecutive identical
   failures ⇒ stop and escalate; no silent retry loops.
4. **Registration discipline** (CL-07, CL-08; RB-7, RM-11/12, P1-3
   contract-input half): author = acting role; Lead adjudication vocabulary
   is a contract input to the epistemic store **before Gate-1**.
5. **Bout contracts** (CL-09; advisory §2): one named deliverable per
   conversation; mandatory split on new work order / gate crossing / phase
   boundary; soft trigger >60–80 inferences or mean pt/inf ≥1.5× early mean;
   anchors specified per role (Research, Analyst).
6. **Dual scale-probe rule** (CL-10; P0-1, advisory §3): Manager pre-dispatch
   — ≥10× workload ratio requires a capped wrapper-free single-item probe at
   target scale on frozen input (≤20 min, sha-cited) or a Lead waiver with a
   pre-registered decision rule; Lead spec-freeze review — largest item,
   largest validated item, ratio, target-scale datapoint or pre-registered
   capped-probe plan, T_slice rule (>20 min full-scale item ⇒ staged-file
   route before any batch dispatch).
7. **Critic correspondence check + seeded environment facts** (CL-11, CL-17;
   advisory §1/§4.3): Critic verifies load-bearing packet numbers against the
   cited records before every gate ruling; work orders carry a standing
   environment-facts header (kills the d8 environment-rediscovery tax).
8. **Mission template + hygiene** (CL-12, CL-19, CL-20, CL-21; F-B3/B5/B6,
   F7): mission template installed at `doctrines/mission_template` with
   preflight/hardening; bundle-script guards; gitignore for
   `doctrine_bundle/`; society constraint notes. **Decisions:** D1 hybrid
   shared-brief mechanism (pointer only after verified recipient access,
   decision-critical facts always inlined); D2 ScoutCoder submodule pointer
   bumped (implemented as 7da7ab8 superset, see §5).

## 5. Deviations

- **CL-18 disable-branch not implemented**: disabling the plan stage for
  operational restatements would have required a new chat option + dependency
  rewiring in `Planned/workflow.rb` — beyond minimal-edit intent. Recorded in
  v9-migration.md; **accepted by Critic** as a legitimate deviation; needs
  its own ledger row if wanted.
- **D2 implemented as 7da7ab8 superset**: the work order said bump to
  488afcf; the submodule checkout additionally carried the v9 CL-14 pin-first
  commit, so the parent gitlink was bumped to 7da7ab8. Critic-verified: the
  range 488afcf..7da7ab8 contains exactly one extra commit touching one
  start_chat line.

## 6. Verification status (honest labels)

| Item | Status | Label / caveat |
|---|---|---|
| Hermetic delivery matrix (7 roles × tools/imports/introductions/wiring) | 29/29 PASS | Reproduced independently by Critic (fresh parse_probe + import_match) — validated |
| Behavioral spot checks (B-1 Manager scale-probe, B-2 Research bout split, B-3 Critic correspondence) | 3/3 PASS | **Single-sample**: each rule fires at its decision point; not a firing rate; no pre-v9 sensitivity comparison (3-inference budget consumed) |
| 5b probe conditions | PASS w/ caveat | Role wiring (tool:/task:/introduce:/kb:/path_kind:/exec_task:) and `socialize:` capability stripped for raw `LLM.ask` — system-text rules only; hermetic matrix covers wiring |
| 5b receipts | documented | Saved verbatim answers + runner scripts (`tmp/v9-probes/live/receipts/`), **not job paths** — LLM.ask cache ephemeral under bwrap |
| Bundle delivery | exit 0, byte-identical | All copies diff-clean; re-run twice after last edit (step 4, step 6b), Critic re-ran once |
| Register row count | **79** | RB 7 + RM 18 + P 8 + FR 14 + F 4 + C 22 + BF 6; earlier "81" figure was wrong — independently recounted by Critic |
| Not-testable hermetically | carried verbatim | mission-template instantiation; Planned runtime; society consumption at launch; domain-tool provisioning (Boolean/Gene outside repo; only society F7 constraint note verifiable) |

## 7. Delegated items (one line each → `new_doctrine/work/v9-packets/`)

- **scout-ai-base-repo.md** — exec-failure surfacing past bwrap −1; .info-only
  job birth + late .error rejection; cortex_brief tool attachment +
  tools-attached receipt; char-based pagination; path_write compaction guard;
  mirror-chat labeling; per-call token metering; staged Agent/ namespace root
  fix; socialize/z.ai 1214.
- **epistemic-api.md** — supported_qualified enum; evidence_tier closed
  vocabulary (measured vs derived; 16/39 d8 records); delete/retire +
  disposable namespace; title lifecycle (C-005).
- **boolean-tooling.md** — timeout as first-class input (8 SIGTERM kills
  ~3600 s each, ~7 h wall, 8.3–9.3M tt avoidable); kill attribution in
  `.info`; MaBoSS cfg dialect; external 3600 s killer investigation.
- **environment.md** — searxng dead (28 mentions, 0 successful calls);
  ExTRI2/SaezLab mounts; workflows/ machine-absolute symlinks (targets
  listed); user-owned decisions.

## 8. Open items

- `Priest/` untracked directory (appeared after the last v9 commit; no v9 row
  owns it) — repo-hygiene decision needed.
- ChatAnalyst gitlink ahead of pin (parent 25f423a, submodule HEAD 2bbc1e9
  clean descendant adding `import: Agent/doctrines/scientific_investigation`)
  — trivial future bump, outside v9 ownership.
- CL-18 disable-branch — candidate new ledger row.
- The merge decision itself (user-owned).

## 9. Launch checklist (user-side, minimal)

a. Decide merge doctrine-v9 → main, or keep the branch.
b. Re-point `workflows/` symlinks if launching from a different host (five
   absolute targets listed in the environment packet; relative-target fix is
   a separate change request).
c. Confirm searxng is up, or accept no web search (d8 fallback documented).
d. Launch the new use case via Planned with the mission template — preflight,
   pre-dispatch probes, and bout contracts are now in doctrine and need no
   manual setup.
e. Optionally record per-run light accounting (the two-level evaluation
   regime: light every run, full X-ray on regression — CL-13/CL-16
   territory).

## 10. Rollback point

**46433830** (doctrine-v8 tip). Branch doctrine-v9 is 23 commits linear from
it, 0 merges; `git checkout doctrine-v8` restores pre-v9. The design survives
independently (register + ledger + decisions are committed work files).

Artifacts: `new_doctrine/work/v9-{baseline,evidence-register,change-ledger,
design-decisions,migration,deployment-verification,behavioral-results,
closure,final-report}.md`, `new_doctrine/work/v9-packets/{scout-ai-base-repo,
epistemic-api,boolean-tooling,environment}.md`, probes in `tmp/v9-probes/`.
