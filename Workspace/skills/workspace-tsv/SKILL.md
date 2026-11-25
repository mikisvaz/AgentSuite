---
name: workspace-tsv
description: "Read, create, inspect, normalize and manipulate Scout TSV files, including computational results, evidence tables, identifier mappings and TSV/CSV inputs. Use when writing a new .tsv artifact, exporting a dataframe for Scout, reading # or #: headers, handling keyed rows or pipe-separated values, or using Workspace tsv_* tools (info, read, query, edit, set_metadata, merge, attach, translate, sort)."
---

# Working with Scout TSVs

Scout TSVs are keyed tables. Use the canonical Scout format for new TSV
artifacts intended for Scout tools or agents, unless the consumer specifies
another format.

## File format

```tsv
#: :type=:list
#Gene	Score	Direction
TP53	2.4	up
MYC	-1.8	down
```

The first column is the key; the others are fields. The column-name line
begins with `#`, immediately before the key-field name. An optional `#:`
metadata preamble comes before it. Declare the intended type for new
outputs; preserve applicable namespace and other metadata when transforming
existing tables. Use actual tabs, not the literal characters `\\t`.

| Type | Shape of value for one key |
|---|---|
| `single` | One scalar |
| `list` | One scalar per field |
| `double` | An array of values per field |
| `flat` | Flattened values, without stable named-field boundaries |

```tsv
#: :type=:double
#GO Term	Gene	Score
GO:0000278	CDK1|CCNB1	2.4|1.8
```

The default sub-value separator is `|`; the second example represents
`[["CDK1", "CCNB1"], ["2.4", "1.8"]]`. Preserve correspondence between
associated values in different fields.

## Creating and reading files

- Write small tables using the ordinary Workspace file-writing tools.
  There is no `tsv_write` task. In Scout Ruby code prefer `TSV.setup`
  followed by native serialization (`tsv.to_s` or a dumper).
- For Python/dataframe outputs, explicitly select the key column, add the
  `#` header marker, and emit the intended metadata. Do not emit an
  accidental dataframe index or assume CSV quoting is decoded by Scout.
  Handle tabs, newlines and literal multi-value separators in cells
  explicitly.
- Keep keys unique for scalar records. For distinct observations sharing
  an identifier, use a composite key or an appropriate multi-valued type.
  Repeated physical keys may be merged or overwritten when materialized.
- Treat identifiers as strings. Do not coerce missing values or invalid
  numbers into zeros. A cast applies to the values, not a declaration of
  per-column types.
- When reading outside Scout, distinguish the `#:` preamble from the `#`
  column-name line; strip only the header marker from the latter before
  parsing its field names. Do not discard every `#` line or use the first
  physical line as the header. Preserve the declared value shape.
- For a newly written or unfamiliar table whose interpretation matters,
  inspect it with `tsv_info` using the intended consumer's parsing options
  (defaults for canonical output). Check the key field, fields, type and
  materialized key count. Use `tsv_query` for representative values.

## Workspace operations

`tsv_info` and `tsv_read` accept source interpretation options such as
`sep`, `sep2`, `header_hash`, `type`, `key_field` and `fields`.
Use `tsv_read` to normalize noncanonical sources before passing them to
downstream tasks. For an ordinary unmarked header use `header_hash: ''`.
If the source is quoted CSV, use a CSV-aware reader when required.

| Need | Task |
|---|---|
| Inspect interpreted shape and counts | `tsv_info` |
| Normalize, project or select records | `tsv_read` |
| Fetch exact keys in request order | `tsv_query` |
| Replace a cell or row | `tsv_edit` |
| Persist metadata or type changes | `tsv_set_metadata` |
| Combine compatible keyed tables | `tsv_merge` |
| Attach right-side fields by explicit matching fields | `tsv_attach` |
| Translate identifiers with a mapping file | `tsv_translate` |
| Sort by key or field and page | `tsv_sort` |

`tsv_query` is exact-key lookup, not search. A missing key is reported
explicitly; the request limit is 5000 keys. Use `@key` for a value field
literally named `key`. Named-field operations are not supported on `flat`
rows where field boundaries are absent.

`tsv_sort` defaults to a page of 500 rows. Its value-field ordering uses
the first value of a multi-valued field. Supply numeric `cast` when needed
and appropriate for the data.

## Mutations and results

