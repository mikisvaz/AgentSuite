# Reader developer documentation

Implementation, environment, export-surface and testing material for the
Reader workflow. Agent-facing usage lives in
[Reader/README.md](../../README.md) and [doc/user/README.md](../user/README.md).

## Workspace dependency (`cmd_json`)

Reader requires the Workspace workflow: `workflow.rb` does
`Workflow.require_workflow 'Workspace'` and merges its helpers into
`Reader.helpers` (`Reader.helpers.merge!(Workspace.helpers)`). The document
conversion tasks run their external converters through the merged Workspace
helpers (notably `cmd_json`), and inherit the same command-execution
behavior Workspace documents for them — converters are invoked as
`cmd_json :pandoc`, `cmd_json :docling`, `cmd_json :html2markdown` (see
`lib/Reader/tasks/documents.rb`), so their availability, output-capture and
error semantics follow Workspace, not Reader-local code.

Consequence for test and programmatic runs: an environment that cannot
resolve the Workspace workflow through `Workflow.require_workflow
'Workspace'` fails at load time (see Testing).

## Dependencies and environment

- Ruby and the Scout/Rbbt environment (the workflow extends Workflow), with
  the `httparty` gem (required by `lib/Reader/tasks/web.rb` at load time).
- The Workspace workflow resolvable by `Workflow.require_workflow
  'Workspace'` (helpers are merged at load time).
- External converters, as applicable: a reachable SearXNG-compatible
  service plus Pandoc (`docx2md`), docling (`pdf2md_full`), or html2markdown
  (`html2md`).
- The RAG tasks require Scout's LLM/RAG support and an available embedding
  provider.

### SearXNG service configuration

The `searxng` task queries a reachable SearXNG-compatible service (default
base URL `http://localhost:8181`). Configure the URL with the
`SEARXNG_URL` environment variable or the `url` setting in the `searxng`
workflow configuration. An optional API key can be supplied with
`SEARXNG_API_KEY` or the `key` workflow setting.

## Export surface (corrected)

`Workflow#export` is functional: scout-gear 10.13.1 defines `export` as an
alias of `export_asynchronous` (`scout-gear/lib/scout/workflow/export.rb`
L71: `alias export export_asynchronous`), so an `export :t` declaration
pushes `t` into the workflow's asynchronous exports. Earlier README text
calling `export` a no-op stub was wrong and has been removed.

Reader's declarations (`lib/Reader/tasks/documents.rb` tail):
`export :html2md, :html_query`, `export :docx2md`, and `export_exec
:searxng` (`lib/Reader/tasks/web.rb`). Live check:
`Reader.asynchronous_exports` → `[:html2md, :html_query, :docx2md]`;
`Reader.exec_exports` → `[:searxng]`.

The operative agent surface follows `LLM.workflow_tools`
(scout-ai 2.1.0 `lib/scout/llm/tools/workflow.rb` L117-118): tasks are
taken from `workflow.all_exports` when non-empty, and only fall back to
`all_tasks` for a workflow that exports nothing. Verified live:
`LLM.workflow_tools(Reader)` returns exactly
`["docx2md", "html2md", "html_query", "searxng"]`.

So: **`tool: Reader` (whole-workflow exposure) surfaces the 4 exported
tasks only**, not all 11. The other 7 — `pdf2md_full`, `pdf2md_no_images`,
`pdf2md`, `excerpts`, `rag`, `query`, `pdf_query` — are CLI-only on the
whole-workflow agent surface (programmatic callers still reach every task
through `Reader.job(:name, ...)`, and a task-level
`tool: Reader <task>` line exposes that one task). The composite PDF tasks
are therefore NOT reachable through a bare `tool: Reader` introduction; to
expose them to an agent, name them explicitly.

All 11 tasks are registered on `Reader` (verified: `Reader.tasks.keys`).

## Testing

Run from the Reader checkout root (tested form):

```bash
ruby -Itest test/Reader/tasks/test_registration.rb
```

Recounted at execution time (2026-11-14, fresh process): **3 tests, 16
assertions, 0 failures, 0 errors, 100% passed** — the historical "16
assertions" claim, previously marked unverified, is confirmed.

The command loads `Reader/workflow.rb`, which resolves Workspace through
`Workflow.require_workflow 'Workspace'`; an environment that cannot resolve
the Workspace workflow fails at load time with `Workflow Workspace not
found` — that is an environment/visibility failure (for example, running
inside the Workspace bwrap sandbox, which cannot see `~/.scout` where
installs live), not a code defect. Run the registration test from a normal
shell where the Scout workflow resolution path is visible.

## Cross-registration note

The same 11-task document family is also registered on ComputerUse
(`ComputerUse/lib/ComputerUse/tasks/documents.rb` is a near-copy; the only
diff is the alias target receiver). Cross-reference it when tracing where a
`pdf2md`-family job actually came from; do not describe the family as
unique to Reader.
