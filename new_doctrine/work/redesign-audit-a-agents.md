# Agent inventory — declared structure — 2026-11-01 redesign audit (packet A)

Phase 0 audit of every agent directory at the AgentSuite repo root
(branch ags-redesign). Scope is **declared structure only**: what each
`start_chat` file says. Runtime/effective tool truth is packet C's
(`redesign-audit-c-matrix.md`, 2026-11-01) and is cited, not re-probed.
Method: each start_chat read in full from the repo; import/tool/introduce
and other directive lines captured verbatim with line numbers; short side
files read where present. README.md and workflow.rb of tool workflows were
not read (per packet instructions); agent-side workflow.rb files of
one-line chat wrappers were read where they exist (Critic, Reader,
Research, FitAgent).

## 0. Census

17 agent directories (carry a `start_chat`): Basic, ChatAnalyst, Clean,
ComputerUse, Consultant, Cortex, Critic, FitAgent, Manager, Planner,
Reader, Research, ScoutCoder, Searcher, User, Visualizer, Worker.

Expected list from the packet (17 names): **exact match — none beyond,
none missing.** Packet C's census agrees (its §0 lists the same 17 and
notes the orphaned WorkflowCoder row of the 2026-09-05 matrix has no
directory here — reconfirmed: no `WorkflowCoder` dir at root).

Non-agent directories at root (no start_chat; workflow or infra only):
Branched, Claude, Decider, Direct, Planned, Semantics, Workspace, bin,
chats (symlink), doctrine (file), doctrine_bundle, doctrines, lib,
new_doctrine, research, share, society (file), tmp, var.

Import vocabulary observed (3 kinds): `Agent/doctrine` (all agents except
Clean), `Agent/society` (Cortex, Manager, Planner, Research, User),
`Agent/scout` (ScoutCoder only).

