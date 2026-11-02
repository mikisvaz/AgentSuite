# v7 baseline and drift check

Date: 2026-11-02 (2026-11-02T20:11+01:00). Repo: /bulk/mvazque2/git/AgentSuite.
Recorded by: Worker (v7 setup bout 1). No instruction files were touched in this bout.

## 1. Rollback point (recorded before any v7 action)

- Current branch: `ags-redesign`
- HEAD sha: `fa843dea96873de148976f14d73fdbc50ce4c421` (= `ags-redesign` tip)
- `git status` summary: 5 entries — 4 modified (` M`), 1 untracked (`??`).
  - Modified: `.vimproject`, `Research/README.md`, `Research/start_chat`, `ScoutCoder` (submodule pointer shown dirty)
  - Untracked: `doctrine_bundle/` (37 files, ~440K, mtime 2026-11-01: a full snapshot of start_chats/READMEs/doctrines/society/scout)
- To return to this state: `git switch ags-redesign` (work tree carries the same 4 modifications + untracked dir; nothing is committed or discarded by the v7 branch).

## 2. Drift check

### git log --oneline -3

```
main:
e6ead1b Improved FitAgent cmd
a060da7 Remove cortex_activity
f6a3c0a Support for wrapping Claude into Scout

ags-redesign:
fa843de Redesign closure report + pilot resume-packet closure pointer (Phase 8)
27f3844 Pre-redesign parallel work: reader-split reports and claude-meta evidence (pre-existing, carried)
bb0ce2c AGS route doc, smoke results, pilot report and resume packet (Phases 5-7)

HEAD (on ags-redesign):
fa843de Redesign closure report + pilot resume-packet closure pointer (Phase 8)
27f3844 Pre-redesign parallel work: reader-split reports and claude-meta evidence (pre-existing, carried)
bb0ce2c AGS route doc, smoke results, pilot report and resume packet (Phases 5-7)
```

Matches `new_doctrine/work/redesign-baseline.md`: main at e6ead1b, ags-redesign baseline 1116c9a, tip fa843de.

### git diff fa843de --stat (tail 20)

```
 .vimproject         | 31 +++++++++++++++++--------------
 Research/README.md  |  2 +-
 Research/start_chat |  1 +
 ScoutCoder          |  0
 4 files changed, 19 insertions(+), 15 deletions(-)
```

### git diff e6ead1b --stat (tail 5)

```
 workflows/Workspace  |   1 +
 111 files changed, 10119 insertions(+), 435 deletions(-)
```

### Plain statements

- The working tree is AT the ags-redesign tip (`HEAD == fa843de`, not ahead, not behind) but DIRTY: 3 ordinary files modified plus the ScoutCoder submodule pointer reported dirty, plus one untracked directory `doctrine_bundle/`.
- The only material dirty content: `Research/README.md` + `Research/start_chat` add an explicit `path_kind: Research` chat line (registration of the observation/claim/hypothesis kinds); `.vimproject` is an editor-state file; `ScoutCoder` submodule is at commit 496df9c with 2 dirty files inside the submodule (pointer change is cosmetic-dirty, not a pointer move: the committed pointer `496df9c` equals the checked-out `496df9c`).
- Branching from the working tree discards NOTHING on the tip (HEAD is the tip) and diverges from the tip only by the small uncommitted diff above, which is carried along untracked/modified rather than committed by this bout (per instructions: no resets, no checkouts that drop files).
- Divergence from `main` (e6ead1b) is the full redesign: 111 files, +10119/-435 — that is the baseline v7 revises, consistent with the mandate.

## 3. Baseline decision

Decision: branch `doctrine-v7` from the CURRENT working-tree state (on `ags-redesign` at fa843de, carrying the 4 dirty entries and the untracked `doctrine_bundle/`). This is the default from the task design, and the drift check found no evidence contradicting it: nothing on the tip is lost (HEAD is the tip), and the dirty content is small, additive (a `path_kind:` registration line plus an untracked snapshot directory), not conflicting state. No Manager escalation required under the task's own criterion (no discarded or materially divergent work).

Evidence: sections 1-2 above (git log/status/diff outputs, run 2026-11-02T20:11+01:00).

## 4. Branch creation (exact command sequence)

Run from /bulk/mvazque2/git/AgentSuite at 2026-11-02T20:1x+01:00:

```
git switch -c doctrine-v7
```

Verification afterwards: `git branch --show-current` -> `doctrine-v7`; `git rev-parse HEAD` -> `fa843dea96873de148976f14d73fdbc50ce4c421`; `git status --porcelain` unchanged (4 M + 1 ??). All working files intact; nothing discarded, nothing committed.
