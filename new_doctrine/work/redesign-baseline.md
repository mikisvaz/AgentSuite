# Redesign baseline — AgentSuite @ /bulk/mvazque2/git/AgentSuite

- **Date recorded:** 2026-11-01 13:41 +0100
- **Branch:** `ags-redesign` (newly created from `main` at e6ead1b)
- **Baseline commit:** `1116c9a7cdd3714c9d8d24d26be063ca68b649b6`
  (`1116c9a` — "Baseline before AGS redesign (pre-audit)")
- **Parent:** `e6ead1bbcbb40a8781e958882924a21e2ab5809a` (`e6ead1b`
  "Improved FitAgent cmd", on `main`, 2026-11-01 12:32:57 +0100)
- **Purpose:** recoverable git checkpoint and recorded pre-redesign state,
  as step 1 of the 10-step AgentSuite redesign plan. Written after the
  commit; deliberately left **untracked**.

Note: commit was made with the repository's standard author identity
(Miguel Vazquez <mikisvaz@gmail.com>) supplied per-invocation via
`git -c user.name=... -c user.email=...`, because no git identity is
configured in this sandbox (`$HOME` is bound elsewhere). Config files were
not modified.

## 1. Observed state (pre-commit, 2026-11-01 ~13:35 +0100)

- Current branch: `main` (up to date with `origin/main`)
- HEAD: `e6ead1bbcbb40a8781e958882924a21e2ab5809a` (`e6ead1b`, "Improved
  FitAgent cmd", 2026-11-01 12:32:57 +0100)
- Branches: only `main` locally; `ags-redesign` did **not** exist before
  (verified with `git rev-parse --verify ags-redesign` → "fatal: Needed a
  single revision"), so it was created, not reused.
- Submodules (all clean, no pointer changes): ChatAnalyst 85a9977,
  ComputerUse 21282a2, Cortex d83a355, ScoutCoder 496df9c.
- Full `git status --porcelain`:

```
 M .vimproject
 M FitAgent/.vimproject
 M FitAgent/lib/FitAgent/tasks/other.rb
 M FitAgent/lib/FitAgent/tasks/use_case.rb
 M FitAgent/workflow.rb
 M research/agent-cortex-capabilities.md
?? FitAgent/]
?? FitAgent/lib/FitAgent/tasks/agent_ask.rb
?? FitAgent/share/
?? bin/
?? doctrine_bundle/
?? new_doctrine/
?? research/claude-meta-evidence/
```

### Diffstat of the dirty tracked files (what the baseline commit folds in)

```
 .vimproject                             | 21 ++++-------------  (pre-existing dirt)
 FitAgent/.vimproject                    |  7 ++++++        (pre-existing dirt)
 FitAgent/lib/FitAgent/tasks/other.rb    | 41 ----------------  (pre-existing dirt; removals)
 FitAgent/lib/FitAgent/tasks/use_case.rb |  8 ++++---       (pre-existing dirt)
 FitAgent/workflow.rb                    |  1 +               (pre-existing dirt)
 research/agent-cortex-capabilities.md   | 36 +++++++++++     (Phase 0 matrix extension, §7)
```

### Redesign/audit deliverables already on disk (pre-commit)

`new_doctrine/work/`:
- `redesign-audit-context.md` (21228 B, mtime 2026-11-01 13:38) — the
  Phase 0 audit context packet from the earlier (misrouted) delegation
  round; present, not read/verified in detail here beyond existence.
- `change-report-reader-split.md` (16110 B, 2026-10-25 23:42)
- `preflight-reader-split.md` (10458 B, 2026-10-25 19:27)
- `startchat-receipts-reader-split.md` (18867 B, 2026-10-25 23:21)
  (the three `*-reader-split.md` files predate the redesign and were
  already untracked before this round.)

`tmp/` (gitignored, untracked):
- `tmp/redesign_audit_matrix_probe.rb` (3332 B, 2026-11-01 13:25)
- `tmp/redesign_audit_matrix_probe.out` (1170 B, 2026-11-01 13:25)
- `tmp/redesign_audit_matrix_probe.err` (0 B)
- `tmp/redesign_audit_chats/` (scratch `Agent/` mirror + start_chat
  copies for Reader / FitAgent / ChatAnalyst, 2026-11-01 13:25)

## 2. The baseline commit — what was folded in

Commit `1116c9a` on `ags-redesign`, message "Baseline before AGS
redesign (pre-audit)", staged **tracked changes only** (`git add -u`;
nothing staged before). 6 files, +54/−60:

- **Pre-existing dirt (folded in, as sanctioned):** `.vimproject`,
  `FitAgent/.vimproject`, `FitAgent/lib/FitAgent/tasks/other.rb`,
  `FitAgent/lib/FitAgent/tasks/use_case.rb`, `FitAgent/workflow.rb`.
- **Sanctioned Phase 0 matrix extension (folded in):**
  `research/agent-cortex-capabilities.md` +36 lines — new section
  "## 7. Extension — 2026-11-01 redesign audit (Reader, FitAgent,
  ChatAnalyst)" with the effective-tools matrix, explicitly attributed to
  the Phase 0 packet with hermetic probe provenance. This is the
  sanctioned Phase 0 output, not a redesign edit.
- No submodule pointer changes existed, so none were folded.

## 3. Untracked entries deliberately left alone

All of these remain untracked after the commit (none staged, none added,
none deleted — parallel Phase 0 packets may land in them):