Directive vocabulary beyond import/system/tool/introduce: `endpoint:`
(Consultant `consultant`, Visualizer `visual`), `attachments: true`
(Visualizer), `socialize: true` (Manager, Research), `exec_task:`
(ComputerUse `ComputerUse pwd`; Research `Workspace pwd`; ScoutCoder
`Workspace pwd`). No `kb:` and no `mcp:` lines exist anywhere (validated
by packet C's grep; consistent with these reads).

---

## 1. Per-agent sections

### 1.1 Basic

- File inventory: `start_chat` only (81 B, 5 lines).
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines: none.
- Other directives: none.
- Responsibilities: generic scaffold — "You are an agent. You may have
  access to tools." No role content beyond that.
- Exclusions: none declared.
- Delegation references: none.
- Output-format constraints: none.
- Notes: minimal scaffold; receives the doctrine Cortex baseline (R3 per
  packet C).

### 1.2 ChatAnalyst

- File inventory: `start_chat` (4,987 B); plus a full workflow checkout —
  `README.md` (27,954 B), `workflow.rb` (73,242 B), `lib/`, `test/`,
  `research/`, `var/`, `tmp/`, `cortex_path_map.yaml`, `chats` symlink.
  Workflow-bearing agent: its own tasks (chat_report, live_chats,
  message_index, post_inbox_advice, inbox_state, …) are its tooling.
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines (verbatim, lines 81–91):
  - `introduce: Workspace`
  - `tool: Workspace`
  - `tool: Cortex cortex_write`
  - `tool: Cortex cortex_edit`
  - (line 90) `introduce: ChatAnalyst`
  - `tool: ChatAnalyst`
- Other directives: none.
- Responsibilities: the suite's introspective analyst — inspects recorded
  Scout-AI chat sessions (chat-file format) for usage patterns,
  tool-calling issues, barriers, confusion; aims at improving harness,
  agent instructions, agent tooling. Provenance-first (sessions span many
  chats and ask jobs; delegation may be recorded as embedded receipts;
  saved societies under `.files/<name>.society/**`, legacy under
  `.files/log/**`). Can act on live sessions: `live_chats` → analysis
  tasks → `post_inbox_advice` via the scout-ai inbox prompt strategy
  (per-save_file sibling inboxes, consume-on-one-real-inference,
  `.inbox_removed` as delivery record, `abort` name reserved as a kill
  signal). Retrieval ladder: `chat_report`/`chat_overview` →
  `chat_tool_calls`/`message_index`/`chat_agents` → `message_content`
  (default retrieval primitive) → `extract_chat_range` only when the
  whole interaction matters.
- Exclusions: reports, does not implement the changes it recommends;
  figures must be read from evidence (job metadata, chat_report outputs,
  receipts), never estimated — label anything unanchored as *estimated*;
  never inline megabyte-scale outputs (check `characters`/`large` first);
  prefer specialized ChatAnalyst tooling over generic Workspace
  (ruby/bash/python); do not reconstruct chat paths from naming
  conventions or retry with guessed paths.
- Delegation references: none (no society import); its subjects are other
  agents' sessions, not other agents.
- Output-format constraints: final assessment must report **target
  conclusions and process conclusions separately**, each citing the
  evidence addresses it rests on. Failure classification vocabulary:
  doctrine / role contract / tooling / documentation / harness /
  project-code. Request classification: target analysis vs process
  analysis, kept separate with separate evidence.

### 1.3 Clean

- File inventory: `start_chat` only (57 B, 3 lines).
- Imports: **none** — the only agent importing nothing.
- Tool/introduce lines: none.
- Responsibilities: same generic scaffold sentence as Basic.
- Notes: zero effective tools — does not even receive the doctrine
  Cortex baseline (packet C tier "none"). Counterpart to Basic for
  import-less scaffolding.

### 1.4 ComputerUse

- File inventory: `start_chat` (849 B); plus full workflow checkout —
  `README.md` (29,787 B), `workflow.rb` (5,033 B), `lib/`, `test/`,
  `doc/`, `share/`, `research/`, `tmp/`, `chats` symlink.
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines (verbatim): `introduce: ComputerUse` — **no
  `tool: ComputerUse` line** (see §3 surprise 1).
- Other directives: `exec_task: ComputerUse pwd`
- Responsibilities: sandbox/path hygiene rules: never write emojis or
  non-standard-width characters; never search (find, grep, …) outside the
  current project directory, `~/.scout`, `~/.rbbt`, or directories
  containing code; on rejected paths / disappearing directories / path
  conflicts run `sandbox_paths`; Cortex never expands filesystem or
  sandbox authority and must not bypass a rejected path; do not persist
  routine shell activity.
- Exclusions: as above (no out-of-scope searching, no emoji).
- Delegation references: none.
- Output-format constraints: plain-width text only (no emojis,
  non-standard-width characters).

### 1.5 Consultant

- File inventory: `start_chat` only (1,611 B).
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines: none (tool-less; endpoint-scoped).
- Other directives: `endpoint: consultant`
- Responsibilities: "the strategic inference point of the suite … very
  expensive; your value is judgment, not labor." Mission: strategy,
  decomposition, methodology, and reframing for difficult or consequential
  problems; "the senior architect and methodologist." Use for: ambiguous
  or high-risk problems needing a decision; architecture and design
  strategy; **scientific methodology: hypotheses, discriminating
  experiments**; reconsidering strategy after surprising evidence;
  classifying work that others keep misclassifying.
- Exclusions: do not explore repositories or run repetitive tools; do not
  execute ordinary coding; do not manage routine coordination; do not
  produce generic best-practice essays. Stopping: deliver the strategy
  and stop; do not follow execution. Cortex: at most one bounded recall
  pass when prior decisions could change the strategy; no investigations,
  upkeep, or continued execution through Cortex.
- Delegation references: produces delegation briefs as part of its output
  contract (decomposition step) — but issues no tools to delegate with.
- Output-format constraints — every answer must contain, compactly:
  1. Classification (what kind of problem this actually is, and why)
  2. Strategy (approach, major risks/assumptions)
  3. Decomposition (bounded steps or delegation briefs to issue)
  4. Decision point (evidence that would falsify the strategy)
  5. Efficiency note (cheapest reliable path; what NOT to spend on)
  One to three screens maximum; list precisely what is missing instead of
  guessing.

### 1.6 Cortex

- File inventory: `start_chat` (6,487 B); plus full workflow checkout —
  `README.md` (19,399 B), `workflow.rb` (6,640 B), `doc/`, `etc/`, `lib/`,
  `research/`, `share/`, `test/`, `var/`, `tmp/`, `.save/`, `chats`
  symlink.
- Imports (verbatim): `import: Agent/doctrine`, `import: Agent/society`
- Tool/introduce lines (verbatim, lines 79–81):
  - `introduce: ComputerUse`
  - `tool: ComputerUse`
  - `tool: Cortex`
- Responsibilities: the Cortex orchestrator — builds and maintains the
  persistent workspace (conversations, briefs, artifacts); makes knowledge
  findable, reliable, evidence-supported without adding overhead.
  Explicitly demarcated: entity support (properties, named lists,
  execution registry) now belongs to Semantics; tracking scientific
  evidence belongs to Research. Working mode (bounded direct work vs
  nontrivial inspection first); choosing conversations/briefs/artifacts as
  working space; evidence inspection (provenance over transcription;
  receipt ≠ correctness); workspace management through Cortex tools by
  logical name; investigation and upkeep (compact, correct, consolidate,
  retire, promote — respecting existing coordination decisions and agreed
  edit plans); persistence ladder (conversations → artifacts →
  `research/` → `doc/`).
- Exclusions: do not directly modify Cortex storage, metadata, or history;
  do not persist every routine answer; do not turn bounded questions into
  investigations; ComputerUse tooling is for upkeep tasks only.
- Delegation references: `cortex_continue` to involve another agent when
  independent analysis, specialist work, or review materially improves the
  result; arrange independent verification for consequential work (doctrine
  §7); society import is the roster context.
- Output-format constraints: none fixed; report what was done, evidence,
  unresolved items; distinguish recommendations from actions performed.

### 1.7 Critic

- File inventory: `start_chat` (6,453 B); `workflow.rb` (370 B — one
  `ask` chat_task that prompts "Evaluate the previous work." and attempts
  `Chat.parse_json` on the answer into job info); `lib/` (empty).
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines (verbatim, lines 121–122):
  - `introduce: Workspace`
  - `tool: Workspace`
- Other directives: none in start_chat.
- Responsibilities: "the verification gate on consequential results" —
  verifies another agent's work product (from Worker, ScoutCoder, Manager,
  or any producer) against the request, plan, repository, and artifacts;
  returns a verdict plus branch advice. Workflow: (1) check requested
  deliverables first; (2) inspect the producer's evidence (cited source
  locations, probes, tests, ledgers, run receipts); (3) targeted source
  verification only for a concrete reason; (4) selective independent
  verification prioritized for architecture/dependency direction,
  persistence and caching, concurrency and lifecycle, public API,
  serialization, cross-repository attribution, edge cases, misleading
  claims, previously-uncertain claims, plus small spot checks — recomputing
  own expected values before reading the producer's. Investigation budget:
  maximize confidence per unit of investigation; evidence check → targeted
  verification → report; never repository-wide rediscovery. Distinctive
  checks: transformation errors (meaning drift, stale references,
  stronger-than-evidence claims, wrong cross-repo attribution), regression,
  cross-repository claims (implemented-by vs dependency vs consumed vs
  deployed-elsewhere), evidence-quality classes: VERIFIED,
  PARTIALLY_VERIFIED, CONTRADICTED, UNSUPPORTED, UNVERIFIED, AMBIGUOUS
  (mapping to the doctrine's validated / independently reviewed /
  unverified).
- Exclusions: verifier, not a second producer — do not redo the
  investigation merely for independent confirmation, do not fix problems,
  do not ask the producer for clarification. Filesystem: "read-oriented
  Workspace tasks" against cited artifacts, avoid broad root-wide listings
  (but see §3 surprise 2 — the declared `tool: Workspace` line is the
  whole workflow). An execution a check needs is a delegated verification,
  not the Critic's own change. Cortex: read-only while verifying;
  `cortex_result` may resolve a cited property address read-only. Cold
  process: fresh-process check for initialization/caching/import-path/
  call-order claims. Corruption: treat a corrupted transcript as
  unverified; recover from the smallest durable claim.
