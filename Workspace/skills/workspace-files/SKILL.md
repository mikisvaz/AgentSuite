---
name: workspace-files
description: Choose a Workspace task for reading, writing or editing files and diagnose a rejected path.
---

# Workspace file operations

Use `list_directory` for discovery, `read` for contents and `search` for literal matches. Use `write` for complete contents, `precise_edit` for an exact count-checked change, and `patch` for diffs against the workflow root. Use the registered ScoutCoder Path kind for a managed development resource.

When a call fails on a path, request `sandbox_paths` in that context. File reads accept shared read and writable grants. Writes need the root or another writable location. For a command, check the covering mount's destination and mode. A symlink's usable spelling depends on the mount plan.

See [Sandbox and outputs](../../doc/user/SandboxAndOutputs.md) for the diagnostic sequence and the difference between an input path, a task result and a script output.
