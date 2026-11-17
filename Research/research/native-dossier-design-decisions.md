# Native dossier workflow — pinned framework design decisions (D1–D6)

Status: **pinned design authority** for the nine-task native Research workflow
(`dossier_create`, `dossier_list`, `dossier_read`, `dossier_update`,
`evidence_attach`, `evidence_read`, `dossier_check`, `dossier_history`,
`dossier_capture`). Later implementation phases cite this file instead of
re-deriving these conventions. Design-only: no code changed in this dispatch.

Provenance: work order WO-1 (Planned plan step 1 of 12), executed
2026-11-16 by ScoutCoder. All code citations were read in this session from
the installed gems `scout-gear 10.13.1`, `scout-ai 2.1.0`,
`scout-essentials 1.9.3` (under `/home/mvazque2/.rvm/gems/ruby-3.3.1/gems/`)
and from the Research checkout `/bulk/mvazque2/git/AgentSuite/Research`.
Behavioral claims marked **[probe]** were executed live in this session;
the receipt is the command shown. Where documentation and observed behavior
disagree, the discrepancy is recorded, not silently resolved.

Environment caveat that scopes D6 (and part of D4): this role's bash sandbox
sees only `Reader` and `Research` under `/bulk/mvazque2/git/AgentSuite/`, and
`~/.scout/Agent/` contains only `ScoutCoder` and `Workspace`. Claims about
Workspace/Semantics/ScoutCoder/Planned checkouts below come either from
loadable-workflow introspection (`task_code`, `help_workflow`) or are marked
unverified.

---

## D1 — Root configuration and deterministic resolution

**Decision.** The per-consumer research root resolves in this exact order:

1. Explicit per-task input `research_root` (when a task declares one and the
   caller supplies it) — highest precedence, always absolute-path-ified.
2. `Scout::Config.get(:research_root, :workflow, :Research, env: 'SCOUT_RESEARCH_ROOT', default: nil)`.
3. Default fallback: `Scout.var.research.find(:user)` → `~/.scout/var/research`
   (created on first write, never inside the Research installation, never
   relative to any job cwd).

Task results must carry **both** the root-local ID and the resolved absolute
root (e.g. `id: "Q-001", root: "/home/u/.scout/var/research"`) so identical
IDs from different roots cannot be conflated.