- Delegation references: none outgoing (receives work from Manager;
  mentions Worker, ScoutCoder, Manager as typical producers).
- Output-format constraints: verdicts NEEDS_WORK / BLOCKED / PASS; set
  `search_needed` true with the smallest search needed when a search must
  precede the decision; Markdown by default; if JSON is requested, the
  fixed `critic_review` schema (status, summary, issues, next_step,
  search_needed), never mentioning the schema in the response; numbers
  come from executed checks in the structured verdict block, "prose is not
  evidence."

### 1.8 FitAgent

- File inventory: `start_chat` (729 B); plus full workflow checkout —
  `README.md` (14,642 B), `workflow.rb` (404 B), `lib/` (tasks/use_case,
  tasks/agent_ask), `test/`, `etc/`, `research/`, `use_case/`,
  `workflows/`, `var/`, `tmp/`, `.save/`, `.pytest_cache`.
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines: none (persona tool-less by design; packet C notes
  `evaluate_agent` runs the persona with `agent.workflow = nil`).
- Responsibilities: "evaluate how agents work and improve their doctrine,
  tools, and instructions." Given a scenario and a rubric, evaluate the
  agent's result following the rubric; the injected material is ordered
  scenario-start marker → scenario → rubric → agent response; do not
  confuse the agent's response with own actions.
- Exclusions: when asked to review an agent response with scenario,
  rubric, and result already provided, do **not** call `evaluate_agent`.
- Delegation references: none.
- Output-format constraints: none declared.

### 1.9 Manager

- File inventory: `start_chat` (4,976 B); `lib/` (empty). No workflow.rb.
- Imports (verbatim): `import: Agent/doctrine`, `import: Agent/society`
- Tool/introduce lines (verbatim, lines 110–111):
  - `tool: Cortex cortex_continue`
  - `tool: Cortex cortex_brief`
- Other directives: `socialize: true`
- Responsibilities: "controller of a budgeted multi-agent loop: you decide
  what happens next, which agent does it, with what context, and when to
  stop. You normally do not implement; you delegate through `ask`."
  Inside Planned its context is exactly the three upstream reports
  (restatement, search brief, plan) treated as canonical; outside Planned
  it normalizes the request itself. Control loop: (1) classify and scale
  first — bounded task → straight to the owning specialist, no plan round;
  clear path → one plan; genuine alternatives/dispute → 2–4 candidate
  plans scored by Critic (pre-scoring reserved for high-risk/disputed);
  (2) execute one step at a time, each naming its durable deliverable
  before it runs; (3) verify proportionally — Critic for every
  consequential step (doctrine §7 classes), returning status, score,
  missing checks, smallest next action, branch advice; (4) on NEEDS_WORK:
  minimal repair → targeted search → local replan → branch switch;
  (5) stop on acceptance tests or budget exhaustion; if blocked, smallest
  question set for the user.
- Routing table (society import is the authoritative roster): Scout-stack
  code infrastructure → ScoutCoder; concrete task execution on that
  tooling → Worker; source documents → Reader; scientific investigation
  and evidence-grounded interpretation → Research; verification gates →
  Critic; introspection over recorded sessions → ChatAnalyst; ambiguous or
  high-risk judgment → Consultant. Prefer the specialist whose chat
  carries the domain tooling; recruit outside the suite only on explicit
  user request.
- Budget policy: candidate plans 2–4; active branches ≤2; broad search
  rounds before execution ≤1 (targeted only during); repair cycles per
  step ≤2; full branch switches ≤1 unless clearly necessary.
- Exclusions: does not implement; does not execute entity-property
  computations itself (delegates one bounded evidence-producing step and
  inspects the run receipt: result address, definition version,
  materialized path).
- Delegation references: the whole role is delegation through `ask`;
  delegation packet structure (below) is mandatory in every ask; branches
  carry branch summary, step request, execution result, critic review.
  Provenance: before delegating possibly-pre-existing work, inspect Cortex
  artifacts, materialized property results, embedded receipts; never
  attribute pre-existing outputs to the current branch; a corrupt child
  transcript warrants targeted recovery from durable outputs, not a rerun.
- Output-format constraints:
  - Delegation packet template: `# Introduction` / `# Current state` /
    `# Design` / `# Task` / `# Output required`.
  - Machine-readable decisions: plain text only, no markdown emphasis, no
    code fences; exactly one action and one target; never repeat the menu
    of allowed values in `Action:`/`Target:`; only the prompt body after
    `Prompt:`.
  - Bout discipline: one well-defined unit per bout; split growing
    explorations into named conversations each producing a curated report;
    one-shot asks or branch-specific chat ids over passing whole
    conversations; direct ask chat ids distinct from Cortex conversation
    names.

### 1.10 Planner

- File inventory: `start_chat` only (1,594 B).
- Imports (verbatim): `import: Agent/doctrine`, `import: Agent/society`
- Tool/introduce lines (verbatim, lines 46–51):
  - `introduce: ScoutCoder`
  - `tool: ScoutCoder help_list_repos`
  - `tool: ScoutCoder help_list_repo_documents`
  - `tool: ScoutCoder help_get_repo_document`
  - `tool: ScoutCoder help_overview`
  - `tool: ScoutCoder help_workflow`
- Other directives: none.
- Responsibilities: "Planned's plan stage: you do not execute tasks." Turns
  the restated request plus the search brief (when attached) into one
  practical plan other agents can follow; when no brief is attached
  (search off / `NO_SEARCH_NEEDED`), plans from the restated request alone
  and says so in the plan. Guidelines: short and concrete; each step one
  bounded bout-sized operation with its deliverable named before it runs;
  single path over alternatives unless the user asks for alternatives;
  separate research from implementation only when actually needed;
  acceptance tests a Critic can verify; reuse existing decisions and
  constraints from Cortex citing exact logical paths.
- Exclusions: does not execute the plan; does not mutate the Cortex
  workspace; planning must not become a new investigation.
- Delegation references: plan steps name an "Owner agent: any named
  specialist in the society roster, chosen by capability so the Manager
  can route it."
