---
name: workspace-tsv
description: "Inspect, normalize, query, edit, set metadata, merge, attach, translate and sort Scout TSV tabular data with the nine Workspace tsv_* tasks. Use when an agent must work with a TSV/CSV table — check its shape, normalize a non-Scout source, look up exact keys, replace a cell or row, persist a key/field/type/cast change, join two tables, translate identifiers, or page through sorted output — or when a tsv_* task rejected an input and the reason is interpretation (sep, sep2, header_hash, type). Triggers: tsv_info, tsv_read, tsv_query, tsv_edit, tsv_set_metadata, tsv_merge, tsv_attach, tsv_translate, tsv_sort, TSV, \"tabular\", \"table join\", \"column separator\", \"sep2\", \"key field\", \"double\", \"normalize CSV\", \"identifier mapping\"."
---

# Workspace TSV operations (the nine `tsv_*` tasks)

## What this skill covers

Operational choice among the nine TSV tasks, the prepare-then-operate flow,
and the mutation-safety rules. Per-input detail is authoritative in
`Workspace/doc/user/TSV.md` (project-qualified); Scout TSV value-type
semantics (`single`/`list`/`flat`/`double`, `sep2`) live in scout-gear
`doc/user/ProcessingTabularData.md`. This skill does not repeat either.

## Prepare first, then operate

`tsv_info` and `tsv_read` accept source delimiters and header options. Use `tsv_read` to produce canonical TSV for downstream operations. Individual tasks also accept field, type or cast options as described in their task help.

Recommended flow on an unfamiliar source:

1. `tsv_info` — shape: interpreted key field, value fields, type, materialized key
   counts, entity-format candidates (hints, not validated identifiers). It is
   side-effect free: it only reports.
2. `tsv_read` with any needed options — normalize into canonical Scout TSV
   (tab columns, pipe multi-values, `#` headers); text result feeds the
   downstream tasks; `return_path: true` when a path is needed instead.
3. Operate: `tsv_query` / `tsv_edit` / `tsv_set_metadata` / `tsv_merge` /
   `tsv_attach` / `tsv_translate` / `tsv_sort`.

## Which task for which need

| Need | Task |
|---|---|
| Inspect shape (fields, type, counts) | `tsv_info` (read-only) |
| Normalize / subset / reinterpret a source | `tsv_read` |
| Fetch exact keys in request order | `tsv_query` |
| Replace one cell or a whole row | `tsv_edit` |
| Persist key/field labels, cast, namespace, identifiers or type | `tsv_set_metadata` |
| Join two compatible tables (replace or zip) | `tsv_merge` |
| Attach right-side fields on matching keys | `tsv_attach` |
| Translate identifiers through a mapping file | `tsv_translate` |
| Sort by key or field, return one page | `tsv_sort` |

## Read vs traverse vs query

- `tsv_read` is the full normalization read: it returns the whole table
  (optionally filtered via `select`/`grep`/`keys`), not a lookup.
- `tsv_query` is exact-key lookup: give it the keys you want, it returns
  each row (or one `column`) in request order, with `found: false` for
  misses. It does not search or rank. A `column` accepts the reserved
  alias `key`, the exact key-field label, or a value-field name; prefix `@`
  for a value field literally named `key`. Requests are capped (5000 keys).
- Full-table traversal order (e.g. scanning by value) is a `tsv_sort` (by a
  value `column`, possibly `just_keys`) or a `tsv_read` concern, not a
  query concern.

## Mutation-safety rules

- `tsv_edit` **always rewrites its source on success** (atomic
  same-directory tmp + rename). Point it only at a file you own.
- `tsv_set_metadata` is the only metadata mutation: it persists
  `new_key_field`, `rename_fields`, `cast`, `new_type`, `namespace` or
  `identifiers` into the source (atomic rewrite, write-authorized first).
  It needs at least one of them and refuses CSV sources — normalize with
  `tsv_read` first.
- `tsv_info` never rewrites anything. Metadata persisted through
  `tsv_info` in older revisions now lives in `tsv_set_metadata`.
- `tsv_query`, `tsv_read`, `tsv_merge`, `tsv_attach`, `tsv_translate`,
  `tsv_sort` never modify their inputs; `tsv_attach` operates on a copy
  because Scout's `TSV.attach` mutates its receiver.
- Mutation requires a writable, regular, non-symlink file and writable
  parent directory.
- TSV-producing tasks return text; use the harness-level `return_path: true`
  when a persisted path is needed (not a task input).

## Common mistakes

- Calling an operating task with `sep`/`header_hash` on a raw CSV — those
  options exist only on `tsv_info`/`tsv_read`; normalize first.
- Expecting `tsv_query` to search or filter — it fetches exact keys only.
- Using `tsv_edit` on a shared or tracked source without expecting the
  rewrite — it mutates in place.
- Expecting `tsv_info` to persist a change — it is side-effect free; use
  `tsv_set_metadata`.
- Treating `tsv_info`'s or `tsv_set_metadata`'s `identifiers` as a
  translation — it is metadata assignment; actual translation is
  `tsv_translate` with an explicit mapping file.
- Sorting a `flat` TSV by a named field, or expecting named columns there —
  `flat` rows carry no stable field boundaries.
- Assuming `type` on `tsv_info`/`tsv_read` persists a conversion — it is a
  parse override; `new_type` on `tsv_set_metadata` is the persistent
  conversion.
- Forgetting `page_size` on `tsv_sort` and assuming the whole table — the
  default is a bounded page (500 rows) and never silently truncated; pass
  an explicit size for everything.

## Going deeper (repo-relative pointers, optional)

- `Workspace/doc/user/TSV.md` — authoritative per-input detail for all
  nine tasks, the ingest flow, data-shape reference, mutation rules.
- `Workspace/README.md` — one-line entries for the nine `tsv_*` tasks.