`tsv_edit` and `tsv_set_metadata` rewrite the source on success. They
require a writable regular non-symlink file and writable parent directory;
normalize CSV first. The other TSV tasks do not mutate their inputs.
A parse override (`type`, `key_field`, `fields`) is not by itself a
persistent change; metadata mutation may bake a projection into the source.

`identifiers` associates mapping metadata; actual translation requires
`tsv_translate`. TSV-producing tasks return text; use the harness-level
`return_path: true` when a persisted result path is needed.

## Working with Scout TSVs in Python

The Workspace `python` tool makes Scout's registered Python modules available automatically. The scout-rig Python companion package provides pandas-based TSV reading and writing utilities:

```python
import scout
import pandas as pd
```

There is no need to locate the scout-rig installation, modify `sys.path`, or implement a custom reader for ordinary Scout TSV files.

### Reading TSVs

```python
df = scout.tsv("expression.tsv")
```

The Scout key field becomes the DataFrame index, and the value fields become its columns. The reader handles the `#` field header and the optional `#:` metadata preamble.

Additional pandas options can be supplied:

```python
df = scout.tsv(
    "identifiers.tsv",
    dtype=str,
    keep_default_na=False
)
```

This is useful when identifiers must retain their textual representation or empty cells must remain empty strings.

Inspect metadata separately when it affects the interpretation:

```python
header = scout.tsv_header("expression.tsv")
print(header)
```

Do not use `comment="#"` with pandas to read Scout TSVs: it discards the field header as well as the metadata.

### Creating TSVs

Use `scout.save_tsv` to produce Scout-compatible tabular artifacts from pandas DataFrames.

```python
df = pd.DataFrame({
    "Gene": ["TP53", "MYC", "CDK1"],
    "Score": [2.4, -1.8, 3.1]
}).set_index("Gene")

scout.save_tsv(
    "scores.tsv",
    df,
    metadata={"type": "list"}
)
```

This produces:

```tsv
#: :type=:list
#Gene	Score
TP53	2.4
MYC	-1.8
CDK1	3.1
```

The DataFrame index becomes the Scout key. Select an appropriate index rather than inadvertently exporting pandas' default numeric row index. The optional `key` argument overrides its name.

Supply relevant metadata through the `metadata` dictionary:

```python
scout.save_tsv(
    "expression.tsv",
    df,
    key="Ensembl Gene ID",
    metadata={
        "type": "list",
        "namespace": "Hsa"
    }
)
```

Common metadata includes `type`, `namespace`, `cast` and `filename`. Declare the type that describes the actual structure of the data. Ordinary DataFrames with one scalar per value field generally correspond to `list` TSVs.

Metadata is optional, but explicitly declaring the TSV type avoids ambiguity. Metadata values must be scalar. The output uses tab-separated columns, `#` field headers and, when provided, a `#:` metadata preamble.

### Multi-valued fields and keyed data

A pandas DataFrame is not equivalent to a native Scout TSV object. In particular:

- Pipe-separated values in `double` TSVs generally remain strings when read into pandas.
- `scout.save_tsv` does not automatically serialize Python lists as pipe-separated values. Prepare the field representation explicitly when writing multi-valued tables.
- Repeated DataFrame index values are permitted by pandas but can be merged or overwritten by Scout. Choose keys that express the intended logical records.
- Metadata is not automatically transferred from an input TSV to an output DataFrame or TSV. Retain applicable metadata explicitly, and reconsider it when transformations change the table's meaning.
- Scout's native TSV format is not quoted CSV. Avoid embedded tabs, newlines and values requiring CSV quoting.

For operations that depend on native Scout type conversion, duplicate-key merging, multi-valued field semantics or identifier translation, use Workspace's native TSV tools or ScoutCoder's workflow-aware interfaces.

When the interpretation of a generated table matters, `tsv_info` and `tsv_query` can verify its key field, value fields, type and representative values through the native Scout parser.

## References

- `Workspace/doc/user/TSV.md` — task-specific options, interpretation, result
  shapes and mutation semantics.
- scout-gear `doc/user/ProcessingTabularData.md` — Scout TSV format, types,
  Ruby API, serialization, traversal and joins.
- `Workspace/README.md` — task reference.
- The Python interfaces are documented in scout-rig's `python/README.md` and
  implemented in `python/scout/__init__.py`.
