---
name: workspace-files
description: Read, write, edit, search and manage files under the Workspace workflow root with the right tool each time. Use when an agent must create or rewrite a file, make a count-checked exact edit, apply a patch, read or inspect a file or directory, copy/delete files, or when a path was rejected by a Workspace tool and the sandbox permission model needs to be consulted. Triggers: write, read, patch, precise_edit, copy, delete, search, list_directory, file_stats, sandbox_paths, "workflow root", "sandbox permissions", "rejected path", "choose edit tool", "where do job outputs land".
---

# Workspace file operations (sandbox-aware)

## What this skill covers

Choosing the right Workspace task for file work, and the sandbox rules that
decide which paths each task can reach. The eight TSV tasks are covered by
the separate root skill `skills/scout-tsv-toolkit/SKILL.md` — do not
duplicate that here.

## Scope: the workflow root

`read`, `write`, `delete`, `search`, `list_directory` and `file_stats`
check that input paths are under the current process working directory
(PWD). Paths outside it are rejected by design. Generated job outputs from
your own work are also accessible.

## Choosing the write/edit tool (decision is self-contained here)

- A Scout workflow source draft (task/entity/property/test file) → ScoutCoder
  `path_write` (`kind=task path=greet_user`): validated root, no extension
  to remember, and a workflow reload registers the draft. Not a Workspace
  concern, but the split avoids misfiring `write` at ScoutCoder drafts.
- An ordinary file (results, notes, data) → Workspace `write`; the path
  tools reject non-registered paths by design.
- One exact replacement (you know the text and its occurrence count) →
  `precise_edit`; it is count-checked (`expect_matches`) and hash-guarded.
- A localized diff to an existing file → `patch` (ChatGPT-style or unified
  diff; auto-detects strip; use `dry_run` to test).
- Whole-file rewrite or a new file → `write` (preferred over a large patch
  for generated content).
- A python/ruby script is never the right edit tool: it skips count/hash
  verification and leaves no diff diagnostics.
- Do not use `patch` to add or delete files — use `write` and `delete`.

## Sandbox rules that decide reachability

- Two permission layers do not always coincide: the file tasks above are
  checked in Ruby against an allowlist (workflow root plus configured
  writable/readable paths), while `bash`/`python`/`ruby`/`r`/`patch` run
  inside a bwrap sandbox built from the same lists plus exec extras. A path
  can be readable from `bash` but rejected by `read`, or granted by the
  allowlist yet bound read-only inside bwrap.
- On a rejected path, do not retry the same call: run `sandbox_paths` and
  read the inventory (every allowed read/write path, symlink targets and
  realpaths, origin of each permission, planned bwrap mounts with ro/rw).
  One tool's restriction says nothing about another's.
- Symlink spelling matters: a `/home/...` spelling can be invisible inside
  the bash sandbox while the `/bulk/...` realpath works everywhere. Use the
  realpath spelling.
- Execution is unsandboxed when bwrap is missing or `BWRAP_PATH=false`.

## Where outputs land

Every task runs as a Scout job under the workflow checkout's
`var/jobs/Workspace/…`; each job carries a `.files` sidecar directory for
auxiliary outputs; the harness `return_path` option returns the persisted
result file inside the job directory. A result that "vanished" is a
job-directory question, not a reason to re-read stderr or write a locator
script.

## Task cheat sheet

| Need | Task |
|---|---|
| Read a file (head/tail, line window) | `read` |
| List a directory (files/dirs, optional stats) | `list_directory` |
| Basic stats (size, lines, mtime) | `file_stats` |
| Write/rewrite a file or create a new one | `write` |
| One count-checked exact replacement | `precise_edit` |
| Apply a diff (ChatGPT-style or unified) | `patch` |
| Copy a file or directory recursively | `copy` |
| Delete a file or directory | `delete` |
| Literal content search under a directory | `search` |
| Effective sandbox permissions | `sandbox_paths` |
| Current working directory | `pwd` |

## Common mistakes

- Retrying a rejected path unchanged — read `sandbox_paths` first.
- Editing a shared file with `bash`/`sed` or a python script instead of
  `precise_edit`/`patch`: no verification, no diagnostics.
- Expecting `patch` to create or delete files — it cannot; use
  `write`/`delete`.
- Editing a Scout workflow draft with `write` instead of ScoutCoder
  `path_write` (the draft then lives outside the validated root).
- Writing scratch files into the repo root instead of `tmp/`, `results/`
  or `sandbox/`.

## Going deeper (repo-relative pointers, optional)

- `Workspace/doc/user/SandboxAndOutputs.md` — sandbox model, the two
  permission layers, scratch-file etiquette, output handling, job trees.
- `Workspace/README.md` — the `# Tasks` entries for every file task.
- `Workspace/doc/user/TSV.md` — per-task TSV detail (or see the root TSV
  skill).
- scout-ai `doc/developer/Sandbox.md` §2 — which paths each action can
  reach (external to this repo).
