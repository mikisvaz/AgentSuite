---
name: workspace-execution
description: "Run bash, Python, Ruby or R code through the Workspace exec tasks with fresh-process discipline and durable provenance. Use when an agent must run a shell command or a script, compute a value, reproduce a calculation, decide which language surface fits the job, or interpret exec task failures such as condensed stderr or sandbox launch errors. Triggers: bash, python, ruby, r, \"run command\", \"execute script\", \"compute\", \"stderr_full\", \"exit_status\", \"fresh process\", \"return_path\", \"reproducible check\", \"bwrap\"."
---

# Workspace execution (bash / python / ruby / r)

## What this skill covers

Choosing among the four Workspace execution surfaces, running them with
reproducibility and provenance, and reading their structured results.
File-tool choice and sandbox permission inspection are covered by the
sibling skill `Workspace/skills/workspace-files/SKILL.md`; tabular data by
`Workspace/skills/workspace-tsv/SKILL.md`.

## Choosing the surface (decision is self-contained here)

- `bash` — shell one-liners, file plumbing, pipelines, `sha256sum`,
  `git status`, building directory listings. Not for code with quoting
  hazards.
- `python` — numeric/data computation, parsing JSON, quick statistics.
- `ruby` — Ruby computation; the environment beneath everything (Scout
  TSV, `Open`, `CMD`), so it is the natural surface for Scout-ecosystem
  checks (`require "scout"`; e.g. parsing workflow documentation).
- `r` — R-specific analysis.
- Each invocation is a FRESH process: variables, ambient imports and
  state from previous calls do not carry over. When behavior depends on
  prior state, encode it in files, not in call order.
- Write scripts with the Workspace `write` task and run them by path; do
  not inline script bodies in `bash -c` strings where quoting can corrupt
  them. Iterate in `tmp/`, ship results from the results area.

## Reproducibility conventions

- Pin inputs explicitly (files, options); never rely on ambient state,
  caches or call order for a claim that matters.
- When behavior may depend on process state, test it in a fresh process —
  a warm-state success is not standalone correctness.
- Keep commands and outputs in files (a script under `tmp/`, results in
  `results/`) so the work stays re-runnable; cite the job path for a
  durable provenance trail.
- Cap probe iterations: after two consecutive identical failures, change
  one material variable or switch surface instead of repeating the call.

## Reading exec results

- Every exec task returns `{stdout, stderr, exit_status}` as JSON. A
  non-zero exit is a real result — read it, do not treat the call as
  failed tooling.
- On failure or huge error streams, `stderr` is condensed root-cause-first
  (distinct error lines hoisted, repeats collapsed as `line [x N]`,
  framework backtraces dropped, giant argv dumps summarized, long streams
  cut with `... [N lines omitted] ...`). The complete stream is preserved
  on disk and its path returned in `stderr_full` — read that file when the
  condensed view is not enough.
- Sandbox launch failures surface as the bwrap argv in stderr; treat them
  as environment constraints, consult `sandbox_paths` (see the
  workspace-files skill), and use a path spelling the sandbox can see.

## Task cheat sheet

| Need | Task |
|---|---|
| Shell command / pipeline / checksums | `bash` |
| Numeric or data computation | `python` |
| Ruby / Scout-ecosystem computation | `ruby` |
| R analysis | `r` |
| Exact current time (also registered on the deprecated ComputerUse) | `current_time` |
| Where jobs and their outputs live | see workspace-files skill |

## Common mistakes

- Reading only `exit_status` and skipping `stdout` — tool success is not
  correctness; read what the run actually produced.
- Inlining multi-line scripts into `bash -c` and losing them to quoting —
  write the script file first.
- Expecting variables from a previous exec call to persist — fresh process
  every time.
- Chasing a "vanished" result in stderr instead of checking the job
  directory (`var/jobs/Workspace/…`, `.files` sidecar).
- Repeating an identical failing command — change one variable or switch
  surface after two failures.

## Going deeper (repo-relative pointers, optional)

- `Workspace/doc/user/SandboxAndOutputs.md` — sandbox execution model,
  output handling and `stderr_full`, examples.
- `Workspace/README.md` — the `# Tasks` entries for `bash`, `python`,
  `ruby`, `r`, `current_time`.
- scout-essentials `doc/user/RunningCommands.md`,
  `doc/user/HandlingStreams.md` — the `CMD`/`Open` layers beneath the exec
  tasks (external to this repo).
