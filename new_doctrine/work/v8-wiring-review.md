# v8 wiring review (step 2 deliverable)

Date: 2026-11-03. Branch: doctrine-v8 @ c85587c (working tree, uncommitted).
Author: Worker, single instruction editor, per Manager's step-2/step-3 work
order.

Evidence base (read, not re-derived):

- Cortex artifact `research/v8-path-kind-wiring-facts.md` (7 verified facts;
  cited below as FACT-1..FACT-7).
- `tmp/v8-step2/evidence-current-wiring.txt` (154 lines, per-role wiring
  verbatim at c85587c).
- `tmp/v8-step2/scientific_investigation` (byte-identical copy of draft
  `Agent/investigation`).
- Drafts under `tmp/chat/scout_scientific_agent_design/` (8 role start_chats
  + `wiring/mission_template.md`, `wiring/role_capability_matrix.md`).

## Defaults confirmed or amended

- **D-W1 CONFIRMED.** Install `doctrines/scientific_investigation`.
  Justification: FACT-1/W1 — `import: Agent/investigation` raises "Import
  not found" (repo-root `investigation` does not exist; the file is
  `doctrines/investigation`), while `import:
  Agent/doctrines/scientific_investigation` resolves via the caller_lib_dir
  branch. The new file name makes the draft import line correct without
  editing the drafts' `import: Agent/investigation` into a different
  namespace.
- **D-W7 CONFIRMED.** Research keeps its full current Cortex block
  (cortex_list/search/read/write/edit/continue/brief/rename/move/remove),
  Semantics + Workspace introduces, `exec_task: Workspace pwd`, and
  `path_kind: Research`. Justification: D-W7 was already the current wiring
  at c85587c (`tmp/v8-step2/evidence-current-wiring.txt` lines 141-175); the
  draft Research start_chat carries no Cortex block at all and drops
  `import: Agent/society` and the Society semantics Research needs as the
  epistemic-centre role. Nothing in FACT-1..7 requires reducing the block.
- **D-W8 CONFIRMED.** Reader keeps the bare `introduce: Cortex` / `tool:
  Cortex` line. Justification: current wiring (evidence file lines 85-86);
  the draft Reader also keeps it; nothing contradicts.

## Per-file findings

### Manager (draft `start_chats/Manager.start_chat`)

- Defect (draft): `import: Agent/investigation` (line 2) — raises "Import
  not found" (FACT-1). Draft also drops `import: Agent/society`,
  `import: Agent/doctrines/collaboration`, `import: Agent/doctrines/handoff`,
  the `socialize: true` line, and the `tool: Cortex cortex_continue` /
  `tool: Cortex cortex_brief` pair (W2).
- Correction applied: imports are `Agent/doctrine`, `Agent/society`,
  `Agent/doctrines/collaboration`, `Agent/doctrines/handoff`,
  `Agent/doctrines/scientific_investigation` (D-W1 import form); draft prose
  installed verbatim; `socialize: true` and both Cortex tool lines restored
  from the c85587c wiring.
- Gap: none.

### ScientificLead (draft `start_chats/ScientificLead.start_chat`)

- Defect: `import: Agent/investigation` (line 2) — W1.
- Draft wiring intent for a tool-less role: imports only. The current file
  at c85587c carried `import: Agent/doctrines/discipline` and
  `Agent/doctrines/collaboration` which the draft drops; ScientificLead
  adjudicates numerical/inferential claims and gate norms, so both are kept
  (current-file wiring wins over draft omission per the
  prose-on-top-of-verified-wiring rule).
- Correction applied: imports = doctrine, society, collaboration,
  scientific_investigation, discipline, handoff; draft prose installed
  verbatim.
- Gap: none.

### Research (draft `start_chats/Research.start_chat`)

- Defect: `import: Agent/investigation` (W1). Draft drops `import:
  Agent/society`, `import: Agent/doctrines/discipline`, `import:
  Agent/doctrines/handoff`, `import: Agent/doctrines/catalogue`, the whole
  current Cortex block, `exec_task: Workspace pwd`, `import: Agent/doctrines/collaboration`
  (the draft drops it too), and `socialize: true`.
- Draft wiring tail is `introduce: Workspace / tool: Workspace / introduce:
  Semantics / tool: Semantics / introduce: Research / tool: Research /
  path_kind: Research` — D-W7 CONFIRMED means the current full block wins.
- Correction applied: imports = doctrine, society, scientific_investigation
  (replacing `investigation`), discipline, handoff, catalogue; prose
  installed verbatim; wiring = Semantics introduce/tool, Workspace
  introduce/tool, `Your current directory is:` + `exec_task: Workspace
  pwd`, full 10-line Cortex block, `introduce: Research / tool: Research`,
  then `socialize: true` and `path_kind: Research` at the end (current-file
  order preserved).
- Gap: none. `path_kind: Research` retained per FACT-4 (registers
  claim/hypothesis/observation).

### Analyst (draft `start_chats/Analyst.start_chat`)

- Defect: `import: Agent/investigation` (line 2) — W1. Draft wiring tail is
  bare `introduce: Workspace / tool: Workspace` and drops the 8 explicit
  Workspace task lines plus `import: Agent/society` and `import:
  Agent/doctrines/collaboration` (W3).
- Correction applied: imports = doctrine, society, collaboration,
  scientific_investigation, handoff; draft prose installed verbatim;
  Workspace wiring restored to the 8 explicit lines (bash, python, ruby, r,
  read, write, list_directory, file_stats) from c85587c.
