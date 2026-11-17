# Research developer notes

How the workflow is built and why. The user-facing contract is in
[doc/user](../user/README.md); this page does not repeat it. The Markdown
files under `research/` are [development history](HISTORY.md), not
current authority.

## Task layout

`workflow.rb` is a bootstrap: it requires Scout and `scout-ai`, opens
`module Research; extend Workflow; end`, and requires the task files.
All nine tasks are ordinary declarations inside `module Research` in
`lib/Research/tasks/*.rb` — each file holds its own `desc`, `input`
declarations (adjacent to the task they belong to) and `export_exec`,
with the orchestration in the task body:

```ruby
module Research
  input :type, :select, 'Dossier type', nil, select_options: %w[question claim hypothesis]
  desc '…'
  task :dossier_create do |type, title, content|
    …
  end
  export_exec :dossier_create
end
```

`lib/Research/tasks/common.rb` holds shared validation helpers
(`parse_id!`, `int!`, `reject_placeholder_text!`, `map_store_errors`,
`store_root`); `lib/Research/evidence.rb` (outside `tasks/`, because it
declares no tasks) holds sandbox-authorized source/destination
resolution, durable/ephemeral classification and citation building.
`lib/Research/{layout,store,store_bytes,ids,line_edit}.rb` are the store
layer.

## Project-context propagation

The store root is resolved at **execution time inside the task body**:

```ruby
def store_root
  File.expand_path('research', Dir.pwd)
end
```

Why execution time and not declaration or job-build time: the root must
never be captured into job inputs or Step construction, because anything
captured there becomes part of the job digest and the memoization key.
Resolved per execution from the working directory it is invisible to the
framework's caching, so two projects are isolated purely by `Dir.chdir`
between dispatches in one process, and no configuration chain, registry
or fallback exists to drift. Other contents of `research/` are not the
store's; the store owns `questions/`, `claims/`, `hypotheses/` and the
per-dossier `store/` directories only.

## Exec behavior

All nine tasks are exec-exported. Each call executes fresh: identical
inputs do not replay an earlier result, a repeated `dossier_create`
allocates a new ID, and caller job names flow through to the job.

Historical note (why there is no dispatch apparatus): the pre-refactor
workflow passed a `research_root` **Directory input** to every task.
Scout's `Task#job` memoizes one Step per (task, inputs) keyed on the
input digest, and empty directory inputs all digest identically
(`Directory MD5: []`), so unrelated calls could collide on a memoized
Step. The fix was structural: the directory input was removed, the root
moved into the task body (above), and the dispatch-id/memoization
workarounds (`dispatch_job_id`, `DISPATCH_EXEC_TASKS`, the `Research.job`
override) were deleted rather than patched. Remaining inputs are
strings/integers whose digests are faithful; memoized Steps re-execute
their blocks.

## Store transaction guarantees

`Store.transaction(root, type, id, expected_revision:, …) { |ctx| … }`
yields a conventional context object (no `instance_exec` binding). Under
the per-dossier lock it runs the S/J/M/V/C protocol:

- **S** — stage content-addressed objects for every staged byte
  (idempotent, ordered; objects are never swept).
- **J** — journal the complete revision record.
- **M** — write the marker that disambiguates redo from drift.
- **V** — materialize document/attachment views.
- **C** — pointer swap; the linearization point.

An interrupted commit is recovered on the next transaction (`recover!`)
and redone if the marker is present, detected as drift otherwise.
`expected_revision` provides optimistic concurrency; `dossier_capture`
is the only caller passing `allow_drift: true` (it adopts observed
external edits explicitly). Failure maps to Scout `ParameterException`
via `map_store_errors` so exec dispatch surfaces actionable errors. The
on-disk format is unchanged from the pre-refactor store; old stores
remain valid (`test_legacy_store_compatibility.rb`).

## Line-edit contract

`lib/Research/line_edit.rb` is a pure one-based, half-open
`[start_line, end_line)` editor (nil `end_line` = through end of
document), checked against the exact revision the caller read.
`delete_lines` exists as an explicit mode (rather than an empty
replacement) so a span deletion cannot be confused with a zero-length
replacement and remains reachable from every surface.

## Link-checker contract

`dossier_check` scans document bytes with a bounded, documented syntax:
inline links/images `[text](target "title")` (angle-bracket and
balanced-paren targets included); fenced code blocks (``` and ~~~)
skipped and counted; fragments split from file paths and never
validated; ordinary links resolved relative to the **containing
document**; absolute links resolved, not skipped; resolution constrained
inside the research root. **Unsupported syntax** — reference-style links
(`[text][ref]`), HTML anchors (`<a href>`, autolinks) — is counted under
`unsupported_syntax`, never silently treated as checked; the task-level
`not_checked` list states what was not validated (external URLs, targets
outside the root, fragments). The legacy bare-ID pseudo-link form
(`[x](C-001/README.md)`) remains supported for cross-kind links.

## Tests

See [Testing.md](Testing.md) for the ten suites, the runner, and the
temp-project harness discipline.

## Limitations

- Link checking is bounded to the documented syntax above; fragments and
  headings are never validated, external URLs are never fetched.
- `dossier_list` `query` scans current document contents (one read per
  document per listed dossier); it never searches history or evidence
  bytes.
- Evidence binaries are not readable through `dossier_read`/`evidence_read`
  text surfaces; they return file/media info.
- The placeholder guard matches a fixed marker list
  (`TOOL-COMPACTION-RECORD`); it is a write guard, not a content policy.
