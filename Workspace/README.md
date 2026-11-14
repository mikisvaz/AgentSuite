Workspace

Filesystem sandboxed helpers, command execution, patching and precise edits,
and Scout TSV utilities for AI agents operating over a codebase or dataset.
All tasks integrate with the Scout/Rbbt workflow model (typed inputs/outputs,
caching, provenance, and CLI integration), and can be called programmatically
from other workflows or via the workflow runner.

When to use it: read, write, copy, delete, search and list files under the
workflow root; run bash/python/ruby/R code; patch or make count-checked
precise edits to repository files; inspect sandbox permissions; and inspect,
normalize, query, edit, merge, attach, translate and sort Scout TSV data.
Every task runs as a Scout job with provenance and caching.

The doc-acquisition tasks (web-search, document conversion, retrieval) that
once lived beside these are now the Reader workflow; `kb_register` and
`playwright` remain in ComputerUse only; `current_time` is registered here
(and in ComputerUse). Usage detail for agents — sandbox semantics, the two
permission layers, choosing the write/edit tool, examples, where job outputs
land: [Sandbox, execution and output
handling](doc/user/SandboxAndOutputs.md); per-input TSV detail:
[Working with TSV files](doc/user/TSV.md); developer material —
dependencies, testing, export surface:
[Developer documentation](doc/developer/README.md).

All Workspace tasks are exported for use by other workflows; no task is
internal-only. For exact input types and defaults, consult the task
definitions or `task_inputs`.

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

Workspace must be installed or otherwise available to Scout's workflow lookup
for the CLI examples to resolve it.

# Tasks

## current_time
Return current time as string

Returns the current system time formatted by Ruby's Time.now.to_s. Exported for direct execution (export_exec :current_time). Takes no inputs and returns a plain string for quick checks.

Example
```
ComputerUse.current_time # => "2026-02-03 11:00:00 +0000"
```

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

## tsv_info
Summarize a TSV row count, materialized key count, type and fields.

## tsv_read
Read a TSV and return normalized Scout TSV text.

## tsv_query
Fetch exact key values in request order.

## tsv_edit
Edit one field or a complete row supplied as JSON; type and row shape are validated.

## tsv_merge
Merge compatible TSV tables; replace delegates to TSV#merge (right wins), zip delegates to TSV#merge_zip for double tables.

## tsv_attach
Attach right-side TSV fields on exact matches with TSV.attach, using a copy because that API mutates its source.

## tsv_translate
Translate a TSV key or value field with TSV.translate and an explicit identifier mapping.

## tsv_sort
Sort a TSV by key or field and return one page as TSV or sorted keys.

