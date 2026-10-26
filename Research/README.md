Research

Scientific interpretation for Scout workflows: the durable scientific record — observations, claims and hypotheses as agent Path kinds — plus the record-store maintenance tasks around them. Source acquisition (web search, document conversion, retrieval-augmented querying) has moved to the Reader workflow ([Reader README](../Reader/README.md)); Research consumes Reader dossiers and owns the interpretation and the record.

Reader requires Workspace and merges its helpers; so does Research — `workflow.rb` does `Workflow.require_workflow 'Workspace'` and `Research.helpers.merge!(Workspace.helpers)` — and the remaining tasks keep using those helpers. The record Path kinds are local to Research and need none of them.

## See also (verified pointers)

- [Reader README](../Reader/README.md) — source acquisition: `searxng`, document conversion, excerpting and RAG retrieval, formerly Research's tasks.
- [Workspace README](../Workspace/README.md) — the required workflow whose helpers (`cmd_json` and friends) execute external commands.

## Scientific record Path kinds

Research declares three agent Path kinds — **observation**, **claim**, **hypothesis** — for the durable scientific record. They register when the whole Research workflow is incorporated as a tool (`tool: Research`); a task-level tool line registers nothing.

- **observation** (`OBS-###`) — a recorded result or measurement tied to at least one source. Use it when the point is *what was observed and from what provenance*. Registering an observation without any source is rejected.
- **claim** (`C-###`) — an assertion the record store tracks through an evidential lifecycle (`proposed` → `supported`/`qualified`/`contradicted` → `superseded`). Use it when the point is *what is being asserted*, with links to the observations and other claims that support, contradict or qualify it.
- **hypothesis** (`H-###`) — a candidate explanation with predictions (`proposed` → `under_test` → `consistent_with_evidence`/`weakened`/`rejected`/`unresolved` → `superseded`). Use it when the point is *what would explain the observations and how it could fail*.

**The only way to create a record is the shared `register` operation** (one tool across all three kinds): it allocates the ID from an atomic per-kind counter inside a lock, validates the complete record, writes the body and its `.info` sidecar atomically, and returns the ID and path. Agents never allocate IDs. `statement` is required; `sources` is required in effect for observations; `title`, `scope`, `links`, `limitations` and the per-kind fields (`value` for observations; `predictions`, `test_ideas`, `assessment` for hypotheses; `assessment` for claims) are optional. `status` and `version` are system-managed and rejected as inputs.

**Records mutate only through `path_edit`.****Citing tool results (`tool_result`, return_path).** Sources may now use the general type `tool_result`: the `ref` cites the persisted result of any tool invocation — an absolute path, or a Research-root-relative path — resolving to an existing file inside a persisted job tree (`var/jobs/<Workflow>/<task>/...` with result + `.info`, at either the checkout root or the user-global `~/.scout/var/jobs`) or a named durable store (`var/records-attachments/`). Non-exec tool calls return the durable path in `receipt.job.path` (or as the `return_path` answer); cite that path. A temporary result (TmpFile/exec-mode scratch, temp roots) is never silently registered: either promote it first with the `promote_tool_result` operation (copies the bytes into `var/records-attachments/<destination>/` and returns the durable path to cite) or re-run the tool non-exec and cite the returned job path. `locator` for a `tool_result` source is one minimal string `kind:value` with kind in {row, range, line, section}. A missing `digest` is a warning; a recorded digest that no longer matches its file is a hard error at edit/validate. The full contract is `research/return-path-citation-contract.md`.
 An edit must carry the version line of the record it was read from; if the record has moved on, the edit fails as stale with a re-read instruction, and the prior body is snapshotted under `history/<ID>.v<N>.yaml` before the version is bumped. Never renumber or delete history. `write`, `move`, `rename` and `delete` are disabled for all three kinds — records are born through `register` and change through versioned edits.

**Validation separates record integrity from scientific assessment.** Hard errors (missing/ill-typed fields, unknown top-level keys, invalid status or transition, malformed links, relationship not allowed between the source and target kinds, broken local references, duplicate IDs) reject the operation. Warnings — a hypothesis with no predictions yet, a proposed claim not yet challenged, an unreachable external source, a mutable source with no digest, a claim that has not considered counterevidence, a non-re-executable derivation, a link whose target is invalidated or superseded — never block, they are reported for the author to consider. Backlinks and reference resolution are derived at validate/list time by scanning the records; they are never stored or maintained by hand.

**Link vocabulary** (direction: from the linking record to `target`):

| from \ relationship | `supported_by` | `contradicted_by` | `qualified_by` | `motivated_by` | `explains` | `supersedes` | `related_to` |
|---|---|---|---|---|---|---|---|
| observation | → observation | → observation | → observation | | | → observation | → any |
| claim | → observation, claim | → observation, claim | → observation, claim | | | → claim | → any |
| hypothesis | | → observation, claim | | → observation, claim | → observation, claim | → hypothesis | → any |

The observation row is the chosen symmetric closure reported in step 3 (the spec tabulates claim and hypothesis only); it is pending user adjudication.

**Sources reference provenance without copying it.** A source entry is `{type, ref}` plus optional `locator` and `digest`, with `type` one of `file`, `entity_property`, `task`, `workflow`, `external`. Local `file`/receipt refs must resolve at registration time (a broken local path is a hard error); `external` URLs are never fetched by the validator (reachability is a warning only); unknown-but-well-formed types are accepted as opaque with a warning.

The authoritative contract for schemas, lifecycle and validation is [research/path-kinds-spec.md](research/path-kinds-spec.md); the implementation lives in `lib/Research/path_kinds/`.

## Testing

Run from the Research checkout root:

```bash
ruby -Itest test/Research/tasks/test_registration.rb
```

and the record-kinds suites from the same root: `ruby -Itest test/Research/path_kinds/test_records.rb`, `.../test_path_kinds_engine.rb`, `.../test_spec9_matrix.rb` (the last includes fork-based concurrency tests). Together they cover workflow loading, that none of the 11 tasks moved to Reader is registered on Research, that the Workspace helpers stay merged, and the full scientific-record Path-kinds contract. They do not require network services, LLM credentials, or document-conversion programs. The deterministic excerpting test that used to live here moved with the `excerpts` task to Reader.

The registration test loads `Research/workflow.rb`, which resolves Workspace through `Workflow.require_workflow 'Workspace'`; an environment that cannot resolve the Workspace workflow fails at load time with `Workflow Workspace not found` — an environment/visibility failure (for example, running inside the Workspace bwrap sandbox, which cannot see `~/.scout` where the Workspace agent install lives), not a code defect.

Research registers no workflow tasks of its own today; the only registrations are the three record Path kinds. Reader's 11 source-acquisition tasks are registered on Reader, not Research.

This README describes the Path kinds registered by `Research/workflow.rb` through `lib/Research/path_kinds.rb`.
