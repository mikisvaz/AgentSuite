# Tasks

The authoritative task reference for the nine Research tasks. Every input
below is the real registered declaration (`input`, `desc`) from
`lib/Research/tasks/`; every output shape is a real payload produced by
running the task in a temporary project. Inputs not shown here do not
exist.

Common conventions for all tasks:

- The store root is fixed: `<working project>/research/`, resolved at
  execution time from the process working directory. No `research_root`
  input, configuration or environment variable exists.
- Every mutation is revisioned with optimistic concurrency: pass the
  revision you read as `expected_revision`; a mismatch rejects with a
  `StaleRevision` message that names both revisions.
- All tasks are exec-exported: each call executes fresh (identical inputs
  do not replay an old result), and caller job names flow through.
- Task failures surface as Scout `ParameterException` with actionable
  messages. In tests, note that `LLM.call_workflow` *returns* exception
  objects instead of raising.

Task list: `dossier_create`, `dossier_list`, `dossier_read`,
`dossier_update`, `evidence_attach`, `evidence_read`, `dossier_check`,
`dossier_history`, `dossier_capture`.

---

## dossier_create

```
Research.input :type, :select, 'Dossier type', nil, select_options: %w[question claim hypothesis]
Research.input :title, :string, 'Dossier title (written as the entry heading when content is omitted)'
Research.input :content, :text, 'Optional initial Markdown for the entry document README.md', nil, nofile: true
Research.desc 'Create a scientific record dossier (question, claim or hypothesis) and its first revision. Returns the root-local ID, revision, entry document README.md and a Markdown link to it.'
```

Output: `{id, type, revision, changed, entry_document, link}`. Real example
(`create_question.json`):

```json
{"id": "Q-001", "type": "question", "revision": 1, "changed": true,
 "entry_document": "README.md",
 "link": "[Q-001](<project>/research/questions/Q-001/README.md)"}
```

Errors: unknown type; missing/empty title; placeholder transcript markers
in title or content (`TOOL-COMPACTION-RECORD`); invalid UTF-8 in content.

## dossier_list

```
Research.input :type, :select, 'Restrict the listing to one dossier type', nil, select_options: %w[question claim hypothesis]
Research.input :query, :string, 'Case-insensitive substring matched against id, title, authored-document names and CURRENT authored-document contents (never history snapshots, never attachment bytes). Scan cost is one read per document per listed dossier.'
Research.input :limit, :integer, 'Maximum dossiers to return (1..1000)', 100
Research.input :continuation, :string, 'Continuation token from a previous page'
Research.desc 'List dossiers under the research root: id, title, type, revision, location. Derived live from the store; there is no index file to go stale.'
```

Output (`list.json`): `{total, offset, count, dossiers: [{id, type, title,
revision, documents}], continuation, truncated}`. Empty store returns an
empty `dossiers` array, not an error.

## dossier_read

```
Research.input :id, :string, 'Dossier id, e.g. Q-001'
Research.input :document, :string, "Authored text document to read: 'README.md' (default) or 'supplements/<name>'", 'README.md', nofile: true
Research.input :revision, :integer, 'Historical revision to read (default: current)'
Research.input :overview, :boolean, 'Compact overview mode: entry document metadata plus attachment inventory', false
Research.input :start_line, :integer, 'First line to return (one-based; default 1)', 1
Research.input :max_lines, :integer, 'Maximum lines to return per call (1..5000; default 500)', 500
Research.desc 'Read authored text documents of a dossier with bounded ranges and continuation. Raw text is returned separately from line-number metadata. Evidence binaries are rejected here.'
```

Document output (`read_default.json`): `{id, type, document, revision,
current_revision, total_lines, start_line, end_line, lines_returned,
content, continuation, truncated}` — revision and the line range are
always present so line edits can be applied against a known state.
Overview output (`overview.json`): `{id, type, revision, entry_document:
{name, title, total_lines, digest}, documents, attachments}`.

Errors: unknown id; unknown document; evidence binaries offered as text.

## dossier_update

