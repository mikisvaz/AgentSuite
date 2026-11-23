---
name: workspace-files
description: "Choose a Workspace task for reading, writing, searching or editing files, page oversized reads, and diagnose a rejected path."
---

# Workspace file operations

Use `list_directory` for discovery (or `list_directory_page` for a bounded,
deterministic page with a `more` flag), `read` for contents, and `search` for
literal path matches — `search_details` when you need line numbers, snippets,
scanned/skipped counts or an explicit truncation reason. Use `write` for
complete contents, `precise_edit` for an exact count-checked change, and
`patch` for diffs against the workflow root. Use the registered ScoutCoder Path
kind for a managed development resource.

Bounded by design, so results are never silently truncated or clipped:

- `read` defaults to 100 lines with a 16 KiB inline ceiling. Omitting both
  limits does NOT fetch an unlimited file; an oversized selection returns a
  structured envelope (reason/offset/ceiling) and `read_window` continues by
  byte offset. Negative AND zero `limit`/`chars` are rejected — zero is not an
  unlimited escape.
- Queries are literal: a search query is never a regular expression; regexp
  punctuation must match itself. Compressed files are skipped. A scan that
  hits its file or byte budget reports `truncated`, never a complete negative.
- `dry_run: true` on `patch` previews and writes nothing, even when
  `apply_direct` is true.

When a call fails on a path, request `sandbox_paths` in that context (add
`verbose: true` to also see `realized_mounts`). File reads accept shared read
and writable grants. Writes need the root or another writable location. For a
command, check the covering mount's destination and mode. A symlink's usable
spelling depends on the mount plan.

See [Sandbox and outputs](../../doc/user/SandboxAndOutputs.md) for the
diagnostic sequence and the difference between an input path, a task result
and a script output.
