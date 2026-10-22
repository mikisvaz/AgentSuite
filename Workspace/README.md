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

Code execution with `bash`, `ruby`, `python`, `r`, or `patch` runs inside a
bwrap sandbox (write access: the current process working directory plus the
usual tmp/var locations; read access: the places where libraries and code
live). Tools that intend to create cache or temporary files elsewhere must be
pointed inside the current directory, typically through environment variables.
Execution is unsandboxed when bwrap is not available in the system or when the
environment variable 'BWRAP_PATH' is set to 'false'. Each invocation runs in a
fresh Bash, Python, Ruby or R process; variables from previous calls are not
available. Which paths each kind of action can reach is documented in the
scout-ai developer document `doc/developer/Sandbox.md` (§2 "Which paths can
this action reach?").

The two permission layers (Ruby allowlist for the filesystem tasks vs bwrap
mounts for the exec tasks), which tools are sandboxed, and the recovery
procedure for a path that exists but a tool cannot see are documented
authoritatively in the scout-ai developer document
`doc/developer/Sandbox.md`; the `sandbox_paths` task entry below reports the
live inventory of both layers.

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

## See also (verified pointers)

- scout-ai `doc/developer/Sandbox.md` — sandbox model, which tools are
  confined, recovery for a path a tool cannot see.
- scout-gear `doc/user/ProcessingTabularData.md` — TSV value types
  (`single`/`list`/`flat`/`double`), opening options, `sep2`.
- scout-essentials `doc/user/WorkingWithFiles.md`,
  `doc/user/RunningCommands.md`, `doc/user/HandlingStreams.md` — the `Open`
  and `CMD` layers beneath code run through `bash`/`python`/`ruby`/`r`.
- scout-ai `doc/user/ToolCalling.md` (§ "Exposing an entire workflow") —
  why every exported task here appears as a callable tool to an agent.

Where job outputs land: every task runs as a Scout job under the workflow
checkout's `var/jobs/Workspace/…`; each job carries a `.files` sidecar
directory for auxiliary outputs; the harness `return_path` option returns the
persisted result file inside the job directory; and TSV `persist` uses the
task's own `.files` area. A result that "vanished" is a job-directory
question, not a reason to re-read stderr or write a locator script.

Choosing the write/edit tool:

- A Scout workflow source draft (task/entity/property/test file) → ScoutCoder
  `path_write` (e.g. `kind=task path=greet_user`): validated root, no
  extension to remember, and a workflow reload registers the draft.
- An ordinary file (results, notes, data) → Workspace `write`; the path tools
  reject non-registered paths by design.
- One exact replacement (you know the text and its occurrence count) →
  `precise_edit`.
- Localized diff to an existing file → `patch`.
- Whole-file rewrite or a new file → `write`.
- A python/ruby script is never the right edit tool: it skips count/hash
  verification and leaves no diff diagnostics.

Examples:

```bash
scout workflow task Workspace list_directory --directory . --recursive=false
scout workflow task Workspace bash --cmd 'ruby -v'
scout workflow task Workspace tsv_info --file data.tsv
```

```ruby
# Worked example 1 — normalize a CSV (choose the task, not the filesystem):
prepared = Workspace.job(:tsv_read, nil,
  file: 'genes.csv', sep: ',', header_hash: '', type: 'double').run

# Worked example 2 — one exact text replacement (choose precise_edit, not
# sed-in-bash or a python script, which would bypass verification):
Workspace.job(:precise_edit, nil,
  path: 'config/settings.rb', operation: 'replace',
  selector: 'OLD_VALUE', replacement: 'NEW_VALUE', expect_matches: 1).run
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

If the target is a Scout workflow draft (task/entity/property/test file),
prefer the ScoutCoder path tools — see ScoutCoder README "Agent path kinds".

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
Run Python code or file. For edits to existing files prefer `patch`/`precise_edit`; use this task for computation.

Inputs
- code: Python code to run (ignored if file provided)
- file: Path to a Python file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## ruby
Run Ruby code or file. For edits to existing files prefer `patch`/`precise_edit`; use this task for computation.

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

Minimal worked example — a ChatGPT-style block that applies:

```text
*** Begin Patch
*** Update File: lib/example.rb
@@
-old line to replace
+new line
*** End Patch
```

For one exact, count-checked replacement the cheaper call is `precise_edit`:

```ruby
Workspace.job(:precise_edit, nil, path: 'lib/example.rb',
  operation: 'replace', selector: 'old line to replace',
  replacement: 'new line', expect_matches: 1).run
```

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

Minimal worked example — replace one exact line, count-checked:

```ruby
Workspace.job(:precise_edit, nil, path: 'config/settings.rb',
  operation: 'replace', selector: 'OLD_VALUE',
  replacement: 'NEW_VALUE', expect_matches: 1).run
```

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

One line per task:

- `tsv_info` — inspect shape and metadata; optional metadata update rewrites the source. JSON.
- `tsv_read` — normalize a source into canonical Scout TSV text. Text.
- `tsv_query` — fetch exact key values in request order. JSON.
- `tsv_edit` — replace one field or one whole row of an existing key, atomically, in place. Text.
- `tsv_merge` — merge two compatible prepared tables (`replace` or `zip`). Text.
- `tsv_attach` — attach right-side fields on an exact key/field match. Text.
- `tsv_translate` — translate a key or value field through an identifier mapping. Text.
- `tsv_sort` — sort by key or field and return one page. JSON.

Per-input detail (opening options, edit forms, validation rules) lives in
[Working with TSV files in Workspace](doc/user/TSV.md). TSV value-type
semantics (`single`/`list`/`flat`/`double`, `sep2`) are Scout `TSV`
semantics, documented in scout-gear
`doc/user/ProcessingTabularData.md` (§ "Core concepts" and the opening-options
table).

Example: normalize a CSV with a plain header, then query the normalized result:

```ruby
normalized = Workspace.job(:tsv_read, nil,
  file: "download.csv", sep: ",", header_hash: "", type: "double").run
File.write("prepared.tsv", normalized)
answer = Workspace.job(:tsv_query, nil,
  file: "prepared.tsv", keys: ["A123"]).run
```

### Shared TSV behavior and safety

All TSV tasks validate source paths as files. `tsv_edit` and metadata-changing `tsv_info` additionally reject symlinks and non-writable source/directory paths before replacement. The tasks use Scout TSV parsing, metadata, conversion, and merge/attach/translation behavior rather than treating TSV rows as untyped strings. Where Scout rejects an incompatible type or row shape, the task reports a controlled `ParameterException`. Use `tsv_info` to inspect shape, `read` to inspect source text when parsing is unclear, and `tsv_read` to make a deliberate normalized variant before downstream operations.

All Workspace tasks are exported for use by other workflows: `write`, `read`, `list_directory`, `file_stats`, `pwd`, `copy`, `delete`, `search`, `sandbox_paths`, `bash`, `python`, `ruby`, `r`, `patch`, and `precise_edit` are exported for direct execution (`export_exec`), and the eight TSV tasks are exported as regular workflow tasks. No Workspace task is internal-only.

For exact input types and defaults, consult the task definitions or `task_inputs`.

This README describes the tasks registered by `Workspace/workflow.rb` and its required task files.
