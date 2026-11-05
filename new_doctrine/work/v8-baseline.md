# v8 baseline and drift check

Date: 2026-11-03 (2026-11-03T17:4x+01:00). Repo: /bulk/mvazque2/git/AgentSuite.
Recorded by: Worker (v8 setup bout, step 1 of 8). Only this work file, `v8-mandate.md`, and `v8-wiring-plan.md` were written in this bout; no doctrine/start_chat/wiring file was touched.

## 1. Actual git state (quoted, pre-branch-cut)

### git branch --show-current

```
doctrine-v7
```

### git rev-parse HEAD

```
c85587cb0fd2bf2188ef8fac5eccaf4c7984633f8
```

### git status --short

```
 M .vimproject
 M ScoutCoder
?? doctrine_bundle.v7/
?? doctrine_bundle.zip
?? doctrine_bundle/
```

### git rev-parse main ags-redesign doctrine-v7

```
e6ead1bbcbb40a8781e958882924a21e2ab5809a   main
fa843dea96873de148976f14d73fdbc50ce4c421   ags-redesign
c85587cb0fd2bf2188ef8fac5eccaf4c7984633f8  doctrine-v7
```

### git submodule status (and worktree HEADs)

```
 25f423a8a1d5858d0e5d9e98c498d5f8c6fd4674 ChatAnalyst (heads/main)
 21282a2c5922e28a788698516f81fc3ce1ae056e ComputerUse (remotes/origin/HEAD)
 d83a355ef2ffd4c1552f6845b7b0f3399d2e6439 Cortex (heads/main)
 dd19a83a84be21c385230654f47d69978fc42632 ScoutCoder (heads/main)
```

Worktree submodule HEADs equal the recorded index pointers for all four (`git ls-files -s` vs `git -C <sub> rev-parse HEAD`): ChatAnalyst 25f423a, ComputerUse 21282a2, Cortex d83a355, ScoutCoder dd19a83.

### git log --oneline -3 (doctrine-v7)

```
c85587c Doctrine v7 final
509ba7f v7 closure: migration note, behavioral results, validation-mission definition, doc fixes, submodule pointer updates (Critic advisories applied)
91919a8 v7: doctrine, shared guides, role start_chats, Analyst role, work files (ledger-driven)
```

`git merge-base --is-ancestor 509ba7f c85587cb` -> YES: 509ba7f is the immediate parent of the tip; HEAD is not behind anything.

## 2. Drift assessment vs the expected state

The task brief expected: "current branch doctrine-v7 at tip 509ba7f with working tree equal to the v7 closure state (possibly with known-untracked doctrine_bundle/ and local-only submodule pointers ScoutCoder 667d1e2, ChatAnalyst 25f423a)".

Drift items found (three, all pointing at one cause):

1. **Tip drift: doctrine-v7 is at c85587c, not 509ba7f.** Commit `c85587c "Doctrine v7 final"` (2026-11-03 17:22 +0100, by the repo owner) sits exactly one commit on top of 509ba7f, i.e. above the v7 closure the task remembered. It is the v7 set's own finishing commit: `git show --stat c85587c` = "24 files changed, 68 insertions(+), 1355 deletions(-)" — it deletes the old `Agent/` namespace (10 start_chats, Agent/doctrine, Agent/doctrines/*, Agent/society; 1331 of the deletions) and moves roles to top-level dirs (`Manager/`, `Research/`, ... now tracked there), updates `doctrine` (35 lines), `society` (2), `Workspace/README.md`, `Workspace/workflow.rb`, `Research/README.md`, `.vimproject`, and updates the ScoutCoder submodule pointer.
2. **Submodule pointer drift: ScoutCoder recorded at dd19a83, not 667d1e2.** `git ls-tree 509ba7f ScoutCoder` = 667d1e2; `git ls-tree c85587c ScoutCoder` = dd19a83 — the pointer move is part of commit c85587c itself, and the worktree matches the index (dd19a83). Note: the "local-only pointer" is therefore no longer local-only; it has been committed. ChatAnalyst is 25f423a exactly as expected (matches both 509ba7f and c85587c).
3. **Extra dirty/untracked entries:** ` M ScoutCoder` (content modifications inside the submodule: README.md, lib/ScoutCoder/path_kinds*.rb, workflow.rb, tests, plus untracked reload_workflow files — the `path_kind: ScoutCoder` machinery), ` M .vimproject` (editor state), and untracked `doctrine_bundle/`, `doctrine_bundle.v7/`, `doctrine_bundle.zip` (snapshot exports). Expected list mentioned only `doctrine_bundle/`; `doctrine_bundle.v7/` + zip are additional untracked artifacts of the same kind.

