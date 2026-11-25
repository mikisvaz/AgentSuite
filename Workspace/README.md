Suite of sandboxed tools to work with the filesystem and execute scripts

Use Workspace to inspect project files, edit text, execute scripts, and work with Scout TSV tables. For a first call, run `sandbox_paths` with no inputs to see the workflow root, grants from Scout-AI, and the planned bwrap mounts. A directory granted outside the checkout can be a valid input or output.

Start with the [agent introduction](doc/user/README.md). For path access and job results, see [Sandbox and outputs](doc/user/SandboxAndOutputs.md). For table preparation and row shapes, see [Working with TSV files](doc/user/TSV.md).

## Tabular artifacts

Scout TSVs are keyed tables: the first column is the key, the remaining columns are fields, and the column-name line starts with `#`, optionally preceded by `#:` metadata. Multi-valued fields use `|` as the default sub-value separator. When producing TSV artifacts for Scout, use its native format rather than an unmodified CSV/TSV export. The `workspace-tsv` skill describes creation, interpretation and manipulation of these files.

# Tasks

## sandbox_paths
Show the filesystem grants and planned bwrap mounts for this Workspace invocation.

Takes no inputs. In the JSON result, `writable` entries permit reads and writes, and `readable` lists additional read grants. Compare the grant's `path`, `origin` and `realpath` with the mount's `requested_path`, `destination` and `mode`. The report also identifies the root, working directory and bwrap setting. When available, `realized_mounts` describes the reporting process.

## pwd
Return the Workspace process's working directory spelling.

Takes no inputs. Returns `ENV['PWD']` when set, otherwise `Dir.pwd`. Use `sandbox_paths` to distinguish this value from the configured workflow root and the physical working directory.

## list_directory
List entries in a readable directory as separate file and directory arrays.

Set `recursive` to false for immediate children. The default recurses using a glob that skips dotfiles. For sizes and modification times of individual files, use `file_stats`.

## read
Read a permitted file and return its contents as text.

Omitting both limits does not fetch an unlimited file; the defaults are 100 lines and a 16 KiB inline ceiling. For line paging, use `file_end: head`, a positive `limit`, and a zero-based `start`. Use `file_end: tail` with `start` to skip lines back from the end. For character paging use head mode. Negative and zero limits are rejected — zero is not an unlimited escape; a selection past the end returns an empty string. A selection over the inline ceiling returns a structured envelope, and `read_window` pages the file from there by byte offset.

## list_directory_page
List one bounded page of entries from a readable directory as JSON.

Uses the same enumeration as `list_directory` and adds explicit paging fields and a `more` flag, in deterministic order. `page_size` 0 or empty means all entries, preserving the full-array behavior for migrating callers.

## file_stats
Return a JSON object describing a readable file or directory.

Directories return `type`. For files the task reports size in bytes and modification time with sampled binary detection, cheaply. Set `count_lines` to true for an exact line count, which streams the whole content.

## read_window
Read a byte window of a permitted file and return it as a JSON object.

Continue a clipped `read` selection by byte offset. `byte_offset` and `max_bytes` must be non-negative and positive respectively; the window is bounded by the inline ceiling. The result is structured JSON rather than literal text, so truncation metadata never hides inside the text.

## search
Find files containing a literal string and return paths relative to the search directory.

Search walks lazily beneath `path`, skipping ignored directories, and skips compressed and binary files. The default result limit is 10; a `max_results` of 0 returns every match up to the budget. `max_files` (default 200) caps the candidate files examined after filtering directories and ignored paths, and negative values are rejected. The query is never a regular expression. A scan that hits its budget is not a complete negative; use `search_details` for scanned counts and the truncation reason.

## write
Create or overwrite a writable file with the supplied text and return a confirmation.

Supply the complete contents. For one exact edit to existing text use `precise_edit`. For a ScoutCoder resource managed by a Path kind, use that kind's writing operation.

## search_details
Search contents for a literal string and return detailed matches.

Same literal matching and budgets as `search`, plus an optional relative-path `glob` restricting candidates and `filenames_only` for name matching. Returns paths with 1-based line numbers, bounded snippets, scanned/skipped counts and the truncation reason; budget exhaustion is reported as truncated, never as a complete negative.

## precise_edit
Edit exact occurrences of a text selector in a writable file and return a verification record.

Choose `replace`, `insert` after each match, or `delete`. Supply the expected number of occurrences and the required replacement input (empty text for deletion). An optional SHA-256 checks the original contents before matching. Inspect `status` for `updated` or `precondition_failed`. A successful edit includes the new hash and byte sizes.

## copy
Copy from a readable source to a writable destination.

Supply a source and target path. The task checks read and write access separately before calling Scout's file-copy operation, and a copy onto the same file is detected through file identity, not path spelling. Check the destination before relying on it.

