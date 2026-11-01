# AgentSuite redesign — closure report (Phase 8)

- **Date:** 2026-11-01 (Phase 8, closure bout)
- **Branch:** `ags-redesign` · **Pre-redesign baseline commit:** `1116c9a`
  ("Baseline before AGS redesign (pre-audit)")
- **Author:** Worker (closure execution); phase deliverables were produced
  across Phases 0–7 and gated as cited below.
- **Companion inputs:** `redesign-baseline.md` (git baseline),
  `redesign-role-contracts.md` (§6 stop conditions), `redesign-matrix-final.md`
  (authoritative capability record), `redesign-ags-route.md` (mission route),
  `redesign-smoke-results.md` (Phase 6), `redesign-pilot-report.md` +
  `redesign-pilot-resume-packet.md` (Phase 7), all in this directory.

## 1. Executive summary

The redesign replaced the AgentSuite society's ad-hoc per-agent instruction
piles with a two-layer shared-instruction architecture — a common doctrine
plus five focused doctrines (collaboration, discipline, handoff,
investigation, catalogue) and a rewritten society roster — implemented as 19
role start_chats (17 rewritten, 2 new: ScientificLead and Investigator)
wired through a canonical `Agent/` import namespace with explicit, verified
tool provisioning (effective-capability matrix, all probe checks true),
capped by an AGS mission route (Manager-driven, Research-curated artifact
layout, S1–S6 stop conditions) that was validated by 6/6 FitAgent smoke
scenarios and a bounded end-to-end surrogate pilot (mission foxo-pi3k:
stages 1–8 executed, Lead SUFFICIENT, Critic gate PASS), and is now
committed on `ags-redesign` as six logical commits awaiting a real-substrate
mission before any merge to `main`.

## 2. Final role configuration (19 agents)

