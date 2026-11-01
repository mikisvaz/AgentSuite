# Redesign Phase 0 — shared-doc inventory & import/naming policy (packet B)

Date: 2026-11-01. Packet: B (shared-doc inventory, import/naming policy,
recommendations for the five planned shared documents). Read-only audit;
only sanctioned write: this file (scratch under `tmp/redesign_audit_b_*`).
Suite root: `/bulk/mvazque2/git/AgentSuite` (= `/home/mvazque2/git/AgentSuite`),
branch `ags-redesign`, HEAD `1116c9a`.
Predecessor: `new_doctrine/work/redesign-audit-context.md` (packet A) —
read first, not redone here.

Evidence basis (commands in §7): full reads of the four shared files; grep
of all 17 `start_chat` files for `import:` lines (machine map in
`tmp/redesign_audit_b_importer_map.rb` / `.out`); four hermetic probes
(`tmp/redesign_audit_b_chain_probe.rb`, `_depth3_`, `_dedup_`, `_cycle_`,
`_nested_`, `_resolution_probe.rb`) driving `Chat.imports` /
`Chat.find_file` directly (no model turns); content-marker counts on a real
persisted Planned `work` chat
(`/home/mvazque2/.scout/var/jobs/Planned/work/Default_a8a505ef95d0e1de3824559e0c712f36.chat.files/Manager.chat`).

---

## 1. Shared-doc inventory

Suite-root shared files (all git-tracked, verified by `git ls-files`):
`doctrine`, `doctrines/advice`, `society`, `scout`. Sizes via `wc -l`/`wc -c`.

### 1.1 `doctrine` — universal agent doctrine

- **Size/structure:** 233 lines / 12,201 bytes. `system:` role; sections
  `# Agent doctrine` + `## 1. Classify and scale` … `## 8. User override`,
  `## 9. Blockers`, then `# Appendices` (emptied pointer), then footer.
- **Footer is special (L222-233):** it is a chat-file fragment carrying
  directives, not prose only:
  - L222 `import: Agent/doctrines/advice` (chains the appendix into every
    agent; 0 direct importers — packet A §6 pinned this).
  - L229 `introduce: Cortex`, L231-233 `tool: Cortex cortex_list` /
    `cortex_search` / `cortex_read` — a read-only Cortex trio.
- **Importers:** 16 of 17 start_chats (all except `Clean`), always line 1,
  always spelled `import: Agent/doctrine`. Effective reach: 17 of 17 agents
  in practice (`Clean` is the null control agent).
- **What a new agent must inherit:** everything — role-agnostic process law
  (classification, evidence, persistence, delegation, invariants), plus the
  Cortex read-only trio as its *only* Cortex tooling unless the start_chat
  adds more.
- **What a new agent should not inherit:** role content. Nothing
  role-specific belongs here; `doctrine` is the universal layer and is
  imported by everyone, including evaluation agents (FitAgent) and the null
  agent (Basic).

### 1.2 `doctrines/advice` — emptied transition pointer

- **Size/structure:** 39 lines / 1,622 bytes. `system:` role; single section
  `# Advice appendix (pointer)` stating its generic content moved to the new
  doctrine and its Scout-specific content is scheduled to move into the
  ScoutCoder start_chat; retains one unit-test placement convention pending
  that move. Explicit "Do not add new advice here."
- **Importers:** 0 direct. Effective reach = all 16 doctrine importers via
  the doctrine footer chain (validated: the real Manager chat contains the
  appendix body exactly once — `test_helper.rb` marker count = 1).
- **Must inherit:** nothing of substance; it is a placeholder whose only
  live payload is the test-file placement convention.
- **Should not:** be imported directly by any start_chat (would duplicate it
  for agents that also import doctrine — no dedup, see §4/check 3); be
  extended (the file forbids it); be deleted before its two pointer duties
  are relocated (test convention → ScoutCoder start_chat), because the
  doctrine footer import would then fail at load time with
  `Import not found: Agent/doctrines/advice` (packet A saw exactly this).

### 1.3 `society` — the roster / delegation map

- **Size/structure:** 144 lines / 6,954 bytes. `system:` role; intro
  ("not exhaustive… agents may exist outside it"), `# Conversational agents`
  with `## <Agent>` sections, `# Inference workflows` with `## Planned`.
- **Importers:** 5 — `Cortex`, `Manager`, `Planner`, `Research`, `User`
  (line 1 or 2). Doctrine references it (`the society import says who else
  can take work`) but does not import it.
