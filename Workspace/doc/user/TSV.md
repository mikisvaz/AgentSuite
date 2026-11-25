# Working with TSV files in Workspace

Workspace provides a small suite for inspecting, reading, querying, editing,
setting metadata, merging, attaching, translating, and sorting Scout TSV data.
The implementation uses Scout TSV parsing and serialization rather than
defining an independent format. This document carries the per-input detail for
the nine TSV tasks; the README summarizes them. TSV value-type semantics
(`single`/`list`/`flat`/`double`, `sep2`) are Scout `TSV` semantics, documented
in scout-gear `doc/user/ProcessingTabularData.md`.

## Scout TSV file format

Scout TSV is a keyed table, not just a rectangular array of records. The
canonical on-disk representation uses actual tab characters between columns:

```tsv
#: :type=:list
#Gene	Score	Direction
TP53	2.4	up
MYC	-1.8	down
```

- The first column is the key; the remaining columns are the value fields.
  The column-name line begins with `#` immediately before the key-field name.
- An optional `#:` metadata preamble precedes the column-name line. It can
  describe the value type, namespace, cast, filename and other scalar
  options. Declare the type when writing new Scout TSVs so that the intended
  value shape is explicit. Preserve applicable metadata when transforming a
  table; do not copy stale filename, cast or namespace information blindly.
- Data lines do not carry a header marker. `#:` metadata and the `#` field
  header are not interchangeable. Do not write an unmarked column-name line
  or discard all `#` lines as comments.
- A key identifies the logical record. Use unique keys for scalar records;
  repeated keys can collapse or merge on loading. If records are identified
  by a tuple (e.g. gene, treatment and time), use an unambiguous composite
  key, or model the multiplicity explicitly.

For a multi-valued table, the default sub-value separator is `|`:

```tsv
#: :type=:double
#GO Term	Gene	Score
GO:0000278	CDK1|CCNB1	2.4|1.8
```

Here the row for `GO:0000278` has two value fields, represented as
`[["CDK1", "CCNB1"], ["2.4", "1.8"]]`. Where field values describe associated
items, preserve their positional correspondence. A `:list` table represents
one scalar per field; a `:single` table one scalar per key; a `:flat` table
does not preserve stable named-field boundaries.

Keep identifiers as strings, including leading zeros. Missing values are not
zeros. A literal tab or newline in a value, or a literal sub-value separator
in a multi-valued field, needs explicit handling rather than ordinary CSV
quoting: do not assume Scout decodes CSV quoting in canonical TSVs.

## Reading and writing

Use `tsv_info` to inspect the interpreted structure rather than treating
the first physical line as the column names. Its materialized key count is
not necessarily the physical number of records. Use `tsv_query` for exact
key lookups and `tsv_read` for normalization or selected rows.

There is no `tsv_write` task. For small new tables use Workspace's ordinary
file-writing tools with the canonical representation above. For programmatic
outputs prefer Scout serialization in Ruby, or emit the format explicitly
from Python or another language. `tsv_set_metadata` rewrites an existing
table; it is not a constructor and cannot recover rows already lost through
incorrect key interpretation.

For an ordinary unmarked tab-separated header, use `header_hash: ''` and
the intended `type` when inspecting or normalizing the source. For comma-
separated sources set the delimiter as well; quoted CSV requires a
CSV-aware reader if the values contain quoted delimiters or line breaks.

## Recommended ingest flow

1. Run `tsv_info` on an unfamiliar source to inspect the interpreted key field,
   value fields, type, materialized counts, and possible entity-format fields. Pass
   source interpretation options such as `sep`, `sep2`, `header_hash`, or `type`
   when required. `key_field` and `fields` select an alternative interpretation.
   `tsv_info` never modifies its source: it is read-only inspection.
2. Run `tsv_read` with those source options to normalize the source into canonical
   Scout TSV (tab-delimited columns, pipe-delimited multi-values, `#` headers).
   Its text result can be passed to downstream TSV tasks. Callers needing a
   persisted path can request it through the harness option `return_path: true`.
3. Use `tsv_query`, `tsv_edit`, `tsv_set_metadata`, `tsv_merge`, `tsv_attach`,
   `tsv_translate`, or `tsv_sort` on prepared/canonical TSV inputs. These tasks
   intentionally do not accept parser-only delimiter and header options. If a
   source needs reinterpretation, normalize it again with `tsv_read` first.

## Tasks at a glance

| Need | Task | Result |
|---|---|---|
| Inspect table shape | `tsv_info` | JSON summary; side-effect free |
| Normalize or subset a source | `tsv_read` | Scout TSV text; harness can return persisted result path |
| Fetch exact key values | `tsv_query` | JSON query records in request order |
| Replace a cell or row | `tsv_edit` | Updated source and TSV text; harness can return persisted result path |
| Persist metadata changes | `tsv_set_metadata` | JSON summary of the rewritten source |
| Merge tables | `tsv_merge` | TSV text; harness can return persisted result path |
| Attach fields | `tsv_attach` | TSV text; harness can return persisted result path |
| Translate identifiers | `tsv_translate` | TSV text; harness can return persisted result path |
| Sort and page | `tsv_sort` | JSON: page as TSV text or ordered keys |

## Scout TSV data shape

| Type | Typical row value | Interpretation |
|---|---|---|
| `single` | `"42"` | One scalar per key |
| `list` | `["42", "yes"]` | One scalar per value field |
| `flat` | `["a", "b"]` | Flattened values without stable named-field boundaries |
| `double` | `[["a"], ["b"]]` | An array of values per value field |

`sep` is the column separator (tab by default), `sep2` the multi-value
separator (pipe by default), and `header_hash` the header marker (`#` by
default). These options describe how to interpret the input.

## `tsv_info`

