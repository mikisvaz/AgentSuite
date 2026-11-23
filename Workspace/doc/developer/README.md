# Developing Workspace

Load the workflow through `workflow.rb` with Ruby, Scout and scout-ai available. The task definitions live under `lib/Workspace/tasks/`. Filesystem, execution, edit and time tasks use `export_exec`. The TSV tasks use `export`. The system patch utility supports diff application, and bubblewrap provides process isolation for the exec runner.

## Register access in the calling context

Use the public scout-ai registrar from the Ruby thread that will invoke Workspace. For example, given existing input and output directories:

```ruby
LLM::Sandbox.allow_read_path('/data/study')
LLM::Sandbox.allow_path('/analysis/results')
```

For a Scout Step, `allow_read_job(job)` and `allow_job(job)` on the same module register its result path, info file and files directory in the corresponding mode. Thread-local registration scopes access to the caller. Check the receiving context separately when delegating.

| Purpose | Scout configuration keys |
| --- | --- |
| Shared writable grants | `allowed_paths`, `dirs`, `root`, `thread` |
| Additional shared read grants | `allowed_read_paths`, `exec_paths`, `read_paths`, `thread_read` |
| Extra writable or read-only exec mounts | `bwrap_paths`, `bwrap_read_paths` respectively |

Workspace requests grants with scope `Workspace`. Core consults the workflow and sandbox configuration tokens and uses the uppercase environment variable as a fallback for each key. String lists accept colon or comma separators. Prefer absolute directory names in configuration. Unlocated Scout paths use the resource maps. For the core implementation, see [scout-ai sandbox.rb](https://github.com/mikisvaz/scout-ai/blob/main/lib/scout/llm/sandbox.rb).

## Enforcement and reporting

- In `filesystem.rb`, `normalize` calls `LLM::Sandbox.authorize_path` with the root, shared grants, operation mode and relative base. Use the decision to authorize the operation and preserve the operational spelling for I/O. An allowed decision concerns containment. OS permissions remain applicable. Every tsv task calls the same `normalize` helper on every materialized input (main file, both merge inputs, both attach inputs, and the translate identifiers mapping when opened) before opening it, and on the source again with `:write` before any rewrite.
- In `exec.rb`, `sandbox_run` starts from the same grants, includes the workflow root as writable, and adds exec-specific paths before building bwrap arguments. Planning is shared with `sandbox_paths`, deduplicates mounts nearest-parent-first, resolves symlinked dependency mounts to their exact target, and orders parents before children. The base plan reported by `sandbox_paths` omits per-command additions; `cmd_json` preserves the `writable_paths` extras. The runner reports `execution_mode` (`bwrap` or `host_fallback`) — the fallback policy is unchanged — and uses the same working directory in both modes. The runner falls back to host execution if bwrap is absent or disabled.
- When extending a task, identify where it opens each input and output. The native TSV helpers and patch's direct fallback perform file I/O in the workflow process. Filesystem tasks check the arguments passed to `normalize`. Recursive operations require separate consideration of descendants.
- Keep task descriptions in the parsed root README and input help on the declarations. The [agent introduction](../user/README.md) owns first-call guidance.

## Runtime contracts implemented by the tasks

- **Exec (`exec.rb`)**: one shared child runner for all four language tasks. An ordinary nonzero exit returns the real exit code; `-1` appears only when no exit code exists. A classified failure adds the additive `failure_kind` (`timeout`, `signal`, `launch`, `runner_exception`). Child stderr is returned verbatim when small — including empty stderr — and stdout is preserved independently of stderr. Oversized streams are condensed to an in-order head/tail whose byte budget includes the elision markers, with the complete stream spooled to a per-call artifact under the step's `files_dir` (`stdout_full`/`stderr_full`) readable by the exported `read` tool in the same caller context. Debug diagnostics include the launcher argv. Streams are never dropped or reordered.
- **Filesystem (`filesystem.rb`)**: `read` validates all inputs before any I/O; negative **and zero** `limit`/`chars` are rejected (zero is not an unlimited escape); default is 100 lines with a 16 KiB inline ceiling; an over-ceiling selection returns a structured envelope (reason/offset/ceiling) rather than clipped text, and `read_window` continues by byte offset. Tail uses a reverse scan for seekable plain files and a bounded forward scan otherwise (compressed files are documented as unsupported there). `search` keeps the plain relative-path array for existing callers; `search_details` adds 1-based line numbers, bounded snippets, scanned-file/skipped-directory counts and an explicit truncation reason. A budget-exhausted scan is always reported as truncated, never as a complete negative. Both searches are literal (regexp punctuation included) and skip compressed files; `search_details` supports a filename-only glob mode. `list_directory` keeps its full-array shape; `list_directory_page` is the bounded, deterministic `more`-flagged page (a `page_size` of 0 or empty returns all entries). `file_stats` returns cheap metadata with sampled binary detection by default; an exact line count is opt-in through `count_lines` and streams the file. `copy` is identity-aware (inode/`samefile`) and rejects a symlink source; `sandbox_paths` exposes `realized_mounts` only when asked with `verbose: true`.
- **TSV (`tsv.rb`)**: `tsv_query` and `tsv_sort` share one field resolver accepting the key-field label, the alias `"key"`, or a value-field name, with the `@` escape for a value field literally named `"key"`; an unknown name is an error listing the actual key label and the available value fields. `tsv_info` is **side-effect free**; metadata persistence lives in `tsv_set_metadata`, which requires at least one metadata option, refuses CSV sources, bakes the supplied `key_field`/`fields` projection into the persisted table and rewrites atomically after a write authorization. `return_path` remains a wrapper-level way to retrieve complete products. Interactive sorting defaults to a bounded page (500 rows) and never truncates silently; queries are capped at 5000 keys; persisted transforms are never truncated. Persisted CSV mutation is refused (normalize with `tsv_read` first) rather than emitting corrupt quoting. Cast allowlists are unified to `to_i`/`to_f`. The `tsv_edit` row branch rejects embedded tabs, newlines and inner separators before touching the source.
- **Patch (`patch.rb`)**: a single parse and a validate-the-complete-plan-then-commit sequence; `changed_files` stays truthful on partial failure; targets are authorized before conversion reads *and* before apply; strip/header resolution is consistent between probe and apply; leading literal `-`/`+` lines are preserved byte-exactly; no `Dir.chdir`; malformed probes terminate with the real stdout/stderr/status and no misleading suggestion; diagnostics are bounded with the full diff saved to a `files_dir` artifact readable in context. `dry_run: true` previews and writes nothing — including when `apply_direct` is true.
- **Text edit (`precise_edit.rb`, `text_edit.rb`)**: public surface unchanged. Successful zero-match expectations and identical replacements verify `changed=false` with no write; refusals return the original content plus a reason; literal backslashes stay literal. Dossier integration is not implemented (source absent — documented blocker); the transformation library remains Workspace-local.

## Tests

From the Workspace checkout with its Scout dependencies installed, run each task suite in a fresh Ruby process:

```bash
for suite in test/Workspace/tasks/test_*.rb; do
  ruby -Itest "$suite" || exit 1
done
```

The suites are:

- `test_exec.rb` — the shared child runner: real exit codes for ordinary nonzero exits, verbatim small (including empty) stderr, stdout independence, `failure_kind` classification (`timeout`/`signal`/`launch`/`runner_exception`), `-1` only when no exit code exists, bounded head/tail condensation with the budget inclusive of elision markers, `stdout_full`/`stderr_full` spooling under `files_dir`, launcher argv in debug diagnostics, `execution_mode` reporting, shared host/bwrap cwd, mount dedup and symlink exact-target mounts.
- `test_exec_helpers.rb` — mount planning and diagnostics, including the base plan shared with `sandbox_paths`.
- `test_filesystem.rb` — grant scope, symlink resolution, missing descendants and relative paths.
- `test_filesystem_contracts.rb` — the read/search/listing contracts: input validation before I/O (negative and zero limits), the 100-line/16 KiB defaults, the structured over-ceiling envelope and `read_window` continuation, literal search including regexp punctuation, `search_details` line numbers/snippets/skipped counts/truthful truncation, `list_directory_page` paging and `file_stats` streaming/binary detection.
- `test_patch.rb` — the rebuilt patch suite: dry-run read-only even with `apply_direct`, terminal malformed probe with real output, parse-then-validate-then-commit, truthful `changed_files` on partial failure, authorization before conversion reads and apply, consistent strip/header resolution, byte-exact leading `-`/`+`, bounded diagnostics with a saved full diff.
- `test_precise_edit.rb` and `test/scout/llm/test_text_edit.rb` — precondition/zero-match/identical-replacement `changed=false` behavior, refusal payloads, literal backslashes.

To check a deployment, run `sandbox_paths` and exercise the intended file and exec operations in the same caller context. Do not treat any of these as concurrency guarantees: none of the tasks claim safe interleaved mutation by concurrent callers.