- **Must inherit:** roles that decide who does what (Manager, Planner), the
  liaison/reporting role (User), and conversation-orchestrating roles
  (Cortex, Research).
- **Should not:** leaf executors and specialists do not import it today
  (Worker, Reader, ScoutCoder, Searcher, Critic, Visualizer, Consultant,
  FitAgent, Basic, ChatAnalyst, Clean). Note the small inconsistency that
  doctrine mentions the society import to all agents while 11 agents lack
  it — treat "delegation-capable ⇒ import society" as the rule, and do not
  add society to pure executors in Phase 2 without a reason.

### 1.4 `scout` — Scout-stack vocabulary

- **Size/structure:** 389 lines / 25,060 bytes (the largest shared doc).
  No `system:` role marker line of its own header form seen in grep of
  directives (it carries none — pure prose), sections `## 0. How to reason
  about Scout` onward.
- **Importers:** 1 — `ScoutCoder` (line 2).
- **Must inherit:** roles that build or debug Scout workflows/gems.
- **Should not:** domain, science, and reporting roles — 25 KB of stack
  vocabulary is the single most expensive optional context in the suite;
  importing it into the five planned science/collaboration readers would be
  the worst context-budget regression available.

### 1.5 Distribution mechanisms (not import locations)

- `chats` → symlink at repo root to `/home/mvazque2/chats/AgentSuite/`
  (host chat store; **not visible inside this sandbox** — see check 1).
- `bin/bundle_doctrine.sh` (untracked) copies `doctrine scout society` into
  `doctrine_bundle/` plus each `<Agent>/start_chat` and `README.md` — a
  packaging step for sharing the suite's context elsewhere; it does **not**
  know about `doctrines/` or any new file.
- `doctrine_bundle/` (untracked) is the output of that script.

---

## 2. Importer map (all 17 start_chats, machine-generated)

Source: `tmp/redesign_audit_b_importer_map.rb` → `tmp/redesign_audit_b_importer_map.out`.
Every import line in the suite uses exactly the `Agent/<name>` spelling; no
bare/relative import lines exist in any start_chat.

| Agent | Imports |
|---|---|
| Basic | Agent/doctrine |
| ChatAnalyst | Agent/doctrine |
| Clean | — (no imports) |
| ComputerUse | Agent/doctrine |
| Consultant | Agent/doctrine |
| Cortex | Agent/doctrine, Agent/society |
| Critic | Agent/doctrine |
| FitAgent | Agent/doctrine |
| Manager | Agent/doctrine, Agent/society |
| Planner | Agent/doctrine, Agent/society |
| Reader | Agent/doctrine |
| Research | Agent/doctrine, Agent/society |
| ScoutCoder | Agent/doctrine, Agent/scout |
| Searcher | Agent/doctrine |
| User | Agent/doctrine, Agent/society |
| Visualizer | Agent/doctrine |
| Worker | Agent/doctrine |

Summary counts: `Agent/doctrine` 16 direct importers; `Agent/society` 5;
`Agent/scout` 1; `Agent/doctrines/advice` 0 direct (16 effective, via the
doctrine footer). One agent (Clean) imports nothing.

---

## 3. Import & naming policy for new shared docs

Mechanism (pinned in packet A, re-validated here against
`scout-ai-2.1.0/lib/scout/llm/chat/process/files.rb` and
`lib/scout/llm/chat.rb`):

- `Chat.imports` resolves each `import:` target through `Chat.find_file`:
  (i) relative to the importing file's directory, (ii) via the chats path
  map `Scout.chats[<file>]` = `<libdir>/chats/<file>` where `<libdir>` is
  the chat anchor (`SCOUT_CHAT_DIR`, set from `Path.caller_lib_dir(<chat
  file>)` — validated to be the suite root for `Worker/start_chat`), (iii)
  as given. Failure raises `Import not found: <file>` (validated).
- In this suite `<root>/chats` is a symlink into the host store
  `/home/mvazque2/chats/AgentSuite/`, so the live namespace for shared docs
  is that store's `Agent/` subtree; the repo-root files (`doctrine`,
  `doctrines/advice`, `society`, `scout`) are the tracked sources that must
  be present there. A real Planned `work` run resolves all four (validated
  by content markers: doctrine §3 heading ×1, society heading ×1, advice
  `test_helper.rb` ×1).

