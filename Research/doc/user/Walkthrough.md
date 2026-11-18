# Using Research

The [task reference](Tasks.md) lists every task with its real registered
inputs and output shapes. This page is a short runnable walkthrough of the
normal working loop, with the behaviors most likely to surprise: relative
evidence sources, references versus copies, safe line editing and error
recovery. All examples are real payloads produced by running the tasks
in a temporary project.

## The working loop

1. `dossier_create` a question; note the returned `id` and `revision`.
2. Attach evidence with `evidence_attach` as you produce it, citing the
   producing script in the item.
3. Edit the entry document with `dossier_update` (line edits preserve
   history; `change_note` records why).
4. `dossier_read` / `evidence_read` to inspect; `dossier_history` for what
   changed; `dossier_check` for mechanical integrity.
5. Link dossiers with the Markdown links the tasks return
   (`[C-001](…/claims/C-001/README.md)`) and check them with
   `dossier_check`.

## Relative evidence sources

`evidence_attach` items accept a `source` that is absolute or relative.
A **relative** source resolves against the working project — the same
base the sandbox uses — so `{"source": "results/endpoint.tsv", "slot":
"data"}` attaches `<working project>/results/endpoint.tsv`
(`attach_relative.json`).

`base_path` is **not** part of the item schema and is rejected:

```
items[0]: base_path is not part of the item schema; relative sources
resolve against the working project (the process cwd), and absolute
sources are used as-is
```

Resolving a relative path does not authorize it: the source must still be
inside the process's sandbox read grants, and a path outside them is
rejected with the reason (`escape.json`):

```
evidence source "/home/<user>/nope.tsv" is outside the granted paths for
read access (reason: outside_grants); a model-supplied path is not a
permission grant
```

Destination escapes (traversal in `slot`/`name`) are rejected the same
way.

## References versus copies

Two attach modes, one durable record each:

- **`copy`** retains the exact bytes in the dossier's content-addressed
  store; the recorded digest is computed from the retained bytes. Later
  edits to the original file do not change the evidence
  (`attach.json`, `evidence_read.json`).
- **`reference`** retains the source identity plus the digest observed at
  attach time (`attach_reference_durable.json`,
  `evidence_read_reference.json` — `integrity` reports whether the
  referenced source still hashes to that digest).

References under temporary roots are rejected as **ephemeral** — they
would not survive the producing process:

```
ephemeral reference: "/tmp/.../tmp_src.tsv" resolves under a temporary
root (C2/R10: it does not survive the producing process). Remedy: attach
with mode "copy" to promote the bytes into the dossier store, or cite a
durable artifact (job-tree result file, var/records file) instead.
```

A reference to a durable job-tree result (a persisted
`var/jobs/<Workflow>/<task>/` result file) attaches cleanly.

## Safe line editing

`dossier_read` always returns the revision and the exact line range of
the content it returned (`start_line`, `end_line`, `lines_returned`,
`total_lines`, `continuation` for paging). Use them for line edits:

```
dossier_read   {id: Q-001}          # revision 2, start_line 1, end_line 3
dossier_update {id: Q-001, expected_revision: 2, mode: "replace_lines",
                start_line: 2, end_line: 2, replacement: "answer line"}
```

Spans are **one-based and half-open** — `[start_line, end_line)` — and
`nil` `end_line` means "through end of document". `delete_lines` uses the
same span and needs no replacement text. An out-of-range span is rejected
with the valid range in the message (`range_error.json`):

```
RangeError: start_line 99 out of range: with 3 line(s), valid start_line
is 1..4 (dossier Q-001 at root <project>/research)
```

A no-op edit returns `changed: false` and creates no revision.

## Error recovery

- **Stale revision** (`stale.json`): another writer committed after you
  read. Re-read the dossier, re-apply your edit against the new revision.
  The message names both revisions:

  ```
  StaleRevision: stale mutation of Q-001: current revision is 3; caller
  expected 1; re-read the dossier and re-apply the mutation
  ```

- **Path escape**: see above — use a source inside your grants or an
  authorized absolute path; never treat a model-supplied path as a grant.
- **Placeholder-text guard** (`placeholder_guard.json`): transcript
  compaction markers (`TOOL-COMPACTION-RECORD`) in `title`, `content`,
  `replacement` or `change_note` are rejected — re-read the durable
  source and write the real content:

  ```
  change_note contains the transcript compaction marker
  "TOOL-COMPACTION-RECORD": compaction placeholders are pointers, never
  evidence — re-read the durable source and write the real content
  instead of persisting transcript metadata
  ```

- **Lost response**: mutations are linearized at the pointer swap; if a
  call's response is lost, re-read to observe whether it landed instead
  of re-sending blind.
- **Attachment not found**: the error lists the attachment keys the
  dossier actually has at that revision.
