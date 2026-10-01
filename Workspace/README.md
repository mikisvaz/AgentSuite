Workspace

Filesystem helpers, sandboxed command execution, patching and precise edits, and Scout TSV utilities for AI agents operating over a codebase or dataset. Workspace holds the local-machine half of the former ComputerUse workflow. All tasks integrate with the Scout/Rbbt workflow model (typed inputs/outputs, caching, provenance, and CLI integration). You can call them programmatically from other workflows or via the workflow runner.

The web-search, document-conversion, and retrieval (RAG) tasks that used to live alongside these in ComputerUse now form the Research workflow. Research requires Workspace and reuses its sandbox helpers (notably `cmd_json`) to run its conversion commands, but it registers its own tasks and does not inherit Workspace's. `kb_register`, `current_time`, and `playwright` are not part of Workspace; they remain available in ComputerUse.

Dependencies and environment
- Ruby and the Scout/Rbbt environment (the workflow extends Workflow)
- The system `patch` utility for the patch task
- bwrap for sandboxed execution (optional; see below)

Notes on outputs
- The `patch` task returns a structured JSON result (stdout, stderr, exit_status,
  generated_patch, used_strip, tried_strips, applied flags).
- The `precise_edit` task returns a JSON verification record (see its section).
- Exec tasks (bash/python/ruby/r) return stdout, stderr and exit status as
  JSON. When a command fails (non-zero exit) or its error stream is huge,
  `stderr` is condensed to a root-cause-first view: the distinct error-bearing
  lines are hoisted to the top, repeated lines are collapsed (`line  [x N]`),
  host Ruby framework backtrace frames are dropped, giant flattened argv
  dumps from the sandbox launcher are summarized, and long streams are cut
  with explicit `... [N lines omitted] ...` markers. The complete, uncondensed
  stream is preserved on disk and its path returned in the additional
  `stderr_full` field, so nothing is lost. Successful commands with small
  stderr are returned byte-identically.

These tools are intended to be used to alter the files on one particular
project while limiting access to arbitrary places in the filesystem. For that
reason tasks like `read`, `write`, `delete`, `search` and `list_directory`
check that the input paths are under the current process working directory
(PWD). You will also be granted access to workflow jobs generated during your
work.

Execution of arbitrary code with `bash`, `ruby`, `python`, `r`, or `patch` is
ran using the bwrap tool to create a secure sandbox that only provides write
access to the current process working directory, and a few other locations like
'/tmp', '~/.rbbt/tmp', '~/.rbbt/var', '~/.scout/tmp', and '~/.scout/var', and
read access to other locations that may contain libraries and code, such as the
users home directory, '/usr/lib', and '/usr/local/lib'. Some tools you execute
this way may intend to create cache or temporary files outside the allowed
directories, consider if these tools can be pointed to do that inside the
current directory, perhaps using environment variables. Tools can also be
executed without a sandbox if bwrap tool is not available in the system or if
explicitly deactivated by setting the environment variable 'BWRAP_PATH' to
'false'. Each invocation runs in a fresh Bash, Python, Ruby or R process;
variables from previous calls are not available.

A note on etiquette for AI agents: If you are going to be generating files with
data and scripts to perform tasks or test developments, please consider writing
them on a directory like './tmp', './results', or './sandbox'.

Sandbox permissions have two layers that do not always coincide, which is a
common source of confusion. The `read`, `write`, `delete`, `search`,
`list_directory`, and `file_stats` tasks are checked in Ruby against an
allowlist (the workflow root plus configured writable and readable paths), while
`bash`, `ruby`, `python`, and `r` run inside the bwrap sandbox built from the
same lists plus exec extras. A path can therefore be readable from `bash` but
rejected by `read`, or granted by the allowlist yet bound read-only inside
bwrap. Run the `sandbox_paths` task to get the exact inventory: every allowed
read and write path, whether it is a file, a directory, or a symlink and where
the symlink points, the realpath, the origin of the permission (root, config
key, thread, exec defaults, TMP_DIRS), and the planned bwrap mounts with source,
destination, ro/rw mode, and whether the destination was redirected because of a
symlink.

