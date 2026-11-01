# Redesign Phase 0 — orchestration & context-delivery audit (AgentSuite)

Date: 2026-11-01. Packet: orchestration/context-delivery (read-only audit;
only sanctioned writes: `tmp/redesign_audit_*` probes, this file, and the
capability-matrix extension under `research/agent-cortex-capabilities.md`).

All quotes below are from the current working tree at
`/bulk/mvazque2/git/AgentSuite` (branch `main`, HEAD `e6ead1b` at audit
time). Line numbers are those of the on-disk files read.

---

## 1. Planned/workflow.rb trace and route-feasibility verdict

File: `Planned/workflow.rb`, 91 lines, read fully (evidence: `cat -n`
in the audit log; structure confirmed by greps listed in §6).

### Task-by-task trace

| Task | Agent | Depends on | Tooling | Special behavior |
|---|---|---|---|---|
| `request` | `:User` (fixed, L8) | — (entry) | `chat: chat` only — no `tooling:` override, so **full tooling** | prompt: "Restate the request from the user as self contained instructions for the agents." (L11) |
| `search` | `:Searcher` (fixed, L21) | `dep :request` (L17) + dynamic `dep :search` block (L30-36) | `tooling: self.tooling_intro` (L21) — **introductions only** | prompt: "Prepare a report that can be used as reference..." (L24). Dynamic dep: if chat option `use_search` != 'false' → normal search job; else reroutes the jobname to `task: :request` inputs (L30-36), so the chain proceeds with request's segment |
| `plan` | `:Planner` (fixed, L47) | `dep` absent in file — chat follows `step(:request)` and `step(:search)` if present (L39-43) | `tooling: self.tooling_intro` (L47) | `chat.message :clear_tools, true` (L46) before prompt "You have been asked to fulfill a user request. Elaborate a plan" |
| `work` | `worker_agent` variable (L63) | `dep :plan` (L56); follows request/search/plan segments (L59-61) | `tooling: self.tooling` (L65) — **full tooling** | `worker_agent = config :worker_agent, default: (options[:Planned_worker_agent] \|\| options[:worker_agent] \|\| 'Manager')` (L63). Prompt "Proceed with the plan" |
| `ask` | `:User` (fixed, L82) | `dep :work` (L74) | `tooling: false` (L82) — **no tools** | `chat.message :clear_tools, true` (L80) before "Please elaborate a final report for the User." |

Notes pinned from source:

- `clear_tools` is a chat message role (`:clear_tools`) consumed when the
  chat is built: it drops prior `tool:` traces from the context; it does not
  remove tool availability declared in the *same* stage's `tooling:` (plan
  keeps introductions; ask keeps none).
- `self.tooling` selects chat messages with roles `introduce/tool/mcp/kb`
  (gem scout-ai 2.1.0, `lib/scout/llm/chat/process/tools.rb` L255-257:
  `def tooling; self.select{|msg| [:introduce, :tool, :mcp, :kb].include?(msg[:role].to_sym) }; end`),
  and `tooling_intro` selects only `introduce` (gem
  `lib/scout/llm/agent/workflow.rb` L64-66).
- Chat options honored: `use_search` (L32), `worker_agent` /
  `Planned_worker_agent` (L63). No other option gates stage structure.

### Verdict: can the AGS route be expressed without editing Planned/workflow.rb?

**Not as a single `Planned ask` run — partially via options, fully via a
sibling workflow.** Three observations, each evidence-backed:

1. **Agent selection is configurable but stage topology is not.** The only
   lever is `worker_agent`/`Planned_worker_agent` (L63), which changes ONE
   stage's agent. The requested AGS route (recon → background search →
   scientific-lead plan → manager work orders → investigator packets → lead
   review loop → consolidation → fresh reporting) has ~8 stages with loops;
   `Planned` is a fixed 5-stage linear chain with exactly one conditional
   edge (`use_search`). No chat option adds, removes, or loops stages.
2. **The loop and multi-recipient stages have no anchor.** `work` builds one
   agent and one prompt (L57-72); a lead-review loop or manager→multiple
   investigator packets cannot be expressed by prompt text alone, because
   the workflow, not the agent, decides when a stage ends.
