# Using Workspace

Workspace handles ordinary files, command execution and Scout TSV tables. The workflow root and Scout-AI's read/write grants are available to the file tools. Additional read grants let you inspect inputs outside the project. The same grants feed the bwrap mounts used for commands.

| What you need | First call |
| --- | --- |
| Inspect a directory or file | Call `list_directory` with `directory` and `recursive: false`, then pass a returned file path to `read`. |
| Create or edit text | Use `write` for complete contents, `precise_edit` for an exact selector with a known match count, or `patch` for a multi-hunk diff. ScoutCoder manages registered development resources through its Path kinds. |
| Run a command or script | Pass a command as `cmd` to `bash`, or pass `code` or a script `file` to `python`, `ruby` or `r`. Inspect `exit_status`, `stdout`/`stderr`, and `failure_kind` when a failure is classified. |
| Inspect or query a table | Call `tsv_info` with just `file` to inspect its fields. Use `tsv_read` to normalize a source or `tsv_query` to retrieve exact keys. |
| Diagnose a rejected path | Call `sandbox_paths` with no inputs in the affected context. Check the requested operation against its grant and, for commands, the planned mount destination and mode. |

For example, if a read grant covers `/data/study`, call `read` with `{"path":"/data/study/counts.tsv","file_end":"head","limit":1}`. For a table beginning with a header, the result is the header line. A derived table can be written under the workflow root or another writable grant.

## What to expect from the tools

These contracts hold for every call:

- **Reads are bounded.** `read` returns text with a default of 100 lines and a 16 KiB inline ceiling. Omitting both limits does not fetch an unlimited file; an oversized selection returns a structured envelope instead of clipped text, and `read_window` pages the remainder by byte offset. Negative *and zero* `limit`/`chars` are rejected — zero is not an unlimited escape.
- **Search is literal and truthful.** `search` returns the plain array of matching relative paths; `search_details` adds 1-based line numbers, bounded snippets, scanned/skipped counts and truncation reasons. A query is never a regular expression. A scan that hits its file or byte budget is reported as truncated, never as a complete negative.
- **Exec results are faithful.** A child that exits nonzero returns its real exit code with stderr verbatim when small (even empty) and stdout preserved independently. `-1` is only used when no exit code exists. A classified failure additionally carries `failure_kind` (`timeout`, `signal`, `launch`, `runner_exception`). Oversized streams are bounded to an in-order head/tail whose budget includes the elision markers, and the complete stream is spooled to a file under the step's `files_dir` (`stdout_full`/`stderr_full`), readable with `read` in the same caller context.
- **Metadata changes are explicit.** `tsv_info` is side-effect free: it only reports. Persisting a change to a TSV's key field, field labels, cast, namespace, identifiers or type is the job of `tsv_set_metadata`.
- **Dry runs are read-only.** `patch` with `dry_run: true` previews and writes nothing, even when `apply_direct` is true.

See [Sandbox and outputs](SandboxAndOutputs.md) for paths, symlinks and result files, [Working with TSV files](TSV.md) for table operations, and the [task reference](../../README.md#tasks) for individual calls.