Workspace's TSV tasks are documented in detail in
[Working with TSV files in Workspace](doc/user/TSV.md); the task reference
below summarizes them.

Examples:

```bash
scout workflow task Workspace list_directory --directory . --recursive=false
scout workflow task Workspace bash --cmd 'ruby -v'
scout workflow task Workspace tsv_info --file data.tsv
```

```ruby
prepared = Workspace.job(:tsv_read, nil,
  file: 'genes.csv', sep: ',', header_hash: '', type: 'double').run
```

Workspace must be installed or otherwise available to Scout's workflow lookup
for the CLI examples to resolve it.

## Testing

From the Workspace workflow directory, the task implementation tests can be
run with:

```bash
ruby -Itest test/Workspace/tasks/test_tsv.rb
ruby -Itest test/Workspace/tasks/test_exec_helpers.rb
ruby -Itest test/Workspace/tasks/test_patch.rb
ruby -Itest test/Workspace/tasks/test_precise_edit.rb
```

They cover the TSV suite, the sandbox/exec helpers, patch conversion, and
precise_edit; they do not require network services or external CLIs, and they
do not test or modify ComputerUse or Research.

# Tasks

## write
Write a file

Write content to a file under the workflow root. Paths are validated so targets must be under Workspace.root.

There is no need to check for the presence of directories, if the directory
structure that will hold the file does not exist it will be created.

Inputs
- path (required): path under Workspace.root
- content (required): text to write

Outputs
- A short success message

## read
Read a file (head/tail or full)

Inputs
- path (required): Path to the file
- limit: Max number of lines to return
- chars: Max number of chars to return
- file_end: head | tail (default: head)
- start: Line offset (default: 0)

Outputs
- The requested file contents

## list_directory
List files and directories

Inputs
- directory (required): path under Workspace.root. Regular expression not allowed.
- recursive: boolean (default: true)
- stats: boolean (default: false)

Outputs
- JSON with files, directories (and optional stats)

## file_stats
Return basic stats about a file

Inputs
- file (required): path under Workspace.root

Outputs
- JSON with basic stats (type, size, lines, mtime)

## pwd
Return current working directory

Outputs
- String with the current working directory path

## sandbox_paths
Report the effective sandbox filesystem permissions

Read-only introspection, takes no inputs. Use this whenever a path is rejected,
whenever you need to know if a location is writable, or before assuming that
something readable in `bash` is readable with the `read` task.

Outputs
- JSON with:
  - root, pwd, pwd_realpath, home, bwrap: context of the workflow process
  - note: explanation of the two permission layers (Ruby allowlist for the
    filesystem tasks vs bwrap mounts for the exec tasks)
  - writable: array of entries, one per writable path
  - readable: array of entries, one per readable path
  - mounts: planned bwrap mounts
  - realized_mounts: current process /proc/mounts view when readable

Each writable/readable entry has:
- path: the expanded path
- symlink: boolean
- readlink: symlink target when applicable
- realpath: resolved path, null when missing
- exists: boolean
- type: directory | file | symlink | missing
- origin: root | dirs | allowed_paths | thread | exec_paths | read_paths |
  allowed_read_paths | thread_read

Each mount entry has:
- source: host path bound
- destination: path inside the sandbox
- mode: ro or rw
- requested_path: the path that was originally requested
- redirect: true when destination differs from requested_path, which happens
  when the requested path is a symlink and the mount was moved to its realpath

Example
```
Workspace.sandbox_paths # => {"root"=>"/home/user/git/AgentSuite/Workspace",
  "pwd"=>"/home/user/git/AgentSuite/Workspace", "pwd_realpath"=>"...",
  "home"=>"/home/user", "bwrap"=>"/usr/bin/bwrap",
  "writable"=>[{"path"=>"/home/user/git/AgentSuite/Workspace", "symlink"=>false,
    "readlink"=>nil, "realpath"=>"/home/user/git/AgentSuite/Workspace",
    "exists"=>true, "type"=>"directory", "origin"=>"root"}, ...],
  "readable"=>[{"path"=>"/bin", ..., "origin"=>"exec_paths"}, ...],
  "mounts"=>[{"source"=>"/bin", "destination"=>"/bin", "mode"=>"ro",
    "requested_path"=>"/bin", "redirect"=>false}, ...]}
```

