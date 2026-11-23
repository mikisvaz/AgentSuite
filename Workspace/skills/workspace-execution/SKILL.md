---
name: workspace-execution
description: "Run bash, Python, Ruby or R code through the Workspace exec tasks with fresh-process discipline and durable provenance. Use when an agent must run a shell command or a script, compute a value, reproduce a calculation, decide which language surface fits the job, or interpret exec task failures such as bounded streams, failure_kind classification or sandbox launch errors. Triggers: bash, python, ruby, r, \"run command\", \"execute script\", \"compute\", \"stderr_full\", \"stdout_full\", \"exit_status\", \"failure_kind\", \"fresh process\", \"return_path\", \"reproducible check\", \"bwrap\"."
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
- All four surfaces share one child runner: the cwd is the same in host
  and bwrap modes, and the reported `execution_mode` tells you which one
  ran (`bwrap` or `host_fallback`; the fallback policy is unchanged).
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

## Reading exec results (faithful by construction)

- Every exec task returns `{stdout, stderr, exit_status}` as JSON. An
  ordinary nonzero exit returns the REAL exit code and is a real result —
  read it, do not treat the call as failed tooling. `-1` appears only when
  no exit code exists.
- A classified failure additionally carries the additive `failure_kind`:
  `timeout`, `signal`, `launch` or `runner_exception`.
- Streams are never dropped or reordered. Small child stderr is returned
  verbatim — including EMPTY stderr — and stdout is preserved
  independently of stderr: a quiet stderr never hides a loud stdout.
- When a stream is oversized, `stderr`/`stdout` carry an in-order
  head/tail excerpt whose byte budget INCLUDES the elision markers. The
  complete stream is spooled to a file under the step's `files_dir` and
  referenced as `stderr_full`/`stdout_full`; both are readable with the
  exported `read` tool in the same caller context.
- Sandbox launch failures surface as the launcher argv in debug
  diagnostics; treat them as environment constraints, consult
  `sandbox_paths` (see the workspace-files skill), and use a path spelling
  the sandbox can see (`failure_kind: 'launch'`).

## Task cheat sheet

| Need | Task |
|---|---|
| Shell command / pipeline / checksums | `bash` |
| Numeric or data computation | `python` |
| Ruby / Scout-ecosystem computation | `ruby` |
| R analysis | `r` |
| Current time with UTC offset | `current_time` |
| Where jobs and their outputs live | see workspace-files skill |

## Common mistakes

- Reading only `exit_status` and skipping `stdout` — tool success is not
  correctness; read what the run actually produced.
- Treating empty stderr as "dropped" — an ordinary nonzero exit returns
  empty stderr verbatim; nothing is elided for small streams.
- Inlining multi-line scripts into `bash -c` and losing them to quoting —
  write the script file first.
- Expecting variables from a previous exec call to persist — fresh process
  every time.
- Chasing a "vanished" result in stderr instead of reading
  `stdout_full`/`stderr_full` under the job's `files_dir`.
- Repeating an identical failing command — change one variable or switch
  surface after two failures.

## Going deeper (repo-relative pointers, optional)

- `Workspace/doc/user/SandboxAndOutputs.md` — sandbox execution model,
  output handling and `stdout_full`/`stderr_full`, examples.
- `Workspace/README.md` — the `# Tasks` entries for `bash`, `python`,
  `ruby`, `r`, `current_time`.
- scout-essentials `doc/user/RunningCommands.md`,
  `doc/user/HandlingStreams.md` — the `CMD`/`Open` layers beneath the exec
  tasks (external to this repo).
