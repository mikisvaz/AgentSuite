Research dossiers: versioned records for scientific questions, claims and hypotheses.

Every dossier holds authored Markdown documents, attached evidence and an
immutable revision history. Mutations are revisioned with optimistic
concurrency: pass the revision you read as `expected_revision`; a mismatch
rejects the change with a `StaleRevision` message naming both revisions.

Dossier types and ID prefixes: `question` (one answerable scientific
question, `Q-###`), `claim` (a bounded statement the attached evidence
supports, `C-###`), `hypothesis` (a falsifiable explanation with
predictions, `H-###`).

Storage layout:

The store is fixed and project-relative:

```
<working project>/research/
  questions/Q-001/     # one dossier per directory
  claims/C-001/
  hypotheses/H-001/
```

The root resolves at execution time from the working project; there is no
configuration, environment variable or per-call path input. Other
contents of `research/` are not the store's and stay untouched. Inside a
dossier, `README.md`, `supplements/` and `evidence/<slot>/<name>` are
machine-materialized views of the current revision; the durable truth is
the content-addressed object store `store/objects/<sha256>` plus the
immutable revision records `store/history/rN.json`. Attachment bytes and
history are never rewritten by later edits.

# Tasks

## dossier_create
Start a new dossier: allocate its ID and write the first revision.

Use when a new question, claim or hypothesis enters the record. Inputs:
`type` (`question`, `claim` or `hypothesis`), `title` (becomes the entry
heading unless `content` is given) and optional `content` for the entry
document. Creates `<project>/research/<type-dir>/<ID>/`, commits revision
1 into its history, and returns `{id, type, revision, changed,
entry_document, link}` — `link` is a Markdown link to the entry document.
Because every call executes fresh, a repeated identical call creates a
*new* dossier, so create once and reuse the returned `id`. Rejects an
unknown type, a missing/empty title, placeholder transcript markers and
invalid UTF-8.

## dossier_list
Find dossiers in the store by type or by text query.

Use to discover which dossiers exist, or to locate an `id` before reading
or editing. Inputs: `type` restricts to one dossier type; `query` is a
case-insensitive substring matched against id, title, document names and
*current* authored-document contents (never history snapshots, never
attachment bytes; the scan reads every current document once per listed
dossier, so keep queries targeted); `limit` (1..1000, default 100) and
`continuation` page the result. The listing is derived live from the
store — no index to go stale. Returns `{total, offset, count, dossiers,
continuation, truncated}` where each dossier entry carries `id`, `type`,
`title` (first H1), `revision` and current document names.

## dossier_read
Read a dossier's authored documents, or a compact overview, with bounded ranges.

The normal read path for entry documents and supplements; evidence files
are rejected here (use `evidence_read`). Inputs: `id`; `document`
(`README.md` by default, or `supplements/<name>`); `revision` to read a
historical revision (served from the object store, not the current view);
`overview: true` for a compact metadata-plus-attachment-inventory view
instead of the document text — the cheap first stop when orienting on an
unfamiliar dossier; `start_line`/`max_lines` (defaults 1/500) bound the
returned window, with continuation metadata so long documents can be
paged. Text is returned separately from line-number metadata, so keep the
reported line numbers when you edit later — `dossier_update` spans are
addressed by them, and line numbers go stale as soon as any earlier edit
lands. Pass the span text from this read as `dossier_update`'s `anchor`:
it is compared with the live span before anything is staged, turning stale
line numbers into a clean rejection instead of a mis-anchored edit. The
anchor verifies the current text of the stated span only — it cannot
distinguish identical text at two different positions, and an empty span's
anchor is always empty (no position protection for insertions).

## dossier_update
Edit an authored document and commit a new revision.

The only way to change authored text. Inputs: `id`, `expected_revision`
(the revision you last read), `mode`, `document`, optional `change_note`.
Document modes take full `content`; line modes take `replacement` with
`start_line`/`end_line` (one-based, half-open; `end_line` is required for
`replace_lines` and `delete_lines` — to edit through end of document pass
`total_lines + 1` from the read; include the line breaks you want; omit
`replacement` for `delete_lines`). For line modes the optional `anchor`
is the exact text currently occupying `[start_line, end_line)` — it is
compared with the live span before anything is staged, so stale line
numbers reject cleanly instead of editing the wrong span (an anchor
mismatch tells you to re-read and retry with the corrected span and an
anchor, never to drop the anchor and edit positionally). When a
non-empty tail follows the span and the replacement does not end with a
line terminator, the adjacent terminator is appended so no line is
merged with the retained tail; the result reports `newline_normalized`.
On success the result echoes the after-state — `total_lines`,
`lines_removed`, `lines_inserted` and a `context` excerpt (2 lines before
and after the span plus the first lines of the new span, truncated) — so
a wrong span is visible from the payload without another read. The new
bytes go to `store/objects/<sha256>`, an immutable record to
`store/history/rN.json`, and the `README.md`/`supplements/` views are
re-materialized from objects — history and attachments are never touched.
A no-op edit creates no revision and reports `changed: false`; a stale
`expected_revision` rejects with `StaleRevision` (re-read, then retry).