3. **Precedent exists for sibling routes without touching Planned.**
   `Branched/workflow.rb` (101 lines) already does this: it aliases
   `Planned`'s plan stage (`task_alias :plan, Planned, :plan`, L9) and adds
   its own `work` (fan-out to sub-task worker agents, L12-79) and `ask`
   (L81-98). `Direct/workflow.rb` (11 lines) is a minimal single-stage
   `ask`. So the established pattern for a new route is a new sibling
   workflow directory (e.g. `Ags/` or `Redesigned/`), possibly reusing
   Planned stages via `task_alias` — `Planned/workflow.rb` itself stays
   untouched.

What *is* achievable inside `Planned` without edits (worth stating for
Phase 5): choosing the `work` agent per run (`option worker_agent
ScientificLead`), skipping search (`option use_search false`), and shaping
behavior through the selected agents' start_chats (which Phase 2-3 edits).
That yields "ScientificLead executes the plan" but not the multi-stage
review loop.

---

## 2. Capability matrix: located, read, extended

- It is a **repo file**: `research/agent-cortex-capabilities.md` (156 lines
  before extension), not a Cortex artifact. (A related Cortex artifact
  `plans/agentsuite-rollout-spec.md` exists under `var/cortex/artifacts/`.)
- Format: title, prose intro, profile-tier legend (R/A/E/P/C), a 13-row
  per-agent table (columns: Agent, Profile, Cortex tool lines in start_chat,
  Effective Cortex tools, Role sentence anchor), evidence section citing
  probe outputs under `tmp/`, and a verification appendix.
- **Extension performed (sanctioned):** appended a new section
  `## 7. Extension — 2026-11-01 redesign audit (Reader, FitAgent,
  ChatAnalyst)` with three new rows and discrepancy notes; no existing row
  edited. Verified by reading the file tail after the edit.

### Probe (hermetic, no model turns)

- Script: `tmp/redesign_audit_matrix_probe.rb` (patterned on the
  reader-split probes `tmp/p4hermetic_doctrine_propagation.rb` and
  `tmp/d2_probe.rb`): parses each `start_chat`, resolves `import:` chains
  (via `Chat.imports` against a scratch `Agent/` mirror in
  `tmp/redesign_audit_agent_mirror/` — the repo's `chats` symlink target is
  absent in this sandbox, mirroring the constraint the reader-split probes
  documented), expands `introduce:`/`tool:` lines, and counts the effective
  tool table exactly as `LLM.chat` would.
- Output: `tmp/redesign_audit_matrix_probe.out`; stderr clean
  (`tmp/redesign_audit_matrix_probe.err`), exit 0.

Results (from the .out file):

```
== Reader
  own tool lines:      ["tool: Reader", "tool: Workspace", "tool: Cortex"]
  effective tool table: 40 tools
  cortex_* tools (13 keys, 10 distinct): cortex_brief, cortex_continue,
    cortex_edit, cortex_list(×2), cortex_move, cortex_read(×2),
    cortex_remove, cortex_rename, cortex_search(×2), cortex_write
== FitAgent
  own tool lines: []   (doctrine footer only)
  effective tool table: 3 tools
  cortex_* tools (3): cortex_list, cortex_read, cortex_search
== ChatAnalyst
  own tool lines: ["tool: Workspace", "tool: Cortex cortex_write",
                   "tool: Cortex cortex_edit", "tool: ChatAnalyst"]
  effective tool table: 44 tools
  cortex_* tools (5): cortex_edit, cortex_list, cortex_read,
                      cortex_search, cortex_write
```

New matrix rows (also written into the file):

| Agent | start_chat | Own Cortex tool lines (current) | Effective Cortex tools | Profile vs current 10-task Cortex |
|---|---|---|---|---|
| Reader | 77 lines; L1 `import: Agent/doctrine` | L76 `introduce: Cortex`; L77 bare `tool: Cortex` | 10 distinct = full set | C-equivalent |
| FitAgent | 17 lines; L1 `import: Agent/doctrine` | none | 3 (list/search/read) | R |
| ChatAnalyst | 91 lines; L1 `import: Agent/doctrine` | L83 `tool: Cortex cortex_write`; L84 `tool: Cortex cortex_edit` | 5 | A |

Discrepancies vs the 2026-09-05 table (recorded in the file, rows untouched):

- Doctrine footer no longer carries `cortex_activity` — commit a060da7
  "Remove cortex_activity" (2026-11-01) left `introduce: Cortex` +
  `cortex_list/cortex_search/cortex_read`, so profile R = 3 tools now.
