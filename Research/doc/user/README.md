# Research user documentation

Research keeps the scientific record as versioned dossiers — one per
question, claim or hypothesis — each holding authored Markdown documents,
attached evidence and an immutable revision history. The store lives at
`<working project>/research/`; the root is fixed, so no call takes a path
argument.

## Choosing the first call

- **Start a record**: `dossier_create` with `type` (`question`, `claim` or
  `hypothesis`), `title` and optional `content`. Note the returned `id`
  (e.g. `Q-001`) and `revision`; every later call takes the `id`, and
  every mutation takes the `revision` you last read as
  `expected_revision`.
- **Back it with evidence**: `evidence_attach` with `id`,
  `expected_revision` and `items` — one `{source, slot, mode}` object per
  file; `mode: copy` retains the bytes, `mode: reference` keeps only the
  source identity and digest.
- **Revise the text**: `dossier_update` with `expected_revision` and a
  `mode`; line modes address the one-based half-open span reported by
  `dossier_read`.
- **Find and inspect**: `dossier_list` (`query`, `type`) to locate
  dossiers; `dossier_read` for documents (`overview: true` for a compact
  orientation), `evidence_read` for attachments, `dossier_history` for
  past revisions and diffs.
- **Integrity**: `dossier_check` after crashes, interrupted calls or
  external edits; `dossier_capture` is the only way to adopt externally
  edited documents as a new revision.

## Representative path

```
dossier_create   {type: question, title: "Does the intervention change the endpoint?"}
                   -> {id: Q-001, revision: 1, ...}
evidence_attach  {id: Q-001, expected_revision: 1,
                  items: [{source: "results/endpoint.tsv", slot: "data", mode: "copy"}]}
                   -> {revision: 2, items: [{attachment: "data/endpoint.tsv", ...}]}
dossier_read     {id: Q-001}
                   -> {revision: 2, start_line: 1, end_line: 3, ...}
dossier_update   {id: Q-001, expected_revision: 2, mode: "replace_lines",
                  start_line: 2, end_line: 2, replacement: "answer line"}
                   -> {revision: 3, changed: true}
```

Evidence sources are absolute paths or paths relative to the working
project; a model-supplied path is never a permission grant, and
references under temporary roots are rejected as ephemeral.

Deeper guides for less common cases:

- [Task reference](Tasks.md) — every task with its real registered
  inputs, output shapes and error cases.
- [Walkthrough](Walkthrough.md) — the working loop, relative evidence
  sources, references versus copies, safe line editing and error
  recovery.
