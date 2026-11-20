# Using Workspace

Workspace handles ordinary files, command execution and Scout TSV tables. The workflow root and Scout-AI's read/write grants are available to the file tools. Additional read grants let you inspect inputs outside the project. The same grants feed the bwrap mounts used for commands.

| What you need | First call |
| --- | --- |
| Inspect a directory or file | Call `list_directory` with `directory` and `recursive: false`, then pass a returned file path to `read`. |
| Create or edit text | Use `write` for complete contents, `precise_edit` for an exact selector with a known match count, or `patch` for a multi-hunk diff. ScoutCoder manages registered development resources through its Path kinds. |
| Run a command or script | Pass a command as `cmd` to `bash`, or pass `code` or a script `file` to `python`, `ruby` or `r`. Inspect `exit_status` and the output streams. |
| Inspect or query a table | Call `tsv_info` with just `file` to inspect its fields. Use `tsv_read` to normalize a source or `tsv_query` to retrieve exact keys. |
| Diagnose a rejected path | Call `sandbox_paths` with no inputs in the affected context. Check the requested operation against its grant and, for commands, the planned mount destination and mode. |

For example, if a read grant covers `/data/study`, call `read` with `{"path":"/data/study/counts.tsv","file_end":"head","limit":1}`. For a table beginning with a header, the result is the header line. A derived table can be written under the workflow root or another writable grant.

See [Sandbox and outputs](SandboxAndOutputs.md) for paths, symlinks and result files, [Working with TSV files](TSV.md) for table operations, and the [task reference](../../README.md#tasks) for individual calls.