- `Claude/` — **absent**; only `Claude/workflow.rb` exists, which is
  **tracked** (committed in 6c5bf6c "Support for wrapping Claude into
  Scout", 2026-11-01 12:32:05 +0100, i.e. before the snapshot cut below).
  The snapshot's "untracked: Claude/" is stale relative to disk.
- `new_doctrine/` — including `work/redesign-audit-context.md` (Phase 0)
  and the three older `*-reader-split.md` reports.
- `tmp/redesign_audit_*` probes and scratch (also covered by `.gitignore`
  `tmp`).
- `FitAgent/], ` — accidental filename (39 bytes of job-sidecar text);
  clearly junk from an editor/redirect mishap; not addressed.
- `FitAgent/lib/FitAgent/tasks/agent_ask.rb` — untracked new source.
- `FitAgent/share/` (contains `probes`), `bin/` (`bundle_doctrine.sh`),
  `doctrine_bundle/` (agent start_chat/README copies), 
  `research/claude-meta-evidence/` — other parallel work.

## 4. Post-commit verification

- `git status --porcelain` after commit: only `??` lines (the untracked
  entries above) — **the tracked tree is clean**.
- Branch: `ags-redesign`; commit `1116c9a` contains exactly the 6 tracked
  files.
- Command sequence: `git checkout -b ags-redesign` → `git add -u` →
  `git -c user.name=... -c user.email=... commit -m "Baseline before AGS
  redesign (pre-audit)"`.
- Note on the failed first commit attempt: with no configured identity,
  `git commit` failed with "Author identity unknown"; the retry used the
  repo's standard identity (from `git log` authorship) via `-c` flags,
  one change, and succeeded. No config file was written.

## 5. Differences vs the 2026-10-25 snapshot description

The "Current state" section described the repo as of 2026-10-25; disk
today (2026-11-01) differs:

1. **Dirty tracked set expanded.** Snapshot: `.vimproject`, ScoutCoder
   submodule pointer, doctrine, scout, FitAgent sources possibly. Observed
   now: the submodule pointer is **not** dirty and **doctrine / scout are
   not dirty**; instead `.vimproject`, `FitAgent/.vimproject`,
   `FitAgent/lib/FitAgent/tasks/other.rb`,
   `FitAgent/lib/FitAgent/tasks/use_case.rb`, `FitAgent/workflow.rb` are
   dirty. (Commits 03b3b57 "Updated instructions and doctrine" and 8d29b20
   "ScoutCoder", both 2026-10-26, and later FitAgent commits on
   2026-11-01, likely explain the change.)
2. **Claude/ is not untracked-any-more.** `Claude/workflow.rb` was
   committed in 6c5bf6c (2026-11-01 12:32, "Support for wrapping Claude
   into Scout"); the directory is tracked, not the untracked entry the
   snapshot expected. `git status --porcelain` therefore shows no
   `?? Claude/` line.
3. **research/agent-cortex-capabilities.md carries the Phase 0
   extension.** Not part of the snapshot's dirty list; now +36 lines
   (section 7). This was folded into the baseline commit deliberately.
4. **More untracked entries than listed.** Beyond `Claude/`,
   `new_doctrine/`: `FitAgent/]`, `FitAgent/lib/FitAgent/tasks/agent_ask.rb`,
   `FitAgent/share/`, `bin/`, `doctrine_bundle/`,
   `research/claude-meta-evidence/`, plus the `tmp/redesign_audit_*`
   probes (gitignored). None disturbed.
5. **new_doctrine/work/ now contains four files**, including the already
   landed `redesign-audit-context.md` (the misrouted round's Phase 0
   deliverable) plus three older `*-reader-split.md` reports that
   predate the redesign.
6. HEAD moved from the snapshot cut to `e6ead1b` (2026-11-01 12:32:57
   +0100), which includes the Claude-wrapping work.

## 6. How to detect later out-of-scope edits

Tracked files:

```bash
git diff 1116c9a --name-only          # vs baseline commit
# or, from the current branch tip:
git diff 1116c9a7cdd3714c9d8d24d26be063ca68b649b6 --name-only
```

Untracked/never-committed areas (audit packets, scratch) are invisible to
`git diff` against the baseline; check them by listing:

```bash
ls new_doctrine/work/ ; ls tmp/redesign_audit_*
```

`redesign-*` deliverables live only in `new_doctrine/work/`.

## 7. Rollback instructions

- Discard uncommitted edits after the baseline (tracked files):
  `git checkout -- .` from `ags-redesign` (or `git restore .`), then
  confirm with `git status --porcelain` that only the known untracked
  entries remain.
- Return the branch pointer to the baseline (drops commits made after it,
  keeping working tree):
  `git reset --soft 1116c9a` (keep changes staged) or
  `git reset --hard 1116c9a` (**destructive**: discards post-baseline
  tracked edits too; untracked files survive).
- Full checkpoint restore: `git checkout ags-redesign` and
  `git reset --hard 1116c9a7cdd3714c9d8d24d26be063ca68b649b6`; `main`
  is untouched at `e6ead1b` and can be re-entered with
  `git checkout main`.
- The baseline does not capture untracked files; `new_doctrine/`,
  `tmp/redesign_audit_*`, `doctrine_bundle/`, etc. have no baseline copy
  in git (by design, per the plan's "do not add untracked" rule).
