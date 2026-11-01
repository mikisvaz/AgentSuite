# Phase 1 — target role map and authority-boundary contracts (AgentSuite redesign)

- **Date:** 2026-11-01 (Phase 1 bout, ~15:15 +0100)
- **Repo:** `/bulk/mvazque2/git/AgentSuite`, branch `ags-redesign`, baseline `1116c9a`
- **Status:** DRAFT FOR CRITIC GATE — freezes the target role map and the
  authority-boundary table before any prompt edit (Phase 2+). No start_chat,
  shared doc, roster, or workflow file was edited by this bout; the only
  writes are this file and `tmp/redesign_role_contracts_drift.txt`.
- **Inputs (final, in reading order):** `redesign-audit-a-agents.md` (agents
  packet), `redesign-audit-b-shared.md` (packet B), `redesign-audit-c-matrix.md`
  (packet C), `redesign-audit-context.md` (packet A / orchestration),
  `redesign-baseline.md`; plus the Manager's nine arbitration decisions
  supplied with the Phase 1 task, which are **final inputs, not suggestions**.

## Traceability legend

Every substantive claim below carries one of:

- `[A §x]` — agents audit `redesign-audit-a-agents.md`
- `[B §x]` — shared-doc audit `redesign-audit-b-shared.md`
- `[C §x]` — capability matrix `redesign-audit-c-matrix.md`
- `[CTX §x]` — orchestration audit `redesign-audit-context.md`
- `[BASE]` — `redesign-baseline.md`
- `[D1]`…`[D9]` — Manager arbitration decisions (numbered as in the Phase 1
  task: D1 Consultant, D2 Research, D3 Worker/Investigator, D4
  ScientificLead, D5 Manager, D6 Searcher, D7 ScoutCoder, D8 Critic, D9
  Planner/User untouched + out-of-scope list)
- `[P1]` — probe run by this bout (command + output preserved in
  `tmp/redesign_role_contracts_drift.txt`)
- `[MC2]` — Manager confirmation round 2 (2026-11-01, Phase 1 follow-up):
  resolves conflict C-1 (Research target tier) and ratifies the gold-plating
  stop condition S6. Final; not suggestions.

---

## 0. Bout-start drift check (task 1)

Command (log: `tmp/redesign_role_contracts_drift.txt` [P1]):

```
git diff 1116c9a --name-only   → FitAgent/README.md
                                 ScoutCoder
git status --short              → M FitAgent/README.md, m ScoutCoder,
                                 ?? (untracked, unchanged in kind):
                                 FitAgent/lib/FitAgent/tasks/agent_ask.rb,
                                 FitAgent/research/12-readme-retired-fit-era.md,
                                 bin/, doctrine_bundle/, new_doctrine/,
                                 research/claude-meta-evidence/
git rev-parse --abbrev-ref HEAD → ags-redesign
```

**Verdict: no drift beyond the two known entries.** Tracked-tree diff vs
`1116c9a` is exactly the sanctioned parallel work (FitAgent/README.md rewrite
in progress, 125→272 lines; ScoutCoder submodule pointer dirty — its own
README.md modified internally). The untracked set matches `[BASE §3]` in kind
(two new untracked entries appeared since the baseline —
`FitAgent/lib/FitAgent/tasks/agent_ask.rb` was already listed there; only
`FitAgent/research/12-readme-retired-fit-era.md` is new, and it is FitAgent
parallel work, invisible to `git diff` and consistent with the known entry).
No redesign-relevant file (start_chat, shared doc, roster, workflow.rb)
differs from the baseline.

---

## 1. Target role map (deliverable a)

Classification vocabulary: **new** (directory to create in Phase 2),
**revised** (start_chat edit sanctioned), **untouched** (in-scope roster, no
edit this redesign), **out-of-scope** (no redesign action identified).
Counts: 2 new, 6 revised, 4 untouched, 7 out-of-scope = 17 existing agents
(census verified `[A §0]`, `[C §0]`) + 2 new = 19 target roles.

### 1.1 Existing 17 agents

