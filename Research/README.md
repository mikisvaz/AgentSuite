Scientific interpretation for Scout workflows

The durable scientific record — observations, claims and hypotheses as agent Path kinds — plus the record-store maintenance operations around them. Source acquisition (web search, document conversion, retrieval-augmented querying) has moved to the Reader workflow ([Reader README](../Reader/README.md)); Research consumes Reader dossiers and owns the interpretation and the record.

Research registers no workflow tasks of its own today; the only registrations are the three record Path kinds, exposed to agents as path-kind operations (`register`, `path_edit`) rather than as tasks. The workflow still requires Workspace and merges its helpers (`workflow.rb` does `Workflow.require_workflow 'Workspace'` and `Research.helpers.merge!(Workspace.helpers)`); the require exists for the path-kinds engine's command execution, not for any task.

**See also (verified pointers)**

- [Reader README](../Reader/README.md) — source acquisition: `searxng`, document conversion, excerpting and RAG retrieval, formerly Research's tasks.
- [Workspace README](../Workspace/README.md) — the required workflow whose helpers (`cmd_json` and friends) execute external commands.
- [doc/user/README.md](doc/user/README.md) — using the record kinds: register/edit rules, citing tool results.
- [doc/developer/README.md](doc/developer/README.md) — path-kind registration mechanics, the link vocabulary, sources model, testing.

**The record kinds (agent-facing summary)**

- **observation** (`OBS-###`) — a recorded result or measurement tied to at least one source: *what was observed and from what provenance*.
- **claim** (`C-###`) — an assertion tracked through an evidential lifecycle (`proposed` → `supported`/`qualified`/`contradicted` → `superseded`): *what is being asserted*, linked to the observations and claims that support, contradict or qualify it.
- **hypothesis** (`H-###`) — a candidate explanation with predictions (`proposed` → `under_test` → `consistent_with_evidence`/`weakened`/`rejected`/`unresolved` → `superseded`): *what would explain the observations and how it could fail*.

The only way to create a record is the shared `register` operation; records mutate only through `path_edit` (versioned edits, history snapshots); `write`, `move`, `rename` and `delete` are disabled for all three kinds. Validation separates record integrity (hard errors that reject the operation) from scientific assessment (warnings reported to the author).

The authoritative contract for schemas, lifecycle and validation is [research/path-kinds-spec.md](research/path-kinds-spec.md); the implementation lives in `lib/Research/path_kinds/`.

This README describes the Path kinds registered by `Research/workflow.rb` through `lib/Research/path_kinds.rb`.
