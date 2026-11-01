# AGS orchestration route — launch configuration (Phase 5)

- **Date:** 2026-11-01 (Phase 5 bout)
- **Repo:** `/bulk/mvazque2/git/AgentSuite`, branch `ags-redesign`
- **Status:** route configuration — documentation only. No workflow code,
  no `Planned/workflow.rb` edit, no start_chat, roster, or shared-doc
  changes this bout (§8).
- **Authority chain** (all under `new_doctrine/work/`): Phase 0 audit
  `redesign-audit-context.md` §1 (the AGS route is not expressible as a
  fixed stage chain in `Planned/workflow.rb`; sibling shape recommended)
  → role contracts `redesign-role-contracts.md` (§2 boundaries, §6 stop
  conditions, D3/D4/D5) → matrix `redesign-matrix-final.md` (Phase 4
  final, 19 agents) → this document. The plan's constraint — a documented
  Manager-driven route over new orchestration code, `Planned/workflow.rb`
  edited only if options cannot express the route — is honored: no code
  added, no file outside `new_doctrine/` touched.

## 1. What the route is, and is not

A **Manager-driven conversation route**: one bounded scientific mission
runs as a small set of named Cortex conversations plus mission-scoped
artifacts, orchestrated by the Manager through `cortex_continue` /
`cortex_brief` — its only delegation surface (matrix row *Manager*, D5).
Every mechanism it relies on exists today (verified vs assumed, §6.4):
`cortex_continue` with a not-yet-existing name seeds an empty chat and
persists every turn under the conversations namespace
(`Cortex/lib/Cortex/tasks/conversation.rb`), returning an `agent_meta`
provenance receipt; the delegation packet form (doctrine §6,
`doctrines/handoff`, Manager's `# Introduction / # Current state /
# Design / # Task / # Output required` template — referenced in §6.3);
S1–S6 (contracts §6; §4 below); the matrix as per-agent capability truth.

It is **not** a new workflow directory and not a stage chain: inside
`Planned` only per-run work-agent selection (`option worker_agent
ScientificLead`) and search suppression exist — one stage's agent
changed, never a review loop [CTX §1]. A request that fits one linear ask
belongs to Planned; this route exists for missions with a question
decomposition, a review loop, and a record to keep.

## 2. Route stages

Owner is the agent invoked (`cortex_continue --conversation <name>
--agent <Owner>`); the Manager dispatches or performs every stage.

| # | Stage | Owner | Durable deliverable |
|---|---|---|---|
| 1 | Intake | Manager | restatement + budget declaration, sent to Research as a Curator request (verbatim wording); Research writes `ags/<slug>/mission.md` and confirms the path |
| 2 | Reconnaissance | Searcher (Reader for close reading of mission material) | recon brief / Reader dossier in `ags/<slug>/evidence/`; `NO_SEARCH_NEEDED` is valid and binds the caller |
| 3 | Background search | Searcher | background brief in `ags/<slug>/evidence/`; sentinel as above |
| 4 | Scientific plan | ScientificLead | outline: per question — hypothesis, evidence standard, discriminating experiment to run first, review point, reopening condition; Manager sends the outline to Research as a Curator request (Lead's wording verbatim), Research scaffolds `ags/<slug>/questions/Q<nn>-<slug>.md` and confirms the paths |
| 5 | Work orders | Manager | one work-order packet per question into its investigation conversation; acquisition needs become Curator requests to Research |
| 6 | Investigation loop | Investigator (one per question) | bounded conclusion with evidence chain; findings as `ags/<slug>/evidence/` artifacts citing result addresses / run receipts (Investigator writes its own findings — it holds write, A5); Research registers Observations/Claims/Hypotheses from handed-over results |
| 7 | Lead review checkpoint | ScientificLead | go/no-go with rationale and reopening condition, sent to Research as a Curator request; Research appends it to the question artifact and confirms the path; sufficiency close (S6) allowed even with budget remaining |
| 8 | Consolidation | Research (optional Critic gate on consequential results) | compiled epistemic record in `ags/<slug>/reports/`; Critic verdict cited by receipt path when the gate ran |
| 9 | Reporting | User or Manager, **fresh conversation** | composes the final report from cited durable paths; Research persists it as `ags/<slug>/reports/final.md` and confirms the path |

Loop: stages 6–7 repeat per question until each is answered, explicitly
closed, or blocked (S3); Manager keeps active branches ≤2 (S2) and routes
every conclusion back through the Lead — never substituting scientific
judgment in either direction (D5; `Manager/start_chat` AGS clause).

## 3. Mission artifact layout (the Phase 2 deferred item)

**Provenance:** Phase 2 stripped the unauthorized `mission/<name>/`
layout lines from `doctrines/handoff` and deferred the layout here
(`change-report-redesign-doctrine.md`, §"AGS layout strip-and-defer";
raw material `tmp/redesign-probes/handoff.pre-phase2b`). `doctrines/
handoff` still points here: *"The layout for mission-scoped Cortex
artifacts is defined by the AGS route configuration (Phase 5)."*

All mission-scoped Cortex **artifacts** live under one namespace per
mission:

```
ags/<mission-slug>/mission.md                  charter, budget, conversation map, status
ags/<mission-slug>/questions/Q<nn>-<slug>.md   one per owned question
ags/<mission-slug>/evidence/                   findings, dossiers, reusable briefs
ags/<mission-slug>/reports/                    epistemic record, verdicts, final report
```

- **Naming.** `<mission-slug>` lowercase-hyphen, stable for the mission's
  lifetime, chosen at intake; questions numbered in the Lead's
  decomposition order (`Q01`, `Q02`, …); evidence and report files carry
  semantic names; every name under the namespace is unique.
- **Who writes — Research writes, others request [MC7].** Every mission-artifact write is performed by Research as Curator, receiving wording **verbatim** in a packet and confirming the durable path back: Manager's intake restatement → `mission.md`; the Lead outline → `questions/` scaffolding; review outcomes and go/no-go decisions → appends to question artifacts; the reporting agent's composed report → `reports/final.md`. Investigator, Reader, and Searcher also write into `evidence/` directly (they hold write: A5/A5/C10). Research alone performs rename/move/remove stewardship inside the namespace (curator set, matrix row *Research*, C10). `.info` sidecars and history snapshots come free with every write. **Caution:** Manager (D5), User, and ScientificLead hold **no cortex_write** — nothing in the route may assign them an artifact write; their contribution is the verbatim wording in the Curator request, never the write itself.
- **How cited.** Always by durable logical path, never an inlined copy
  (the handoff contract's cite-don't-duplicate rule); computed evidence
  cites result addresses and definition versions, not transcribed values.
- **Rationale.** One namespace per mission keeps citations unambiguous
  across missions, maps 1:1 onto the Lead's decomposition, and makes a
  whole mission enumerable with one `cortex_list` prefix query
  (`ags/<slug>/`). No scaffold is created in advance; a mission that
  outgrows the layout may extend it inside its own directory (same ruling
  as the stripped Phase 2 lines).

Scientific records (Observations/Claims/Hypotheses) are **not** mission
artifacts: they live in the Research workflow's Path-kind record
interface; mission artifacts cite them by identifier.

## 4. Stop conditions

S1–S6 as frozen in the contracts (`redesign-role-contracts.md` §6):

- **S1 Lead go/no-go** — explicit decision at each review point, recorded
  in the question artifact; Manager may not reverse a scientific no-go
  (a budget/authority stop is recorded as a non-scientific override).
- **S2 Budget exhaustion** — Manager's declared budget (plans 2–4,
  branches ≤2, broad search ≤1 pre-execution, repair cycles ≤2, branch
  switches ≤1) stops the loop at a step boundary with partial results
  preserved durably; budget stop is Manager's call.
- **S3 Blocked questions** — smallest unblocking dependency outside the
  loop's authority; owner reports blocked per doctrine §9; Lead
  reclassifies: drop, defer with reopening condition, or escalate via
  Manager → User.
- **S4 Natural completion** — every question answered or explicitly
  closed; Lead declares completion; Research closes record state; the
  route proceeds to consolidation and fresh reporting.
- **S5 No momentum rule** — never continue past a satisfied stop
  condition; reopening requires new evidence through S1's condition.
- **S6 Sufficiency close** — the Lead may close a branch when its
  evidence chain is complete enough to support or refute its hypothesis,
  even with budget remaining (anti-gold-plating, ratified [MC2]).

**Route-level stop:** the mission is complete when the Lead declares the
evidence chain sufficient — S6 per branch, S4 for the decomposition.
Consolidation and reporting then run mechanically; no stage after the
declaration reopens questions (S5's territory).

## 5. Endpoint and tool cautions (Phase 4 facts)

Matrix and wiring report; all validated by hermetic probe.

1. **No judgment endpoint exists.** `endpoint:` lines select an LLM config
   under `Scout.etc.AI`, empty here: `consultant` and `visual` do not
   resolve and would raise `Endpoint not found` on a live ask (MC5:
   `tmp/redesign-probes/redesign_phase4_endpoint_semantics.*`).
   ScientificLead carries **no** endpoint, runs on the default model;
   launch instructions must not pass endpoint options to any stage.
2. **Investigator lacks Semantics** (Workspace + explicit Cortex
   list/search/read/write/edit, A5). Route entity-property computation
   through Worker (Manager work order) or Research-driven Semantics; the
   Investigator cites result addresses it is handed.
3. **Worker, Reader (and the Cortex agent) hold the full C10 curator
   set** — `cortex_rename`/`move`/`remove` included — an accepted residual
   risk (contracts §9 C-2). Do not hand them workspace stewardship over
   `ags/` artifacts; mission-namespace stewardship is Research's (§3).
4. **"Research" is two things.** The Research **agent** (evidence curator)
   and the Research **workflow** (Path kinds, record interface) share a
   directory name; rename deferred with its inventory
   (`tmp/redesign-probes/redesign_phase4_rename_inventory.out`). Packets
   and reports must always say which.
5. **AGS data substrate unreachable from this sandbox** [CTX §4] — mission
   material enters only through paths this environment can see; an
   unreachable substrate makes the affected questions S3-blocked, not
   rerouted.
6. **Flagged, not fixed (out of scope):** `scout` §7 "Scientific
   investigation" still carries pre-redesign adjudication wording
   ("claims assessed … hypotheses challenged") that the redesign moved to
   ScientificLead; owner action for a later phase.

## 6. Launch instructions

### 6.1 Conversation set (Manager creates via `cortex_continue`)

Flat names, one mission prefix — matching the store's existing flat-name
practice (nested names are legal but unused for conversations):
`ags-<slug>` (mission control: loop state, budgets, overrides);
`ags-<slug>-lead` (Lead direction/review); `ags-<slug>-q<nn>` (one per
question, Investigator); `ags-<slug>-record` (Research curation thread,
optional — Research may work one-shot); `ags-<slug>-report` (**fresh**
conversation for stage 9, so the report synthesizes from cited paths, not
mission-control history). Conversation names stay distinct from artifact
paths (`ags-<slug>-q01` conversation vs `ags/<slug>/questions/Q01-….md`
artifact).

### 6.2 Agent per stage

Intake Manager (itself); recon/background Searcher (Reader when mission
material needs close reading — dispatched through a Research or Manager
packet; Reader does not self-delegate); plan and review ScientificLead;
work orders Manager; investigation Investigator; registration, lifecycle,
consolidation Research; verification gate Critic (optional, consequential
results); reporting User or Manager.

### 6.3 Packets

Every dispatch uses the packet form already defined in doctrine §6,
`doctrines/handoff`, and Manager's template. The Lead's decomposition,
hypothesis framing, and evidence standards enter packets **verbatim**,
never rewritten (D5). Discovery replies may be exactly
`NO_SEARCH_NEEDED`; callers consume the sentinel as-is.

### 6.4 Verify context delivery at launch (probe technique)

Two layers, cheapest first:

- **First-turn delivery probe** (model turns, one per new conversation):
  before the real work order, one bounded prompt asking the agent to
  state its role, the packet's objective, and the tools it sees; compare
  against the matrix row and the packet. Any mismatch — wrong role,
  missing context, tools the matrix denies — fix the invocation or packet
  **before** spending mission budget.
- **Hermetic context probe** (no model turns) when wiring itself is in
  doubt: capture resolved imports and effective tools through the
  production `Chat.parse` pipeline and diff against the matrix, per the
  context-delivery verification contract [CTX §6]; ready-made pattern
  `tmp/redesign-probes/redesign_phase4_final_probe.rb`.

**Verified vs assumed (this bout + MC7 repair).** Verified against
source/probe: `cortex_continue` seeds-and-persists a fresh conversation
and returns `{agent_meta, content}` (task code read); conversation names
are jobname inputs over the conversations namespace; Manager's tool
lines are exactly `cortex_continue` + `cortex_brief`; ScientificLead has
no endpoint, 3 effective tools; Investigator's explicit 5-task Cortex
list, no Semantics/continue/curator set; Worker/Reader/Cortex hold C10;
`NO_SEARCH_NEEDED` defined in `doctrines/handoff`; layout provenance and
raw material (snapshot read); `cortex_list` prefix enumeration —
`tasks/listing.rb` declares `input :prefix` and
`lib/Cortex/listing.rb` L51/L60 filter names with
`prefix.nil? || name.start_with?(prefix)`, so `cortex_list
--prefix ags/<slug>/` enumerates a mission (verified reading the filter
code this bout). Assumed (stated, not re-probed): first-turn probe
efficacy (validated the first time a mission runs it).

### 6.5 Resume after compaction

An interrupted or compacted bout resumes from a **resume packet** per
`doctrines/handoff` §Resume packets — what was done, what the evidence
showed, what remains, the paths needed to continue — never from memory or
transcript scrolling. The Manager posts the resume packet in `ags-<slug>`
and sends its pointer to Research as a Curator request to update
`ags/<slug>/mission.md` §Status, so any agent can resume from the
mission root.

## 7. Quick-launch checklist

1. **Drift check** — branch `ags-redesign`; no diffs beyond known parallel
   work.
2. **Intake** — Manager restates mission, picks `<slug>`, declares budget
   → Curator request; Research writes `ags/<slug>/mission.md`.
3. **Conversations** — `ags-<slug>`, `-lead`, `-q<nn>` (as assigned),
   `-record`, `-report`; Manager-owned via `cortex_continue`.
4. **Probe each new conversation** (§6.4) before real work.
5. **Recon + background** — Searcher / Reader into `evidence/`; honor
   `NO_SEARCH_NEEDED`.
6. **Scientific plan** — Lead outline verbatim → Curator request;
   Research scaffolds `questions/Q<nn>-<slug>.md`.
7. **Work orders** — one packet per question; acquisition → Curator
   requests to Research.
8. **Loop** — Investigator concludes → Research registers → Lead
   go/no-go verbatim → Research appends; ≤2 branches; S6 allowed.
9. **Stop** — S1–S6; complete on the Lead's sufficiency declaration;
   record S3 blocks verbatim.
10. **Consolidate** — Research compiles `reports/`; optional Critic gate
    (verdict by receipt).
11. **Report** — fresh `ags-<slug>-report` conversation composes;
    Research persists `reports/final.md`.
12. **Close out** — Research updates `mission.md` status; resume packet
    in `ags-<slug>` if anything remains open.

## 8. Drift, scope, and repairs (this bout + MC7 repair)

Written: this file only. Not touched: any `start_chat`, any shared doc,
`society`, `scout`, any `workflow.rb`; no new workflow directory.
**MC7 ruling (Manager, Phase 5 Critic repair):** all mission-artifact
persistence routes through Research as Curator requests with
verbatim-wording packets; Lead and Manager deliver wording, Research
writes and confirms the durable path — repairing the Critic's Finding 1
(write duties previously assigned to Manager/User/ScientificLead, who
hold no cortex_write). Finding 2 repaired in §6.4 (prefix enumeration
upgraded assumed → verified against `listing.rb`); §7 checklist
compressed with no content loss. Drift verified at bout start and end:
branch `ags-redesign`; tracked diff vs `1116c9a` unchanged (known
parallel work plus the sanctioned Phase 2–4 start_chat edits;
`Planned/` diff count 0); `new_doctrine/` untracked as before.
Verification labels: mechanisms in §6.4 verified against source read
this bout; probe-backed facts cite Phase 4 evidence paths; the layout
(§3) with the MC7 write rule is a ratified convention, first exercised
by the next mission that runs it.
