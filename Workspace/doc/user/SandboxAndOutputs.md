# Sandbox and outputs

## Which directory can I use?

Scout-AI combines configuration and grants registered in the calling thread. A grant can name a file or a directory. A directory grant covers its descendants. The table assumes separate directories with no overlapping grants and an active bwrap process.

| Location | Workspace file operations | Commands launched with bwrap |
| --- | --- | --- |
| Workflow root or a shared read/write grant | Read, create, edit and delete, subject to task-specific checks | Requested as a writable mount |
| Shared read grant | Read, list and search | Requested as a read-only mount |
| Directory supplied only through bwrap configuration | Requires an independent file-tool grant | Requested with the configured mount mode |

The core file check also accepts the directory in the workflow process's `PWD` as a root. Workspace passes `Dir.pwd` as the base for ordinary relative file inputs. A bwrap child starts in `Workspace.root`. When these differ, an absolute path removes ambiguity. Filesystem permissions and file existence still matter after authorization. A read grant inside a wider writable grant does not revoke file-tool write access.

**Example.** Suppose the calling thread grants read access to `/data/study` and read/write access to `/analysis/results`. The `read` task can open `/data/study/counts.tsv`, and `write` can create `/analysis/results/summary.txt`. With both directories present, a bwrap command requests the same input as read-only and the results directory as writable. Passing a path in a message to a different agent does not register a grant in that agent's thread.

## Diagnose a path in the context that failed

1. Call `sandbox_paths` with no inputs. Compare `root`, `pwd` and `pwd_realpath`. For a file operation, find the enclosing entry in `writable` or, for a read, `readable`. The entries include grant origin, existence, symlink information and realpath. For `copy`, check the source for read access and the destination for write access.
2. Check the resolved target. A link inside a granted directory can point outside it. Workspace authorizes the physical target, including the existing parent of a new file, then uses the supplied spelling for I/O. A missing input and a policy denial require different fixes.
3. For an exec failure, inspect `bwrap`, then find the covering mount in `mounts`. Compare `requested_path`, host `source`, child `destination` and `mode`. A symlink component can cause the planner to redirect a mount to its realpath. A parent mount may cover a child. Use the destination and relative suffix that correspond to the file in this plan.
4. If the expected grant is absent, have the caller supply the appropriate grant in this context or provide an input under an existing grant. If the grant is present, check the exact operation with the affected tool. A successful shell read alone does not establish file-task access.

The report describes the base mount plan. The runner adds process-specific mounts, including runtime paths and an existing step files directory. Missing grant targets cannot themselves be bound. When present, `realized_mounts` comes from the reporting process's `/proc/mounts`. A missing or disabled bwrap makes the runner warn and execute with host process access. A bwrap launch failure is reported as an execution failure.

## Which tasks use these checks?

`read`, `list_directory`, `file_stats` and `search` check their supplied input path for read access. `write`, `delete` and `precise_edit` check the target for write access. `copy` checks both endpoints. The four language runners launch fresh processes. An explicit script file for Python, Ruby or R must pass the file read check and be accessible to the child.

The system patch command uses the exec runner. Patch preparation and the optional direct-write fallback run in the workflow process. For a preview, keep `apply_direct` false when setting `dry_run`. The TSV tasks use Scout TSV and the workflow process's filesystem access. The shared file-tool grant list is therefore insufficient to predict the outcome of every Workspace task.

## Execution results and files

A language runner returns `stdout`, `stderr` and `exit_status`. Inspect the status before using stdout as the result. A runner exception can produce status `-1`. For failures or large stderr, the runner may shorten the diagnostic and include `stderr_full` if it saved the complete text.

When a tool wrapper supports `return_path: true`, it returns the address of the persisted **task result**. For `read` with a line limit that result contains the selected text. For a runner it contains the execution record. A file written by your script has the path you supplied in the script. Scout jobs may also have auxiliary files in a sibling `.files` directory. Pass on the returned path and check that the recipient can read it.

With Workspace available to the Scout CLI, run:

```bash
scout workflow task Workspace sandbox_paths
```

The JSON result includes the workflow root, writable and readable entries, and the planned mounts.
