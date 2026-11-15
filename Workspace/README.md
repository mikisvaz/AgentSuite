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
`playwright` are ComputerUse-only capabilities with no successor
registration anywhere: they remain only in the deprecated ComputerUse
(pending migration decision — see its README deprecation notice);
`current_time` is registered here and in the deprecated ComputerUse. Usage detail for agents — sandbox semantics, the two
permission layers, choosing the write/edit tool, examples, where job outputs
land: [Sandbox, execution and output
handling](doc/user/SandboxAndOutputs.md); per-input TSV detail:
[Working with TSV files](doc/user/TSV.md); developer material —
dependencies, testing, export surface:
[Developer documentation](doc/developer/README.md).

All 24 registered tasks are agent-exposed: a `tool: Workspace`
whole-workflow introduction surfaces every task, and every task is also
callable from the CLI (`scout workflow task Workspace <task>`) and exported
for programmatic use by other workflows — none is CLI-only or internal.
For exact input types and defaults, consult the task definitions or
`task_inputs`.

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
Return the current wall-clock time as a formatted string (`Time.now.to_s`,
e.g. `"2026-02-03 11:00:00 +0000"`) for timestamping artifacts and log
lines. Takes no inputs; no timezone conversion. Exported for direct
execution (`export_exec`), so it also works as a plain method call in
workflow code.

Example
```
Workspace.current_time # => "2026-02-03 11:00:00 +0000"
```

## write
Write a file

Write content to a file under the workflow root; paths outside it are
rejected. Missing parent directories are created automatically; an existing
target is overwritten. For small exact edits to existing shared files prefer
`precise_edit` (count-checked) over rewrite-by-`write`. For a Scout workflow
source draft (task/entity/property/test file) prefer the ScoutCoder path
tools (ScoutCoder README, "Agent path kinds").

Inputs
- path (required): path under Workspace.root
- content (required): text to write

Outputs
- A short success message

## read
Read a file (head/tail or full)

Read a file under the workflow root; no limit returns the whole file. For
big files, page with `limit`/`start` (line offsets; `start` is 0-based from
the beginning for `head` and from the end for `tail` where 0 is the last
line) or cap with `chars`. Use `return_path` to hand the file itself to
another tool instead of inlining its contents.

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

Lists a directory under the workflow root (recursively by default; disable
`recursive` for a shallow listing). The first call before writing into an
unfamiliar area, and the cheap way to see what a directory holds before
deciding what to read. Set `stats: true` to get sizes and mtimes without a
separate `file_stats` per entry.

Inputs
- directory (required): path under Workspace.root. Regular expression not allowed.
- recursive: boolean (default: true)
- stats: boolean (default: false)

Outputs
- JSON with files, directories (and optional stats)

## file_stats
Return basic stats about a file

Cheap existence/size/mtime probe — `type`, `size`, `lines`, `mtime` as JSON.
Cheaper than `read` when you only need to know a file is there and how big
it is.

Inputs
- file (required): path under Workspace.root

Outputs
- JSON with basic stats (type, size, lines, mtime)

## pwd
Return current working directory

Returns the workflow root path as a string (`ENV['PWD']` or `Dir.pwd`) — the
base every relative path in the other tasks resolves against. No inputs.

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
removed recursively. The workflow root itself cannot be deleted. Recursive
directory deletion is not reversible — list before deleting.

Inputs
- file (required): file or directory path under Workspace.root

Outputs
- A short message naming what was deleted

## copy
Copy a file or directory

Copies a file, or a directory recursively, from a readable source to a
writable target, both under the workflow root. Missing target directories are
created automatically; copying a path onto itself is rejected. The standard
route for staging a fresh copy to experiment on while keeping the original.

Inputs
- source (required): existing file or directory to copy
- target (required): destination path

Outputs
- No meaningful return value; the effect is the copy itself

## search
Search plain-text file contents

Searches file contents beneath a directory for a literal query string and
returns the matching file paths, relative to Workspace.root. Only compressed
files (`.zip`, `.gz`, `.bgzip` by extension, via `Open.compressed?`) are
skipped; all other files are read and matched as plain text, and regular
expressions are not interpreted — keep queries literal (identifiers, exact
phrases) and scope `path` tightly, since every candidate file is read.

