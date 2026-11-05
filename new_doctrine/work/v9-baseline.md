# v9 baseline — verified AgentSuite state for doctrine-v9 work

Executor: Worker, v9 step 1 of 7. All claims below carry the command or path
that produced them. No fixes applied in this bout; no merges, rebases, pushes,
or commits performed. Branch `doctrine-v9` was cut from the verified
doctrine-v8 tip.

## Branch topology (verified)

Commands: `git branch -a`, `git log --oneline -3 <ref>` per ref,
`git rev-parse HEAD`, `git merge-base --is-ancestor`.

| Ref | Verified SHA | Matches hint |
|---|---|---|
| `doctrine-v8` | `46433830f5aa53a56ce88c911e0d06ec5dec0607` ("Doctrine v8") | yes |
| `main` | `e6ead1b` ("Improved FitAgent cmd") | yes |
| `doctrine-v7` | `c85587c` ("Doctrine v7 final") | yes |
| `ags-redesign` | `fa843de` ("Redesign closure report… Phase 8") | yes |

- The four refs form one linear chain (verified by `git merge-base
  --is-ancestor`): `main` → ancestor of `ags-redesign` → ancestor of
  `doctrine-v7` → ancestor of `doctrine-v8`. `main..doctrine-v8` = 13
  commits. No side branches; `git branch -a` shows only local branches plus
  `origin/main` and `origin/HEAD`.
- `main` == `origin/main` (`git rev-parse main origin/main` both `e6ead1bb…`):
  local main is not stale.
- `doctrine-v8` commit `4643383` contains 17 files: 6 parent-repo role
  start_chats, `doctrine`, 7 files under `doctrines/` (incl. new
  `scientific_investigation`, +324 lines), `society`, `Visualizer/workflow.rb`,
  `.vimproject` (`git show --stat 46433830`).

## Working-tree and submodule state

Command: `git status --porcelain=v1 -b --untracked-files=all`,
`git submodule status`, `git diff --submodule=short ChatAnalyst ScoutCoder`,
`git status --short` inside each submodule.

Dirty (modified):

1. `ChatAnalyst` (submodule, `m`): pointer recorded `25f423a` == submodule
   HEAD `25f423a`; inside, `ChatAnalyst/start_chat` is modified and
   uncommitted. Matches v8-change-ledger exactly.