**Policy (2-3 sentences):** New shared documents live as extension-less
files in the repo root's `doctrines/` namespace (`doctrines/<name>`) and are
imported by start_chats only through the canonical chats-store spelling
`import: Agent/doctrines/<name>` — never bare/relative paths, which no
current start_chat uses and which resolve against CWD and therefore break
under job sandboxes and staged repos. Keep chains one level deep
(start_chat → shared doc; at most shared doc → shared doc, as
`doctrine → doctrines/advice` does today): the mechanism happily resolves
deeper chains (validated: 3 levels) but has no cycle guard (validated:
cycles and self-imports raise `SystemStackError`) and no dedup (validated:
the same doc imported twice appears twice). The repo root stays reserved
for the universal trio plus the roster (`doctrine`, `doctrines/advice`,
`society`, `scout`); only a document every agent needs belongs there.
Directives in shared docs are dangerous: any `tool:`/`introduce:` line in a
shared doc becomes part of every importer's effective tool surface (the
doctrine footer's read-only Cortex trio is live evidence — packet A §2
matrix), so only `doctrine` may carry them, by explicit design.

---

## 4. Recommendations for the five planned shared documents

All five are role-scoped, not universal → all five go under `doctrines/`.
Sizes should stay society-scale (~150 lines / ≤8 KB), never scout-scale.

| # | Planned doc | File (repo root) | Import spelling | Intended importers (one sentence) |
|---|---|---|---|---|
| 1 | Agent Collaboration guide | `doctrines/collaboration` | `import: Agent/doctrines/collaboration` | Every role that hands work to or receives work from another agent — Manager, Planner, User, Worker, Critic — imports it; pure producers (Visualizer, Clean, Basic) do not. |
| 2 | Scientific Investigation guide | `doctrines/investigation` | `import: Agent/doctrines/investigation` | The scientific executors and reviewers — Research, Searcher, Reader, Critic — import it; it defines how an investigation is run, split, and closed. |
| 3 | Scientific Discipline guide | `doctrines/discipline` | `import: Agent/doctrines/discipline` | Domain-facing roles — Research, Consultant, Critic — import it for field methodology and standards; it is the layer above the investigation guide. |
| 4 | Context/handoff contract | `doctrines/handoff` | `import: Agent/doctrines/handoff` | Delegation endpoints — Manager, Planner, User, Worker — import it so every packet they send or accept has the same objective/artifacts/constraints/output shape. |
| 5 | Scientific capability-catalogue format | `doctrines/catalogue` | `import: Agent/doctrines/catalogue` | Catalogue authors and readers — Research, Reader, Consultant — import it to produce and consume capability catalogues in one format. |

Deliberate choices, reconciled with packet A:

- **`doctrines/` over root:** both are mechanically legal (root precedent:
  `society`, `scout`), but root is reserved for the universal trio + roster
  per §3; the five are all optional by role.
- **One word, lowercase, no extension:** matches `advice`; hyphens are legal
  but the existing convention (`doctrine`, `society`, `scout`, `advice`) is
  single lowercase words.