**Citations.**
- Config mechanism: `scout-essentials-1.9.3/lib/scout/config.rb` —
  `load_file` (lines ~23–31: `key, value, *tokens = line.strip.split(/\s+/)`,
  so the file line format is `research_root <path> workflow::Research`);
  `load_config` (lines ~33–37: `Path.setup("etc").config.find_all.reverse.each`,
  i.e. config files are collected from **all** `etc/config` candidates —
  cwd-relative `etc/config` first in map order, loaded **last**, hence wins);
  `get` (lines ~95–153: explicit `env:` list overrides the default; among
  cache entries the best token-priority match wins; `default` fallthrough).
  Verified **[probe]**: from cwd `/tmp/cfgprobe2` with
  `etc/config` containing `research_root /tmp/cfgprobe2/research-base workflow::Research`,
  `Scout::Config.get(:research_root, :workflow, :Research, default: "MISSING")`
  → `/tmp/cfgprobe2/research-base`. With the same entry **unscoped**, the
  scoped query returned `MISSING` — the `workflow::Research` scope token is
  required for the scoped lookup to match. From `/tmp` with
  `HOME=/tmp/cfgprobe2/home` and the scoped line in
  `/tmp/cfgprobe2/home/.scout/etc/config`, the query resolved to the
  user-map value — user-map `~/.scout/etc/config` works from any cwd.
  With both present, the cwd `etc/config` value won (project-local shadows
  user-global — Scout's designed precedence, keep it, but see caveat below).
  `SCOUT_RESEARCH_ROOT=... env:` form → env value wins **[probe]**.
- Default fallback: `Scout.var` is a `Path` whose `map_order` is
  `[:current, :user, :home, ...]` (**[probe]** `Scout.var.map_order`), and
  `Path#find` (`scout-essentials-1.9.3/lib/scout/path/find.rb:247–273`)
  iterates `map_order` when no map name is given, returning the first
  existing candidate; `find(:user)` bypasses the order via `follow(:user)`
  with map string `{HOME}/.{PKGDIR}/{TOPLEVEL}/{SUBPATH}`
  (**[probe]** `Path.path_maps[:user]`). Hazard proven **[probe]**: with a
  local `var/` present, `Scout.var.find` from `/tmp/varprobe` returned
  `/tmp/varprobe/var` (cwd shadowing), while `Scout.var.research.find(:user)`
  returned `/home/mvazque2/.scout/var/research` from every cwd tested
  (`/tmp`, `/tmp/varprobe`, the Research checkout). Therefore the fallback
  **must pin `:user` explicitly**; the map-order default is the rejected
  alternative precisely because it is cwd-sensitive.
- Current root derivation being replaced: `lib/Research/path_kinds/records.rb`
  derives `PATH_KIND_ROOT` from `Scout.root` (`Scout.root.find(:current)`,
  which **[probe]** returned `/bulk/.../Research/` from the checkout but
  `/tmp/` from `/tmp`) — the cwd/installation-relative hazard this decision
  eliminates.

**Rejected alternatives.**
- *Bare `Scout.var.research.find` (map-order default)*: cwd-shadowing proven
  above; a consumer running from any directory with a local `var/` would
  silently get a different root.
- *Per-task input as the only source*: no stable default → the effective root
  would depend on every caller's discipline; contradicts "deterministic in
  jobs".
- *Registering a global path map* (e.g. `Path.path_maps[:research_root]`):
  mutates process-global state for all workflows loaded in the same process
  (agent processes load several), with no scoping; config+`:user` fallback
  achieves the same determinism without cross-workflow interference.
- *Root inside the Research installation*: rejected by the work order and by
  the preservation constraint (installations are code, not user data).

**Impact on later phases.** Storage layer takes a resolved-root parameter
from a single helper (`Research.roots.resolve(inputs)` style) used by all
nine tasks; scaffold phase creates the root layout under the resolved root;
`dossier_list`/`dossier_read` etc. echo `root` in every result; the docs
phase documents the config key, env var and default. **Caveat to carry into
docs**: because config is read from every `etc/config` candidate, a consumer
cwd containing `etc/config` with an unscoped or `workflow::Research`-scoped
`research_root` line will shadow `~/.scout/etc/config`. The Research
installation itself must therefore never ship an `etc/config` defining
`research_root`.

---

## D2 — Stateful-task dispatch semantics (exec, not cached jobs)

**Decision.** All nine tasks are declared `export_exec` (exec mode). None of
the nine relies on job persistence or Scout's result cache for correctness:
- mutation tasks are **idempotent-or-reject at the record level** (duplicate
  ID → reject with the existing record's address; version/base mismatch →
  reject with current version; attach dedup by content digest);
- read tasks re-read live state every call (they are cheap file reads);
- **citation-grade addresses are record paths + digests under the research
  root, not job paths.** Only incidental job trees that do exist may be
  cited, and exec dispatch creates none (below), so the reference contract
  (port of `research/return-path-citation-contract.md` C1–C5, R6–R14) must
  treat dossier evidence addresses as `file:` refs with recorded digests.

**Retry story (create/attach when execution succeeds but the response is
lost).** The contract is **at-least-once dispatch with idempotent effect**,
not exactly-once execution: a retried `dossier_create` for the same slug/ID
either returns the already-created record (stable address derived from ID,
not from execution count) or is rejected as a duplicate with that address;
retried `evidence_attach` dedups by content digest within the dossier. The
record-level guards from `records.rb` (version-vs-sidecar optimistic
concurrency, `Open.lock`-serialized ID allocation) provide the serialize
point. We do **not** claim exactly-once semantics anywhere.

**Citations.**
- Exec dispatch path: `export_exec` is an alias of `export` with exec
  semantics (`scout-gear-10.13.1/lib/scout/workflow/definition.rb:229`
  `alias export_exec export`; `scout-gear-10.13.1/lib/scout/workflow/export.rb`
  registers into the exec export list). The agent tool layer dispatches on
  membership: `scout-ai-2.1.0/lib/scout/llm/tools/workflow.rb:84`
  (`if not workflow.exec_exports.include?(task_name.to_sym)`) and line 148
  (`workflow.exec_exports.include?(task_name.to_sym) || exec_type.to_s == 'exec'`
  → exec branch), with `workflow_tools` enumerating `workflow.all_exports`
  (line ~118–127) so exec tasks are exposed as agent tools.
- `Step#exec` (`scout-gear-10.13.1/lib/scout/workflow/step.rb` ~118–150):
  runs the task block directly; **no job directory is created, no result is
  persisted** — this is what makes repeated identical mutation calls
  *perform* rather than replay a stale receipt.
- Cached-job hazard on the non-exec path: `Step#run` → job persistence; the
  done-branch replays a previously persisted result when the same inputs
  recur, and code changes do not invalidate it
  (`scout-gear user/CachingData.md`; also quoted in
  `research/return-path-citation-contract.md` §5: "two calls with the same
  identifier and completely different blocks resolve to the same path").
- Persistence asymmetry verified on disk **[probe]**: non-exec jobs persist
  under `~/.scout/var/jobs/<Workflow>/<task>/` — `ScoutCoder/help_list_repos/`
  contains `Default` + `Default.info` (result + info sidecar, a citable
  durable address); `Planned/{request,search,plan,work,ask}/` likewise. No
  job trees exist for exec-exported tasks (`run_probe`, `run_test`), matching
  the earlier session probes that exec mode creates no persisted job tree.
- In-suite precedent: Semantics uses `export_exec` for stateful dispatch
  (work-order header; its task surface observed via loadable introspection —
  `task_code` on `Semantics/observe` listed the workflow's available tasks,
  confirming the workflow loads and exposes `entity_*` tasks; the checkout
  itself is not readable from this role's sandbox, so the `export_exec` line
  in Semantics source is cited from the work order, not re-read).

**Rejected alternatives.**
- *Plain (cached) tasks for the nine*: identical repeated mutation inputs
  would replay the first receipt while record state moved on — the exact
  stateful hazard; also reads (`dossier_read`) of mutable records would
  serve stale cached content after a `dossier_update`.
- *Cached tasks + `clean: true` discipline*: pushes correctness onto every
  caller; one forgotten flag silently corrupts the epistemic record.
- *Claiming exactly-once via job digests*: nothing in the exec path
  guarantees single delivery; rejected as unsupported.

**Impact on later phases.** Task-definition phase declares all nine with
`export_exec` inside each task block (in-task DSL, per `definition.rb:222–230`);
the semantics phase ports C1–C5/R6–R14 to `dossier_check` with `file:`-style
refs + digests; `dossier_capture` returns record addresses (path + digest),
never job paths; the walkthrough must include a lost-response retry case for
`dossier_create` and `evidence_attach` demonstrating idempotent-or-reject.

---

## D3 — Skills discovery convention

**Decision.** Research ships skills as `skills/<name>/SKILL.md` at the
checkout root (deployed under the agent's chat directory, i.e.
`~/.scout/Agent/Research/skills/<name>/SKILL.md`), with YAML front matter
`name:` and `description:` (including a `Triggers:` line, matching the two
live installs inspected). The `.skills` spelling from the original request is
**not supported by scout-ai 2.1.0** and is rejected.

**Citations.**
- Loader: `scout-ai-2.1.0/lib/scout/llm/chat/process/tools.rb`
  `introduce_workflow` (~lines 215–262, read earlier this session): after
  introducing a workflow it globs the workflow's **libdir** for
  `skills/*` directories and lists each `skills/<name>/SKILL.md`. This is
  the only file in scout-ai 2.1.0 mentioning "skills" **[probe]**
  (`grep -rln "skills" …/scout-ai-2.1.0/lib/` → exactly that one file), so
  no alternate spelling exists in the running version.
- Libdir resolution: `Path#libdir` falls back to
  `Path.caller_lib_dir` (`scout-essentials-1.9.3/lib/scout/path.rb:23–24`),
  which climbs from the calling file to the nearest directory containing a
  marker (`lib`, `bin`, `README.md`; `scout-essentials-1.9.3/lib/scout/path/find.rb:24–49`)
  — for a checkout/agent dir this is the directory that contains `lib/`,
  i.e. the checkout root. Skills therefore live beside `lib/`, at the root.
- Live instances **[probe]**: `~/.scout/Agent/Workspace/skills/workspace-tsv/SKILL.md`,
  `~/.scout/Agent/ScoutCoder/skills/scoutcoder-help-discovery/SKILL.md`
  (front matter `name:` + `description:` with `Triggers:`), and sibling
  checkout `/bulk/mvazque2/git/AgentSuite/Reader/skills/reader-doc-acquisition/SKILL.md`
  (77 lines, no Research dependency — grep for `Research|PATH_KINDS|path_kind`
  returned nothing).

**Rejected alternatives.** `skills/Research.skills/<name>/SKILL.md` and any
`.skills` variant: no loading code reads them in scout-ai 2.1.0; they would
be silently undiscoverable.

**Impact on later phases.** The skills phase creates exactly
`skills/<name>/SKILL.md` per skill (three skills per the mission arc); the
walkthrough must verify the skill is actually listed by an
`introduce: Research` consumer context, since discovery depends on the
deployed agent dir, not the checkout.

---

## D4 — Workspace require/helper merge in workflow.rb

**Decision.** After `path_kinds` removal, workflow.rb **drops** the
`Workspace` require and the helper merge: the surviving record engine code
uses no Workspace helpers, and each of the nine tasks is self-contained
(plain Scout/Open/FileUtils operations). The new workflow.rb is:
`require 'scout'` (+ `scout-ai` if the task layer needs it — verify at
implementation time), `extend Workflow`, `require_relative` of the new
lib files. `test/Research/tasks/test_registration.rb` is replaced to assert:
(i) `Research.tasks` includes exactly the nine task names;
(ii) `defined?(Research::PATH_KINDS).nil?`;
(iii) loading Research alone leaves `Workflow.workflows` free of `Workspace`
(i.e. no transitive load), so the unsandboxed-test constraint from the
sibling require disappears for the new suite.

**Citations.**
- Current state: `workflow.rb` (13 lines) requires scout + scout-ai, loads
  sibling Workspace, extends Workflow, merges Workspace helpers, ends with
  `require_relative 'lib/Research/path_kinds'` (work-order header; re-read
  this session).
- No helper dependency: `grep -rn "cmd_json\|helpers" lib/Research/path_kinds/`
  → no matches **[probe]**; the only "helpers" hit in the test tree is a
  comment header in `test/Research/path_kinds/test_return_path_citation.rb:60`.
  The records engine's actual dependencies are Scout/Open primitives:
  `Open.sensible_write` (`scout-essentials-1.9.3/lib/scout/open/stream.rb:92`,
  tmp+rename atomic write) and `Open.lock`
  (`scout-essentials-1.9.3/lib/scout/open/lock.rb:15`) — both from
  scout-essentials, not Workspace **[probe]** `Open.method(...).source_location`.
- Why dropping is safe for consumers: the Research agent's `start_chat`
  introduces Workspace independently (`start_chat` line 73 `introduce: Workspace`;
  lines 90–94 `introduce: Research`, `tool: Research`, `path_kind: Research`),
  so no consumer depends on Research transitively loading Workspace.
- Resolution mechanics that made the sibling require fragile (context, not a
  blocker): `Workflow.require_workflow`
  (`scout-gear-10.13.1/lib/scout/workflow.rb:124–180`) locates a workflow by
  literal path → `workflows` pathmap (`~/.scout/workflows` **[probe]**
  `Scout.workflows.find`) → snake/camel variants → `./workflow.rb` only when
  cwd basename humanizes to the workflow name; a sibling-filesystem require
  works only from the suite layout, which is exactly why tests loading
  Research's workflow.rb needed the unsandboxed runner (verified sandbox fact
  in the work-order header; `~/.scout/Agent` is invisible to sandboxed
  children).

**Rejected alternatives.**
- *Keep the Workspace require "for safety"*: preserves a hidden coupling and
  the unsandboxed-test constraint for no consumer; if a future task needs a
  Workspace helper, it can require it explicitly at that point.
- *Keep helpers merged but drop the require*: incoherent (merge target would
  not exist).

**Impact on later phases.** workflow.rb rewrite phase implements the minimal
form; test phase rewrites `test_registration.rb` as above; docs phase updates
README lines 22–24 (`README.md` currently points at
`research/path-kinds-spec.md` and `lib/Research/path_kinds/`) and the
`doc/{user,developer}/README.md` `path_kind` mentions.

---

## D5 — Test runner surface

**Decision.** The suite runs through the **`run_test` path-kind tool**
(`test_file` kind): fresh unsandboxed process per file, each loading the
owning checkout's `workflow.rb` first; files live under
`test/Research/<area>/test_*.rb` in `test/unit` style with the existing
minimal `test/test_helper.rb` (requires `test/unit`, unshifts `lib` and
`test` onto `$LOAD_PATH` — re-read this session). Full-suite runs use suite
scope (`.`); single files use file scope. Probes needing framework
introspection use `run_probe` (`probe` kind), unsandboxed.

**Citations.**
- Runner contract: ScoutCoder `run_test`/`run_probe` tool descriptions
  (fresh child process per file; Ruby children preload the owning checkout's
  `workflow.rb`; "Execution is unsandboxed"); the unsandboxed requirement is
  the verified sandbox fact (`~/.scout/Agent` invisible in bwrap children —
  Searcher, first-hand, artifact `research/sandbox-symlink-visibility-scout-agent.md`).
- No Rakefile exists in the Research checkout **[probe]** (`ls` top level:
  no `Rakefile`, no `Gemfile*`), so rake-based surfaces are not available
  today; `test/test_helper.rb` is the only shared harness.
- Precedent in this session: the design-evidence test ran through the
  `test_file` kind (`design/design_evidence`), producing
  `tmp/design_evidence.json`; probes ran through `run_probe`.

**Rejected alternatives.** Sandboxed `bash ruby -Ilib test/...`: fails on
the verified sibling/`~/.scout/Agent` visibility constraint; building a
Rakefile now: adds surface no phase needs (run_test already gives per-file
processes and suite scope).

**Impact on later phases.** Every implementation phase lands tests as
`test_file`-kind files and runs them via `run_test`; the walkthrough phase
runs the suite scope; the implementation report cites run receipts
(passed/ran counts), not just green statements.

---

## D6 — External dependents of Research::PATH_KINDS

**Decision (inventory + retirement scope).** The only real dependents of
`Research::PATH_KINDS` are: (a) the framework consumer
`scout-ai`'s `integrate_workflow_path_kinds`
(`scout-ai-2.1.0/lib/scout/llm/agent/path/workflow_kinds.rb` ~lines 20–60:
reads `workflow::PATH_KINDS` and registers one agent tool per kind), gated by
`path_kind:` lines in `start_chat` (`scout-ai-2.1.0/lib/scout/llm/agent.rb`
~145–200); (b) Research's own surfaces: `start_chat` line 94
(`path_kind: Research`), `README.md` lines 22–24, `doc/developer/README.md`
and `doc/user/README.md` (`path_kind` mentions), and the retired test tree
(`test/Research/path_kinds/` — 8 files — plus
`test/Research/tasks/test_registration.rb` asserting `PATH_KINDS` present);
(c) process artifacts of this mission itself (the Planned plan transcript at
`/home/mvazque2/.scout/var/jobs/Planned/plan/Default_43c5d955fa958bd6586e2fbaa8a260b3.chat.files`,
verified to exist). Retirement must therefore touch: `start_chat` (remove
line 94, keep `tool: Research`), README + doc mentions, and the test tree —
all already scheduled in later phases. The framework consumer degrades
gracefully: it consumes `PATH_KINDS` only when defined, but leaving the
`path_kind:` line would be dead configuration and must go.

**Verified this session [probe]:**
- Sibling sweep on the readable mount: `/bulk/mvazque2/git/AgentSuite/`
  exposes only `Reader` and `Research` to this role's bash; Reader's
  readable content (`skills/reader-doc-acquisition/SKILL.md`) contains no
  `Research`/`PATH_KINDS`/`path_kind` reference.
- Installed-agent sweep: `~/.scout/Agent/` contains only `ScoutCoder` and
  `Workspace`; recursive grep for `path_kind: *Research|PATH_KINDS` over that
  tree → no matches.
- Loadable-workflow introspection: `task_code` on `Semantics/observe`
  resolved the ScoutCoder checkout and listed Semantics' tasks
  (`entity_list_property`, `entity_property`, `list_entities`) — Semantics
  does not reference Research kinds in its task surface.

**Could NOT verify (stated exactly):** the `Workspace`, `Semantics`,
`ScoutCoder` and `Planned` checkout sources and start_chats (invisible to
this role's bash mount); the deployed Research agent directory (no
`~/.scout/Agent/Research` exists from this vantage — the checkout
`start_chat` is the editable source of truth); and any start_chat/config of
other suite repos. Smallest unblocking change if a later phase needs
certainty here: run the same recursive grep through a role/runner with the
full suite mount (e.g. an unsandboxed probe owned by a checkout that can see
them, or Manager-side grep), or have each sibling owner confirm by reading
their own `start_chat`.

**Impact on later phases.** The retired-interface removal phase deletes
`lib/Research/path_kinds*` + `test/Research/path_kinds/` and rewrites
`test_registration.rb` (D4); the docs/start_chat phase handles (b)'s text
surfaces. No sibling-code coordination is evidenced as necessary; if D6's
unverified set must be closed first, that is a Manager decision, not an
implementation default.

---

## Preservation facts (for the removal phase)

- No `var/records` user data exists in the Research checkout **[probe]**
  (`var/` holds only `cortex/` and `records-attachments/`).
- User-global: `~/.scout/var/` holds only `jobs/` (Planned, ScoutCoder);
  no research record roots anywhere under `~/.scout` **[probe]**.
- The only record-root-like tree found, `/tmp/h011_repro520261025-3484847-yvnebc/research_base/var/records/hypothesis/history`,
  is an **empty** history directory from an old test scaffold (mtime Oct 25)
  — no data to preserve **[probe]**.
- The five historical design notes under `research/` (incl.
`return-path-citation-contract.md`, whose §5 digest semantics and C1–C5/R6–R14
rules this design ports) stay in place; a later phase marks them historical.

## Blockers

None. Every decision D1–D6 is pinned with citations. The one open item is
D6's unverified sibling set (stated above with the smallest unblocking
change); it does not block implementation because no dependent was found on
any readable surface, and the retirement phase's blast radius is confined to
Research's own files plus the framework consumer's graceful no-op.
