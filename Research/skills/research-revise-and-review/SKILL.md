---
name: research-revise-and-review
description: >
  Revise a dossier after new evidence: change an interpretation, correct a
  number, replace an attachment, resolve a stale-revision conflict or an
  external edit, and review integrity. Triggers: editing a claim, fixing an
  error, expected_revision rejection, drift found by dossier_check,
  adopting external edits via dossier_capture.
---

# Revise and review

## When

Evidence moved, an interpretation must change, a number was wrong, an
attachment must be replaced, a `StaleRevision` error appeared, or an external
edit hit a dossier and needs adopting or reverting.

## Procedure

1. **Read before writing**: `dossier_read` the current revision — line
   numbers come from the read you base the edit on. Use `overview: true` for
   structure, `dossier_history` for what changed and when.
2. **Guarded edit**: `dossier_update` with `expected_revision` = the revision
   you just read. To fix a link or a phrase, use `replace_text` with the unique
   literal `old_text` and its `new_text`. For line edits, spans are one-based half-open `[start_line, end_line)`;
   `end_line` is required for `replace_lines`/`delete_lines` — to edit through
   end of document pass `total_lines + 1` from the read; the replacement
   includes its own line breaks; `delete_lines` deletes a span; `[N+1, N+1)`
   appends after the last line. Pass the span text from that read as
   `anchor` — line numbers go stale as soon as any earlier edit lands, and
   the anchor makes a stale span reject cleanly (observed span quoted,
   nothing staged) instead of editing the wrong lines. Note what the anchor
   does NOT do: it verifies the current text of the stated span only, so it
   cannot distinguish identical text at two different positions, and an
   empty span's anchor is always empty (no position protection for
   insertions).
3. **Replace an attachment explicitly**: `evidence_attach` with
   `replace: true` on the same attachment key — collisions without `replace`
   fail; previous evidence mappings stay in history (old revision records
   keep the old digest).
4. **Conflicts**: `StaleRevision` means someone wrote first — re-read, merge
   your intent into the new state, re-apply. Never retry the identical
   dispatch hoping for a different result.
5. **External edits (drift)**: `dossier_check` reports view drift when a
   document was edited outside the tasks (e.g. by hand). To *keep* the
   external work, `dossier_capture` with `id`, `expected_revision`, the
   document names and a `change_note` — it is the only adoption path, guarded
   by the revision you read and the observed digests, and it refuses when
   retained evidence is corrupted (repair that first) or when nothing
   drifted. There is no task that discards drift — ordinary updates refuse
   a drifted dossier, so external edits are either adopted with
   `dossier_capture` or the file bytes are restored externally back to the
   pinned content, after which `dossier_check` confirms consistency.
6. **Narrow, do not retcon**: when contrary evidence weakens a claim, edit
   the current document (e.g. bounding the claim to the subset that
   survived) and put the reason in `change_note` ("narrow claim after
   stricter multiple-testing"). The earlier revision in history keeps the
   original statement — the record shows the claim was narrowed, not that it
   always predicted the result. Do not rewrite the historical hypothesis.
7. **Mechanical check**: `dossier_check` after structural work (attachments,
   links, captures) — missing/changed references, corrupted retained copies,
   broken local links. It is an integrity report: `status: "ok"` means the
   machinery is consistent, not that the science is right. Scientific review
   — whether the claim is warranted by the evidence — is a judgment you or a
   reviewing agent make against the attachments; no task issues that verdict.

## Example (narrow a claim after contrary evidence)

```ruby
# current claim C-006 README (3 lines):
#   # Changed genes concentrate in metabolism
#   All changed genes map to metabolism terms.
#   Evidence: enrichment table, attachment revision 3.
r = LLM.call_workflow(Research, :dossier_read, 'id' => 'C-006')
# revision 1, total_lines 3

LLM.call_workflow(Research, :dossier_update,
  'id' => 'C-006', 'expected_revision' => r['current_revision'],
  'mode' => 'replace_lines', 'start_line' => 2, 'end_line' => 3,
  'replacement' =>
    "After stricter multiple-testing, one term remains significant; the claim is\n" \
    "narrowed to that term. The broader statement did not survive correction.\n",
  'change_note' => 'narrow claim after stricter multiple-testing (was: metabolism genes changed)')
# => {"id"=>"C-006", "revision"=>2, "changed"=>true, "previous_revision"=>1, ...}

LLM.call_workflow(Research, :dossier_history, 'id' => 'C-006')
# revisions[1] keeps change_note null (original claim) — history stays honest.
```

## Example (replace a three-line section, anchored)

```ruby
# dossier_read reported total_lines 40 and lines 26-28 are:
#   26: ## Status
#   27:
#   28: Investigation in progress.
LLM.call_workflow(Research, :dossier_update,
  'id' => 'Q-001', 'expected_revision' => 2,
  'mode' => 'replace_lines',
  'start_line' => 26, 'end_line' => 29,                       # 29 is EXCLUSIVE -> covers 26-28
  'replacement' => "## Status\n\nAnswered (bounded).\n",
  'anchor' => "## Status\n\nInvestigation in progress.\n",    # includes line 28's trailing \n
  'change_note' => 'status: answered (bounded)')
# => {"id"=>"Q-001", "revision"=>3, "changed"=>true,
#     "lines_removed"=>3, "lines_inserted"=>3, "newline_normalized"=>false, ...}
```

Notes the five-retry failures in real runs came from:
- `end_line` is **exclusive**: `[26, 29)` covers lines 26-28 — passing 28
  would leave line 28 in place.
- The `anchor` quotes the span text **including the final newline of the
  last span line** (`…in progress.\n`, not `…in progress.`); quoting
  without it mismatches.
- Line modes use `replacement` (the new span text); `content` is only for
  whole-document modes (`create_document` / `replace_document`).
- To replace through the end of the document, pass `end_line` =
  `total_lines + 1` from the read.

## Details

- Line-edit contract and error recovery (stale revisions, range errors,
  placeholder guard): `doc/user/Walkthrough.md`; capture semantics and
  task signatures: `doc/user/Tasks.md`; when/how-to-use guidance per
  task: repository `README.md` (`# Tasks`).
- Resuming long work: keep settled definitions and the next action in the
  question dossier (see `research-question-to-dossier`).