- Output-format constraints (always): `## Overview` (self-contained
  restatement); `## Assumptions and constraints` (key assumptions,
  technical constraints, risks); `## Plan steps` — numbered, each with
  Goal / Owner agent / Method / Outputs / Stop condition; `## Acceptance
  tests` (objective checklist).

### 1.11 Reader

- File inventory: `start_chat` (3,580 B); `README.md` (11,389 B);
  `workflow.rb` (239 B — requires Workspace, merges helpers, loads
  documents + web tasks); `lib/`; `test/`.
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines (verbatim, lines 70–77):
  - `introduce: Reader`
  - `tool: Reader`
  - `introduce: Workspace`
  - `tool: Workspace`
  - `introduce: Cortex`
  - `tool: Cortex`
- Other directives: none.
- Responsibilities: "the suite's source acquisition and reading agent" —
  takes supplied or discovered sources (papers, reports, PDFs, DOCX, web
  pages) and turns them into inspected, citable source material:
  retrieve, convert, read, extract passages/tables/figures with locators
  back to the source. Deliverable: source-grounded citable **dossiers
  persisted as Cortex artifacts**, recording per source: identity (URL or
  identifier, title, authors, publication/retrieval dates), a locator for
  everything cited (page, section, table/figure id), retrieval context
  (tool, when, from where), and extraction limitations (OCR quality,
  truncation, paywalls, failed/partial retrieval). Fidelity: never lose a
  citation anchor; mark what extraction could not see (a failed retrieval
  is a recorded limitation); quotation vs paraphrase explicit (quotations
  reproduce source text exactly); the dossier must let another agent audit
  what a source says without re-reading it.
- Exclusions: "You acquire and read; you do not interpret" — judging what
  the evidence warrants belongs to the research agent consuming the
  dossier; do not register scientific records (observations, claims,
  hypotheses) or shape their interpretation; **do not delegate** — "You
  are a bounded specialist: finish the reading task you were given and
  report."
- Delegation references: none outgoing (is a delegation target — Research
  and Searcher both route reading here).
- Tool guidance: prefer composite `pdf_query`/`html_query` (conversion +
  retrieval wired together, Scout caching); `pdf2md`/`docx2md`/`html2md`
  when the whole converted document is the deliverable; `searxng` for
  discovery; probe converter/embedding availability before a bout; size
  bouts deliberately (one conversion + N targeted queries; defaults
  searxng count 10, query num 3; reuse identical inputs to replay cached
  steps); Workspace as filesystem fallback; cite producing job paths and
  receipts rather than transcribing excerpts into chat.
- Output-format constraints: dossier structure as above (no fixed literal
  template); quotation marking mandatory.

### 1.12 Research

- File inventory: `start_chat` (13,035 B — the longest role contract);
  `README.md` (8,076 B); `workflow.rb` (200 B — requires Workspace, loads
  only `lib/Research/path_kinds`; **defines 0 tasks**);
  `research/`, `results/`, `share/`, `test/`, `var/`, `tmp/`, `chats`
  symlink.
- Imports (verbatim): `import: Agent/doctrine`, `import: Agent/society`
- Tool/introduce lines (verbatim; note `tool: Research` sits at line 3,
  before `system:`):
  - line 3: `tool: Research`
  - line 44: `introduce: Semantics`
  - line 45: `tool: Semantics`
  - line 47: `introduce: Workspace`
  - line 48: `tool: Workspace`
  - line 71: `tool: Cortex cortex_list`
  - line 72: `tool: Cortex cortex_read`
  - line 73: `tool: Cortex cortex_write`
  - line 74: `tool: Cortex cortex_edit`
- Other directives: `exec_task: Workspace pwd` (line 51);
  `socialize: true` (line 253).
- Responsibilities: "Scout's scientific investigation agent … acquiring
  evidence, interpreting results, testing hypotheses, challenging
  conclusions, and producing traceable scientific syntheses." Owns the
  scientific process, not Scout framework implementation — reuses
  Semantics, Workspace, entity properties, tasks, workflows, receipts, and
  the Research scientific-record Path kinds. Scientific operating protocol
  (7 steps): (1) recall and establish scope (Cortex first; research
  question, deliverable, data, methods, limits); (2) map the evidence
  (inventory datasets, frozen results, properties, receipts; primary vs
  derived; avenues); (3) acquire and register **Observations** (statement
  describes what was found without mechanistic interpretation; source via
  the supported schema; scope, locators, content identity, limitations);
  (4) form **Claims** and **Hypotheses** (claims = propositions whose
  evidential support can be assessed; hypotheses = proposed explanations
  with predictions/discriminating tests); (5) challenge and investigate
  (counterevidence, alternatives, controls, sensitivity; test hypotheses
  through discriminating analyses, not confirmatory accumulation);
  (6) validate and synthesize (schemas, references, provenance, status
  consistency, dependencies; scientific narrative where every material
  conclusion resolves through Claim/Hypothesis to supporting Observations
  and sources); (7) close and preserve progress (conclusions, unresolved
  questions, failed analyses, next actions, resumable durable context).
  Records: `observation`, `claim`, `hypothesis` Path kinds; register
  through the supported operation (no invented identifiers, no manual
  record-file manipulation, no competing writable copies); implemented
  relationship vocabulary only; one authoritative writable record per
  finding; preserve historical versions, use invalidation/supersession
  instead of deleting evidence. Evidence discipline: evidence precedes
  interpretation; traceability ≠ causality; distinguish direct
  measurements, retrieved facts, computed results, inferred activities,
  process enrichment, comparative interpretations, mechanistic hypotheses;
  preserve uncertainty and contradictions; multiple analyses of one dataset
  are not independent confirmation; do not infer significance, replication,
  causality, efficacy beyond what data and design warrant; a missing
  dependency is a tooling limitation, not a negative finding. Tool
  selection: Semantics for domain concepts/entities/properties; Workspace
  for files/scripts/computation; Path interface for records; Cortex for
  durable framework findings; inspect capabilities before workaround;
  never construct a new property/task/abstraction merely because an
  existing tool was not yet discovered. Completion standard: calibrated
  answer + registered records + resolvable provenance + durable challenge
  outcomes + traceable synthesis + progress info; compact auditable result
  over long narrative.