Everything else matches: branch doctrine-v7 checked out; main at e6ead1b untouched; ags-redesign at fa843de unmerged; v7 work files complete under `new_doctrine/work/` (12 v7-*.md files incl. v7-baseline-drift.md, v7-mandate.md, v7-closure.md); role start_chats all present at top level; `doctrines/` carries the six shared docs.

Assessment: the drift is explained by the repo owner running the v7 finalization commit (c85587c) after the search stage read the repo. c85587c is the *most advanced v7 state* (it implements the v7 role layout the v8 drafts build on: top-level role dirs, `doctrines/` shared namespace). Branching from it is strictly safer than branching from 509ba7f: cutting at 509ba7f would resurrect the deleted `Agent/` namespace alongside top-level roles and revert the ScoutCoder pointer that current wiring depends on.

## 3. Draft package inventory (confirmed)

`find tmp/chat/scout_scientific_agent_design -type f` (12 files):

```
tmp/chat/scout_scientific_agent_design/Agent/investigation
tmp/chat/scout_scientific_agent_design/README.md
tmp/chat/scout_scientific_agent_design/start_chats/Analyst.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/ChatAnalyst.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/Critic.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/Manager.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/Reader.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/Research.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/ScientificLead.start_chat
tmp/chat/scout_scientific_agent_design/start_chats/ScoutCoder.start_chat
tmp/chat/scout_scientific_agent_design/wiring/mission_template.md
tmp/chat/scout_scientific_agent_design/wiring/role_capability_matrix.md
```

Matches the mandate's inventory (Agent/investigation, README.md, 8 role start_chats, 2 wiring docs). Not edited in this bout.

## 4. Baseline decision

Decision: branch `doctrine-v8` from the current HEAD `c85587c` (doctrine-v7 tip, post-"Doctrine v7 final"), carrying the dirty/untracked entries as-is. Rationale: c85587c is the authoritative end-state of v7 (it created the top-level role layout and `doctrines/` convention that the v8 wiring plan's defect table W1/W5/W6/W7 assume); nothing on the tip is lost (HEAD is the tip); the dirty content is additive (uncommitted ScoutCoder submodule work + untracked bundle exports) and stays in the working tree. No rollback to 509ba7f: that would *lose* the v7 final layout, not preserve it.

Deviations from the task text: (a) branch cut from c85587c instead of 509ba7f — cause: drift item 1 above; (b) rollback point text therefore cites c85587c with 509ba7f noted as the remembered sha.

## 5. Branch creation (exact command sequence)

Run from /bulk/mvazque2/git/AgentSuite at 2026-11-03T17:4x+01:00:

```
git switch -c doctrine-v8
```

Verification afterwards:

```
git branch --show-current   -> doctrine-v8
git rev-parse HEAD          -> c85587cb0fd2bf2188ef8fac5eccaf4c7984633f8
git status --porcelain      ->  M .vimproject /  M ScoutCoder / ?? doctrine_bundle.v7/ / ?? doctrine_bundle.zip / ?? doctrine_bundle/   (unchanged)
```

Nothing committed; nothing discarded.

**Rollback point:** doctrine-v7 tip c85587cb0fd2bf2188ef8fac5eccaf4c7984633f8 (one commit above the v7-closure sha 509ba7f named in the task; see drift item 1); return with: `git switch doctrine-v7 && git branch -D doctrine-v8`.

## 6. Mandate pin

`new_doctrine/work/v8-mandate.md` written this bout with exactly the text between BEGIN/END MANDATE (4740 bytes, starts `## Restated request`, ends `- The user can submit the new use case immediately after reading the ready-to-launch statement.`).

```
sha256sum new_doctrine/work/v8-mandate.md
bc7ef6c0827f7cf58b9364ce41d4435f6a41343c05978b2b24eb02eca38d7bcb  new_doctrine/work/v8-mandate.md
```