`tsv_info` returns the selected key field and value fields, type, materialized
counts, and candidate fields matching registered `Entity.formats`. Both
`source_rows` and `unique_keys` count materialized keys; `physical_input_records`
is the heuristic count of physical input records behind them. Candidate fields
are identified by name. `type`, `key_field`, `fields`, delimiters, and header
marker describe how to interpret the source.

`tsv_info` is **side-effect free**. Persist metadata changes with
`tsv_set_metadata` instead.

## `tsv_read`

`tsv_read` is the parser-facing normalization operation. It accepts an allowlisted
set of Scout TSV opening controls (`type`, `sep`, `sep2`, `key_field`, `fields`,
`cast`, `select`, `grep`, `persist`, `header_hash`, `field`, `identifiers`,
`namespace`, `merge`, and `one2one`) plus exact `keys` selection and optional
output field/key renaming. It does not forward arbitrary options.

Text output is canonical Scout TSV: tab-separated columns, pipe-separated
multi-values, and `#` headers, independent of source parsing delimiters and
header markers. `identifiers` associates mapping metadata; it does not perform
translation. `persist` controls parser/cache persistence, not output location.
`keys` retains exact key names. A caller that needs a path instead of the text
can set the harness-level `return_path: true` option; the task does not declare
that option or create a task-specific output file.

```ruby
prepared = Workspace.job(:tsv_read, nil,
  file: 'genes.csv', sep: ',', header_hash: '', type: 'double').run
```

In-place mutation of a CSV source is refused by the mutation tasks (`tsv_edit`,
`tsv_set_metadata`): Scout renders TSV, not quoted CSV, so a persisted rewrite
would corrupt quoted values. Normalize with `tsv_read` first, then mutate the
normalized TSV.

## Downstream tasks

`tsv_query` fetches exact keys in request order and reports `{key, found, value}`
for each, including misses. A `column` selects the reserved alias `key`, the
exact current key-field label, or one named value field; prefix `@` to select a
value field literally named `"key"`. Without `column`, the full row is
returned. Requests are capped at 5000 keys; request a subset above that.
`cast` accepts `to_i` and `to_f` and is applied recursively. Named columns are
unsupported for `flat` TSVs.

`tsv_edit` takes `file`, `key`, and either `field` plus scalar `value` or a full
`row` encoded as JSON. Successful edits rewrite the input source atomically. JSON
row shapes are scalar for `single`, one scalar per field for `list`, an array of
scalars for `flat`, and an array of per-field scalar arrays for `double`. Values
are serialized as TSV strings; a row containing tabs, newlines, or inner
multi-value separators is rejected before the source is touched. Invalid JSON,
absent keys/fields, and invalid shapes fail before source replacement. Named
field edits on `flat` are rejected. A successful result is normalized TSV text;
the caller can request the persisted job result path using the harness-level
`return_path: true` option. That option does not select or replace the mutated
source.

`tsv_set_metadata` explicitly persists metadata changes. It takes one or more of `new_key_field`
(new key label), `rename_fields` (new value-field labels in order; duplicate
labels are rejected), `cast` (`to_i`/`to_f`), `namespace`, `identifiers`
(recorded as metadata only; not opened or applied), and `new_type` (persisted
type conversion). The `key_field`/`fields` projection supplied at open time is
baked into the persisted table. CSV sources are refused: normalize them with
`tsv_read` first. The rewrite is authorized for write and applied atomically.

`tsv_merge` requires matching key field, fields, type, and non-filename
annotation metadata. `replace` (default) keeps left-only rows and replaces a
whole colliding row with the right row. `zip` is distinct and supported only for
`double` TSVs. Neither source is modified.

`tsv_attach` explicitly names `match_key` and `other_key` (key or value field),
attaches selected right-side fields to matching source rows, ignores right-only
rows, and leaves unmatched source rows. Duplicate right-side match values are rejected for either setting of `one2one`. It rejects `flat` inputs, and field collisions. Scout's attach operation
mutates its receiver, so Workspace works on a copy. No identifier translation
is implicit.

`tsv_translate` explicitly invokes `TSV.translate` for `field`, `target_format`,
and an identifier mapping file. It returns a new table and does not mutate the
source. Setting `identifiers` in `tsv_set_metadata` or `tsv_read` is metadata
assignment, not value translation.

`tsv_sort` sorts a prepared table by `key` (default) or a value `column` and
returns one `page` (1-based; `page_size` rows, or a bounded default of 500 rows
when omitted — the page is never silently truncated, so pass an explicit size
for the whole table) as canonical Scout TSV text in `tsv`, or just the ordered
`keys` with `just_keys`. `direction` is `ascending` (default) or `descending`.
Value-field sorting compares the field's first value for `list`/`double` rows;
`cast` (`to_i`/`to_f`) makes that comparison numeric and is ignored when
sorting by `key`. Unknown fields, invalid casts/directions, and non-positive
page numbers or sizes are rejected; a page beyond the available rows is empty.
Value-field sorting on `flat` TSVs is unsupported.

## Mutation safety and outputs

`tsv_edit` and `tsv_set_metadata` mutate their source on success; every other
TSV task is read-only. These tasks open their inputs in the workflow process.
Their file checks are separate from Workspace file-task grants and bwrap
mounts. Mutation requires a writable regular, non-symlink input and a writable
parent directory; replacement uses a same-directory temporary file and rename.
Read/query/merge/attach/translate do not modify their sources. TSV-producing
tasks return text by default. A caller can set the harness-level
`return_path: true` option to retrieve the persisted job result path; this is
not an input declared by TSV tasks. `tsv_info`, `tsv_query` and `tsv_sort`
return JSON.

There is no `tsv_write` task. Consult ScoutCoder `task_inputs` for the exact
live task input schema before calling a task.
