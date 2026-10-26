Reader

Web search, document conversion, Markdown excerpting, and retrieval-augmented querying for Scout workflows. Reader owns the source-acquisition half of the former Research workflow: the `searxng` search task and the document reading, excerpting and RAG retrieval tasks. Scientific interpretation of what Reader produces lives in the Research workflow (see [Research](../Research/README.md)), which consumes Reader dossiers and owns the durable scientific record.

Reader requires the Workspace workflow: `workflow.rb` does `Workflow.require_workflow 'Workspace'` and merges its helpers into `Reader.helpers`. The document conversion tasks run their external converters through the merged Workspace helpers (notably `cmd_json`), and inherit the same command-execution behavior Workspace documents for them.

## See also (verified pointers)

- [Workspace README](../Workspace/README.md) — the required workflow: its helpers (`cmd_json` and friends) execute Reader's external converters, and its README documents the sandbox and command-execution semantics those helpers use.
- [Research README](../Research/README.md) — the consumer workflow: scientific interpretation over Reader dossiers and the durable scientific-record Path kinds.

## Dependencies and environment

- Ruby and the Scout/Rbbt environment (the workflow extends Workflow), with the `httparty` gem (required by `web.rb` at load time).
- The Workspace workflow resolvable by `Workflow.require_workflow 'Workspace'` (helpers are merged at load time).
- External converters, as applicable: a reachable SearXNG-compatible service plus Pandoc (`docx2md`), docling (`pdf2md_full`), or html2markdown (`html2md`).
- The RAG tasks require Scout's LLM/RAG support and an available embedding provider.

The `searxng` task queries a reachable SearXNG-compatible service (default base URL `http://localhost:8181`). Configure the URL with the `SEARXNG_URL` environment variable or the `url` setting in the `searxng` workflow configuration. An optional API key can be supplied with `SEARXNG_API_KEY` or the `key` workflow setting.

The generic retrieval path is `excerpts` → `rag` → `query`: provide Markdown text through `text` and a search `prompt`. `pdf_query` and `html_query` convert their document input and feed the resulting text into the same retrieval path. Inputs can be propagated through task dependencies; use `task_inputs` to inspect the complete accepted inputs for a task.

Examples:

```bash
scout workflow task Reader pdf_query --pdf ./report.pdf --prompt 'What are the key findings?'
scout workflow task Reader searxng --query 'Scout workflow documentation' --count 5
scout workflow task Reader docx2md --docx ./report.docx
scout workflow task Reader pdf2md --pdf ./report.pdf
scout workflow task Reader html2md --html '<h1>Report</h1><p>Text</p>'
```

To query supplied Markdown directly, pass it as `text` with a `prompt` to `query`; the task builds its excerpt and RAG dependencies.

```ruby
converted = Reader.job(:html2md, nil,
  html: '<p>Research document content...</p>'
).run

matches = Reader.job(:query, nil,
  text: converted,
  prompt: 'What does the document conclude?',
  num: 3
).run
```

For a document plus questions, prefer the composite tasks — `pdf_query` / `html_query` — over manually chaining `pdf2md` → `query` (see "Using Reader in a bout" below).

## Using Reader in a bout

- **Bout sizing.** Plan one conversion plus N targeted queries, not interactive loops. `searxng` `count` defaults to 10 and follows pages (each page is a request); `query`/`pdf_query`/`html_query` `num` defaults to 3; every `rag`/`query` run embeds text (provider cost). Reuse identical `text`/`strategy`/`chunk_words`/`overlap` inputs so Scout replays the cached excerpt and index steps instead of re-embedding.
- **Report placement.** Query results are JSON in the job, not a durable report. A bout that used Reader must persist its conclusions in a durable artifact (Cortex artifact or a `./research` note) and cite the producing job paths / receipts rather than transcribing excerpt text into chat.
- **Where outputs land.** Excerpts are stored as task files under the job's `files/` sidecar (the result is their digest list); the `rag` index is a binary job result; jobs land under `var/jobs/Reader/…` as resolved by Scout's path maps for the invoking process, and replay from cache when inputs are unchanged.
- **Prefer the composite tasks.** For a document plus questions, call `pdf_query`/`html_query` rather than manually chaining `pdf2md` → `query`; the composite task wires the dependency and inherits caching. The risk to avoid is the reverse one: `searxng` + manual reading instead of the retrieval path.
- **Availability probe first.** Pandoc, docling, html2markdown, and the embedding provider are external: one bounded availability check early in the bout beats discovering a missing converter mid-investigation.

## How the tasks are reachable

`searxng` is exec-exported (`export_exec :searxng`). `html2md`, `html_query` and `docx2md` carry `export` declarations in the task sources, but in the current framework `Workflow#export` is a no-op stub: it records nothing, and no execution or tool surface is derived from it. Do not read those `export` lines as a capability statement. The operative surface for all 11 tasks is the whole-workflow tool line: a `tool: Reader` introduction exposes every registered task (including the composite and alias tasks), and programmatic callers reach every task through the `Reader.job(:name, ...)` API regardless of any export declaration.

## Testing

Run from the Reader checkout root:

```bash
ruby -Itest test/Reader/tasks/test_registration.rb
```