| # | Agent | Class | Target identity (one line) | Source |
|---|---|---|---|---|
| 1 | Basic | out-of-scope | Minimal scaffold agent; doctrine R3 baseline only; no role content. | [A §1.1] [C §1] |
| 2 | ChatAnalyst | out-of-scope | Introspective analyst of recorded chat sessions (own workflow tooling); reports, never implements. | [A §1.2] [C §1] [D9] |
| 3 | Clean | out-of-scope | Null-control scaffold: imports nothing, zero effective tools. | [A §1.3] [C §1] |
| 4 | ComputerUse | out-of-scope | Sandbox/path-hygiene persona (known anomaly: instructs `sandbox_paths` without a `tool:` line — recorded, not fixed this redesign). | [A §1.4] [C §2.5] |
| 5 | Consultant | **revised** | Architecture/strategy judgment only: classification, strategy, decomposition, reframing of consequential problems; scientific-methodology lane deleted (moves to ScientificLead). | [D1] [A §1.5] |
| 6 | Cortex | out-of-scope | Cortex workspace orchestrator (conversations/briefs/artifacts) with its own workflow; entity and evidence duties already demarcated away. | [A §1.6] [D9] |
| 7 | Critic | **revised** | Verifier role unchanged (verdicts + branch advice); provisioning contradiction fixed toward its text: read/list/search + bash for probes, no write/edit/delete. | [D8] [A §1.7] [C §2.4] |
| 8 | FitAgent | out-of-scope | Agent-fitness harness persona (scenario + evaluation avenues); evaluator runs tool-less by design. | [A §1.8] [C §3] [D9] |
| 9 | Manager | **revised** | Execution authority unchanged (planning, routing, budgets, work orders, verification gates) + AGS-route duties: translate Lead's scientific outline into work orders and Investigator packets; never substitutes scientific judgment. | [D5] [A §1.9] |
| 10 | Planner | untouched | Planned's plan-stage producer: one practical single-path plan from restated request (+ search brief when present); does not execute. | [D9] [A §1.10] |
| 11 | Reader | untouched* | Source acquisition and reading specialist producing citable dossiers; acquires and reads, never interprets, never delegates. (*Not named in any arbitration; matrix C's "C10 broader than the dossier role needs" observation is recorded here as deferred, unarbitrated — no Phase 2 edit sanctioned.) | [A §1.11] [C §4] |
| 12 | Research | **revised** | Evidence curator: record registration (Observations/Claims/Hypotheses), lifecycle, traceability; delegates acquisition to Reader, takes direction from ScientificLead, does not own scientific questions. Name `Research` retained pending §5 precondition. | [D2] [A §1.12] [A §2.3] |
| 13 | ScoutCoder | **revised** | Computational planning authority + Scout-stack code infrastructure steward; absorbs the unit-test placement convention still pending in `doctrines/advice`; roster alignment. | [D7] [A §1.13] [A §4.8] |
| 14 | Searcher | **revised** | Generic narrow targeted-discovery role producing the search brief; Planned's search stage remains one named consumer; tools and brief format preserved. | [D6] [A §1.14] [A §2.4] |
| 15 | User | untouched | Liaison: intake restatement (Planned request stage) and final synthesis from validated outputs (ask stage); never solves the task. | [D9] [A §1.15] |
| 16 | Visualizer | out-of-scope | Scientific figure construction/review agent (endpoint-scoped, attachments); self-critique loop, conservative interpretation. | [A §1.16] [D9] |
| 17 | Worker | untouched | Generic default step executor and residual catch-all ("any concrete task not explicitly another agent's responsibility"); unchanged in this redesign, full current tooling retained. | [D3] [A §1.17] |

### 1.2 New agents (created in Phase 2 from this map)

| # | Agent | Class | Target identity (one line) | Source |
|---|---|---|---|---|
| 18 | ScientificLead | **new** | Tool-less scientific direction owner: question decomposition, hypothesis framing, discriminating-experiment design intent, evidence-review standards, go/no-go on investigative branches; technology-independent but not evidence-blind (consumes evidence summaries from artifacts and packets, not domain tools). | [D4] [A §2.1] |
| 19 | Investigator | **new** | Question-owning investigation executor created from Worker's template (evidence specialty, bout discipline, report contract preserved): one question → evidence chain → bounded conclusion per bout; explicit Cortex task list, never the bare `tool: Cortex` curator set. | [D3] [A §2.2] |

---

## 2. Authority-boundary table (deliverable b)

Tool tiers are expressed against the **current 10-task Cortex checkout**
(cortex_brief, cortex_continue, cortex_edit, cortex_list, cortex_move,
cortex_read, cortex_remove, cortex_rename, cortex_search, cortex_write; tiers
R3 = footer list/search/read, A5 = R3+write+edit, D5 = R3+continue+brief,
C10 = all ten `[C §1]`) and the **23-task Workspace surface** (bash, python,
ruby, r; write, read, list_directory, file_stats, sandbox_paths, pwd, delete,
copy, search; patch; precise_edit; tsv_info/read/query/edit/merge/attach/
translate/sort — enumerated from `Workspace/lib/Workspace/tasks/` this bout
[P1], matching C's "23: full Workspace"). Where an arbitration pins intent
but not spelling, the contract states intent and Phase 4 pins exact task
lines (precedent: [D8]).

### 2.1 ScientificLead (new)

- **Owns:** scientific direction — question decomposition; hypothesis
  framing; discriminating-experiment design intent; evidence-review
  standards; go/no-go on investigative branches [D4].
- **May do:** consume evidence summaries from Cortex artifacts and received
  packets (read-only); produce direction documents/outlines with reopening
  conditions; declare branch go/no-go and loop completion [D4].
- **Must not:** execute anything; plan execution (Manager's); plan
  computation (ScoutCoder's); own or curate the scientific record
  (Research's); hold domain tools; substitute for Critic's verification
  [D4]; decide routing or budgets [D5].
- **Delegates to:** Manager (its outline is translated into work orders and
  packets); no direct tool delegation — tool-less by design, Consultant's
  shape [D4] [A §2.1].
- **Target tier:** R3 only (doctrine footer; no own `tool:` lines, no
  Workspace tasks; endpoint decision Phase 2) [D4].

### 2.2 Investigator (new)

- **Owns:** investigation bouts — one assigned scientific question →
  evidence chain → bounded conclusion, with the Worker-template evidence
  specialty (result addresses, definition versions, verification labels)
  [D3] [A §2.2].
- **May do:** run experiments/analyses/evidence production on provisioned
  tooling; write durable Cortex artifacts for reusable findings; report
  blocked questions upward with the smallest unblocking change [D3]
  [A §1.17].
- **Must not:** hold cortex_rename/move/remove (curator set explicitly
  denied [D3]); decide loop-level next steps or open new branches (Lead/Manager);
  own the scientific record (registration is Research's); build framework
  infrastructure (ScoutCoder's); silently drop sub-tasks [D3] [A §2.2].
- **Delegates to:** none directly — a packet executor; acquisition and
  follow-on work flow through Manager work orders (Worker template has no
  outgoing delegation [A §1.17]).
- **Target tier:** full Workspace + Cortex A5 as an **explicit task list**
  (footer R3 + `cortex_write`, `cortex_edit`); no cortex_continue/brief; no
  rename/move/remove. Exact lines pinned in Phase 4 [D3].

### 2.3 Research (revised; name retained pending §5)

- **Owns:** the scientific record — registration of Observations/Claims/
  Hypotheses through the supported Path-kind operations; record lifecycle
  (invalidation/supersession, one authoritative writable record);
  traceability; Cortex workspace stewardship for scientific artifacts
  including rename/move/remove [D2] [D3] [A §2.3].
- **May do:** register records from dossiers and run receipts (citing
  locators, never silently re-interpreting); curate/consolidate artifacts;
  issue acquisition requests to Reader/Searcher; consume Lead direction;
  verify record integrity and status consistency [D2] [A §1.12].
- **Must not:** own scientific questions or adjudicate claims (moved to
  ScientificLead [D2]); execute document acquisition beyond bounded checks
  (Reader's); plan execution or computation; build Scout framework
  tooling [A §1.12].
- **Delegates to:** Reader (document acquisition/close reading), Searcher
  (source discovery) — "delegate acquisition, not epistemology" inverts to
  "delegate acquisition upward-judgment": judgment is received from Lead,
  not exercised [D2] [A §2.3].
- **Target tier (confirmed [MC2]):** Cortex **C10, all ten tasks, via
  explicit per-task lines** — current A5 (cortex_list, cortex_search,
  cortex_read, cortex_write, cortex_edit — list/read/write/edit declared,
  search via doctrine footer) plus cortex_continue, cortex_brief,
  cortex_rename, cortex_move, cortex_remove, because record registration
  needs write/edit and record lifecycle needs rename/move/remove [MC2,
  resolving conflict C-1 in §9; current-state delta corrected per Critic
  gate]. Semantics (entity_property, entity_list_property, list_entities),
  full Workspace, `exec_task: Workspace pwd` retained; the no-op
  `tool: Research` line removed (behavior-neutral [C §2.6]) [D2] [C §1]
  [MC2].

### 2.4 Consultant (revised)

- **Owns:** architecture/strategy judgment — classification of what a
  problem actually is, strategy, decomposition, reframing for consequential
  or high-risk decisions [D1] [A §1.5].
- **May do:** one bounded Cortex recall pass when prior decisions could
  change the strategy; issue delegation briefs as part of its 5-part output
  contract [A §1.5].
- **Must not:** scientific methodology — hypotheses, discriminating
  experiments (use-for bullet deleted; lane moved to ScientificLead [D1]);
  execute; explore repositories; run repetitive tools; routine coordination;
  generic best-practice essays [A §1.5].
- **Delegates to:** issues briefs only; no tools to delegate with [A §1.5].
- **Target tier:** R3, tool-less, endpoint-scoped (`endpoint: consultant`)
  — unchanged tooling; the edit is exactly one deleted use-for bullet [D1].

### 2.5 Manager (revised; authority unchanged)

- **Owns:** execution planning, routing, budgets, work orders, verification
  gates [D5]; plus AGS-route duties — translating Lead's scientific outline
  into work orders and Investigator packets [D5] [CTX §1].
- **May do:** delegate through ask packets (cortex_continue/cortex_brief);
  score candidate plans with Critic; declare budget stop (§6 S2); inspect
  run receipts instead of executing [A §1.9].
- **Must not:** substitute scientific judgment — never rewrites hypothesis
  framing, evidence standards, or a Lead no-go on scientific merit (may stop
  or re-scope on budget/authority grounds, recorded as such) [D5];
  implement; execute entity-property computations itself [A §1.9].
- **Delegates to:** every specialist via structured packets
  (Objective/Current state/Design/Task/Output required); Critic for gates
  [A §1.9].
- **Target tier:** D5 (cortex_continue + cortex_brief + footer R3),
  `socialize: true`; no Workspace/other tools at start_chat level — current
  shape ratified [D5] [C §1].

### 2.6 Searcher (revised)

- **Owns:** targeted discovery producing the concise search brief (main
  question / findings / sources / relevant skills / uncertainties /
  recommendation; `NO_SEARCH_NEEDED` sentinel) — a generic narrow role;
  Planned's search stage is one named consumer, not the definition [D6]
  [A §2.4].
- **May do:** local-first search (Workspace list_directory/search/read);
  light web checks (Reader searxng/html2md); ScoutCoder help docs; persist
  reusable findings (cortex_write/edit); hand documents needing substantial
  extraction to Reader with resolvable references [A §1.14].
- **Must not:** make code or design decisions; extract document contents
  (Reader's); continue conversations or manage the workspace; participate in
  loop decisions [A §1.14].
- **Delegates to:** Reader (explicit handoff) [A §1.14].
- **Target tier:** A5-narrow preserved — 15 effective tools (3 Workspace +
  2 Reader + 5 ScoutCoder help + 5 Cortex) [D6] [C §1]. Phase 4 re-check:
  the `match_skills` instruction references a task absent from its declared
  lines [A §2.4]; and the `NO_SEARCH_NEEDED` sentinel needs a defined
  meaning for non-Planned callers (§9 C-4).

### 2.7 ScoutCoder (revised)

- **Owns:** computational planning authority and Scout-stack code
  infrastructure — workflows, tasks, entity/property drafts under `share/`,
  promotion, shared-interface stewardship [D7] [A §1.13]; absorbs the
  unit-test placement convention pending in `doctrines/advice` (closing that
  migration) [D7] [A §4.8].
- **May do:** full ScoutCoder + full Workspace tooling; cortex_write/edit
  for durable findings; run_probe/run_test fresh-process verification;
  documentation-lookup tasks [A §1.13].
- **Must not:** own scientific direction or evidence-record curation; execute
  non-code concrete tasks (Worker's lane); commit/push/merge unless asked
  [A §1.13].
- **Delegates to:** none outgoing — is the delegation target for code
  infrastructure [A §1.13].
- **Target tier:** current ratified — A5 + full Workspace + full ScoutCoder
  (45 effective) [D7] [C §1]. Roster alignment (society "semantic entity
  definitions" phrasing vs Semantics ownership) is a Phase 2 roster edit,
  not a tooling change [A §3].

### 2.8 Critic (revised)

- **Owns:** verification gates on consequential results — verdicts
  (PASS/NEEDS_WORK/BLOCKED) plus branch advice; evidence-quality classes
  [D8] [A §1.7].
- **May do:** read/list/search Workspace tasks against cited artifacts
  (read, list_directory, file_stats, search, sandbox_paths, pwd); **bash for
  probes and fresh-process (cold-process) checks**; read-only Cortex;
  resolving cited property addresses read-only [D8] [A §1.7].
- **Must not:** write/edit/delete (no Workspace write, delete, copy, patch,
  precise_edit, python/ruby/r, tsv_* mutations) [D8]; fix problems; redo the
  investigation; ask the producer for clarification; second-produce [A §1.7].
- **Delegates to:** none — an execution a check needs is a delegated
  verification routed via Manager [A §1.7].
- **Target tier:** Cortex R3 (footer only) + Workspace **explicit read set +
  bash** (7 tasks: read, list_directory, file_stats, search, sandbox_paths,
  pwd, bash); target total ≈10 effective vs 26 today. Contract states
  intent; exact Workspace task spellings pinned in Phase 4 [D8].

### 2.9 Worker (untouched)

- **Owns:** concrete step execution; residual catch-all executor [D3]
  [A §1.17].
- **May do:** full Workspace + full Cortex (C10) — exactly today's surface
  [D3] [C §1].
- **Must not:** decide next steps when a plan exists; manage conversations/
  properties/workspace unasked [A §1.17].
- **Delegates to:** none [A §1.17].
- **Target tier:** C10 + full Workspace (33 effective), unchanged [D3].
  Residual accepted risk recorded in §9 C-2.

### 2.10 Planner (untouched)

- **Owns:** turning a restated request (+ search brief) into one practical
  single-path plan with owners, deliverables, stop conditions, acceptance
  tests [D9] [A §1.10].
- **May do:** ScoutCoder help-documentation lookups; reuse prior Cortex
  decisions by exact logical path [A §1.10].
- **Must not:** execute the plan; mutate the Cortex workspace; let planning
  become a new investigation [A §1.10].
- **Delegates to:** plan steps name owner agents (vocabulary gains
  ScientificLead/Investigator in Phase 2 roster work — downstream effect
  only) [A §3].
- **Target tier:** R3 + 5 ScoutCoder help tasks (8 effective), unchanged
  [D9] [C §1].

### 2.11 User (untouched)

- **Owns:** intake normalization (restatement) and final synthesis from
  validated outputs [D9] [A §1.15].
- **May do:** bounded read-only Cortex recall for explicitly supplied
  artifacts; work with whatever tool exposure each Planned stage provides
  (request: full; ask: none) [A §1.15] [CTX §1].
- **Must not:** execute, search, solve the task; invent results [A §1.15].
- **Delegates to:** none — pipeline front/back door [A §1.15].
- **Target tier:** R3, unchanged [D9] [C §1].

### 2.12 Reader (untouched; not arbitrated — recorded for boundary completeness)

- **Owns:** source acquisition and reading into citable dossiers (identity,
  locators, retrieval context, extraction limitations) [A §1.11].
- **May do:** Reader workflow tools (searxng, docx2md, html2md, pdf2md,
  html/pdf queries), full Workspace, full Cortex (C10 today) [C §1].
- **Must not:** interpret what evidence warrants; register scientific
  records; delegate [A §1.11].
- **Delegates to:** none — is the acquisition target of Research and
  Searcher [A §1.11].
- **Target tier:** unchanged (C10 + full Workspace + Reader tools, 37
  effective). Matrix C's observation that write/edit would suffice for the
  dossier role is **deferred, unarbitrated** — no redesign action sanctioned
  [C §4]; flag for a later phase.

---

## 3. Shared-doc import sets (deliverable c)

Policy ratified from [B §3]: new shared docs are extension-less files under
`doctrines/`, imported only as `import: Agent/doctrines/<name>`; chains at
most one level deep; **no `tool:`/`introduce:`/directive lines in any of the
five** (prose only — directive leakage is live-risk [B §5.7]); sizes
society-scale (~150 lines / ≤8 KB), never scout-scale [B §4] [B §6];
repo root stays reserved for `doctrine`, `doctrines/advice`, `society`,
`scout` [B §3].

Packet B's provisional importer sets are **ratified except where an
arbitration decision forces an adjustment** (marked ADJUST); both new agents
are placed (marked NEW).

| Doc | File / import spelling | Importers (target) | Basis |
|---|---|---|---|
| 1. Agent Collaboration guide | `doctrines/collaboration` / `import: Agent/doctrines/collaboration` | Manager, Planner, User, Critic, Worker, **Investigator** (NEW), **ScientificLead** (NEW) | Ratify B's five [B §4]; extend to the two new loop roles — Investigator participates in multi-step loops exactly as Worker [D3]; ScientificLead hands direction to Manager and receives packets [D4]. Leaf specialists (Reader, Searcher, ScoutCoder, Consultant, Visualizer, ChatAnalyst) stay out, as in B. |
| 2. Scientific Investigation guide | `doctrines/investigation` / `import: Agent/doctrines/investigation` | Research, Searcher, Reader, Critic, **ScientificLead** (NEW), **Investigator** (NEW) | Ratify B's four [B §4]; extend — ScientificLead owns how investigations are decomposed and closed [D4]; Investigator runs them [D3]. **Manager deliberately excluded**: structural enforcement of "never substitutes scientific judgment" [D5]. |
| 3. Scientific Discipline guide | `doctrines/discipline` / `import: Agent/doctrines/discipline` | Research, Critic, **ScientificLead** (NEW); **Consultant dropped** (ADJUST) | B's set included Consultant for its science-facing lane [B §4]; D1 deletes that lane, so the adjustment follows from arbitration. ScientificLead owns evidence-review standards and methodology [D4]. Investigator considered and excluded: standards arrive via Lead outlines and work orders; duplicating the standards layer in an executor adds context without authority (Phase 2 may revisit). |
| 4. Context/handoff contract | `doctrines/handoff` / `import: Agent/doctrines/handoff` | Manager, Planner, User, Worker, **Investigator** (NEW), **ScientificLead** (NEW), **Research** (ADJUST) | Ratify B's four delegation endpoints [B §4]; extend to both new roles (packet sender/receivers [D3] [D4]); add Research because the narrowed curator receives work orders and direction and sends acquisition requests — squarely B's own "delegation endpoints" criterion, and D2 makes that explicit. Reader/Searcher/ScoutCoder stay out (receivers of well-formed packets; senders are covered). |
| 5. Scientific capability-catalogue format | `doctrines/catalogue` / `import: Agent/doctrines/catalogue` | Research, Reader, Consultant | Ratify B unchanged [B §4]: Consultant's surviving architecture/classification lane still consumes capability catalogues; D1 deleted only the scientific-methodology bullet. ScientificLead excluded — technology-independent by design [D4]; Investigator excluded — methods arrive via work orders [D3]. |

**Context-budget consequence (Phase 2 constraint):** worst importer is now
Research with doctrine + advice + society + investigation + discipline +
handoff + catalogue ≈ 20.8 KB current shared payload + up to 4 new docs.
At B's ≤8 KB/doc ceiling that reaches ~53 KB — worse than ScoutCoder's
45.8 KB full stack [B §6]. Phase 2 must either keep the docs Research
imports at ≤3–4 KB each, or trim Research's set (candidate: catalogue,
since the curator authors but does not need the format doc at full length).
Recorded as a constraint, not a change to the ratified sets.

Related carried items: `bin/bundle_doctrine.sh` does not know `doctrines/`
and must be updated or retired when the five land [B §5.8]; the five files
must exist in the host chat store **before** any start_chat references them
(load-time `Import not found` [B §5.5]).

---

## 4. Arbitration decisions record (deliverable d)

All nine decisions supplied with the Phase 1 task are recorded as final.
The task text says "the three arbitration decisions"; since nine were
supplied and all are load-bearing for this document, **all nine are
recorded**, and the three structurally decisive ones (D1, D2, D3) are marked
as headline decisions. Interpretation flagged; no decision was omitted or
reinterpreted.

| # | Decision (final) | Reason (as arbitrated / from audit) | Consequences |
|---|---|---|---|
| **D1** (headline) | Consultant narrowed to architecture/strategy judgment; scientific-methodology lane (hypotheses, discriminating experiments) moves to ScientificLead; exactly one use-for bullet deleted. | Verbatim overlap with Research's protocol steps 4–5; a third claimant (ScientificLead) makes the boundary load-bearing; Consultant's tool-less 5-part output contract is a strategy shape, not an investigation shape [A §2.1]. | Consultant start_chat: one-bullet deletion, nothing else; discipline import set adjusted (§3); roster "scientific methodology" phrase must move in Phase 2 roster alignment. |
| **D2** (headline) | Research keeps directory and agent name; start_chat rewritten to evidence-curator identity (record curation, registration, traceability; delegates acquisition to Reader; takes direction from ScientificLead; does not own scientific questions); rename to EvidenceCurator deferred behind §5 precondition; no-op `tool: Research` line removed deliberately. | The 7-step protocol interleaves registration with interpretation; narrowing is a protocol rewrite [A §2.3]; the `tool: Research` line is a validated no-op (workflow defines 0 tasks) [C §2.6]. | Research start_chat: protocol rewrite (Phase 2, largest single edit); tier upgrade to C10 explicit (§2.3, conflict C-1); §5 precondition recorded; sentinel behavior unchanged elsewhere. |
| **D3** (headline) | Worker and Investigator coexist: Worker unchanged, generic default executor; Investigator created from Worker's template with question-ownership, bout discipline, and an explicit Cortex task list; must NOT inherit the bare `tool: Cortex` curator set (rename/move/remove stay with Research). | Worker is investigation-shaped but lacks epistemic identity and is prohibited from next-step decisions; an Investigator between Worker and Lead/Research is structurally supported [A §2.2]; the flagged replace-vs-coexist decision is resolved as coexist. | New Investigator/ directory (Phase 2) from Worker template with Worker's artifact-path and validation-report conventions preserved verbatim [A §2.2]; explicit Cortex task list (A5-shape, §2.2); Worker keeps C10 (accepted risk, §9 C-2); roster gains Investigator. |
| D4 | ScientificLead: new, tool-less (R3 via doctrine import only); owns scientific direction — question decomposition, hypothesis framing, evidence-review standards, go/no-go on investigative branches; technology-independent but not evidence-blind (consumes evidence summaries from artifacts and packets, not domain tools); does not execute, does not plan execution (Manager), does not plan computation (ScoutCoder). | First cut in [A §2.1]/[A §3]: absorbs the direction layer while a narrowed Research keeps curation; Consultant's tool-less shape is the template. | New ScientificLead/ directory (Phase 2); §2.1 boundary; §3 imports (collaboration, investigation, discipline); §6 stop conditions S1/S4; Manager AGS duties (D5). |
| D5 | Manager unchanged in authority (execution planning, routing, budgets, work orders, verification gates); revision adds AGS-route duties: translating Lead's scientific outline into work orders and Investigator packets, never substituting scientific judgment. | Manager's control loop and packet template already fit [A §1.9]; AGS route is a sibling of Planned, not inside it [CTX §1], so the route's orchestration duties land on Manager's existing authority. | Manager start_chat: routing table + packet guidance extended (Phase 2); Manager excluded from the investigation doc (§3); §6 S2 budget stop stays Manager's. |
| D6 | Searcher de-bound from Planned's stage framing into a generic narrow search role (Planned usage remains one consumer, named explicitly); tools and brief format preserved. | Identity text is hard-bound to Planned while two non-Planned consumers already exist (Research's contract, society roster) [A §2.4]; the tool set is already the right narrow shape [A §2.4] [C §1]. | Searcher start_chat: opening reworded with explicit Planned clause (Phase 2); sentinel semantics for direct callers must be defined (§9 C-4); `match_skills` anomaly re-checked at Phase 4 [A §2.4]. |
| D7 | ScoutCoder: computational planning authority confirmed; absorbs the unit-test convention still pending in `doctrines/advice` (close that pending migration); roster alignment. | The advice appendix is an emptied pointer whose only live payload is the test-placement convention, explicitly "pending its move into the ScoutCoder start_chat" [A §4.8]; ScoutCoder core is stable [A §3]. | ScoutCoder start_chat gains the convention; then `doctrines/advice` retirement becomes possible only with the doctrine-footer import chain kept resolvable (remove footer line in the same edit [B §4]); roster "semantic entity definitions" alignment [A §3]. |
| D8 | Critic: verifier role unchanged; provisioning contradiction fixed in the direction of its text — read/list/search plus bash for probes, no write/edit/delete; exact Workspace task spellings pinned in Phase 4, contract states intent. | Validated contradiction: role text says "read-oriented Workspace tasks" while bare `tool: Workspace` exposes write/delete/bash/patch/precise_edit (23 tools) [C §2.4] [A §4.2]; bash is retained for probes and cold-process checks (an extension beyond the audited text — see §9 C-5). | Critic tool lines narrowed to an explicit read set + bash (§2.8); Phase 4 pins spellings and re-runs the effective-tools probe; Critic's cold-process and evidence-class duties unchanged [A §1.7]. |
| D9 | Planner and User untouched; Basic, Clean, ChatAnalyst, ComputerUse, Cortex, FitAgent, Visualizer out of scope. | Stable, stage-scoped or pipeline-agnostic contracts [A §3]; no redesign action identified at the declared-structure layer for the out-of-scope seven [A §3]. | No edits; known anomalies in out-of-scope agents (ComputerUse undeclared tool reference [C §2.5]) are recorded, not fixed. Reader is untouched-but-not-arbitrated (§2.12). |

---

## 5. Rename-deferral precondition (deliverable e)

The rename `Research` → `EvidenceCurator` is **deferred** [D2]. Precondition
recorded: before any rename, a grep-based **external reference inventory**
must be produced covering at least:

1. `society` roster entries and routing lines;
2. all agents' `start_chat` files (Research is named in Manager's routing
   table, Searcher's consumers, Reader's clients [A §1.9] [A §1.14]);
3. repository `README.md` files and `research/` documents;
4. Cortex artifacts and conversation names (logical-name references are not
   path-renamable by grep alone — `cortex_rename` touches the store, not
   citations);
5. job histories / `.info` sidecars under `var/jobs` that recorded
   `agent: Research` inputs (historical records must not be rewritten — the
   rename must tolerate old names in provenance).

Until the inventory exists and the rename is executed, the agent name
`Research` and the directory name are authoritative; the curator identity is
carried by the rewritten start_chat only [D2]. The rename is a name change,
not a boundary change: §2.3 applies either way.

---

## 6. Stop conditions for the AGS scientific loop (deliverable g)

Stated at contract level; the loop itself lives in a sibling route of
Planned (Phase 5/7), not inside `Planned/workflow.rb` [CTX §1]. These
conditions bind the roles named below regardless of route implementation.

- **S1 — Lead go/no-go.** Every investigative branch opened under a
  ScientificLead outline carries an explicit go/no-go decision at its review
  point, with recorded rationale and the evidence condition that would
  reopen a closed branch [D4]. A no-go closes the branch; **Manager may not
  reverse a no-go on scientific grounds** — only on budget or authority
  grounds, and then recorded as a non-scientific override [D5].
- **S2 — Budget exhaustion.** When the Manager's declared budget policy is
  exhausted (candidate plans 2–4, active branches ≤2, repair cycles per step
  ≤2, full branch switches ≤1 [A §1.9]), the loop stops at the current step
  boundary; partial results are preserved durably; the report labels
  unverified items per the doctrine vocabulary. Budget stop is Manager's
  call, never Lead's [D5].
- **S3 — Blocked questions.** A question is blocked when its smallest
  unblocking dependency lies outside the loop's authority (unreachable
  substrate — e.g. the AGS-substrate reachability gate [CTX §4] — missing
  data, unanswered user question). The owning role (Investigator or
  Research) reports blocked with the failed operation, the evidence, the
  diagnostic already run, and the smallest unblocking change (doctrine §9);
  ScientificLead reclassifies: drop, defer with a reopening condition, or
  escalate to the user via Manager → User [D4] [D5].
- **S4 — Natural completion.** The loop is complete when every question in
  the Lead's decomposition is answered or explicitly closed with recorded
  status; ScientificLead declares completion; Research closes record state
  (status consistency, supersession) and the route proceeds to
  consolidation and fresh reporting [D4] [D2].
- **S5 — No momentum rule.** The loop never continues past a satisfied stop
  condition; more verification is not more work (doctrine §1). Reopening
  requires new evidence against an established claim, recorded through S1's
  reopening condition.
- **S6 — Sufficiency close (anti-gold-plating) [MC2].** The Lead may
  terminate a branch when the evidence chain is complete enough to support
  or refute its hypothesis, **even if budget remains** — remaining budget is
  not a reason to keep a concluded branch open [D4] [MC2].

---

## 7. Errata carried from the Critic gate (deliverable f)

Recorded as carried; where this bout could check, the check is noted.

1. **Packet A (`redesign-audit-context.md`) §5 FitAgent facts are superseded
   by matrix C §3.** Use [C §3] (use_case staging, analyze mechanics,
   minimal smoke recipe, caveats: `agent none` broken, `exclude` declared
   but unconsumed, `endpoint_analyst` not forwarded) as authoritative for
   FitAgent mechanics; [CTX §5] retains historical value only (notably the
   README/code `job_use_case` discrepancy, which C §3 does not repeat).
2. **Packet B §7 marker counts are stale — the chat file grew after the
   check.** Validated this bout [P1]: `grep -c "test_helper.rb"` over
   `…/Planned/work/Default_a8a505ef95d0e1de3824559e0c712f36.chat.files/Manager.chat`
   now returns **3** (B recorded ×1); the file is now 960,881 B. B's
   conclusion (doctrine-footer chain delivers the advice body exactly once
   per import expansion) rests on the hermetic probes [B §5.3], not on this
   chat count; do not re-cite the ×1 figure.
3. **Matrix C §1 total column mixes raw vs distinct counts.** The `total`
   column adds distinct Cortex counts to non-Cortex counts, while the raw
   tool table contains duplicate cortex keys for Cortex/Reader/Worker (3
   duplicate raw keys each, resolving idempotently) [C §1]. Use the
   "Cortex (distinct)" and "non-Cortex effective" columns; treat `total` as
   distinct-only and do not derive dedup conclusions from it.

---

## 8. Preconditions and carried constraints

1. **Host chat-store sync unverified** (`bin/bundle_doctrine.sh` vs manual
   copy): the import namespace is the host store's `Agent/` subtree, not
   visible from this sandbox; every Phase 2 start_chat edit fails at load
   with `Import not found` unless the store mirrors the new files first
   [B §5.1]. **Blocking for Phase 2 edits; not blocking for this document**
   (carried, unchanged).
2. **Bout-start drift check:** done (§0); re-run at every subsequent bout
   and treat FitAgent/README.md + ScoutCoder submodule dirt as known
   parallel work [BASE §3] [P1].
3. **Five shared docs must exist in the store before reference** [B §5.5];
   `bin/bundle_doctrine.sh` must learn `doctrines/` or be retired [B §5.8].
4. **`doctrines/advice` retirement order** (D7): convention moves into
   ScoutCoder's start_chat first; the doctrine-footer `import:` line is
   removed in the same edit — the import must never dangle (load-time
   failure, validated [B §4]).
5. **Phase 4 verification contract** [CTX §6]: the provisioning table's
   expected side gains the five doc names and the per-role target tiers of
   §2; the effective-tools probe is re-run after every Phase 2–3 edit.
6. **AGS substrate unreachable from this sandbox** [CTX §4] — Phase 7
   conditional (confirm visibility on the pilot machine or attach an AGS
   path map); affects S3 blocking classification only.

---

## 9. Conflicts: arbitration decisions vs audit evidence (task 3)

Stated conflicts — arbitration is final in each case; the conflict is
recorded, not reopened.

- **C-1 (D3 vs [C §1] current state): "rename/move/remove stay with
  Research" describes a target grant, not the current state.** Today
  Research holds A5 (5 distinct Cortex tools: list/read/write/edit + footer
  search); no matrix row ever associated the curator set with Research —
  the full C10 set is currently held by Cortex, Reader, and Worker [C §1]
  [C §2.1]. Consequence: §2.3 specifies an upgrade to C10 via explicit
  lines, and Phase 4 must add them. **Resolved — Manager confirmed the C10
  upgrade [MC2]: Research's target is the full 10-task set (current A5 =
  cortex_list, cortex_search, cortex_read, cortex_write, cortex_edit —
  list/read/write/edit declared, search via doctrine footer; delta adds
  cortex_continue, cortex_brief, cortex_rename, cortex_move,
  cortex_remove), on the grounds that registration needs write/edit and
  lifecycle needs rename/move/remove. The open one-line-confirmation option
  is closed.** Current-state description corrected per Critic gate.
- **C-2 (D3 "Worker unchanged" vs [C §2.1] / [A §4.3]):** the audits flagged
  Worker's bare `tool: Cortex` (curator-grade rename/move/remove in a step
  executor) as a deliberate-decision item. D3 resolves it as "keep, 
  unchanged". Recorded as an **accepted residual risk**: the same authority
  the redesign denies Investigator remains in Worker's hands. No action this
  redesign; candidate for a later tightening pass.
- **C-3 (D1 vs [B §4] discipline import set):** packet B provisionally
  listed Consultant as a discipline importer on the assumption it keeps a
  science-facing lane; D1 deletes that lane. Adjusted in §3 (Consultant
  dropped, ScientificLead added). This is the one place an arbitration
  decision directly overrode a provisional audit recommendation.
- **C-4 (D6 "brief format preserved" vs [A §2.4]):** the preserved brief
  format includes the `NO_SEARCH_NEEDED` sentinel, which the audit found has
  "no defined meaning outside Planned". De-binding Searcher while preserving
  the format leaves the sentinel undefined for direct callers (Research,
  roster consumers). Not a contradiction of evidence but an unresolved
  tension: Phase 2's Searcher rewrite must define the sentinel's meaning
  (or replacement) for non-Planned callers.
- **C-5 (D8 vs [A §1.7] role text):** bash for probes goes beyond the
  audited "read-oriented Workspace tasks" wording. The audit offered two fix
  directions (narrow tools, or rewrite text to accept write access) [C §2.4];
  D8 chooses narrowing **plus** bash — an extension beyond the role text,
  justified by Critic's cold-process/probe duties [A §1.7]. Recorded as a
  deliberate addition, consistent with the audit's evidence (no conflict
  with any probe result).
- **B-internal (no arbitration involved, noted for Phase 2):** packet B's
  collaboration rationale ("every role that hands work to or receives work
  from another agent") is broader than its own importer list (Reader and
  Searcher both hand off/receive work but are excluded). §3 keeps B's narrow
  set (coordination core) and states the operative rule, so the doc's
  purpose, not the one-sentence rationale, defines membership.

---

## 10. What this bout did and did not touch

- Written: this file; `tmp/redesign_role_contracts_drift.txt` (drift log
  [P1]).
- Not touched: any `start_chat`, any shared doc (`doctrine`,
  `doctrines/advice`, `society`, `scout`), the roster, any `workflow.rb`,
  any README. `git diff 1116c9a --name-only` at bout end is unchanged from
  §0 (the two known entries only).
- Verification status of this document's own claims: role identities,
  boundaries, and tiers are **traceable** to the cited audit sections or
  arbitration decisions (labels inline); the drift check and the Workspace
  task enumeration are **validated** this bout [P1]; nothing here is
  independently reviewed yet — that is the Critic gate's job.
