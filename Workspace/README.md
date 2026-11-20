Workspace

Use Workspace to inspect project files, edit text, execute scripts, and work with Scout TSV tables. For a first call, run `sandbox_paths` with no inputs to see the workflow root, grants from Scout-AI, and the planned bwrap mounts. A directory granted outside the checkout can be a valid input or output.

Start with the [agent introduction](doc/user/README.md). For path access and job results, see [Sandbox and outputs](doc/user/SandboxAndOutputs.md). For table preparation and row shapes, see [Working with TSV files](doc/user/TSV.md).

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

Omit both limits for the whole file. For line paging, use `file_end: head`, a positive `limit`, and a zero-based `start`. Use `file_end: tail` with `start: 0` for the last group of lines. For character paging use head mode. Tail line offsets do not reliably skip trailing lines, and tail character slicing does not enforce an exact character count.

## file_stats
Return a JSON object describing a readable file or directory.

Directories return `type`. For files the task also reads the contents to count lines and reports size in bytes and modification time.

## search
Find files containing a literal string and return paths relative to the search directory.

Search recurses beneath `path` and skips compressed files. The default result limit is 10. A nonpositive `max_results` removes that limit. The task raises if the initial glob contains more than `max_files` entries (default 200), including directories.

## write
Create or overwrite a writable file with the supplied text and return a confirmation.

Supply the complete contents. For one exact edit to existing text use `precise_edit`. For a ScoutCoder resource managed by a Path kind, use that kind's writing operation.

## precise_edit
Edit exact occurrences of a text selector in a writable file and return a verification record.

Choose `replace`, `insert` after each match, or `delete`. Supply the expected number of occurrences and the required replacement input (empty text for deletion). An optional SHA-256 checks the original contents before matching. Inspect `status` for `updated` or `precondition_failed`. A successful edit includes the new hash and byte sizes.

## copy
Copy from a readable source to a writable destination.

Supply a source and target path. The task checks read and write access separately before calling Scout's file-copy operation. The root guard refers to the step’s file helper rather than either endpoint, so a copy can fail before reaching the copy operation. Check the destination before relying on it.

## delete
Remove a writable file or directory and return a message naming the target.

Directory deletion is recursive. The task rejects the expanded workflow root as a target.

## bash
Run a Bash command and return stdout, stderr and exit status.

Supply `cmd` and optionally a timeout in seconds. With bwrap active the child starts in the workflow root. On failure, inspect `stderr` and, when present, the full log at `stderr_full`.

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

Supply a unified diff or a ChatGPT patch block with root-relative paths. Omit `strip` to try strip counts automatically. Inspect `generated_patch`, `tried_strips`, `used_strip`, `exit_status`, `applied` and `applied_directly`. For a preview set `dry_run: true` and leave `apply_direct: false`. Direct fallback handles eligible plain-content blocks in the workflow process and can write even during a dry run.

## current_time
Return the current time as a string with its UTC offset.

Takes no inputs and uses the workflow process's local time zone.

## tsv_info
Report the interpreted TSV schema, materialized key counts and candidate entity fields as JSON.

Use delimiter and field options for inspection. Both count fields describe the materialized table and cannot measure duplicate input lines. Supplying a metadata change such as `new_key_field`, `rename_fields`, `new_type`, `cast`, `namespace` or `identifiers` rewrites the source.

## tsv_read
Parse a TSV or CSV source and return normalized Scout TSV text.

Choose source separators and header options as needed. Select keys or fields and optionally rename them in the result. To pass the normalized table to a path input, ask the tool wrapper for `return_path: true`.

## tsv_query
Fetch exact keys and return JSON records in request order.

Each entry in `queries` contains `key`, `found` and `value`. Misses also appear in `missing_keys`. Use `column` for one value field or the reserved `key`. Supply at most one of `field` and `column`.

## tsv_edit
Update one existing TSV row in place and return the resulting table as TSV text.

Supply `field` and `value` for a cell or `row` for a JSON replacement matching the table type. The source must be a writable regular file with a writable parent. A symlink as the source is rejected.

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

Choose `page` (starting at 1) and `page_size`. Omitting the size returns all keys. Use `just_keys` for an ordered key array or read the canonical text in `tsv`. A numeric `cast` applies to value-field sorts. Flat tables support key sorting only.