Inputs
- path (required): directory to search from
- query (required): string to look for in file contents
- max_results: maximum number of matching paths to return (default: 10)
- max_files: maximum number of files to examine (default: 200)

Outputs
- JSON array of relative file paths (empty when nothing matches)

## bash
Run a bash command

Execute an arbitrary bash command in a sandbox when available. Unlike the
filesystem tasks, `bash` sees the bwrap-mounted filesystem, so a path one
tool can see may be invisible to the other — check `sandbox_paths` before
concluding a path is missing. Long output is condensed on failure with the
full stream at `stderr_full`; use `return_path` to page large outputs.

Inputs
- cmd (required): command string
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## python
Run Python code or a Python file

General-purpose computation task — for edits to existing files prefer
`patch`/`precise_edit`. Either `file` (an existing script) or `code` (written
to a temp script under the task root and executed) must be provided; python3
is preferred when present. Useful as a fallback when a domain-specific task
does not fit.

Inputs
- code: Python code to run (ignored if file provided)
- file: Path to a Python file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## ruby
Run Ruby code or a Ruby file

General-purpose computation task — for edits to existing files prefer
`patch`/`precise_edit`. Either `file` (an existing script) or `code` (written
to a temp script under the task root and executed) must be provided. Gives
direct access to the Scout/Rbbt stack the workflow itself runs on, which is
the natural route for one-off Scout TSV or workflow API operations not
covered by the typed tasks.

Inputs
- code: Ruby code to run (ignored if file provided)
- file: Path to a Ruby file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## r
Run R code or an R file

Same contract as `python`/`ruby`: either `file` (an existing script) or
`code` (written to a temp script under the task root and executed) must be
provided; `Rscript` is the preferred runner (falling back to `R`).
Statistical computation that genuinely needs R rather than a generic
scripting task.

Inputs
- code: R code to run (ignored if file provided)
- file: Path to an R file
- timeout: timeout in seconds

Outputs
- JSON with stdout, stderr, exit_status (stderr condensed on failure, full stream at stderr_full when truncated)

## patch
Apply a patch to repository files with auto-detected strip, canonical ChatGPT conversion, and optional direct-apply fallback

Accepts ChatGPT-style blocks (*** Begin Patch / *** Update|Add|Delete File)
or canonical unified diffs and applies them with the system `patch` utility
from the repository root. The task converts the markers into a canonical
unified diff with a/ b/ headers, synthesizes @@ headers when missing,
ensures a trailing newline, and auto-detects the strip level by dry-running
-p0..-p4 when `strip` is not given.

Guidance: use patch only to UPDATE existing files — add files with `write`,
remove them with `delete`; when a change rewrites most of a file, `write`
the new version instead. Prefer ChatGPT-style blocks; strip code fences;
paths must be repo-root relative; add the trailing newline. After a few
failed attempts use `dry_run` to inspect diagnostics; if strip
auto-detection fails, pass `strip` explicitly.

`apply_direct` is a last-resort fallback: when diffing fails and the input
looks like a full-content replacement it writes the file directly
(timestamped backups, atomic tmp+rename). Do not rely on it to create or
remove files.

Inputs
- patch (required): patch content (unified diff or ChatGPT-style)
- strip: integer -pN; omitted means auto-detect via --dry-run
- dry_run: boolean — check applicability only, do not modify files
- apply_direct: boolean — direct-write fallback when diffing fails

Outputs
- JSON: stdout, stderr, exit_status; generated_patch (the canonical diff
  produced); used_strip (integer or null); tried_strips (per-strip dry-run
  results); applied (false on dry_run); applied_directly; suggestion

## precise_edit
Apply one exact, count-checked mutation to a file under an allowed write path

Operations: `replace` (each selector occurrence substituted), `insert`
(replacement appended after each occurrence), `delete` (each occurrence
removed). Required inputs: `path`, `operation`, `selector`, `replacement`,
`expect_matches` — the exact number of selector occurrences; optional
`expected_hash` (SHA-256 of the original file) guards against editing stale
content. A hash mismatch or an unexpected match count leaves the file
untouched and returns status `precondition_failed` with the observed count;
a successful edit returns status `updated` with the resolved path, match
count and a verification block (new SHA-256, byte sizes before/after).
Bulk editing and fuzzy matching are out of scope.