## delete
Delete a file or directory

Deletes a file or directory under the workflow root, applying the same path
sanity checks as the read/write tasks. If the target is a directory it is
removed recursively. The workflow root itself cannot be deleted.

Inputs
- file (required): file or directory path under Workspace.root

Outputs
- A short message naming what was deleted

*Section written for Workspace; the source ComputerUse README has no
corresponding section.*

## copy
Copy a file or directory

Copies a file, or a directory recursively, from a readable source to a
writable target, both under the workflow root. Missing target directories are
created automatically; copying a path onto itself is rejected.

Inputs
- source (required): existing file or directory to copy
- target (required): destination path

Outputs
- No meaningful return value; the effect is the copy itself

*Section written for Workspace; the source ComputerUse README has no
corresponding section.*

## search
Search plain-text file contents

Searches file contents beneath a directory for a literal query string and
returns the matching file paths, relative to Workspace.root. Only compressed
files (`.zip`, `.gz`, `.bgzip` by extension, via `Open.compressed?`) are
skipped; all other files are read and matched as plain text, and regular
expressions are not interpreted.

Inputs
- path (required): directory to search from
- query (required): string to look for in file contents
- max_results: maximum number of matching paths to return (default: 10)
- max_files: maximum number of files to examine (default: 200)

Outputs
- JSON array of relative file paths (empty when nothing matches)

*Section written for Workspace; the source ComputerUse README has no
corresponding section.*

## bash
Run a bash command

Execute an arbitrary bash command in a sandbox when available.

Inputs
- cmd (required): command string
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## python
Run Python code or file

Inputs
- code: Python code to run (ignored if file provided)
- file: Path to a Python file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## ruby
Run Ruby code or file

Inputs
- code: Ruby code to run (ignored if file provided)
- file: Path to a Ruby file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## r
Run R code or file

Inputs
- code: R code to run (ignored if file provided)
- file: Path to an R file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## patch
Apply a patch to repository files with auto-detected strip, canonical ChatGPT conversion, and optional direct-apply fallback

This task accepts textual patch content and applies it using the system patch utility from the repository root. It is designed for AI agents that produce ChatGPT-style patch blocks and handles them robustly:
- Converts ChatGPT markers (*** Begin/End Patch; *** Update/Add/Delete File: path) into a canonical unified diff with a/ and b/ headers
- Synthesizes @@ headers when missing and ensures a trailing newline
- Auto-detects the correct -p (strip) level by trying -p0..-p4 with --dry-run (when strip is not provided)
- Returns structured diagnostics including the generated patch text and all tried -p attempts
- Optional apply_direct fallback that writes full-content updates/additions directly if patch cannot be applied (with backups)

Important usage guidance
- Patches are hard to write correctly, for large changes that change most of the file consider using `write` with the new version instead of using patch
- Use patch ONLY for updating existing files. Do NOT use patch to add or delete files.
  - To add a file, use the write task.
  - To delete a file, use the delete task.
- Use dry-run after a few errors to confirm applicability and inspect diagnostics.
- Input formats supported:
  - ChatGPT-style blocks (recommended for agents):
    *** Begin Patch
    *** Update File: path/relative/to/root.ext
    <either a canonical unified diff hunk, or the full new file content>
    *** End Patch
  - Canonical unified diff (--- a/... +++ b/...) with @@ hunks
- Paths must be repo-root relative (no leading ./ or ../). Absolute paths are rejected or normalized.
- Ensure the patch text ends with a trailing newline.

Diagnostics returned
- stdout, stderr, exit_status: raw outputs from the patch utility
- generated_patch: canonical diff the tool produced from your input
- used_strip: the -pN selected by auto-detection, or null if none worked
- tried_strips: array of {strip, stdout, stderr, exit_status} trials
- applied: whether the patch was applied (false on dry_run)
- applied_directly: whether direct-write fallback was used (see caution below)
- suggestion: human-readable guidance

