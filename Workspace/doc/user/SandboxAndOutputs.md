# Sandbox, execution and output handling (Workspace)

Agent-facing usage guidance for the Workspace workflow's filesystem,
execution, patching and output behavior. Task reference:
`Workspace/README.md` (the `# Tasks` section); TSV detail:
[Working with TSV files](TSV.md).

## Scope: the workflow root

These tools are intended to be used to alter the files on one particular
project while limiting access to arbitrary places in the filesystem. For that
reason tasks like `read`, `write`, `delete`, `search` and `list_directory`
check that the input paths are under the current process working directory
(PWD). You will also be granted access to workflow jobs generated during your
work.

## Sandbox execution model

Code execution with `bash`, `ruby`, `python`, `r`, or `patch` runs inside a
bwrap sandbox (write access: the current process working directory plus the
usual tmp/var locations; read access: the places where libraries and code
live). Tools that intend to create cache or temporary files elsewhere must be
pointed inside the current directory, typically through environment
variables.

Execution is unsandboxed when bwrap is not available in the system or when
the environment variable `BWRAP_PATH` is set to `false`.

Each invocation runs in a fresh Bash, Python, Ruby or R process; variables
from previous calls are not available.

Which paths each kind of action can reach is documented in the scout-ai
developer document `doc/developer/Sandbox.md` (§2 "Which paths can this
action reach?").

## The two permission layers

Sandbox permissions have two layers that do not always coincide, which is a
common source of confusion. The `read`, `write`, `delete`, `search`,
`list_directory`, and `file_stats` tasks are checked in Ruby against an
allowlist (the workflow root plus configured writable and readable paths),
while `bash`, `ruby`, `python`, and `r` run inside the bwrap sandbox built
from the same lists plus exec extras. A path can therefore be readable from
`bash` but rejected by `read`, or granted by the allowlist yet bound
read-only inside bwrap.

Run the `sandbox_paths` task to get the exact inventory: every allowed read
and write path, whether it is a file, a directory, or a symlink and where the
symlink points, the realpath, the origin of the permission (root, config
key, thread, exec defaults, TMP_DIRS), and the planned bwrap mounts with
source, destination, ro/rw mode, and whether the destination was redirected
because of a symlink. The full field inventory is documented in the
`sandbox_paths` task entry in `Workspace/README.md`.

## Scratch-file etiquette

If you are going to be generating files with data and scripts to perform
tasks or test developments, please consider writing them on a directory like
`./tmp`, `./results`, or `./sandbox`.

## Choosing the write/edit tool

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

## Output handling and `stderr_full`

Exec tasks (`bash`/`python`/`ruby`/`r`) return stdout, stderr and exit
status as JSON. When a command fails (non-zero exit) or its error stream is
huge, `stderr` is condensed to a root-cause-first view: the distinct
error-bearing lines are hoisted to the top, repeated lines are collapsed
(`line  [x N]`), host Ruby framework backtrace frames are dropped, giant
flattened argv dumps from the sandbox launcher are summarized, and long
streams are cut with explicit `... [N lines omitted] ...` markers. The
complete, uncondensed stream is preserved on disk and its path returned in
the additional `stderr_full` field, so nothing is lost. Successful commands
with small stderr are returned byte-identically.

The `patch` task returns a structured JSON result (stdout, stderr,
exit_status, generated_patch, used_strip, tried_strips, applied flags); the
`precise_edit` task returns a JSON verification record (see their entries in
`Workspace/README.md`).

## Where job outputs land

Every task runs as a Scout job under the workflow checkout's
`var/jobs/Workspace/…`; each job carries a `.files` sidecar directory for
auxiliary outputs; the harness `return_path` option returns the persisted
result file inside the job directory; and TSV `persist` uses the task's own
`.files` area. A result that "vanished" is a job-directory question, not a
reason to re-read stderr or write a locator script.

## Examples

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