Worked example — replacing a three-line section at lines 26-28
(`## Status` / blank / `Investigation in progress.`): pass
`mode: replace_lines, start_line: 26, end_line: 29` (`end_line` is
exclusive, so `[26, 29)` covers exactly lines 26-28),
`replacement: "## Status\n\nAnswered (bounded).\n"`, and
`anchor: "## Status\n\nInvestigation in progress.\n"` — the anchor quotes
the span including the final newline of line 28. Line modes take
`replacement`; `content` is only for whole-document modes, and to edit
through end of document pass `end_line` = `total_lines + 1` from the read.

## evidence_attach
Attach evidence files to a dossier, as retained copies or live references.

Use after creating or reading a dossier whenever a result file, receipt
or table should back the record. Inputs: `id`, `expected_revision`,
`items` — a JSON array of `{source, slot, name?, mode, caption?,
script?, parameters?, inputs?, receipt?, replace?}` — plus optional
`change_note`. `mode: copy` retains the exact bytes in the dossier's
object store and writes an `evidence/<slot>/<name>` view; `mode:
reference` retains only the source identity plus the digest observed at
attach time. The batch is atomic: one invalid item rolls the whole call
back, and directory sources or accidental name collisions fail loudly.
Returns the new revision plus per-item `attachment` key and `sha256`;
reference those keys (not paths) in later reads.

## evidence_read
Read one evidence attachment: its metadata, integrity state and text.

Use when citing or re-inspecting attached evidence; takes the
`<slot>/<name>` attachment key from `dossier_read` overview or
`evidence_attach`, optional `revision` (evidence as of a past dossier
revision), and `start_line`/`max_lines` to page text evidence. Copies are
read from the retained bytes with their digest recomputed and reported;
binaries return file/media info instead of text. References report their
source's observed integrity — a changed or missing source is surfaced,
never silently substituted, so historical claims cannot drift with the
filesystem.

## dossier_check
Run the read-only integrity check over the store.

Use after crashes, interrupted calls or external edits, and as a
pre-flight before relying on a dossier. With `id` it checks that dossier
only; otherwise `type`, `limit` (default 100) and `continuation` select a
bounded page. It verifies references, retained-copy digests, local
dossier links, view drift (views vs the recorded objects) and metadata
consistency, returning per-dossier `findings`, a total `finding_count`
and a `not_checked` list naming what is out of scope (external web links
are never fetched; scientific validity is never judged). It changes
nothing.

## dossier_history
Browse a dossier's immutable revision inventory, optionally with a diff.

Use to see how a dossier evolved or to quote what it said at a past
revision. Inputs: `id`, `limit`/`continuation` to page the inventory;
optionally `diff_document` with `from_revision`/`to_revision` to get a
line diff of one authored document between two revisions. Each inventory
entry carries the revision number, timestamp, change note and the
document/attachment identities of that revision; binary content never
appears — historical text and evidence stay behind `dossier_read` and
`evidence_read` with `revision` set.

## dossier_capture
Adopt externally edited dossier documents as a new revision.

The only sanctioned response to drift — when files under a dossier were
edited outside the tasks (e.g. by hand) and `dossier_check` reports view
drift. Inputs: `id`, `expected_revision`, `documents` (`all`, a list, or
a JSON array of names) and optional `change_note`. It is guarded by the
revision you last read and the observed digests, and refuses when there
is no drift or when retained evidence is corrupted. Ordinary
`dossier_update` calls never adopt external edits, so drift never enters
the history silently.

# Examples

Real payloads generated while exercising the tasks in a temporary
project:

```
dossier_create  {type: question, title: "Does the intervention change the measured endpoint?"}
  -> {"id": "Q-001", "type": "question", "revision": 1, "changed": true,
      "entry_document": "README.md",
      "link": "[Q-001](<project>/research/questions/Q-001/README.md)"}

evidence_attach {id: Q-001, expected_revision: 1, items: [{source: "endpoint.tsv", slot: "data", mode: "copy"}]}
  -> {"id": "Q-001", ..., "revision": 2, "changed": true,
      "items": [{"attachment": "data/endpoint.tsv", ..., "mode": "copy",
                 "sha256": "07a714…",
                 "retained_location": "<project>/research/questions/Q-001/evidence/data/endpoint.tsv"}]}

dossier_update  {id: Q-001, expected_revision: 2, mode: "replace_lines",
                 start_line: 2, end_line: 2, replacement: "answer line",
                 change_note: "record current answer"}
  -> {"id": "Q-001", "type": "question", "document": "README.md",
      "mode": "replace_lines", "changed": true, "revision": 3,
      "previous_revision": 2, "change_summary": "edited README.md (replacement 71 bytes)",
      "change_note": "record current answer"}
```

# Documentation

- [Agent introduction](doc/user/README.md) — first call and representative
  path
- [Task reference](doc/user/Tasks.md) — real registered inputs, output
  shapes, error cases
- [Developer notes](doc/developer/README.md) — task layout, store
  protocol, tests

