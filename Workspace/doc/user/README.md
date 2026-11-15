# Workspace user documentation

Practical guides for agents calling Workspace tasks. The top-level
[Workspace README](../../README.md) is the task catalog (all 24 tasks, one
entry each); the files here carry the operational detail behind them.

- [Sandbox, execution and output handling](SandboxAndOutputs.md) — sandbox
  semantics, the two permission layers (Ruby allowlist for filesystem tasks
  vs bwrap mounts for exec tasks), choosing `write` vs `patch` vs
  `precise_edit`, examples, and where job outputs land. Read this before
  debugging path access.
- [Working with TSV files](TSV.md) — per-input detail for the eight TSV
  tasks (`tsv_info`, `tsv_read`, `tsv_query`, `tsv_edit`, `tsv_merge`,
  `tsv_attach`, `tsv_translate`, `tsv_sort`), Scout TSV value types, and
  how to combine the tasks.

Agent Skills for this workflow live in [Workspace skills](../../skills/):
`workspace-execution`, `workspace-files`, `workspace-tsv`. Each skill
references the canonical docs here by project-qualified path.

Cortex tools (conversation/brief/artifact operations) are owned by the
Cortex workflow — see `Cortex/doc/user/WorkspaceTools.md` — and are not part
of Workspace.

Developer material (dependencies, testing, export surface) is in
[developer documentation](../developer/README.md).
