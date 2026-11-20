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

- In `filesystem.rb`, `normalize` calls `LLM::Sandbox.authorize_path` with the root, shared grants, operation mode and relative base. Use the decision to authorize the operation and preserve the operational spelling for I/O. An allowed decision concerns containment. OS permissions remain applicable.
- In `exec.rb`, `sandbox_run` starts from the same grants, includes the workflow root as writable, and adds exec-specific paths before building bwrap arguments. Planning resolves mount sources, selects destinations and orders parents before children. The base plan reported by `sandbox_paths` omits per-command additions. The runner falls back to host execution if bwrap is absent or disabled.
- When extending a task, identify where it opens each input and output. The native TSV helpers and patch's direct fallback perform file I/O in the workflow process. Filesystem tasks check the arguments passed to `normalize`. Recursive operations require separate consideration of descendants.
- Keep task descriptions in the parsed root README and input help on the declarations. The [agent introduction](../user/README.md) owns first-call guidance.

## Tests

From the Workspace checkout with its Scout dependencies installed, run each task suite in a fresh Ruby process:

```bash
for suite in test/Workspace/tasks/test_*.rb; do
  ruby -Itest "$suite" || exit 1
done
```

The filesystem suite exercises grant scope, symlink resolution, missing descendants and relative paths. The exec helper suite covers mount planning and diagnostics. The other suites cover patches, precise edits and TSV operations. To check a deployment, run `sandbox_paths` and exercise the intended file and exec operations in the same caller context.