## delete
Remove a writable file or directory and return a message naming the target.

Directory deletion is recursive. The task rejects the expanded workflow root as a target.

## bash
Run a Bash command and return stdout, stderr and exit status.

Supply `cmd` and optionally a timeout in seconds. With bwrap active the child starts in the workflow root. An ordinary nonzero exit returns the real exit code; the result also reports `execution_mode` (`bwrap` or `host_fallback`) and, when a run is classified as failed, an additive `failure_kind` of `timeout`, `signal`, `launch` or `runner_exception`. Small child stderr is returned verbatim, even when empty, and stdout is preserved independently. Oversized streams are condensed in order with markers included in the budget, and the complete stream is spooled to `stderr_full`/`stdout_full` files under the step's files directory, readable with `read`.

## python
Run Python source or a script and return stdout, stderr and exit status.

Supply `code` or a readable `file`. A supplied file takes precedence and must also be visible to the interpreter. Inline code runs from a step file. Workspace looks for python3 before python.

## ruby
Run Ruby source or a script and return stdout, stderr and exit status.

Supply `code` or a readable `file`. A supplied file takes precedence and must also be visible to the interpreter. Each call starts a fresh Ruby process.

## r
Run R source or a script and return stdout, stderr and exit status.

Supply `code` or a readable `file`. A supplied file takes precedence and must also be visible to the interpreter. Workspace looks for Rscript before R.

## patch
Apply or preview a diff against the workflow root and return diagnostics for the attempted edits.

Supply a unified diff or a ChatGPT patch block with root-relative paths. Omit `strip` to try strip counts automatically; an ambiguous placement requires an explicit `strip`. Inspect `generated_patch`, `tried_strips`, `used_strip`, `exit_status`, `applied` and `applied_directly`. For a preview set `dry_run: true`; a dry run never writes targets, whatever `apply_direct` says. A unified diff is applied with the system `patch` command only — plain-content blocks that fail conversion are reported, not rescued by writing files directly.

## current_time
Return the current time as a string with its UTC offset.

Takes no inputs and uses the workflow process's local time zone.

## tsv_info
Report the interpreted TSV schema, materialized key counts and candidate entity fields as JSON.

Use delimiter and field options for inspection. Both count fields describe the materialized table and cannot measure duplicate input lines. Reporting is side-effect free: persisting a metadata change is the job of `tsv_set_metadata`.

## tsv_set_metadata
Persist a metadata change into a TSV source and return the updated table as JSON info.

Supply at least one of `new_key_field`, `rename_fields`, `cast`, `new_type`, `namespace` or `identifiers`. The file is rewritten atomically after a write authorization. A CSV source is refused; normalize it with `tsv_read` first.

## tsv_read
Parse a TSV or CSV source and return normalized Scout TSV text.

Choose source separators and header options as needed. Select keys or fields and optionally rename them in the result. To pass the normalized table to a path input, ask the tool wrapper for `return_path: true`.

## tsv_query
Fetch exact keys and return JSON records in request order.

Each entry in `queries` contains `key`, `found` and `value`. Misses also appear in `missing_keys`. Use `column` for one value field, the exact key-field label, or the reserved alias `key`; prefix `@` for a value field literally named `key`. Supply at most one of `field` and `column`. Requests are capped at 5000 keys.

## tsv_edit
Update one existing TSV row in place and return the resulting table as TSV text.

Supply `field` and `value` for a cell or `row` for a JSON replacement matching the table type. The source must be a writable regular file with a writable parent. A symlink as the source is rejected. Row replacements containing tabs, newlines or inner separators are rejected before the file is touched.

## tsv_merge
Merge two compatible tables and return the combined TSV text.

The key field, value fields, type and annotation metadata must agree. The default `replace` strategy keeps the right row on a key collision. Use `zip` for index-wise merging of double tables.

## tsv_attach
Join right-side fields to matching source rows and return the enriched TSV text.

Supply `match_key` and `other_key` for exact matching. By default the task selects right-side value fields other than the match field. Repeated right-side match values, conflicting field names and flat tables are rejected.

## tsv_translate
Translate a key or value field through an identifier mapping and return the translated TSV text.

Supply the source `field`, the mapping TSV as `identifiers` and its destination field as `target_format`. Inspect the output keys when the mapping is incomplete.

## tsv_sort
Sort a table by key or field and return one page as a JSON object.

Choose `page` (starting at 1) and `page_size`; omitted size uses a bounded default of 500 rows and the page is never silently truncated — pass an explicit size to get everything. Sort by the key-field label, the alias `key`, or a value field name (prefix `@` for a field literally named `key`). Use `just_keys` for an ordered key array or read the canonical text in `tsv`. A numeric `cast` applies to value-field sorts. Flat tables support key sorting only.