- Exclusions: do not delegate to ScoutCoder or build new framework
  infrastructure as part of an investigation; do not introduce ScoutCoder;
  do not bypass record validation or alter frozen inputs; development
  verification of a just-defined property goes through ScoutCoder's
  `run_probe` (fresh process live-loads `share/` drafts — production
  dispatch surfaces like Semantics `entity_property` deliberately do not
  reload; a fresh draft invisible to a running Semantics is expected).
- Delegation references: "**Delegate acquisition, not epistemology.**"
  Source discovery → Searcher; document acquisition/close reading →
  Reader; consume search briefs and Reader dossiers as inputs; a dossier
  is source material, not a registered Observation — register an own
  Observation citing the dossier and its locators. "Research retains
  epistemic ownership of the synthesis." Delegate bounded scientific
  questions and verification when useful, each with research question,
  artifact paths, assumptions, constraints, prior findings, requested
  output; delegated findings must identify actual sources; independent
  review is not independent replication when reviewers share data, methods,
  assumptions.
- Output-format constraints: no fixed template; prefer compact auditable
  result; no emojis; never claim a test/computation/validation/review
  passed unless it ran or is explicitly qualified; never commit, push, or
  merge unless asked.

### 1.13 ScoutCoder

- File inventory: `start_chat` (6,112 B); `README.md` (80,212 B);
  `workflow.rb` (1,048 B); `lib/`, `python/`, `research/`, `test/`, `var/`,
  `tmp/`, `chats` symlink.
- Imports (verbatim): `import: Agent/doctrine`, `import: Agent/scout`
  (only agent importing the scout vocabulary).
- Tool/introduce lines (verbatim, lines 113–123):
  - `tool: Cortex cortex_write`
  - `tool: Cortex cortex_edit`
  - `introduce: Workspace`
  - `tool: Workspace`
  - `exec_task: Workspace pwd` (line 120)
  - `introduce: ScoutCoder`
  - `tool: ScoutCoder`
- Responsibilities: "the Scout-stack specialist: you develop and use
  workflows on the Ruby Scout/Rbbt framework, and you own the supporting
  code infrastructure the other agents depend on. Your job is correct,
  small, verifiable changes in the workflow the task names — by default
  the checkout at `PWD`." Start from the real checkout. Development
  doctrine, in order: (1) check Cortex — recall before rebuilding,
  consolidate footgun notes, inspect available tools
  (`list_tasks`, `task_inputs`, `task_dependencies`, `task_code`,
  `list_entities`) and use the tool whose responsibility matches;
  (2) read documentation when required only (narrowest document; do not
  regenerate overviews); (3) probe documentation gaps with `run_probe` and
  persist via `cortex_write`/`research/`; (4) loop on the Path engine —
  `path_write` the draft (Task/Entity/other kind), `path_write` the paired
  test_file then `run_test`, verify (`path_validate` shape, `path_smoke`,
  `run_test` fresh process; just-defined entity properties verified through
  `run_probe`), document (`desc` under `share/`, `document_task` when
  promoted). Smallest change; existing idioms; inspect diff and call
  sites. Verification proportionate and layered; behavior tests for
  behavior claims (suite test template); fresh process ≠ fresh persistent
  state (clean the exact Step or `clean: true`); record whether an
  execution replayed. Drafts stay under `share/` until deliberate
  promotion; promotion moves one resource and never wires or loads
  anything — wiring into `workflow.rb` is explicit Workspace work.
  Infrastructure stewardship: shared interfaces — treat changes to shared
  tooling as consequential (doctrine §7), keep interfaces stable or
  announce the break, make capabilities discoverable. Leave a
  `ScoutCoder:` Ruby comment near triggering code when a discovery would
  improve documentation.
- Exclusions: no extensive campaigns tracking down how something works
  outside the main repositories (simple probes and documented contracts
  suffice); clean up probes/temp files after testing; never commit, push,
  or merge unless asked; no emojis.
- Delegation references: none outgoing; is the delegation target for code
  infrastructure (Manager routing, Research prohibition).
- Output-format constraints: none fixed.

### 1.14 Searcher

- File inventory: `start_chat` only (2,365 B).
- Imports (verbatim): `import: Agent/doctrine` (no society import).
- Tool/introduce lines (verbatim, lines 40–57):
  - `introduce: Workspace`
  - `tool: Workspace list_directory`
  - `tool: Workspace search`
  - `tool: Workspace read`
  - `introduce: Reader`
  - `tool: Reader searxng`
  - `tool: Reader html2md`
  - `introduce: ScoutCoder`
  - `tool: ScoutCoder help_list_repos`
  - `tool: ScoutCoder help_list_repo_documents`
  - `tool: ScoutCoder help_get_repo_document`
  - `tool: ScoutCoder help_overview`
  - `tool: ScoutCoder help_workflow`
  - `tool: Cortex cortex_write`
  - `tool: Cortex cortex_edit`
- Other directives: none.
- Responsibilities: "**Planned's search stage.** Your brief is the
  reference report the Planner and the work stage consume — one of the
  three reports that form their canonical context — so keep it short,
  concrete, and reusable by agents other than the one who asked." When no
  search is needed, output exactly `NO_SEARCH_NEEDED`. Guidelines:
  targeted search over broad surveys; local documentation and repository
  files first, web only when needed; before searching, check whether the
  executor will read the repository anyway and report that overlap instead
  of duplicating; hand off documents needing substantial extraction or
  close reading to **Reader**, flagged with resolvable source references
  (URL or identifier plus locator hints), no self-extraction; identify
  relevant skills using `match_skills`; trust the documentation — for
  known-but-undocumented behavior search Cortex first and return the exact
  prior artifact with verification status. Boundary: "your brief is
  knowledge and information … Do not make code or design decisions."
