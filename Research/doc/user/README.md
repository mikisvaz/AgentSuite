# Using Research records (user guide)

How agents work with the durable scientific record — observations, claims
and hypotheses — declared by the Research workflow. The workflow
introduction is in `Research/README.md`; registration mechanics, the link
vocabulary, the sources model and testing are in
[doc/developer/README.md](../developer/README.md). The authoritative
contract is [research/path-kinds-spec.md](../../research/path-kinds-spec.md).

## The three kinds

- **observation** (`OBS-###`) — a recorded result or measurement tied to
  at least one source. Use it when the point is *what was observed and
  from what provenance*. Registering an observation without any source is
  rejected.
- **claim** (`C-###`) — an assertion the record store tracks through an
  evidential lifecycle (`proposed` → `supported`/`qualified`/
  `contradicted` → `superseded`). Use it when the point is *what is being
  asserted*, with links to the observations and other claims that support,
  contradict or qualify it.
- **hypothesis** (`H-###`) — a candidate explanation with predictions
  (`proposed` → `under_test` → `consistent_with_evidence`/`weakened`/
  `rejected`/`unresolved` → `superseded`). Use it when the point is *what
  would explain the observations and how it could fail*.

## Creating records

The only way to create a record is the shared `register` operation (one
tool across all three kinds). Agents never allocate IDs; `register` does
that atomically and returns the ID and path. `statement` is required;
`sources` is required in effect for observations; `status` and `version`
are system-managed and rejected as inputs.

## Editing records

Records mutate only through `path_edit`. An edit must carry the version
line of the record it was read from; if the record has moved on, the edit
fails as stale with a re-read instruction, and the prior body is
snapshotted under `history/<ID>.v<N>.yaml` before the version is bumped.
Never renumber or delete history. `write`, `move`, `rename` and `delete`
are disabled for all three kinds — records are born through `register`
and change through versioned edits.

## Citing tool results (`tool_result`, return_path)

When a source is the output of a tool run, cite the persisted result with
the `tool_result` source type rather than copying bytes: non-exec tool
calls return the durable job path (`receipt.job.path`, or the
`return_path` answer); cite that path as `ref`. Temporary results are
never silently registered — promote them with `promote_tool_result`
(copies the bytes into `var/records-attachments/<destination>/` and
returns the durable path) or re-run the tool non-exec and cite the job
path. Give a `locator` (`kind:value`, kind in {row, range, line, section})
and a `digest`; a missing digest is a warning, a stale digest a hard
error. Full contract:
[research/return-path-citation-contract.md](../../research/return-path-citation-contract.md).