```
Research.input :id, :string, 'Dossier id, e.g. Q-001'
Research.input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
Research.input :mode, :select, 'Update mode: create_document, replace_document, replace_lines, delete_lines or replace_text', nil, select_options: %w[create_document replace_document replace_lines delete_lines replace_text]
Research.input :document, :string, "Target authored document: 'README.md' (default) or 'supplements/<name>'", 'README.md', nofile: true
Research.input :content, :text, 'New document content for create_document / replace_document', nil, nofile: true
Research.input :replacement, :text, 'Replacement text for the one-based half-open span [start_line, end_line)', nil, nofile: true
Research.input :start_line, :integer, 'First line of the edited span (one-based)'
Research.input :end_line, :integer, 'End of the edited span (exclusive); required for replace_lines and delete_lines — to edit through end of document pass total_lines + 1 from the read'
Research.input :anchor, :text, 'Optional content anchor: the exact text currently occupying [start_line, end_line); a mismatch rejects the edit before anything is staged, guarding against stale line numbers. Verifies the CURRENT TEXT of the stated span only — identical text at another position also matches, and an empty span anchors against "" (no position protection for insertions)', nil, nofile: true
Research.input :change_note, :string, 'Human-readable note recorded with the new revision'
Research.input :old_text, :text, 'Exact nonempty text to find once for replace_text', nil, nofile: true
Research.input :new_text, :text, 'Literal replacement for replace_text', nil, nofile: true
Research.desc 'Apply revisioned edits to authored documents: create, replace or line-span edit. Optimistic concurrency on expected_revision; no-op edits create no revision.'
```

Output (`update_lines.json`, `delete_lines.json`): `{id, type, document,
mode, changed, revision, previous_revision, change_summary, change_note}`.
A no-op edit returns `changed: false` and creates no revision.

Line-mode results also carry an `update_echo` after-state: `total_lines`,
`lines_removed`, `lines_inserted`, `newline_normalized` and a `context`
excerpt (up to 2 lines before and after the edited span plus the first
lines of the new span, each truncated with a marker) — a wrong span is
visible from the payload without another read. When a non-empty tail
follows the span and the replacement does not end with a line terminator,
the adjacent terminator is appended (the terminator of the last removed
line, reused as-is for CRLF documents) so no line is merged with the
retained tail; at end of document (empty tail) bytes are preserved
exactly and nothing is appended.

Errors: stale `expected_revision` (`stale.json`); span out of range with
the valid range in the message (`range_error.json`); placeholder markers
in content/replacement/change_note (`placeholder_guard.json`).

For a link or phrase inside a paragraph, use `replace_text` with
`old_text`, `new_text`, and the revision you read. The old text must occur
exactly once. For line edits, a read ending on line 23 includes line 23.
To replace just that line, pass `start_line: 23, end_line: 24`.

## evidence_attach

```
Research.input :id, :string, 'Dossier id, e.g. Q-001'
Research.input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
Research.input :items, :text, 'JSON array of attachment items: source (absolute path, or relative resolved against the working project), slot, name, mode (copy|reference), caption, replace, and declared script/parameters/inputs/receipt'
Research.input :change_note, :string, 'Human-readable note recorded with the new revision'
Research.desc 'Attach evidence files (copy or reference mode) to a dossier. Batch-atomic: one invalid item rolls back the whole batch. Returns per-item retained locations and digests.'
```

Each item: `{source, slot, name?, mode: copy|reference, caption?, script?,
parameters?, inputs?, receipt?, replace?}`. Relative `source` resolves
against the working project (the process cwd) — the same base the sandbox
uses; `base_path` is **not** part of the schema and is rejected with an
actionable error (`base_path.json`). Resolution is not authorization: the
source is still checked against the process's sandbox read grants
(`escape.json`), and destination escapes are rejected.

Output (`attach.json`): `{id, type, revision, changed, items:
[{attachment, id, revision, slot, name, mode, source, sha256, size,
attached_at, caption?, retained_location, link, citation, evidence_read: {id, revision, attachment}}], warnings?}`.

The retained location points to the immutable copy or reference-pointer object. Pass the returned `evidence_read` arguments unchanged to read this revision.

Mode semantics: `copy` retains exact bytes in the dossier store (digest
from retained bytes); `reference` retains the source identity plus the
digest observed at attach time. References under temporary roots
(`/tmp`, `/var/tmp`, `/dev/shm`) are rejected as ephemeral with a
promote-or-cite remedy (`ephemeral_reference.json`); a durable reference
to a job-tree result attaches successfully (`attach_reference_durable.json`).

Errors: one invalid item rolls back the whole batch (batch-atomic); stale
revision; source/destination escapes; name collisions without `replace`.

## evidence_read