2. `ScoutCoder` (submodule, `+`): pointer recorded `dd19a83`, but submodule
   HEAD is `488afcf` ("Workflow reload"). Inside ScoutCoder, the ONLY
   uncommitted change is `.vimproject` — `start_chat` in the worktree is
   identical to `488afcf`. The v8-era "uncommitted start_chat edit" described
   in v8-change-ledger no longer exists as such: the start_chat changes were
   committed inside the submodule at `667d1e2` ("v7: ScoutCoder start_chat
   execution-stance block…", 2026-11-02) and carried into `488afcf`. The
   parent pointer update remains unstaged (see Surprises).

Untracked:

- `new_doctrine/work/v8-{baseline,change-ledger,mandate,wiring-plan,wiring-review}.md`
  — 5 files. The v8 commit did NOT include any v8-* work file
  (`git ls-tree -r doctrine-v8 -- new_doctrine/work/` lists 30 files, all
  v7/redesign-era). v7 work files ARE tracked; v8 work files were left
  untracked.
- `doctrine_bundle/` and `doctrine_bundle.v7/` (see frictions inventory).

No stashes touch v8 material: all 11 stashes are `WIP on main` at old commits;
`git stash show --name-only stash@{0..10} | grep new_doctrine/work/v8` → 0 hits.

## v8 verification-gap disposition

Hunt performed (per mandate): `ls -la new_doctrine/work/`, `git status
--untracked-files=all`, `git log --all --diff-filter=A -- new_doctrine/work/`,
`git stash list` + per-stash file lists, `find . … -iname
'*integration*'/'*hermetic*'/'*migration*'/'*ready*launch*'`, content grep for
`ready.to.launch|hermetic delivery matrix` across `new_doctrine/`,
`tmp/v8-step2/3/4/`, and inspection of `tmp/v8-step4/` (contains only
`probe_owner.rb`, 62 bytes).

Result: v8-mandate deliverables 5–8 (three integration-check results, hermetic
delivery matrix, migration note, ready-to-launch statement) were NEVER
PRODUCED. They exist nowhere: not in the working tree, not on any branch
(`git log --all --diff-filter=A` on `new_doctrine/work/` yields only
v7/redesign-era adds), not in stashes, not in `tmp/`. Only planning mentions
exist (v8-mandate.md §Deliverables 5–8; v8-wiring-plan.md steps 5–8).

**Disposition recorded (Manager decision, applied by this bout per the work
order): SUPERSEDED.**

Rationale (recorded, not invented here): the science.v2 doctrine-8 run
(`AGS.full.scout.science.v2.doctrine8_66c09b60223d3f876df84a64ab42584c`) and
its process_xray supersede the planned light integration checks — a full
live run under the v8 configuration is stronger evidence than the three
one-step checks could have been; and v9's own baseline (this file) plus v9's
planned deployment-verification steps re-establish delivery and
launch-readiness for the new configuration that v9 will produce. The
outstanding v8 wiring-plan steps 5–8 (integration checks A/B/C, hermetic
matrix, migration note + ready-to-launch statement) are thereby closed as
superseded rather than open.

## Run-tree readability

Command: `ls <path>` per tree (via bash; all three readable).

| Run tree (under `~/git/sandbox/Scenarios/runs/`) | process_xray entries | Status |
|---|---|---|
| `AGS.full.scout.glm5.doctrine6_d9232750ed4670c4e8e7c7c626766e1a/AGS/process_xray/` | 93 | readable |
| `AGS.full.scout.glm5.doctrine7_21c70f5c34f5e8792cc5cf39ba6f97f1/AGS/process_xray/` | 16 | readable |
| `AGS.full.scout.science.v2.doctrine8_66c09b60223d3f876df84a64ab42584c/AGS/process_xray/` | 23 | readable |

doctrine8 xray includes `doctrine8_process_xray.md`, `report.md`,
`friction_register.tsv`, `remediation_backlog.md`, `context_delivery_matrix.md`,
`timeline.md`, `resource_breakdown.tsv`, `rollups.tsv`, `tool_job_usage.tsv`,
plus analysis files. Note: these run trees are outside the Workspace sandbox
root but were readable from bash (`~/git` = `/home/mvazque2/git`, a real
directory distinct from the `/bulk/mvazque2/git/AgentSuite` checkout).

## Persistent repo frictions inventory

1. **`workflows/` symlinks with machine-absolute targets.**
   Evidence: `git ls-files -s workflows/` → 5 tracked symlinks (mode 120000);
   `ls -la workflows/` → `Cortex -> /bulk/mvazque2/git/AgentSuite/Cortex`,
   `Reader`, `ScoutCoder`, `Semantics`, `Workspace` same pattern;
   `git cat-file` of the blob confirms the absolute path is stored in git;
   introduced by commit `6a3ec78` ("Wiring: Agent/ agent namespace, tool
   provisioning, workflows and etc symlinks (Phase 4)"). All five RESOLVE on
   this machine (`/bulk/mvazque2/git/AgentSuite` exists; note `/home/mvazque2/
   git/AgentSuite` does NOT). Any clone at another path breaks all five.
   Proposed disposition: **delegate** (relative targets like `../Cortex` would
   fix it; touching tracked symlinks affects deployment — ScoutCoder/Manager
   decision, not an inventory bout).

2. **doctrine-bundle script exit noise.**
   Evidence: `bin/bundle_doctrine.sh` (8 lines) loops `for a in *; do cp
   $a/start_chat doctrine_bundle/$a.start_chat; done` and the same for
   `README.md`, over EVERY top-level entry — no existence guards, no `exit 0`.
   Executed `bash bin/bundle_doctrine.sh` → ~54 `cp: cannot stat …` lines and
   exit code 1 (status of the last failed cp). Content is nevertheless
   CORRECT: `diff -q` between every sampled source and its bundle copy is
   clean — `doctrine`, `society`, `scout`,
   `doctrines/scientific_investigation`, and all 8 role start_chats incl.
   ScoutCoder and ChatAnalyst. Defect: exit code + stderr noise only, not a
   data defect (matches v7-deployment-verification.md §"Pre-existing
   deployment workarounds" item 1).
   Proposed disposition: **fix-here** in a later v9 step (add `[ -f … ] ||
   continue` guards and explicit exit) — trivially small; or accept if v9
   retires the bundle mechanism.

3. **`doctrine_bundle/` untracked (and `doctrine_bundle.v7/` too).**
   Evidence: `git status --porcelain` shows `?? doctrine_bundle/` and
   `?? doctrine_bundle.v7/`; `git check-ignore -v doctrine_bundle/` → exit 1
   (NOT ignored); `.gitignore` does not list it. Untracked-by-policy per
   v7-deployment-verification.md; produces permanent `??` noise in every
   status.
   Proposed disposition: **accept** the policy but **fix-here** the noise
   (add `doctrine_bundle/` and `doctrine_bundle.v7/` to `.gitignore`) in a
   later v9 step — requires the same policy owner's confirmation.

4. **Staged-start_chat workaround — mechanism now established.**
   The repo root has NO `Agent/` directory (`ls -d Agent` → absent), yet role
   start_chats import `Agent/doctrine`, `Agent/doctrines/…`, `Agent/scout`
   (these resolve relative to a *chat directory*, not the repo). The
   workaround: every parse, verification, or deployment must first STAGE a
   chat dir containing an `Agent/` namespace with copies of `doctrine`,
   `society`, `scout`, `doctrines/*` plus the role start_chats. Evidence:
   `tmp/v8-step3/parse_probe.rb` does exactly this (creates
   `tmp/v8-step3/chats/Agent/{doctrine,society,scout,doctrines}` + 8 role
   files before `Chat.imports`); `.save/Agent/` holds another staged copy;
   `tmp/ags-smoke/agents/` and `tmp/ags-pilot/Agent/` are staged trees from
   earlier runs; `bin/bundle_doctrine.sh` exists to produce the staging set
   (`doctrine_bundle/` = flattened `doctrine`, `doctrines/`, `society`,
   `<Role>.start_chat`). The live run trees carry their own staged copies
   (e.g. the doctrine8 run has `AGS/etc/path_maps` → `default: :current`,
   `AGS/chats/`).
   Proposed disposition: **accept** for v9 baseline (mechanism works and is
   documented); a real fix (a tracked `Agent/` namespace or a proper staging
   task) is a ScoutCoder-scope design change to **delegate** if v9 wants it.

## Rollback point

`doctrine-v9` was cut with `git checkout -b doctrine-v9` while on
doctrine-v8; both branches point at:

**`46433830f5aa53a56ce88c911e0d06ec5dec0607`**

Verified: `git branch --show-current` → `doctrine-v9`; `git rev-parse HEAD` →
the SHA above; single-parent commit (no merge; `git cat-file -p 46433830`
shows one parent `c85587c…`). Rollback = `git checkout doctrine-v8` (and
`git branch -D doctrine-v9` if discarding). Nothing was merged, rebased,
pushed, or committed; working-tree dirt was left exactly as found.

## Surprises

1. **ScoutCoder submodule advanced beyond the parent pointer since the v8
   ledger was written.** v8-change-ledger.md describes ScoutCoder/start_chat
   as an *uncommitted worktree edit* with pointer `dd19a83`. Today: submodule
   HEAD is `488afcf`, which CONTAINS the start_chat changes (committed at
   `667d1e2`), and the only uncommitted file inside is `.vimproject`. The
   parent still records `dd19a83`, so status shows `+`/` M ScoutCoder`. This
   means later v9 steps will face a submodule-pointer decision (commit the
   pointer bump or pin back), which the v8 ledger did not anticipate.
2. **The v8 commit deliberately excluded the v8-* work files** — they exist
   only as untracked files (v7's work files were committed). If v9 wants the
   v8 record in-tree, they must be committed on doctrine-v9 (a later step's
   decision; not done here).
3. `doctrine_bundle.v7/` is also untracked (one more `??` noise source than
   the hints listed).
4. The bundle script's exit 1 is harmless in content terms (all sampled
   files diff-clean) — the defect is purely exit code/noise.
5. `main` is even with `origin/main`; no push needed for v9 to rely on local
   refs.
6. `WorkflowCoder` appears in `.gitmodules` but is not checked out and absent
   from `git submodule status` (benign; recorded for completeness).
7. Run trees live under `/home/mvazque2/git/sandbox/Scenarios/runs/`
   (`~/git` is a real directory, not a symlink), separate from the `/bulk/…`
   checkout — bash reaches both; Workspace `read` task would not reach the
   run trees (outside sandbox root).