- The Cortex submodule at pointer d83a355 defines exactly **10** cortex_*
  tasks (scan of `Cortex/lib/Cortex/tasks/*.rb`: artifact.rb 5,
  conversation.rb 3, listing.rb 3). The property/list/entity tasks behind
  profiles E and P are not defined in this checkout; entity support moved to
  Semantics (Cortex commit 4c33a6f "Reduce docs to conversations/briefs/
  artifacts; point to Semantics and Research").
- `WorkflowCoder/` has no directory at the repo root as of this audit; its
  old row cites a start_chat not present on disk.
- ChatAnalyst's cited line numbers drifted (tool lines now L83-84).

---

## 3. cortex_path_map.yaml documentation

File: `cortex_path_map.yaml` (repo root; git-ignored per `.gitignore`
entry `cortex_path_map.yaml`). Full content (12 lines, quoted verbatim):

```yaml
maps:
  fit_agent:
    dir: ~/git/workflows/FitAgent
  cortex:
    dir: ~/git/workflows/Cortex
```

- **Maps defined: 2.** `fit_agent` → `~/git/workflows/FitAgent`,
  `cortex` → `~/git/workflows/Cortex`. Both lack `read_only:`, so both are
  read-write maps by default (no `read_only: true` entry exists).
- **No `order:` key** is present, so the default read order applies:
  `[:current, :lib, :user]`, then yaml maps in file order (`fit_agent`,
  `cortex`), then the rest of Scout's base `Path.map_order`.
- **No AGS map is attached** (grep for "AGS"/"ags" in the yaml and repo root
  files: no match).
- **Reachability caveat (observation, not inference):** in this sandbox
  `~/git` does not exist (`ls /home/mvazque2/git` → "No such file or
  directory"; `/home/mvazque2` contains only `software`, `tmp`, `.scout`,
  `.rvm`). So both yaml maps currently point at directories that are not
  visible from here; the suite's agents in this environment see `:current`
  (repo `var/cortex`) and `:lib`, and the yaml maps resolve only where
  `~/git/workflows/*` exists. This is a sandbox-visibility observation, not
  a statement about the developer machine.

Which stores agents can see (per the yaml + read order): repo-local
`var/cortex` (`:current`) first, then `:lib` (chat-anchor store), then
`:user`, then `fit_agent`, then `cortex`.

---

## 4. AGS substrate reachability assessment (Phase 7 gate)

Bounded, read-only probing performed:

| Check | Method | Result |
|---|---|---|
| AGS project dir `/home/mvazque2/git/workflows/AGS` visible? | `ls` via bash | **Not reachable** — `/home/mvazque2/git` does not exist in this sandbox |
| AGS map in `cortex_path_map.yaml`? | read yaml | **No** — only `fit_agent` and `cortex` maps |
| AGS workflows discoverable from here? | grep for AGS in repo root files; `ls /bulk/mvazque2/git/` | **No** — `/bulk/mvazque2/git/` contains only AgentSuite, scout-ai, scout-essentials, scout-gear; no AGS checkout |
| AGS references inside the suite? | `grep -in "ags" cortex_path_map.yaml Planned/workflow.rb FitAgent/README.md` | no matches (exit 1) |

**Verdict: AGS substrate NOT reachable from this environment —
inconclusive on the developer machine, and that is why this gates Phase 7
rather than blocking it.** Evidence: the yaml maps point at `~/git/...`
which is absent here; no AGS checkout exists under the mounted
`/bulk/mvazque2/git/`. The maps were presumably written for the developer
machine where `~/git/workflows/{FitAgent,Cortex}` exist. Phase 7 planning
must therefore (a) confirm AGS visibility on the machine where the pilot
will run, or (b) attach an AGS path map explicitly. Nothing in this
environment can validate AGS tool discovery today.

---

## 5. FitAgent mechanics pinned (Phase 6)

Files read fully: `FitAgent/README.md` (125 lines), `FitAgent/start_chat`
(17 lines), `FitAgent/lib/FitAgent/tasks/use_case.rb` (222 lines) — the
README and code were cross-checked; discrepancies noted below.

### Task surface (from code + README)

- `use_case` (`use_case.rb` L2-168, exported L221): inputs `agents` (path
  to agent definitions), `use_case` (path to use case dir, required),
  `endpoint` (select, hidden), `main_agent` (string, default 'MainAgent'),
  `repo` (path, optional), `repo_mode` (select: copy default / link / git,
  hidden), `exclude` (array, default ['var','.git','tmp']).
- `analyze` (L170-219, exported L221): inputs `instructions`, `experiment`
  (default 'Default'), `endpoint_analyst`; `dep :use_case` (L170).
  Code-comment marked "DEPRECATED (fit-era): superseded by the deterministic
  Scoring.score_scenario rubric path (score task); kept for compatibility
  with existing job references."
- `compare`, `evolve`, `catalogue`, `override`, `score`, `run_arms` in
  `FitAgent/lib/FitAgent/tasks/other.rb` (425 lines; inputs listed L69-73,
  L155-162, L271-273, L292-294, L308-310).

### use_case staging mechanics (code, quoted)

- Repo staging (`use_case.rb` L31-38): `if repo && Open.exists?(repo)` →
  `repo_mode` 'link' symlinks, otherwise (copy) `rsync -a --exclude
  main.chat.files --exclude .git --exclude tmp --exclude etc/AI` into the
  job sandbox (L35). README documents the same exclusions plus `var/`.
- Agent run (L155-156): `CMD.cmd('scout-ai', "agent ask #{main_agent} -c
  main.chat -e #{endpoint} ...")` — the run is a subprocess `scout-ai agent
  ask` inside the staged sandbox.
- Job-path remap (L13-17): a `use_case` input that looks like a previous
  job result is remapped to that job's `.files/sandbox/use_case`, so
  `analyze` can re-run over an existing staged run.
- Endpoints/keys: `etc/AI/<name>` inside the sandbox; keys injected from
  `SCOUT_AI_<NAME>_KEY` env (L74-80; README "Keys are never expected in the
  target repository").

### analyze mechanics

- Loads `LLM.load_agent :ChatAnalyst` (L183), follows `analyze.chat` from
  the use case if present else default criteria, then `analyst.file
  use_case.path` (the report) and points at `main.chat`; the analyst is
  instructed to "Follow any job and agent dependencies that you find to
  explore the entire chat provenance" (L202).
- Verdict format (README + `other.rb` L46-50, L129-133): a fenced
  ```yaml block with `verdict: PASS | PARTIAL | FAIL`, `autonomy: 0-5`, plus
  experiment/rationale; `compare`/`evolve` parse `verdict`/`autonomy` from
  the analysis report.
- **README/code discrepancy:** README says analyze "Accepts `job_use_case:`"
  — no `job_use_case` input exists in code; grep finds it only in README
  text and a historical job `.info` (which shows `input_names:
  ["job_use_case","instructions","experiment","endpoint_analyst"]` — so the
  input existed at fit-era and was renamed/absorbed into the `use_case`
  remap logic). Phase 6 must use current code semantics: pass the previous
  job's *result or .info path* as `use_case`, not a `job_use_case` input.

### Minimal smoke scenario (Phase 6 constraints)

Requirements (README "Deploying FitAgent against another repository" +
observed past-run sandboxes under `FitAgent/var/jobs/FitAgent/use_case/`):

- a use case dir with `main.chat` (blind task; optional `analyze.chat`
  scoring criteria) — one past sandbox stages it at `sandbox/main.chat`
  directly (repo-mode run), not necessarily a nested `use_case/` subdir;
- an agents dir holding `<MainAgent>/start_chat` (default name
  'MainAgent');
- an endpoint resolvable as `etc/AI/<name>` with `SCOUT_AI_<NAME>_KEY` set;
- optional `repo` + `repo_mode copy` (default; per-run rsync snapshot —
  each run re-copies the repo, so keep repos small; `link` leaks writes).
- Scenario authors: the README's deployment recipe implies the repo owner
  (Phase 6 = redesign authors) writes `use_case/<Name>/main.chat` and
  `agents/<Name>/start_chat`; the agent under test never sees the rubric.
- Cost/sandbox constraints: `use_case` runs a full `scout-ai agent ask`
  subprocess per run (real model turns — NOT hermetic); `analyze` adds a
  ChatAnalyst model turn; `compare` multiplies this by arms × repeats.
  Sparse smoke = one use case, one arm, `repo_mode copy` with `exclude`
  defaults, endpoint with cached/cheap keys.

### FitAgent/start_chat (17 lines, quoted key text)

L5-8: "You are the FitAgent agent. / Your role is to evaluate how agents
work and improve their doctrine, tools, and instructions." — it imports
only `Agent/doctrine` (L1), has **no tool:/introduce: lines of its own**,
and its effective Cortex tooling is the doctrine footer's read-only trio
(probe §2). It is an evaluator agent, not an AGS substrate itself.

---

## 6. Context-delivery verification contract (Phase 4)

Purpose: when Phase 4 provisions per-role context (imports, tools,
introductions, options), a probe must be able to capture *what the launched
agent actually received* and diff it against the provisioning table. The
reader-split package already established the technique; this contract
formalizes it for the redesign.

For each agent `<Name>`, a verification probe must capture, as one JSON
record:

1. **Resolved imports** — every `import:` line in `start_chat`, each
   resolved to an absolute file path (e.g. `Agent/doctrine` →
   `<libdir>/Agent/doctrine` or scratch mirror path), plus the resolved
   imports' *own* imports one level deep (doctrine's footer imports
   `Agent/doctrines/advice` — see below). Flag unresolved imports as
   errors (the runtime would raise `Import not found:` per gem
   files.rb L43).
2. **Expanded tool lines** — the effective tool table after import
   expansion and `introduce:`/`tool:` processing: the full list of
   workflow-task tool names (as `Chat.tools` would produce), with the
   cortex_* subset broken out (distinct count vs raw count, to expose
   duplicate-key artifacts the reader-split probes found: e.g. Reader
   13 keys / 10 distinct).
3. **Introductions** — the list of `introduce:` payloads (workflow docs)
   in order, with their source (own start_chat vs imported doc footer).
4. **Options/directives** — every non-message directive line in the
   start_chat (`option:`, `endpoint:`, `attachments:`, `socialize:`,
   `persist:` etc.) with file line numbers, so provisioning drift in these
   is detectable.
5. **Anchor facts** — start_chat line count, byte hash, and the head
   system-role sentence, so the record binds to an exact file version.

Diff discipline: the provisioning table (Phase 4 deliverable) is the
expected side; the probe record is the actual side; any key mismatch is a
provisioning bug, not a probe failure. Re-run after every Phase 2-3 edit.

Provenance pattern to reuse: script under `tmp/` named
`redesign_audit_*` (this audit) / `p4*_effective_tools.rb` (reader-split),
output `.out` saved beside it, both cited from the provisioning table.

**Known import-chain fact pinned during probing (important for Phase 4):**
`doctrine` itself carries `import: Agent/doctrines/advice` (doctrine L222),
and the emptied advice appendix is imported by *every* agent through that
chain — no start_chat imports it directly (grep: 0 direct importers). The
probe run initially failed with `Import not found: Agent/doctrines/advice`
until the scratch mirror included it; any Phase 2 doctrine edit must keep
that chain resolvable.

---

## Open questions needing runtime checks (owner: Phase 5/6/7 planning)

1. Does `tooling_intro` (introductions only) suffice for `Searcher` and
   `Planner` in the AGS route, or do those stages need task tools? — needs
   a `Planned ask` dry-run on the developer machine (model turns).
2. Will `option worker_agent ScientificLead` be honored end-to-end once
   `ScientificLead/` exists, including `socialize: true` inheritance in
   the work stage? — needs the Phase 2 agent dir to exist first.
3. On the developer machine, do the `fit_agent` and `cortex` path maps
   resolve (i.e. does `~/git/workflows/` exist there)? — decides whether
   Phase 7's AGS map can be attached by the same yaml mechanism.
4. Does the FitAgent `score` task (deterministic rubric scoring) fit the
   redesign smoke test better than the deprecated `analyze` model turn?
   — needs a `catalogue` dry run to inspect scenario/rubric format.
5. `WorkflowCoder/` row in the old matrix cites files not on disk; was it
   removed deliberately (no directory at root) or moved elsewhere?
   — git log question for the audit owner, not blocking.

## Files read (evidence base)

`Planned/workflow.rb`; `Planned/README.md` (partial, for corroboration);
`FitAgent/README.md`, `FitAgent/start_chat`,
`FitAgent/lib/FitAgent/tasks/use_case.rb`, `other.rb` (input greps),
`agent_ask.rb`; `cortex_path_map.yaml`; `.gitignore`;
`research/agent-cortex-capabilities.md` (full read pre/post extension);
`var/cortex/artifacts/plans/agentsuite-rollout-spec.md` (head, §1-2);
`doctrine` (footer), `doctrines/advice` (head), `society` (grep-level);
start_chat directive greps for Reader/ChatAnalyst/Research/Worker/Manager/
ScoutCoder/Searcher/User/Visualizer/FitAgent; gem source
scout-ai-2.1.0 `lib/scout/llm/chat/process/files.rb`,
`lib/scout/llm/chat/process/tools.rb`, `lib/scout/llm/agent/workflow.rb`
(bounded, to pin import/tooling mechanics); past-run sandboxes under
`FitAgent/var/jobs/FitAgent/use_case/*.files/sandbox/`.