This is the tested form (3 tests, 16 assertions, passing in a fresh process). The command loads `Reader/workflow.rb`, which resolves Workspace through `Workflow.require_workflow 'Workspace'`; an environment that cannot resolve the Workspace workflow fails at load time with `Workflow Workspace not found` — that is an environment/visibility failure (for example, running inside the Workspace bwrap sandbox, which cannot see `~/.scout` where the Workspace agent install lives), not a code defect. Run the registration test from a normal shell where the Scout workflow resolution path is visible.

This README describes the tasks registered by `Reader/workflow.rb` and its required task files.

# Tasks

## searxng
Search a SearXNG-compatible service and return JSON search results.

Required input: `query`. Optional inputs: `count` (best-effort maximum, default 10), `language`, `categories`, `engines`, `safesearch` (default 0), `time_range`, and `endpoint_path` (default `/search`). Results are unique objects with `url` and `text` combining the result title and content where available. The task requests JSON results, follows pages as needed, and returns up to the requested count. The service URL defaults to `http://localhost:8181` and is configured through `SEARXNG_URL` or the `url` workflow setting; optional authentication uses `SEARXNG_API_KEY` or the `key` workflow setting.

## docx2md
Convert a DOCX file to Markdown using Pandoc.

Required input: `docx`, the path to an existing DOCX file. The converted Markdown is the task's text result. Pandoc must be installed and available to the workflow.

## pdf2md_full
Convert a PDF to Markdown using docling, retaining the converter's image markers.

Required input: `pdf`, the path to an existing PDF file. Docling must be installed and available to the workflow.

## pdf2md
Alias of `pdf2md_no_images`; depends on `pdf2md_full`. It converts a PDF to Markdown through `pdf2md_full` (docling conversion, image markers retained) and removes lines beginning with `![Image]`, so `pdf2md` and `pdf2md_no_images` are both the image-stripped conversion. The `pdf` input is taken through the `pdf2md_full` dependency; see `pdf2md_full` for the input and docling requirements.

## html2md
Convert HTML text or a remote URL to Markdown using html2markdown.

Required input: `html`, which may be HTML code or a URL. Remote content is fetched before conversion. html2markdown must be installed and available to the workflow.

## excerpts
Split Markdown text into excerpts and return their identifiers.

Input: `text` (Markdown), `strategy` (default `paragraph`; choices `paragraph`, `sentences`, or `sliding`), `chunk_words` (default 50), and `overlap` (default 10). Paragraph mode splits on blank lines, drops paragraphs shorter than 40 characters, and further divides longer paragraphs by the word limit. Sentence mode groups sentences up to the word limit; sliding mode moves a word window by `chunk_words - overlap`. Excerpt contents are stored as task files and the result is the list of their digest identifiers. Excerpting is local and does not require an embedding service.

## rag
Build a retrieval index by embedding excerpts with Scout's LLM/RAG support.

This task depends on `excerpts`. It accepts `embed_model` (default `mxbai-embed-large`) and the excerpt inputs `text`, `strategy`, `chunk_words`, and `overlap` through the dependency. The result is a binary RAG index. An embedding provider must be available.

## query
Find excerpts relevant to a prompt using a retrieval index.

Required input: `prompt`. It accepts `num` (number of matches, default 3), plus the `excerpts` source inputs `text`, `strategy`, `chunk_words`, and `overlap`, and `embed_model` (default `mxbai-embed-large`) through its dependencies. `text` is an optional input in the task definition; provide it as the Markdown source for a meaningful query. The task embeds the prompt, searches the index built from the source text, and returns a JSON array of matching excerpt text. The dependency path is `query` → `rag` → `excerpts`.

## pdf_query
Convert a PDF and retrieve excerpts relevant to a prompt.

Required inputs: `pdf` and `prompt`. The task converts the PDF through `pdf2md` (the image-stripped conversion) and passes the resulting text to `query`. It also accepts the retrieval options `num` (default 3), `embed_model` (default `mxbai-embed-large`), `strategy` (default `paragraph`), `chunk_words` (default 50), and `overlap` (default 10). It requires docling and an embedding provider.

## html_query
Convert HTML or a remote URL and retrieve excerpts relevant to a prompt.

Required inputs: `html` and `prompt`. The task converts the source through `html2md` and passes the resulting Markdown to `query`. It also accepts the retrieval options `num` (default 3), `embed_model` (default `mxbai-embed-large`), `strategy` (default `paragraph`), `chunk_words` (default 50), and `overlap` (default 10). It requires html2markdown and an embedding provider; a remote URL also requires network access.

`searxng` is exec-exported; `html2md`, `html_query` and `docx2md` carry `export` declarations that the current framework treats as no-ops (see "How the tasks are reachable"). All 11 tasks are registered on `Reader`.

The PDF conversion dependency preserves docling's image placeholders in `pdf2md_full`; `pdf2md` removes only lines beginning with `![Image]`. The retrieval tasks build their excerpt and index dependencies from the supplied document and options, so Scout can reuse cached steps when the inputs have not changed.

For exact input types and all dependency-propagated inputs, consult the task definitions or `task_inputs`.
