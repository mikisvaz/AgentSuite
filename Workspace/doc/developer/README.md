# Workspace developer documentation

Implementation, environment, testing and cross-repo material for the
Workspace workflow. Agent-facing usage lives in `Workspace/README.md` and
[doc/user/SandboxAndOutputs.md](../user/SandboxAndOutputs.md); this file
owns the developer view.

## Dependencies and environment

- Ruby and the Scout/Rbbt environment (the workflow extends Workflow)
- The system `patch` utility for the patch task
- bwrap for sandboxed execution (optional; see below)

## Layout

- `workflow.rb` — entrypoint; requires the task files and declares the
  export surface (`export_exec` for the filesystem/exec/patch/precise_edit
  tasks; the eight TSV tasks exported as regular workflow tasks).
- `lib/Workspace/tasks/` — task implementations (`filesystem.rb`,
  `exec.rb`, `patch.rb`, `precise_edit.rb`, `tsv.rb`, and the
  exec/sandbox helpers).
- `doc/user/` — agent-facing usage (TSV.md, SandboxAndOutputs.md).
- `test/Workspace/tasks/` — task implementation tests (see Testing).

## Export surface

All Workspace tasks are exported for use by other workflows: `write`, `read`,
`list_directory`, `file_stats`, `pwd`, `copy`, `delete`, `search`,
`sandbox_paths`, `bash`, `python`, `ruby`, `r`, `patch`, and `precise_edit`
are exported for direct execution (`export_exec`), and the eight TSV tasks
are exported as regular workflow tasks. No Workspace task is internal-only.
Verified against `Workspace/workflow.rb` and a live task listing (24 tasks
registered; see `doc_redesign/baseline/Workspace.json`).

## Testing

From the Workspace workflow directory, the task implementation tests can be
run with:

```bash
ruby -Itest test/Workspace/tasks/test_tsv.rb
ruby -Itest test/Workspace/tasks/test_exec_helpers.rb
ruby -Itest test/Workspace/tasks/test_patch.rb
ruby -Itest test/Workspace/tasks/test_precise_edit.rb
```

They cover the TSV suite, the sandbox/exec helpers, patch conversion, and
precise_edit; they do not require network services or external CLIs, and they
do not test or modify ComputerUse or Research.

`test/Workspace/tasks/test_filesystem.rb` also exists in the tree and is not
listed by the historical README test block (noted during the step-2 audit;
adding it to the block above is a small open item).

## Exec-output condensation internals

The `stderr` condensation performed by the exec tasks (root-cause-first
reordering, `[x N]` collapse, backtrace-frame dropping, argv summarization,
`... [N lines omitted] ...` markers, `stderr_full` persistence) is
implemented in the exec/sandbox helpers under `lib/Workspace/tasks/`
(`exec.rb`); the user-facing contract is documented in
[doc/user/SandboxAndOutputs.md](../user/SandboxAndOutputs.md) § "Output
handling and `stderr_full`".

## bwrap details

Execution is unsandboxed when bwrap is not available in the system or when
`BWRAP_PATH` is set to `false`; the mount lists are built from the same
allowlists as the Ruby permission layer plus exec extras. The authoritative
sandbox model (which tools are confined, the two permission layers, recovery
for a path a tool cannot see) is the scout-ai developer document
`doc/developer/Sandbox.md` (§2 "Which paths can this action reach?") —
cross-repo pointer, verified present in the scout-ai checkout.

## Cross-repo pointers (verified)

- scout-ai `doc/developer/Sandbox.md` — sandbox model, which tools are
  confined, recovery for a path a tool cannot see.
- scout-ai `doc/user/ToolCalling.md` (§ "Exposing an entire workflow") —
  why every exported task here appears as a callable tool to an agent.
- scout-gear `doc/user/ProcessingTabularData.md` — TSV value types
  (`single`/`list`/`flat`/`double`), opening options, `sep2`.
- scout-essentials `doc/user/WorkingWithFiles.md`,
  `doc/user/RunningCommands.md`, `doc/user/HandlingStreams.md` — the `Open`
  and `CMD` layers beneath code run through `bash`/`python`/`ruby`/`r`.

Mirrors `doc/developer/ToolingDocumentation.md` pointer policy; that file
owns the convention.