```
Research.input :id, :string, 'Dossier id, e.g. Q-001'
Research.input :attachment, :string, "Attachment key '<slot>/<name>' as returned by dossier overview or evidence_attach", nil, nofile: true
Research.input :revision, :integer, 'Historical revision of the attachment entry (default: current)'
Research.input :start_line, :integer, 'First line to return for text evidence (one-based; default 1)', 1
Research.input :max_lines, :integer, 'Maximum lines to return per call (1..5000; default 500)', 500
Research.desc 'Read an evidence attachment: metadata, integrity state, and bounded text ranges for text evidence (binary evidence returns file/media info). Never substitutes changed bytes for historical evidence.'
```

Output retains full technical detail (`evidence_read.json`,
`evidence_read_reference.json`): `{id, type, attachment, slot, name,
revision, current_revision, mode, caption?, source, sha256, size,
attached_at, attach_mode, retained_location, integrity: {state, detail},
pointer?, content?/media info, start_line, lines_returned, continuation,
truncated}`.

Errors: unknown attachment key (message lists the existing keys);
integrity mismatch is reported through `integrity`, never silently.

To cite a question’s evidence from a claim, read the attachment at its
recorded revision and insert the returned Markdown `link` verbatim. For a
reference attachment this opens the retained pointer. For a copy it opens
the retained bytes.

## dossier_check

```
Research.input :id, :string, 'Check one dossier only (overrides type/limit)'
Research.input :type, :select, 'Restrict the selection to one dossier type', nil, select_options: %w[question claim hypothesis]
Research.input :limit, :integer, 'Maximum dossiers to check (1..1000; default 100)', 100
Research.input :continuation, :string, 'Continuation token from a previous page'
Research.desc 'Run the mechanical integrity check over dossiers: references, retained copies, view drift, local links, metadata. Read-only; never a scientific verdict.'
```

Output (`check.json`): `{scope, checked, has_more, continuation, dossiers:
[{id, type, revision, status, finding_count, links: {checked, broken?,
external_url?, out_of_scope?, fragment_only?, in_code_fence?, images?,
unsupported_syntax?}, findings}], finding_count, not_checked}`.

Link checking resolves ordinary local Markdown links relative to the
containing document (evidence links, cross-kind links, supplementary
documents, images); absolute generated links are resolved, not skipped;
fenced code blocks are skipped and counted; fragments are separated from
file paths and never validated; reference-style links and HTML anchors
count as `unsupported_syntax`, never silently treated as checked; the
bare-ID pseudo-link form (`[x](C-001/README.md)`) remains supported;
resolution is constrained inside the research root. `not_checked` states
exactly which categories were not validated — a clean result never
implies skipped links were checked.

Errors: unknown id; out-of-range limit. Read-only: findings never mutate.

## dossier_history

```
Research.input :id, :string, 'Dossier id, e.g. Q-001'
Research.input :limit, :integer, 'Maximum revisions per page (default 100)', 100
Research.input :continuation, :string, 'Continuation token from a previous page'
Research.input :diff_document, :string, "When set, produce a line diff of this document between from_revision and to_revision ('README.md' or 'supplements/<name>')", nil, nofile: true
Research.input :from_revision, :integer, 'Diff start revision (default: first revision)'
Research.input :to_revision, :integer, 'Diff end revision (default: current revision)'
Research.desc 'Browse the immutable revision inventory of a dossier: revisions, timestamps, change notes, document and attachment identities; optional line diff of one document between two revisions.'
```

Output (`history.json`): `{id, current_revision, total_revisions,
revisions: [{revision, is_current, timestamp, change_note, documents,
attachments: [{key, digest, mode, size}]}], continuation}` and, when
`diff_document` is set, a `diff` entry. Full technical detail is retained
here and in `evidence_read`; concise task outputs do not remove it.

## dossier_capture

```
Research.input :id, :string, 'Dossier id, e.g. Q-001'
Research.input :expected_revision, :integer, 'Revision the caller read; rejects concurrent edits (optimistic concurrency)'
Research.input :documents, :string, "Documents to capture: 'all' (default), a comma/newline list, or a JSON array of document names", nil, nofile: true
Research.input :change_note, :string, 'Human-readable note recorded with the new revision'
Research.desc 'Capture externally edited authored documents as a new revision (the only explicit adoption path for drift). Rejects when retained evidence is corrupted.'
```

Output (`dossier_capture.json`): `{id, revision, changed, documents,
attachments, captured_documents: {<name>: {observed_digest,
pinned_digest}}, change_note, capture_semantics}`.

Errors: no drift to capture (`dossier_capture.json` error case — capture
requires observed external edits); named documents not drifted or other edits omitted; missing entry README; corrupted
retained evidence (capture refuses to inherit a broken mapping);
placeholder markers in captured bytes.