Common pitfalls and fixes
- Patch content contains code fences (``` ... ```): strip fences before submission.
- Missing diff headers: use ChatGPT-style Update File block or a canonical unified diff.
- Paths have leading ./ or are absolute: provide clean, root-relative paths.
- No trailing newline: add one to the patch text.
- Wrong strip level: auto-detect tries 1,0,2,3,4; if it fails, specify strip explicitly.
- Trying to add/delete via patch: use write/delete tasks instead.

Caution on apply_direct
- apply_direct writes full-file "plain content" updates directly when the diff cannot be applied and the input looks like a full replacement. It makes timestamped backups before overwriting.
- Prefer using patch (diff) for updates; reserve apply_direct for last-resort plain-content updates. Do not rely on apply_direct for creating or removing files—use write/delete tasks instead.

Inputs
- patch (required): Patch content (unified diff or ChatGPT-style)
- strip: Integer -pN. If omitted, auto-detects via --dry-run
- dry_run: Boolean. If true, checks only; does not modify files
- apply_direct: Boolean. If true, when patch diffing fails and the block looks like a full-file replacement, write the file directly (with backups)

Outputs
- JSON with:
  - stdout, stderr, exit_status
  - generated_patch (canonical unified diff we produced)
  - used_strip (integer or null)
  - tried_strips ([{strip, stdout, stderr, exit_status}])
  - applied (boolean)
  - applied_directly (boolean)
  - suggestion (string)

Notes
- To add and remove entire files please use write and delete tasks, not patch.
- All paths are validated and must remain under the root (current directory of the process) (".." is disallowed). Absolute paths are normalized against the root when possible.
- When apply_direct is used, existing files are backed up to .bak.<timestamp> and writes are atomic (tmp file then rename).

## precise_edit
Apply one exact, count-checked mutation to a file under an allowed write path.

The operation is replace (selector occurrences substituted by replacement),
insert (replacement appended after each occurrence), or delete (each occurrence
removed). Required inputs: `path`, `operation`, `selector`, `replacement`, and
`expect_matches`, the exact number of selector occurrences the file must
contain; an optional SHA-256 `expected_hash` guards against editing stale
content. A missing file, empty selector, unknown operation, or negative match
count raises a controlled `ParameterException`. A hash mismatch or an
unexpected match count leaves the file untouched and returns a JSON record
with status `precondition_failed`, the observed match count, and the
precondition values. A successful edit returns status `updated` with the
resolved path, match count, and a `verification` block (new SHA-256, byte
sizes before and after). Bulk editing and fuzzy matching are out of scope.

## TSV task reference

The TSV tasks use Scout's `TSV` abstraction. The recommended workflow for an arbitrary downloaded file is:

1. Use `tsv_info` to inspect how the file opens. If its delimiter or header convention is unclear, inspect a small prefix with `read` before selecting options.
2. Use `tsv_read` with the appropriate source parsing options to normalize it. For example, CSV input can use `sep: ","`; `header_hash: ""` means the source header does not have a leading `#` marker.
3. Use the normalized Scout TSV with `tsv_query`, `tsv_edit`, `tsv_merge`, `tsv_attach`, `tsv_translate`, or `tsv_sort`. These downstream tasks expect canonical tab-separated Scout TSV and do not provide source delimiter/header options. If a source needs a different interpretation, normalize it again through `tsv_read`.

The harness may be asked to return the persisted task-result path using its `return_path` feature. `return_path` is not an input declared by any TSV task. For text tasks, the normal result is the task's text; the harness option gives access to the persisted result file instead. `tsv_edit` and metadata-changing `tsv_info` are exceptions in that they also update the input file in place. The merge, attach, translate, sort, and read results do not modify their source files. There is no `tsv_write` task: TSVs are intended to be computational artifacts, with `tsv_edit` reserved for specific small edits.

### `tsv_info`

Inspect a TSV and optionally update selected metadata or representation in the source file. Returns JSON containing `key_field`, `fields`, `type`, `cast`, `namespace`, `identifiers`, `source_rows`, `unique_keys`, `entity_field_candidates`, and `registered_entity_formats`.

Required input: `file`.