- Gap: none.

### Reader (draft `start_chats/Reader.start_chat`)

- Defect: `import: Agent/investigation` (line 1) — W1.
- Draft wiring: `introduce: Reader / tool: Reader / introduce: Workspace /
  tool: Workspace / introduce: Cortex / tool: Cortex` — matches D-W8.
- Correction applied: imports = doctrines/scientific_investigation,
  doctrines/catalogue, doctrine (current order); draft prose installed
  verbatim; wiring block unchanged from current.
- Gap: none.

### ScoutCoder (draft `start_chats/ScoutCoder.start_chat`)

- Defects: `import: Agent/investigation` (W1); drops `import: Agent/scout`,
  `tool: Cortex cortex_write`, `tool: Cortex cortex_edit`, `exec_task:
  Workspace pwd` (FACT-7 enumerates exactly this). Draft DOES carry the
  `introduce: Workspace / tool: Workspace / introduce: ScoutCoder / tool:
  ScoutCoder / path_kind: ScoutCoder` tail (FACT-7 corrects the stale
  defect-table entry).
- Correction applied: imports = doctrine, scout, scientific_investigation;
  draft prose installed verbatim; restored `tool: Cortex cortex_write`,
  `tool: Cortex cortex_edit`, and `Your current directory is:` +
  `exec_task: Workspace pwd` before the tail; tail kept with `path_kind:
  ScoutCoder` (FACT-3: the explicit line is load-bearing).
- Deviation (submodule workaround): `ScoutCoder/start_chat` is tracked by
  the ScoutCoder submodule, whose worktree has uncommitted reload-build
  changes (FACT-6) behind a dirty pointer. Editing the worktree file keeps
  the change uncommitted inside the submodule — nothing was committed or
  discarded; the parent repo only shows the already-dirty `m ScoutCoder`
  pointer. Reported, not resolved.
- Gap: none for v8; the submodule's commit discipline remains the
  constraint.

### Critic (draft `start_chats/Critic.start_chat`)

- Defect: `import: Agent/investigation` (line 2) — W1.
- Current wiring is the narrowed 7-task Workspace surface (read,
  list_directory, file_stats, search, sandbox_paths, pwd, bash); W4 says
  keep it, prose changes only.
- Correction applied: imports = doctrine, scientific_investigation,
  collaboration, discipline; draft prose installed verbatim; wiring block
  restored verbatim from c85587c.
- Gap: none.

### ChatAnalyst (draft `start_chats/ChatAnalyst.start_chat`)

- Defect: `import: Agent/investigation` (line 2) — W1. Current file carries
  `import: Agent/doctrine` only (W6 keeps the tool block; the draft has no
  tool block at all).
- Correction applied: imports = doctrine, scientific_investigation; draft
  prose installed verbatim; tool block restored: `introduce: Workspace /
  tool: Workspace / tool: Cortex cortex_write / tool: Cortex cortex_edit`
  plus the specialized-tooling paragraph and `introduce: ChatAnalyst /
  tool: ChatAnalyst`.
- Deviation (submodule workaround): `ChatAnalyst/start_chat` is tracked by
  the ChatAnalyst submodule. Editing the worktree start_chat leaves the
  change uncommitted inside that submodule; the pointer stays 25f423a as
  required. The parent `m ChatAnalyst` dirty marker now appears because of
  this edit (previously clean). Reported, not resolved.
- Gap: none for v8.

### investigation doctrine (`tmp/v8-step2/scientific_investigation`, from
draft `Agent/investigation`)

- Installed as `doctrines/scientific_investigation` (D-W1).
- Trims applied per the work order: section 4.3 no longer restates the five
  gate states, pointing to the collaboration guide (which owns the norm);
  section 6 keeps the requirement but points to the shared
  branch-consumption report form instead of duplicating the template;
  section 7 moves the duplicated numerical/inferential rules (missing-is-
  not-zero, equal-scalar) to a one-line pointer at the discipline guide,
  keeping only the scientific-specific rules in place.
- `doctrines/investigation` carries a supersede note (last section) stating
  it remains the reference for non-scientific investigations and pointing
  at `doctrines/scientific_investigation` for scientific work.
- Gap: none.

### mission template / role capability matrix (wiring/ drafts)

- `mission_template.md` and `role_capability_matrix.md` describe the
  intended mission packet shape and per-role capability table. They are
  design documents for Manager's mission authoring, not start_chat
  artifacts; no wiring defect applies (no import/tool lines). Not installed
  anywhere this bout; noted as input to step 4 (hermetic delivery matrix),
  which is the natural consumer.
- Gap: no defect found; disposition (install path) is a Manager decision
  deferred to step 4.

## Harness/role-file distinction (for the ledger)

- Parent-repo tracked files edited: `Manager/start_chat`,
  `ScientificLead/start_chat`, `Research/start_chat`, `Analyst/start_chat`,
  `Reader/start_chat`, `Critic/start_chat`, `society`,
  `doctrines/investigation`; untracked new: `doctrines/scientific_investigation`.
- Submodule-worktree files edited (uncommitted inside submodules):
  `ScoutCoder/start_chat`, `ChatAnalyst/start_chat`.
- Untracked work files (not part of the repo): `new_doctrine/work/v8-*.md`,
  `tmp/v8-step2/`, `tmp/v8-step3/`, `share/probes/`, `doctrine_bundle/`
  (regenerated in place).