- Exclusions: no code or design decisions; no document extraction
  (Reader's); Cortex: bounded recall only, persist only reusable findings,
  write nothing when returning NO_SEARCH_NEEDED; do not continue
  conversations, run entity properties, or manage the workspace.
- Delegation references: hands off to Reader (explicit); is itself the
  source-discovery target named by Research's start_chat and the society
  roster.
- Output-format constraints (always):
  `# Search brief` with bullets: Main question / Findings / Sources /
  Relevant skills / Uncertainties / Recommendation; or exactly
  `NO_SEARCH_NEEDED`.

### 1.15 User

- File inventory: `start_chat` only (3,114 B).
- Imports (verbatim): `import: Agent/doctrine`, `import: Agent/society`
- Tool/introduce lines: none.
- Other directives: none.
- Responsibilities: "the suite's liaison: you run Planned's request stage
  (restating the raw request) and its ask stage (synthesizing the final
  report), and you are the reporting point in direct conversations."
  Intake: restate so it is unambiguous, self-contained, actionable without
  conversational context; identify every deliverable, constraint, success
  condition; pass user suggestions/pointers verbatim even when not
  understood; assumptions only when necessary, labeled, safe split from
  risky; continuations distill prior iterations into deltas, decisions,
  open items; smallest question set when blocked. Final reporting:
  synthesize validated outputs; report only what artifacts and execution
  results support; never invent results, files, tool calls, conclusions;
  quote results and figures from executed evidence, not memory;
  verification status per claim with the doctrine vocabulary (validated /
  independently reviewed / unverified); append work content after the
  report when asked to include it.
- Exclusions: do not execute implementation, repository-research, or web
  tools; do not solve the task; sole exception is bounded read-only Cortex
  recall for an explicitly supplied artifact or clearly relevant validated
  reporting context; different tool exposure per Planned stage (request
  full, ask none) — work with whatever the stage provides; no emojis or
  non-standard-width characters.
- Delegation references: none outgoing (is the pipeline's front and back
  door).
- Output-format constraints:
  - Intake/restatement (always): `## Restated request`, `## Deliverables
    requested`, `## Assumptions` (safe / risky), `## Guidance`, `##
    Missing critical information / questions` (each `[Critical? yes/no]`),
    `## Constraints`, `## Success criteria`.
  - Final answer (always): `# Final report` with `## Executive summary`,
    `## What was done`, `## Results / deliverables` (files;
    commands/workflows; key outputs quoted from executed evidence),
    `## Reproducibility`, `## Caveats` (including whether independent
    verification occurred), `## Open issues / next actions`.

### 1.16 Visualizer

- File inventory: `start_chat` (6,848 B); `test` (125 B — a sample chat:
  `agent: Visualizer`, `endpoint: visual`, one user turn asking to comment
  on an image); `test.files/agent.chat` (8,030 B fixture).
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines (verbatim, lines 118–119):
  - `tool: Cortex cortex_write`
  - `tool: Cortex cortex_edit`
- Other directives: `endpoint: visual`, `attachments: true` (only agent
  with attachments).
- Responsibilities: "a scientific visualization and figure-review agent" —
  create, inspect, assess, revise, interpret scientific figures as
  explicit scientific artifacts; a figure succeeds only if it faithfully
  represents the data and question, makes structure visible, avoids
  misleading encodings, and suits scientific communication. Maintains the
  distinctions: observations/measurements; transformations/preprocessing;
  computed quantities; visualization-introduced assumptions; visual
  encodings; scientific interpretations. Review loop:
  construct → execute → **inspect the rendered image** → identify defects
  → revise → render → inspect, repeated until requirements met or a
  genuine limit. Five review dimensions: scientific correctness; perceptual
  correctness; communication; interpretability (which conclusions the
  figure supports / cannot support); reproducibility and provenance
  (explicit inputs, documented transformations, traceable provenance,
  explicit consequential choices). Targeted revisions driven by identified
  problems; no unnecessary stylistic changes. Interpretation conservative:
  visible association ≠ causal; group difference ≠ biologically
  meaningful; clusters may be preprocessing artefacts; state assumptions;
  say when the figure cannot distinguish competing explanations; external
  knowledge distinct from what the data encodes. Self-critique: critique
  is not an oracle; do not claim scientific validation merely from own
  review; seek independent checks.
- Exclusions: no silent pattern→conclusion conversion; no treating
  successful execution or an attractive result as acceptance.
- Delegation references: none (seeks independent checks "where
  appropriate" but names no agent).
- Output-format constraints: persist reusable figure reviews and
  interpretations in Cortex with figure, data, and workflow provenance;
  no fixed chat template.

### 1.17 Worker

- File inventory: `start_chat` only (3,772 B).
- Imports (verbatim): `import: Agent/doctrine`
- Tool/introduce lines (verbatim, lines 86–89):
  - `introduce: Workspace`
  - `tool: Workspace`
  - `introduce: Cortex`
  - `tool: Cortex`
- Other directives: none.
- Responsibilities: "the suite's execution agent: you run concrete tasks
  on the infrastructure ScoutCoder builds — experiments, analyses,
  evidence production — and any concrete task not explicitly another
  agent's responsibility. You produce tangible artifacts; you are a step
  executor, not a project manager." Execution stance: one independently
  verifiable unit at a time; when a plan exists, execute only the given
  step; if asked to implement a whole plan at once, execute the next
  highest-value step or ask for a clearer step-level task; prefer
  files over prose; record commands and outputs for reproducibility;
  deliver durably (files, artifacts, result addresses); write Cortex
  artifacts/lists/properties only when asked or when reusable. Evidence
  specialty: when a claim is computable by an entity property, run it and
  cite the result address and definition version (readers resolve with
  `cortex_result`); run properties over named lists, not entity by entity;
  quote figures from evidence; label each claim validated / independently
  reviewed / unverified. Tooling: Workspace + Cortex plus any introduced
  domain tooling; specific tool before general; on a rejected path inspect
  that tool's permissions rather than retrying. Coding stance: respect
  conventions, output filenames, artifact locations named in the task; aim
  at acceptance tests; `write` over `patch` for large/generated content;
  fresh process for call-order/ambient-state dependence; do not delete or
  overwrite important files unless instructed; flag risky changes; report
  command failures as they are. Bouts: one unit per bout, never silently
  drop a sub-task; split growing explorations and preserve partial results
  durably.
- Exclusions: does not decide next steps when a plan exists (belongs to
  the plan's owner); leaves conversation management, property definition,
  and workspace upkeep to tasks that ask for them.
- Delegation references: none outgoing; is Manager's default execution
  route and Planned's default work-stage agent.
- Output-format constraints — the exact plain-text report (mandatory on
  completion):
  `## Execution summary` (What you tried / What succeeded / What failed or
  remains uncertain); `## Artifacts` (Created / Modified, exact relative
  paths); `## Commands / tool calls`; `## Validation performed` (exact
  commands and outcomes); `## Notes / next steps`. Plus: say so explicitly
  when no files were created/modified; never return only a short sentence
  when a structured report is required; on incompleteness, return the
  smallest blocking issue and the most useful partial artifact.

---

## 2. Overlap analysis

### 2.1 Consultant vs Research vs planned ScientificLead

- Consultant's declared lane includes "scientific methodology: hypotheses,
  discriminating experiments" (Use-for item 3) — verbatim overlap with
  Research's protocol steps 4–5 ("Form Claims and Hypotheses … Test
  Hypotheses through discriminating analyses"). Two agents currently claim
  scientific-methodology judgment; they differ in altitude (Consultant:
  strategy-only, tool-less, deliver-and-stop; Research: executes the full
  investigation with record ownership), so today's split is defensible but
  the boundary is prose, not structure.
- A third claimant (ScientificLead) makes the boundary load-bearing.
  Declared-structure evidence for the split: Consultant has no tools and a
  5-part output contract built around delegation briefs — it is a
  strategy/decomposition shape, not an investigation shape. Research's
  contract fuses methodology with record ownership and epistemic
  synthesis ("Research retains epistemic ownership of the synthesis").
- First cut: ScientificLead absorbs the *direction* layer — what
  investigation to run and why, hypothesis selection, discriminating
  experiment design (Consultant's scientific use-for items) — while a
  narrowed Research keeps *record curation and traceability* (§2.3) and
  executes investigations. Consultant narrows to architecture/design
  strategy and classification, losing its scientific-methodology line.
  Cost: Consultant's start_chat edit is one use-for bullet; Research's is
  a protocol rewrite (see §2.3).

### 2.2 Worker vs planned Investigator

- Worker is already investigation-shaped: "experiments, analyses, evidence
  production," an evidence specialty (entity properties, result addresses,
  named lists, verification labels), durable-delivery and
  reproducibility rules, and the suite's strictest output contract. What
  it lacks is any *epistemic* identity: it executes steps and explicitly
  refuses next-step decisions.
- An Investigator that owns investigation bouts (question → evidence chain
  → bounded conclusion) would sit between Worker (pure step executor) and
  the narrowed Research/ScientificLead (record + direction). Declared
  structure supports deriving it from Worker: the evidence-specialty
  section, bout discipline, and report format transfer directly; what must
  be added is question-ownership and evidence-chain reasoning, which
  Worker's contract currently *prohibits* ("deciding the next step belongs
  to the plan's owner").
- Decision flagged (per packet): whether Investigator replaces Worker or
  coexists. Coexistence leaves Worker's catch-all clause ("any concrete
  task not explicitly another agent's responsibility") as the residual
  executor; replacement moves that clause to Investigator and retires the
  Worker directory. Either way Worker's start_chat is the template source;
  the artifact-path and validation-report conventions should be preserved
  verbatim in whichever survives.

### 2.3 Research vs the planned narrowed evidence-curator identity

- Research's current contract interleaves three things: acquisition
  routing (Searcher/Reader delegation), epistemic judgment (claims
  assessment, hypothesis testing, synthesis, challenge), and record
  curation (Path-kind registration, lifecycle, validation, one
  authoritative writable record, supersession semantics). The planned
  narrowing keeps the third and strips the second.
- Structural finding: the interleaving is inside the 7-step protocol
  itself (steps 3–5 mix registration with interpretation; step 6 fuses
  validation with narrative synthesis). Narrowing is therefore a protocol
  rewrite, not a deletion of sections — the curator must still register
  Observations "without silently adding a mechanistic interpretation"
  (already curator-compatible) but loses the authority to "determine
  whether a Claim should be supported, qualified, weakened, or rejected"
  (step 5), which moves to ScientificLead.
- The evidence-discipline section (levels of evidence, uncertainty
  preservation, no-overclaiming) is curator-compatible and should stay;
  the "Working with other agents" section's "Delegate acquisition, not
  epistemology" inverts under the new split (the curator delegates
  *judgment* upward, not merely acquisition downward).

### 2.4 Searcher's Planned-stage binding vs a generic narrow search role

- Searcher's declared identity is hard-bound to Planned: first sentence
  "Planned's search stage," brief defined as "one of the three reports
  that form their canonical context," and the `NO_SEARCH_NEEDED` sentinel
  is a Planned-protocol artifact (the Planner is the documented consumer
  of that token).
- But two non-Planned consumers already exist in declared structure:
  Research's start_chat ("Route source discovery to Searcher") and the
  society roster ("Use for: source discovery and bounded search"). A
  direct call from Research gets a brief formatted for Planner/work-stage
  consumption and a sentinel token with no defined meaning outside
  Planned.
- The tool set is already the right narrow shape (list_directory, search,
  read; searxng, html2md; five help tasks; cortex_write/edit — 15
  effective tools, packet C's "A5 (narrow)"), and the boundary ("knowledge
  and information … no code or design decisions") plus the Reader handoff
  are role-generic.
- First cut: keep tools, brief format, boundary, and Reader handoff;
  reword the opening from "Planned's search stage" to a generic targeted
  discovery role with an explicit Planned clause ("when running as
  Planned's search stage, … canonical context, NO_SEARCH_NEEDED"), so
  direct callers get a defined contract. The `match_skills` line depends
  on a task not present in Searcher's own declared tool lines — worth
  re-checking at runtime-layer redesign (noted, not probed here).

### 2.5 Adjacent overlap observed while reading (secondary)

- Manager's routing table and the society roster disagree in emphasis:
  Manager routes "ambiguous or high-risk judgment → Consultant"; the
  roster adds the Consultant-is-expensive framing. Both will need edits
  for ScientificLead/Investigator and the narrowed Research.
- Critic and ChatAnalyst have explicitly demarcated territories in both
  contracts (work products vs recorded sessions) — no overlap.
- Reader and Searcher both carry `html2md`, deliberately (Searcher for
  lightweight page checks, Reader for full conversion) — the declared
  boundary ("do not extract document contents yourself") covers it.

---

## 3. First-cut modify/preserve list

- **New — ScientificLead**: absorbs scientific-methodology direction
  (Consultant's hypotheses/discriminating-experiments lane) and the claim
  adjudication authority Research currently holds; no tools needed beyond
  doctrine baseline initially (Consultant's tool-less shape is the
  template).
- **New — Investigator**: derived from Worker's start_chat (evidence
  specialty, bout discipline, report contract preserved verbatim); adds
  question-ownership over investigation bouts; Worker's fate (replace vs
  coexist as residual executor) is the flagged decision.
- **Revised — Manager**: routing table, delegation packet, and budget
  policy updated for ScientificLead/Investigator and the narrowed
  Research; Consultant lane narrows to architecture/strategy.
- **Revised — Searcher**: de-bound from Planned-specific framing into a
  generic narrow search role with an explicit Planned clause; tools and
  brief format preserved.
- **Revised — Research**: narrowed to evidence curator — Path-kind
  registration, lifecycle, traceability, evidence-discipline retained;
  claim adjudication and synthesis judgment move to ScientificLead;
  7-step protocol rewritten to separate registration from judgment;
  `tool: Research` no-op line resolved (drop or give the workflow tasks).
- **Revised — ScoutCoder**: stable core; pending migration of the
  unit-test placement convention from `doctrines/advice` (that appendix is
  an emptied pointer scheduled to move into ScoutCoder); society roster's
  "semantic entity definitions" phrase needs alignment with Semantics
  ownership.
- **Revised — Critic**: declared `tool: Workspace` (full workflow, incl.
  write/delete/bash/patch) vs role text "read-oriented Workspace tasks" —
  either narrow the tool lines to read tasks or rewrite the boundary text
  to acknowledge deliberate write access.
- **Untouched — Planner**: contract is stage-scoped and stable; only
  downstream effects (owner-agent vocabulary gains new names) — no
  structural change required.
- **Untouched — User**: liaison/reporting contract is pipeline-agnostic
  and stable.
- **Decision flagged — Worker**: template source for Investigator; either
  retired after Investigator exists or retained as the residual
  catch-all executor; do not narrow both agents into the same lane.
- **Out of scope**: Basic, Clean (scaffolds), ChatAnalyst, ComputerUse,
  Cortex, FitAgent, Visualizer — no redesign action identified at the
  declared-structure layer. Consultant is affected only through the
  ScientificLead absorption of its scientific-methodology bullet (its
  architecture/strategy core is preserved); noting it here since the
  packet's revise list did not name it.

## 4. Surprises

1. **ComputerUse instructs a tool it does not declare**: its start_chat
   says "run the task 'sandbox_paths'" but carries only
   `introduce: ComputerUse` with no `tool: ComputerUse` line — 0
   ComputerUse tasks at the Chat.tools layer (packet C validated; whether
   `LLM.load_agent` auto-attaches the own workflow at runtime remains
   unverified there).
2. **Critic's declared tools contradict its role text**: "read-oriented
   Workspace tasks" vs bare `tool: Workspace` granting write, delete,
   bash, patch, precise_edit (23 tools, packet C).
3. **Worker and Reader hold the full 10-task Cortex set** (bare
   `tool: Cortex`), including cortex_rename/move/remove — curator-grade
   authority in an executor's and a reader's hands; the 2026-09-05 matrix
   had Worker on a granular per-task list.
4. **Research's `tool: Research` is a declared no-op**: the workflow.rb
   loads only path_kinds and defines 0 tasks — and the line sits at line 3,
   before `system:`, the only such pre-system tool line in the suite.
5. **Clean imports nothing at all** — not even doctrine — so it receives
   no Cortex baseline (0 effective tools); Basic, one line longer,
   imports doctrine and gets R3.
6. **Searcher lacks the society import** although Research's contract and
   the roster both treat it as the suite's source-discovery service; its
   identity text speaks only to Planned.
7. **Only two agents are endpoint-scoped** (`endpoint:` Consultant
   `consultant`, Visualizer `visual`); only Visualizer sets
   `attachments: true`; only Manager and Research set `socialize: true`;
   no `kb:`/`mcp:` lines exist anywhere in the suite.
8. **`doctrines/advice` is a deliberately emptied pointer file**: its
   Scout-specific content (notably the unit-test placement convention) is
   "retained below pending its move into the ScoutCoder start_chat" — an
   explicit outstanding migration the redesign should close.
9. **Critic and Manager carry empty `lib/` directories** — inert residue,
   no code; Critic additionally has a 370-byte workflow.rb defining one
   `ask` chat_task.
10. **The society roster already encodes the intended Specialization
    boundaries** (Reader vs Research split, ChatAnalyst vs Critic
    contrast) more crisply than some start_chats do — the roster is a
    good anchor text for the rewrite.

## 5. Evidence and reproduction

- All 17 start_chats read in full from the repo working tree at
  `/bulk/mvazque2/git/AgentSuite` (branch ags-redesign), 2026-11-01.
  Directive lines quoted with line numbers from `grep -n -E
  '^(import|tool|introduce|kb|mcp|endpoint|attachments|socialize|system|exec_task|exec)'`
  over each `<Agent>/start_chat`.
- Side files read: `society` (roster, 6,954 B), `doctrines/advice`,
  `Critic/workflow.rb`, `Manager/lib` + `Critic/lib` (empty),
  `Reader/workflow.rb`, `Research/workflow.rb`, `FitAgent/workflow.rb`,
  `Visualizer/test` + `Visualizer/test.files/agent.chat`.
- Cross-referenced (not re-probed): `new_doctrine/work/
  redesign-audit-c-matrix.md` (effective tool tiers, §0 census, §2
  discrepancies), `redesign-baseline.md`, `redesign-audit-context.md`
  (existence only).
- Effective-tool figures cited in this file are packet C's probe results;
  everything else is validated by direct read of the cited file.
- No files were modified; no scratch files were needed (all reads fit in
  the conversation). Output: this file only.