Optional opening inputs: `key_field`, `fields`, `type`, `sep` (default tab), `sep2` (default `|`), `header_hash` (default `#`), `merge` (`true`, `false`, or `concat`), and `one2one` (default false). These control source interpretation while inspecting. `type` is an opening override; allowed types are `single`, `list`, `flat`, and `double`.

Optional metadata/update inputs: `new_key_field`, `rename_fields`, `cast` (`to_i` or `to_f`), `new_type` (`single`, `list`, `flat`, or `double`), `namespace`, and `identifiers` (path to identifier metadata). Supplying any of these requests an in-place rewrite of the source; without them `tsv_info` is read-only. `new_key_field` and `rename_fields` rename table metadata; `new_type` converts the representation. Empty or omitted metadata values do not clear existing metadata. Source updates require a writable regular non-symlink file and writable parent directory, and use an atomic same-directory replacement. Invalid options or an unsafe source raise `ParameterException` without replacing the source.

`entity_field_candidates` lists fields whose names are registered in `Entity.formats`; it is a name-based candidate list, not proof that every cell contains valid entity identifiers. The reported row/key counts describe the table materialized by the chosen opening options, so duplicate-key merging affects the counts.

### `tsv_read`

Read a source table and return normalized Scout TSV text. Required input: `file`.

Opening inputs include `keys` (exact keys to retain; empty means all), `key_field`, `fields`, `type` (default `double`), `sep` (default tab), `sep2` (default `|`), `header_hash` (default `#`; set to an empty string if no marker precedes the header), `cast`, `select`, `grep`, `merge` (default true; also accepts false or concat), `one2one`, `field`, `identifiers`, `namespace`, and `persist` (default false). These are applied while interpreting the source. A comma separator uses CSV loading; the output is still Scout TSV. `persist: true` uses HDB persistence under the task's own `.files` area rather than an arbitrary caller-supplied path.

Output metadata can additionally be set with `new_key_field` and `rename_fields`. The result uses canonical tab-separated columns, pipe-separated multi-values, and `#`-marked headers/preamble, ready for downstream TSV tasks. Requested `keys` are retained only when found and emitted in deterministic sorted order. `select` and `grep` are Scout TSV filters. Cast values are restricted to `to_i` or `to_f`; consult `tsv_info` or read a small result when deciding whether a cast is appropriate.

Example: normalize a CSV with a plain header, then query the normalized result:

```ruby
normalized = Workspace.job(:tsv_read, nil,
  file: "download.csv", sep: ",", header_hash: "", type: "double").run
File.write("prepared.tsv", normalized)
answer = Workspace.job(:tsv_query, nil,
  file: "prepared.tsv", keys: ["A123"]).run
```

### `tsv_query`

Fetch exact key values from a prepared Scout TSV. Required inputs: `file` and `keys` (array of key strings). Returns a JSON object with table `key_field`, `fields`, `type`, selected `column`, `queries` in request order, and `missing_keys`. Each query entry has `key`, `found`, and `value`; missing keys retain their request position and have a null value.

Optional inputs are `key_field`, `fields`, `type`, `cast` (`to_i` or `to_f`), `column`, `merge`, `one2one`, and Scout's convenience `field`. `column: "key"` selects the queried key itself; otherwise `column` must name a value field. `field` and `column` cannot be used together. Cast applies recursively to returned values, whether or not a column is selected. Named-column queries on flat TSVs are rejected because flat rows do not provide named field boundaries. Unknown fields and invalid casts raise `ParameterException`.

### `tsv_edit`

Edit one existing key in place and return the updated Scout TSV text. Required inputs: `file` and `key`. Specify exactly one edit form:

- Field edit: `field` plus `value`. Named-field edits are supported for `single`, `list`, and `double` tables; `flat` does not support named-field editing. For a double-valued field, the replacement string is split on `|` into its values.
- Whole-row edit: `row` is a JSON string whose shape must match the TSV type. A `single` row is a scalar; a `list` row is an array with one scalar per field; a `double` row is an array of value-arrays, one per field; a `flat` row is an array of scalars. JSON row values must be scalars (or arrays in the double shape), and row lengths are checked against the table metadata.