- **No `tool:`/`introduce:` lines in any of the five:** tool provisioning
  stays per-start_chat (and doctrine's footer), keeping the Phase 4
  effective-tools matrix a function of start_chat + doctrine only.
- **Cross-imports among the five:** allowed one level deep (e.g.
  `discipline` → `investigation`) but prefer none; if two docs need the same
  content, start_chats import both — no dedup exists, so shared-of-shared
  imports silently duplicate text for agents importing both parents.
- **If `doctrines/advice` is retired in Phase 2**, its test-placement
  convention moves to the ScoutCoder start_chat first, then the doctrine
  footer import line is removed in the same edit — the import must never
  dangle (load-time failure, validated).

---

## 5. Behaviors needing runtime checks before Phase 2 edits

Validated here (hermetic, `Chat.imports`/`Chat.find_file` direct) unless
marked *developer-machine*:

1. **Host chats-store layout & sync (developer-machine).** The import
   namespace is `<libdir>/chats/Agent/...`, and `<root>/chats` is a symlink
   to `/home/mvazque2/chats/AgentSuite/`, which is **not mounted inside the
   exec sandbox** (`ls /home/mvazque2/chats` fails in bwrap while
   `/home/mvazque2/.scout` is readable). Before Phase 2: confirm on the host
   that the store mirrors `Agent/doctrine`, `Agent/doctrines/advice`,
   `Agent/society`, `Agent/scout` from the repo-root sources, and identify
   the sync step (manual copy? `bin/bundle_doctrine.sh`?) that new
   `doctrines/<name>` files must go through — otherwise every Phase 2
   start_chat edit fails at load with `Import not found`.
2. **Chain depth is unbounded, convention only.** Validated: a 3-level
   chain resolves fully. The "one-level-deep" rule in packet A is project
   convention, not a mechanism limit; Phase 2 should either keep the
   convention documented in the policy doc or add a lint (grep imports of
   shared docs for depth > 1).
3. **No dedup on repeated imports.** Validated: importing a doc twice
   (directly + via another doc) yields the body twice. Matters immediately
   for §4's cross-import caveat and for any start_chat that imports both
   `doctrine` and a new doc that itself imports `doctrines/handoff`.
4. **No cycle guard.** Validated: an import cycle and a self-import both
   raise `SystemStackError` at load. A lint over shared docs' import lines
   (small graph, 4 + 5 nodes) is cheap insurance.
5. **Failure mode is load-time `Import not found: <file>`** (validated,
   including for nested `Agent/doctrines/<sub>/<name>` spellings). Phase 2
   must add the five files to the store *before* any start_chat references
   them; packet A's Phase 4 verification contract (resolved-imports check)
   already covers this — extend its expected side with the five names.
6. **Exec-sandbox import resolution.** Validated indirectly: any Phase 2
   probe that resolves imports from inside a job sandbox must mirror the
   `Agent/` tree into scratch first (pattern already in
   `tmp/redesign_audit_chats/` and packet A's mirror) because the host
   store is unreachable there.
7. **Directive leakage from shared docs.** Any `tool:`/`introduce:`/
   `option:`/`continue:`/`last:` line inside a shared doc is processed like
   one in a start_chat (`files.rb` L40 handles `import`, `continue`, `last`
   together; tool lines resolve through the same message stream — the
   doctrine footer trio is live proof). Phase 2 authors of the five docs
   must keep them prose-only; the Phase 4 matrix probe
   (`tmp/redesign_audit_matrix_probe.rb`) will catch violations as
   unexpected effective-tool deltas.
8. **`bin/bundle_doctrine.sh` does not know `doctrines/`.** It copies only
   `doctrine scout society`; update it (add `doctrines/`) or retire it when
   the five land, or bundles will ship an incomplete context.

---

## 6. Context-budget snapshot (for Phase 4 planning)

Worst-case shared payload per agent today: doctrine 12,201 B + advice
1,622 B + society 6,954 B + scout 25,060 B ≈ 45.8 KB before any role text
(only ScoutCoder reaches the full stack). After the five land at the
recommended society-scale budget, an agent importing doctrine + advice +
two new guides stays under ~30 KB shared. Keep `scout` out of every
non-stack role.

---

## 7. Evidence & reproducibility

Scripts (hermetic, no model turns; run from suite root with
`ruby tmp/<script>`):

- `tmp/redesign_audit_b_importer_map.rb` → `tmp/redesign_audit_b_importer_map.out`
  (agent → import lines, counts; §2).
- `tmp/redesign_audit_b_chain_probe.rb` (chain resolution, leftover
  unresolved imports, `Import not found` shape).
- `tmp/redesign_audit_b_depth3_probe.rb` (3-level chain resolves).
- `tmp/redesign_audit_b_dedup_probe.rb` (no dedup: body ×2 when imported twice).
- `tmp/redesign_audit_b_cycle_probe.rb` (cycle + self-import → `SystemStackError`).
- `tmp/redesign_audit_b_nested_probe.rb` (two-component nested path under
  `doctrines/` resolves and chains; missing nested path → `Import not found`).
- `tmp/redesign_audit_b_resolution_probe.rb` (`caller_lib_dir(Worker/start_chat)`
  = suite root; bare `doctrines/advice` resolves against CWD/libdir;
  `Scout.chats[...]` path forms).

Framework reads (bounded, mechanism only):
`scout-ai-2.1.0/lib/scout/llm/chat/process/files.rb` (`imports`, `find_file`,
L18-62), `lib/scout/llm/chat.rb` (L30-51, `SCOUT_CHAT_DIR` anchor),
`lib/scout/llm/agent.rb` (L249-265, agent path search order).

Real-run cross-check:
`/home/mvazque2/.scout/var/jobs/Planned/work/Default_a8a505ef95d0e1de3824559e0c712f36.chat.files/Manager.chat`
— doctrine §3 heading marker ×1, `Cortex artifacts: versioned` ×1, advice
`test_helper.rb` ×1, society heading ×1 (grep -c; contents too large to
inline — counts only).

File facts: `wc -l/-c` over `doctrine doctrines/advice society scout`
(§1); `git ls-files` for tracked status; `readlink chats`; `bin/bundle_doctrine.sh`.

Unverified / not observable from here: the host chat store's actual
contents and its sync trigger (check 1) — the one open question Phase 2
must close first.