The authoritative record is `redesign-matrix-final.md` §1 ("Final matrix
(all 19 agents)", probe checks §2, all true) — this table does not duplicate
its tool-column detail; per-row evidence lives there. Tier vocabulary
(matrix §1 header): **R3** = read-only Cortex trio; **A5** = R3 + write +
edit; **D5** = R3 + write; **C10** = full curator set.

| # | Role | Tier | Key imports | One-line identity |
|---|---|---|---|---|
| 1 | Basic | R3 | doctrine | Minimal baseline agent; doctrine footer Cortex reads only |
| 2 | ChatAnalyst | A5 | doctrine | Chat-transcript analyst with Workspace + self-analysis tooling |
| 3 | Clean | none | — | No-import utility agent; deliberately context-free |
| 4 | ComputerUse | R3 | doctrine | Legacy machine-use surface (`introduce: ComputerUse`) |
| 5 | Consultant | R3 | doctrine, catalogue | Specialist consultant invoked per catalogue, endpoint-routed |
| 6 | Cortex | C10 | doctrine, society | The workspace workflow's own agent; full curator set |
| 7 | Critic | R3 (+read-only Workspace) | doctrine, investigation+collaboration+discipline | Independent verifier; reads evidence paths, issues gated verdicts |
| 8 | FitAgent | R3 | doctrine | The FitAgent workflow's harness agent (use-case runner) |
| 9 | Manager | D5 | doctrine, society, collaboration+handoff | Budgeted loop controller; dispatches via packets, never substitutes judgment |
| 10 | Planner | R3 (+docs) | doctrine, society, collaboration+handoff | Design-level plan author in the Planned pipeline |
| 11 | Reader | C10 (deferred C-1) | doctrine, investigation+catalogue | Close-reading specialist over documents and mission material |
| 12 | Research | C10 (name retained pending §5 rename) | doctrine, society, investigation+discipline+handoff+catalogue | Evidence curator; sole mission-artifact writer (MC7 write rule) |
| 13 | ScoutCoder | A5 | doctrine, scout | Workflow-code specialist with ScoutCoder tooling |
| 14 | Searcher | A5-narrow | doctrine, investigation | Bounded discovery agent (15 tools); may answer `NO_SEARCH_NEEDED` |
| 15 | User | R3 | doctrine, society, collaboration+handoff | Liaison agent; restates requests, composes final reports |
| 16 | Visualizer | A5 | doctrine | Presentation/graphics agent |
| 17 | Worker | C10 | doctrine, collaboration+handoff | Execution agent; runs concrete tasks, produces artifacts |
| 18 | **ScientificLead** (new) | R3 (tool-less; no endpoint — MC5) | doctrine, society, collaboration+investigation+discipline+handoff | Owns scientific judgment: decomposition, hypothesis framing, go/no-go |
| 19 | **Investigator** (new) | A5 (explicit list) | doctrine, society, collaboration+investigation+handoff | Bounded conclusion-producer per question; cites result addresses |

(Import and tier columns transcribed from matrix §1; identities condensed
from the same file plus role `start_chat` openings — spot-checked against
`Manager/start_chat` and `ScientificLead/start_chat` on disk at commit
time. Status label: **validated** for the transcription, matrix rows are
the record.)

## 3. Verified context delivery (probe evidence chain)

Four independent checkpoints, cheapest first; each is a durable probe
output re-runnable from its `.rb` sibling:

1. **Phase 3 final snapshot** — `tmp/redesign-probes/redesign_phase3_final_snapshot.out`
   (19 `== <Agent>` blocks: imports, effective/cortex/non-cortex counts,
   `bare tool: Cortex: false`, `leftover imports: 0` for every agent; checks
   F1–F9 all true, incl. `F4_ScientificLead_3_tools_0_noncortex`,
   `F5_Investigator_28_A5_no_bare_Cortex`). Verified imports resolve and no
   `import:` message leaks into any model context.
2. **Phase 4 final probe** — `tmp/redesign-probes/redesign_phase4_final_probe.out`
   (checks G1–G13 all true: `G1_all_19_imports_resolve_zero_leftover`,
   `G10_ScientificLead_no_endpoint_added`, `G11_Searcher_still_15_tools`,
   `G12_all_others_match_phase4_expected`, `G13_only_Critic_changed_vs_phase3`).
   Verified the post-wiring effective set matches the design, matrix §2.
3. **Phase 6 S5 hermetic** — `tmp/ags-smoke/redesign_phase6_hermetic_s5.rb`
   → `s5-hermetic/s5_hermetic_result.json` + `redesign_phase6_s5.json`
   (8/8 checks ALL_PASS: true — all 5 changed roles' imports resolve,
   effective counts match matrix, doctrine text delivered verbatim after
   the `specialist:` typo fix). Verified text content, not just counts.
4. **Phase 7 first-turn probes** — per route §6.4, one model-turn probe per
   new conversation before real work; logs
   `tmp/ags-pilot/runlogs/ags-pilot-endpoint-probe-4-*.log` (endpoint
   selection) and `ags-foxo-pi3k-*.log` (role-context replies), summarized
   in `redesign-pilot-report.md` (probe findings 1–2). Verified live
   delivery at mission launch, including the two environment workarounds.

Chain status: **validated end-to-end** — static resolution (Phase 3/4,
hermetic Phase 6) plus live first-turn confirmation (Phase 7).

## 4. Smoke-test outcomes (Phase 6)

All six scenarios PASS; authoritative table and per-scenario evidence in
`redesign-smoke-results.md` §3 (details §2, fixes §4):

| # | Scenario | Role | Verdict | Key evidence |
|---|---|---|---|---|
| S1 | Lead outline | ScientificLead | PASS | 0 tool calls; all 4 required elements; `s1.main.chat` |
| S2 | Packet translation | Manager | PASS | hypothesis byte-identical; science/logistics split; `s2.main.chat` |
| S3 | Bounded conclusion | Investigator | PASS | GO verdict citing `evidence/finding.md`; Workspace-only surface |
| S4 | Verbatim registration | Research | PASS | `cortex_write` byte-identical + `.info` provenance |
| S5 | Context inspection | (deterministic) | PASS | 8/8 checks; `redesign_phase6_s5.json` |
| S6 | Long-output discipline | Worker | PASS | 208-line file + 235-word reply; `s6-rerun.main.chat` |

The only failures encountered were environment/infrastructure (dead model
name, tool-schema-incompatible backend, `specialist:` society typo), each
fixed minimally with a targeted re-run of the affected scenario only. S6's
first honest record (run 2 assistant turn not durably captured) was
superseded by the clean re-run, both retained on disk — verdict PASS is
claimed for the clean re-run, not the lost turn.

## 5. Pilot outcome (Phase 7, mission foxo-pi3k)

Cited from `redesign-pilot-report.md` and Cortex artifacts under
`ags/foxo-pi3k/` (12 artifacts, all with `.info` sidecars; conversations
`ags-foxo-pi3k`, `-lead`, `-q1|q2|q3`, `-record`, `-critic`).

- **Surrogate decision:** AGS data substrate unreachable at intake
  (re-verified: `tmp/ags-pilot/AGS_REACHABILITY.txt` — no AGS checkout, no
  AGS path map), so the mission ran in **sanctioned surrogate mode**
  (documented knowledge) rather than rerouting; unreachable-substrate
  questions would be S3-blocked (route §5.5). Stated in
  `ags/foxo-pi3k/reports/final.md` line 3.
- **Loop fidelity:** stages 1–8 executed with owners per route §2 (stage
  table in pilot report); three recorded deviations — staged start_chats
  for role agents, `workflows/` symlinks, `-record` suffix for the curation
  thread — plus the stage-9 fold (see carry item 4). All recorded in
  `reports/final.md`.
- **Stop condition:** **S1** — Lead sufficiency declaration at stage 7,
  ratified by the Critic PASS at stage 8 (S6 close-with-budget-remaining);
  budget respected: 3 questions, 1 broad search spent, 0 branch switches,
  no over-budget repairs (caps were repair ≤2, branch switches ≤1).
- **Critic verdict:** **PASS** — all four checks verified from durable
  paths (verbatim gate text persisted at `ags/foxo-pi3k/reports/critic-gate.md`;
  repo copy `tmp/ags-pilot/critic_reply.md`); one optional cosmetic repair
  (backfill `agent: Investigator` in `Q3-answer.md.info`, a count-checked
  `precise_edit` on the sidecar only) — performed and documented.

## 6. Phase 7 Critic carry list — each item addressed

1. **Route §6.3 packet pattern choice** — **decided (already in the doc):**
   §6.3 adopts the packet form defined in doctrine §6, `doctrines/handoff`,
   and Manager's template — one packet pattern everywhere, no new form.
   Status: closed by the route doc as written; first full-scale mission
   exercises it.
2. **Sidecar-edit exception record** — **decided and executed:** the only
   sidecar-only edit of the pilot (`Q3-answer.md.info`, `agent: null` →
   `"Investigator"`, bytes 2237→2247, count-checked `precise_edit`) is
   recorded in `ags/foxo-pi3k/reports/final.md` and the `-record`
   conversation; artifact content untouched. Convention going forward:
   sidecar repairs are curator actions logged in the mission record, never
   silent.
3. **Deployment gaps status** — **documented deferral (route §5):** no
   judgment endpoint exists (`consultant`/`visual` do not resolve; MC5
   evidence `redesign_phase4_endpoint_semantics.*`); Investigator lacks
   Semantics (route entity-property computation through Worker or
   Research); AGS substrate unreachable from this sandbox; "Research"
   agent/workflow name collision deferred with inventory
   (`redesign_phase4_rename_inventory.out`); `scout` §7 pre-redesign
   adjudication wording flagged, owner action for a later phase.
4. **Stage-9 fold status** — **documented deferral:** the fresh
   `-report` conversation (route §7 step 11) was folded into stage 8 for
   the bounded pilot (pilot report, open issue 4); a full-scale mission
   must exercise it as designed.
5. **Surrogate-scope statement** — **decided:** stated verbatim in
   `reports/final.md` ("Mode: sanctioned surrogate…") and §5 above; the
   pilot's two-part conclusion is documented-knowledge scoped, and the
   merge precondition (§8 below) requires a real-substrate mission.
6. **Pilot hygiene numbers** — **recorded:** budget respected (3 questions,
   1 broad search, 0 branch switches, 0 over-budget repairs; caps ≤2
   repairs, ≤1 branch switch); endpoint hygiene — live endpoint selected
   via staged `option endpoint qwen` lines, **no key material reproduced**
   anywhere in outputs or artifacts (Phase 6 carry rule respected; the 401
   probe output contains only OpenAI error text). Source: pilot report
   (findings + hygiene section), `-record` conversation final turn.
7. **Commit plan decision** — **decided and executed:** see §8 — six
   logical commits on `ags-redesign`, no merge to `main`, merge
   precondition stated.

## 7. Known limitations and open issues

Numbered; owner-hint tags: [suite] = AgentSuite repo work, [framework] =
scout-ai/scout-gear framework work, [env] = this deployment/environment.

1. [env] AGS data substrate unreachable — no AGS checkout or path map in
   this environment; AGS-data questions are S3-blocked, not rerouted
   (route §5.5; `AGS_REACHABILITY.txt`).
2. [env/framework] No judgment endpoint configured — `consultant`/`visual`
   do not resolve; ScientificLead intentionally carries no endpoint and
   runs on the default model (MC5). Any stage passing endpoint options
   would fail.
3. [env/framework] `LLM::Agent.load_agent` resolves a bare
   `<Role>/` dir (start_chat-only, no workflow) over `Agent/<Role>/`;
   the pilot worked around it with staged start_chats carrying
   `option: endpoint qwen` (pilot report, open issue 1). Proper fix is a
   packaging/resolution-order change in the framework.
4. [suite] Stage 9 (fresh `-report` conversation) not yet exercised as
   designed (folded into stage 8 in the pilot).
5. [suite] "Research" agent vs Research workflow name collision — rename
   deferred (contracts §5; inventory on disk).
6. [suite] Worker, Reader, and the Cortex agent hold the full C10 curator
   set including `cortex_rename`/`move`/`remove` — accepted residual risk
   (contracts §9 C-2); do not hand them stewardship over `ags/`.
7. [suite] `scout` §7 "Scientific investigation" still carries
   pre-redesign adjudication wording — flagged, out of scope, owner action
   for a later phase.
8. [suite] `FitAgent/etc/AI/qwen` holds a plaintext API key — deliberately
   NOT committed (also excluded by `FitAgent/.gitignore`); endpoint config
   must be provisioned per-deployment.
9. [suite] `ScoutCoder` submodule carries uncommitted internal edits
   (`README.md`, `start_chat`) from parallel work; the parent-repo pointer
   is unchanged (`496df9c`, shown as `-dirty`). Commit inside the submodule
   or revert before any merge.
10. [suite] Root junk file `]` (137 bytes, editor/redirect mishap;
    pre-existing per `redesign-baseline.md` §3) left untracked.
11. [framework] S6 first honest record had a lost assistant turn
    (durability of `cortex_continue` stdout under that backend); mitigated
    by log capture (`tmp/ags-pilot/runlogs/`) and the clean re-run.

## 8. Rollback points and commit plan

**Git state before this bout:** all redesign work sat uncommitted on
`ags-redesign` (tracked diff 15 files +643 −365 vs `a552de1`; untracked
`new_doctrine/`, `doctrines/`, `bin/`, `Agent/` bundle, `ScientificLead/`,
`Investigator/`, `etc/`, `workflows/`). Baseline for rollback:
`1116c9a` ("Baseline before AGS redesign (pre-audit)") — pre-redesign
`main` content.

**Commit plan executed** (six logical commits, chronological):

| Commit | Contents |
|---|---|
| `333b540` | Phase 2 shared instruction layer: `doctrine`, `society` rewrite, `doctrines/{catalogue,collaboration,discipline,handoff,investigation}`, `bin/bundle_doctrine.sh` |
| `3cc17a9` | Phases 0–1 deliverables: `redesign-baseline`, `redesign-audit-{a-agents,b-shared,c-matrix}`, `redesign-audit-context`, `redesign-role-contracts`, `change-report-redesign-{doctrine,roles,wiring}`, `redesign-matrix-final` |
| `e371fd0` | Phase 3 role implementation: 11 `start_chat` rewrites incl. new `ScientificLead/`, `Investigator/` |
| `6a3ec78` | Phase 4 wiring: `Agent/` namespace (8 role start_chats + `doctrine`/`society`/`doctrines` symlinks), `etc/AI` symlink, `workflows/` symlinks |
| `bb0ce2c` | Phases 5–7: `redesign-ags-route`, `redesign-smoke-results`, `redesign-pilot-report`, `redesign-pilot-resume-packet` |
| `27f3844` | Carried parallel (pre-redesign) work: reader-split reports, `research/claude-meta-evidence/` |

Plus this closure report and the resume-packet pointer line, committed as
the final closure commit (sha recorded in §11 below).

**Deliberately excluded, and why:** `tmp/` (scratch/probes/logs;
`.gitignore`d), `var/` (job/cortex stores; ignored), `FitAgent/etc/AI`
(plaintext API key — security), `doctrine_bundle/` (generated by
`bin/bundle_doctrine.sh`), the root `]` junk file (pre-existing garbage,
§7.10), and the `ScoutCoder` submodule's internal edits (not this
redesign's work to commit; noted as open issue §7.9).

**What a rollback to `1116c9a` would lose:** the entire shared-instruction
layer, all 19-role configuration, the `Agent/` namespace and wiring
symlinks, every redesign deliverable (audits, contracts, matrix, route,
smoke, pilot, closure), and the git history that makes the work reviewable
— the mission artifacts and conversations under `var/cortex/` would remain
on disk (untracked) but orphaned from any committed route. Rollback is
therefore a full redo, not a partial unwind; intermediate per-phase
rollback is possible at the commit boundaries above.

**Merge precondition (do NOT merge to `main` yet):** a full-scale mission
against the real AGS substrate — exercising stage 9 as designed, the §6.3
packet pattern, and at least one S3-blocked question recorded verbatim —
ending in a Lead sufficiency declaration and a Critic PASS, plus closure
of §7.9 (submodule state). Until then `ags-redesign` is the review branch.

## 9. Launch instructions (from the route doc)

Full procedure: `redesign-ags-route.md` §6 (launch instructions) and §7
(quick-launch checklist, 12 steps). Condensed:

1. Drift check on `ags-redesign`; Manager restates the mission, picks
   `<slug>`, declares budget; Research writes `ags/<slug>/mission.md`.
2. Create the conversation set (`ags-<slug>`, `-lead`, `-q<nn>`,
   `-record`, `-report`) via `cortex_continue`, Manager-owned.
3. **Probe each new conversation first** (route §6.4 first-turn delivery
   probe) before dispatching real work.
4. Run the loop per route §2 owners; Research performs every mission
   artifact write (MC7 verbatim-packet rule); stop on S1–S6.

**Two environment workarounds required in this checkout:**

1. **Staged role start_chats** — `LLM::Agent.load_agent` resolves the bare
   `ScientificLead/`/`Investigator/` dirs over `Agent/<Role>/` (§7.3), so
   role turns are launched with the staged `Agent/<Role>/start_chat`
   copies carrying `option: endpoint qwen`; the launch helper
   (`tmp/ags-pilot/launch_role_turn.sh`, stale-claim clearing + env) is
   the reference implementation.
2. **Discovery symlinks** — `workflows/` links for
   Reader/Workspace/ScoutCoder/Semantics/Cortex and `etc/AI` →
   `FitAgent/etc/AI` so workflow tool discovery and the `qwen` endpoint
   config resolve from the chat anchor.

**Endpoint situation:** no judgment endpoints exist
(`consultant`/`visual` unresolvable); ScientificLead deliberately carries
no endpoint line and runs on the default model — **do not pass endpoint
options to any stage** except via the staged start_chats' own
`option endpoint qwen`; the 401 probe showed an unset endpoint falls
through to `api.openai.com` with an invalid key. Key material lives only
in the untracked `FitAgent/etc/AI/` and must never be committed.

## 10. Acceptance-test check (plan's phase criteria)

The plan's phase-level criteria, as gated (verdicts as recorded in each
deliverable and this bout's introduction):

| Phase | Criterion (deliverable) | Verdict |
|---|---|---|
| 0 | Audit + baseline (`redesign-baseline`, audits a/b/c, audit-context) | **met** — PASS |
| 1 | Role map + authority contracts (`redesign-role-contracts`) | **met** — PASS after repair |
| 2 | Shared instruction layer (`change-report-redesign-doctrine`; `doctrine`, `society`, 5 doctrines) | **met** — PASS after repair |
| 3 | Role implementation (`change-report-redesign-roles`; 19 start_chats) | **met** — PASS after import repair |
| 4 | Wiring + capability matrix (`change-report-redesign-wiring`, `redesign-matrix-final`) | **met** — PASS after matrix errata |
| 5 | AGS route doc (`redesign-ags-route`) | **met** — PASS after MC7 write-authority repair |
| 6 | Smoke tests 6/6 (`redesign-smoke-results`) | **met-with-caveat** — 6/6 PASS after honest S6 record + re-run; S6's first clean attempt lost a turn (§7.11) |
| 7 | Bounded pilot (`redesign-pilot-report`) | **met-with-caveat** — PASS in sanctioned surrogate mode; stage 9 folded (§6.4), substrate unreachable (§7.1) |
| 8 | Closure + commits (this report) | **met** — commits executed per §8; merge precondition open by design |

Caveat on provenance: the original plan text itself was not re-readable
from a durable file this bout (it lived in the orchestrating conversation);
the per-phase criteria above are the deliverables and gate verdicts
recorded in the committed reports, which is the durable form of the plan's
acceptance surface.

## 11. Post-commit drift check

Run after the closure commit; expected end state and actual result are
recorded verbatim in `tmp/ags-pilot/DRIFT_CLOSURE.txt` and summarized
here: tracked tree clean except the known residuals (ScoutCoder submodule
`-dirty` from parallel work, untracked `]` and `doctrine_bundle/`,
ignored `tmp/`/`var/`), branch `ags-redesign`, HEAD = closure commit;
tracked-diff vs `a552de1` now 101 files +9699 −277 (was 15 files +643
−365 at pilot end; the growth is the committed redesign content).

- Closure commit: the commit that introduced this file at the tip of
  `ags-redesign` (self-referential, so not restated here as a literal sha;
  resolve with `git log -1 --format=%h -- new_doctrine/work/redesign-closure.md`).
  The sha current at closure is recorded in
  `tmp/ags-pilot/DRIFT_CLOSURE.txt`.