Optional `type` overrides the declared type for parsing. The key and named field must exist. The source must be a writable regular non-symlink file. Changes are validated before an atomic same-directory rewrite; invalid edits leave the source unchanged. The task does not create an alternate edited source: use the harness result path only to inspect or retain the task's returned output.

### `tsv_merge`

Merge two prepared TSV files and return the new Scout TSV text; inputs are not modified. Required inputs: `left` and `right`. Optional `strategy` is `replace` (default) or `zip`.

Both tables must have identical `key_field`, `fields`, `type`, and compatible annotation metadata (`namespace`, `identifiers`, `serializer`, and `entity_options`). With `replace`, right-side rows replace the entire row for any key present on the right, while left-only keys remain. With `zip`, values are combined using Scout's `zip_new` behavior; this is supported only for `double` tables. Incompatible tables and unknown strategies raise `ParameterException`.

### `tsv_attach`

Attach selected fields from a right-hand prepared TSV to a source table on an exact key/field match, returning new Scout TSV text without modifying either input. Required inputs: `source`, `other`, `match_key` (source key or field), and `other_key` (right key or field). Optional `fields` selects right-side fields; by default, all right value fields except the matching field are attached. `one2one` defaults to true.

Flat TSVs are unsupported. A right-side value-field match requires a list or double right table. Requested fields must be existing right value fields and must not collide with source fields. Repeated right-side match values are rejected. The attach is incomplete (`complete: false`): source rows without a match remain, with empty attached values. Scout `TSV.attach` is applied to a copy because it mutates its source table.

### `tsv_translate`

Translate a key or value field using a prepared TSV and an explicit identifier mapping; return a new Scout TSV text without modifying the source. Required inputs: `file`, `field`, `target_format`, and `identifiers` (mapping TSV path). Optional inputs: `type`, `key_field`, `fields`, and `one2one` (default false). Uses Scout `TSV.translate`; the requested field and target format must be interpretable by the mapping. Mapping and source files are expected to be in canonical Scout TSV form.

### `tsv_sort`

Sort a prepared Scout TSV with Scout's `TSV#page` implementation. Required input: `file`. Optional inputs are `column` (value field or `key`, default `key`), `direction` (`ascending` or `descending`), `page` (1-based, default 1), `page_size` (positive row count; omitted means all keys), `cast` (`to_i` or `to_f` for numeric value-field sorting), and `just_keys` (default false).

When `just_keys` is false, the JSON result includes the selected page as canonical Scout TSV text in `tsv`, together with the selected column, direction, page number, effective page size and total key count. When true, `keys` contains the page's ordered keys instead. The full TSV preserves this sorted key order (rather than the receiver's original order). Sorting by a value field uses its first value for list/double rows, following Scout's `TSV#page`/`sort_by` behavior; `cast` changes that comparison value to integer or float, with Ruby's `to_i`/`to_f` conversion semantics. Sorting by `key` orders on the key and ignores `cast`. Unknown fields, invalid casts/directions and non-positive page numbers or sizes are rejected; a page beyond the available rows returns an empty page. Value-field sorting on flat TSVs is unsupported.

### Shared TSV behavior and safety

All TSV tasks validate source paths as files. `tsv_edit` and metadata-changing `tsv_info` additionally reject symlinks and non-writable source/directory paths before replacement. The tasks use Scout TSV parsing, metadata, conversion, and merge/attach/translation behavior rather than treating TSV rows as untyped strings. Where Scout rejects an incompatible type or row shape, the task reports a controlled `ParameterException`. Use `tsv_info` to inspect shape, `read` to inspect source text when parsing is unclear, and `tsv_read` to make a deliberate normalized variant before downstream operations.

All Workspace tasks are exported for use by other workflows: `write`, `read`, `list_directory`, `file_stats`, `pwd`, `copy`, `delete`, `search`, `sandbox_paths`, `bash`, `python`, `ruby`, `r`, `patch`, and `precise_edit` are exported for direct execution (`export_exec`), and the eight TSV tasks are exported as regular workflow tasks. No Workspace task is internal-only.

For exact input types and defaults, consult the task definitions or `task_inputs`.

This README describes the tasks registered by `Workspace/workflow.rb` and its required task files.