```ruby
Workspace.job(:precise_edit, nil, path: 'lib/example.rb',
  operation: 'replace', selector: 'old line to replace',
  replacement: 'new line', expect_matches: 1).run
```

## tsv_info
Summarize a TSV: interpreted key field and value fields, type, cast and
entity metadata, source row count vs materialized (merged) key count, value
fields whose names match registered entity formats, and the list of
registered formats — candidates are hints, not validated identifiers.
Accepts source-interpretation options (`sep`, `sep2`, `header_hash`, `type`,
`key_field`, `fields`, `merge`, `one2one`, CSV via `sep: ','`); optional
`new_key_field`, `rename_fields`, `cast`, `new_type`, `namespace`,
`identifiers` rewrite the *source file's* header/metadata in place (use
`tsv_read` with renaming for a non-destructive variant). Returns JSON.
Per-input detail: Workspace `doc/user/TSV.md`.

## tsv_read
Read a TSV and return normalized Scout TSV text (tab columns, pipe
multi-values, `#` headers) regardless of source delimiters or header
markers; this canonical form is what the other TSV tasks operate on. Full
opening controls (`type`, `sep` — including `','` for CSV, `sep2`,
`header_hash`, `key_field`, `fields`, `merge`, `one2one`, `cast`,
`identifiers`, `namespace`, `field`), post-open filtering (`select` with a
block-like expression, `grep` with a regex, exact `keys` subset), renaming
(`new_key_field`, `rename_fields`), and `persist` for a repeated-read
materialization. When a persisted path is preferred over inline text, use
the harness-level `return_path: true`. Per-input detail: Workspace
`doc/user/TSV.md`.

## tsv_query
Fetch the values of exact keys in request order: give `keys`, get back a
JSON record with each key's value plus `missing_keys` — the spot-lookup
complement to `tsv_read`'s whole-table reads. `column` selects one value
field or the reserved `key`; `field` and `column` are mutually exclusive;
`cast` coerces numerically. Source re-interpretation options (`key_field`,
`fields`, `type`, `merge`, `one2one`) are limited to re-opening the source.
Per-input detail: Workspace `doc/user/TSV.md`.

## tsv_edit
Edit one row of a TSV in place: either set a single field (`field` +
`value`) or replace the whole row (`row` JSON), validated against the
table's type and row shape before writing. The key must already exist — use
`tsv_merge` or file writes to add rows. Per-input detail: Workspace
`doc/user/TSV.md`.

## tsv_merge
Merge two compatible Scout TSVs into one table. `strategy: replace`
(delegating to `TSV#merge`, right side wins on conflicts) or `zip`
(`TSV#merge_zip`, an index-wise merge; double tables only). Both tables must
already agree on `key_field`, `fields`, `type` and annotation metadata —
mismatches raise rather than partially merging. Returns the merged TSV text;
for attaching a few fields instead of whole-table merging, see `tsv_attach`.
Per-input detail: Workspace `doc/user/TSV.md`.

## tsv_attach
Attach value fields from a right TSV onto source rows where the source key
(or named source field, via `match_key`) exactly matches the right table's
key (or named field, `other_key`); flat tables on either side are rejected.
Works on a copy because `TSV#attach` mutates its source. `one2one: true`
(default) requires the right-side match to be unique; attached names must
not collide with existing source fields. Default attached set is every
non-key right field; `fields` narrows it. Per-input detail: Workspace
`doc/user/TSV.md`.

## tsv_translate
Translate a TSV's key or value field between identifier formats and return
the translated table as canonical TSV text (this returns a re-keyed table,
not individual values — for lookups use `tsv_query`). The mapping TSV
(`identifiers`) must carry source-format keys and the destination format as
a named value field (`target_format`). Unmappable keys are dropped by Scout
`TSV.translate`; check row counts before and after. Per-input detail:
Workspace `doc/user/TSV.md`.

## tsv_sort
Sort a TSV by key or by a named value field (either direction, optional
numeric `cast` for field sorts) and return one page — a JSON envelope with
the page metadata and the rows as canonical TSV text (`tsv`), or just the
sorted `keys` with `just_keys: true`. Paged (`page`, `page_size`; no
`page_size` means all rows) so large tables can be inspected without
reading them whole. Flat TSVs sort by key only. Per-input detail: Workspace
`doc/user/TSV.md`.

