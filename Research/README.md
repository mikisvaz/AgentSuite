Research

Web search, document conversion, Markdown excerpting, and retrieval-augmented querying for Scout workflows. Research contains its own web and document/RAG tasks; it does not depend on or inherit Workspace.

The `searxng` task queries a reachable SearXNG-compatible service (default base URL `http://localhost:8181`). Configure the URL with the `SEARXNG_URL` environment variable or the `url` setting in the `searxng` workflow configuration. An optional API key can be supplied with `SEARXNG_API_KEY` or the `key` workflow setting. Document conversion requires Pandoc (`docx2md`), docling (`pdf2md_full`), or html2markdown (`html2md`) as applicable. The RAG tasks require Scout's LLM/RAG support and an available embedding provider.

The generic retrieval path is `excerpts` → `rag` → `query`: provide Markdown text through `text` and a search `prompt`. `pdf_query` and `html_query` convert their document input and feed the resulting text into the same retrieval path. Inputs can be propagated through task dependencies; use `task_inputs` to inspect the complete accepted inputs for a task.

Examples:

```bash
scout workflow task Research pdf_query --pdf ./report.pdf --prompt 'What are the key findings?'
scout workflow task Research searxng --query 'Scout workflow documentation' --count 5
scout workflow task Research docx2md --docx ./report.docx
scout workflow task Research pdf2md --pdf ./report.pdf
scout workflow task Research html2md --html '<h1>Report</h1><p>Text</p>'
```

To query supplied Markdown directly, pass it as `text` with a `prompt` to `query`; the task builds its excerpt and RAG dependencies.

```ruby
converted = Research.job(:html2md, nil,
  html: '<p>Research document content...</p>'
).run

matches = Research.job(:query, nil,
  text: converted,
  prompt: 'What does the document conclude?',
  num: 3
).run
```

For a document plus questions, prefer the composite tasks — `pdf_query` / `html_query` — over manually chaining `pdf2md` → `query` (see "Using Research in a bout" below).

## Using Research in a bout

- **Bout sizing.** Plan one conversion plus N targeted queries, not interactive loops. `searxng` `count` defaults to 10 and follows pages (each page is a request); `query`/`pdf_query`/`html_query` `num` defaults to 3; every `rag`/`query` run embeds text (provider cost). Reuse identical `text`/`strategy`/`chunk_words`/`overlap` inputs so Scout replays the cached excerpt and index steps instead of re-embedding.
- **Report placement.** Query results are JSON in the job, not a durable report. A bout that used Research must persist its conclusions in a durable artifact (Cortex artifact or a `./research` note) and cite the producing job paths / receipts rather than transcribing excerpt text into chat.
- **Where outputs land.** Excerpts are stored as task files under the job's `files/` sidecar (the result is their digest list); the `rag` index is a binary job result; jobs live under the Research checkout's `var/jobs/…` and replay from cache when inputs are unchanged.
- **Prefer the composite tasks.** For a document plus questions, call `pdf_query`/`html_query` rather than manually chaining `pdf2md` → `query`; the composite task wires the dependency and inherits caching. The risk to avoid is the reverse one: `searxng` + manual reading instead of the retrieval path.
- **Availability probe first.** Pandoc, docling, html2markdown, and the embedding provider are external: one bounded availability check early in the bout beats discovering a missing converter mid-investigation.

## Scientific record Path kinds

Research declares three agent Path kinds — **observation**, **claim**, **hypothesis** — for the durable scientific record. They register when the whole Research workflow is incorporated as a tool (`tool: Research`); a task-level tool line registers nothing.

- **observation** (`OBS-###`) — a recorded result or measurement tied to at least one source. Use it when the point is *what was observed and from what provenance*. Registering an observation without any source is rejected.
- **claim** (`C-###`) — an assertion the record store tracks through an evidential lifecycle (`proposed` → `supported`/`qualified`/`contradicted` → `superseded`). Use it when the point is *what is being asserted*, with links to the observations and other claims that support, contradict or qualify it.
- **hypothesis** (`H-###`) — a candidate explanation with predictions (`proposed` → `under_test` → `consistent_with_evidence`/`weakened`/`rejected`/`unresolved` → `superseded`). Use it when the point is *what would explain the observations and how it could fail*.

**The only way to create a record is the shared `register` operation** (one tool across all three kinds): it allocates the ID from an atomic per-kind counter inside a lock, validates the complete record, writes the body and its `.info` sidecar atomically, and returns the ID and path. Agents never allocate IDs. `statement` is required; `sources` is required in effect for observations; `title`, `scope`, `links`, `limitations` and the per-kind fields (`value` for observations; `predictions`, `test_ideas`, `assessment` for hypotheses; `assessment` for claims) are optional. `status` and `version` are system-managed and rejected as inputs.

**Records mutate only through `path_edit`.** An edit must carry the version line of the record it was read from; if the record has moved on, the edit fails as stale with a re-read instruction, and the prior body is snapshotted under `history/<ID>.v<N>.yaml` before the version is bumped. Never renumber or delete history. `write`, `move`, `rename` and `delete` are disabled for all three kinds — records are born through `register` and change through versioned edits.

**Validation separates record integrity from scientific assessment.** Hard errors (missing/ill-typed fields, unknown top-level keys, invalid status or transition, malformed links, relationship not allowed between the source and target kinds, broken local references, duplicate IDs) reject the operation. Warnings — a hypothesis with no predictions yet, a proposed claim not yet challenged, an unreachable external source, a mutable source with no digest, a claim that has not considered counterevidence, a non-re-executable derivation, a link whose target is invalidated or superseded — never block, they are reported for the author to consider. Backlinks and reference resolution are derived at validate/list time by scanning the records; they are never stored or maintained by hand.

**Link vocabulary** (direction: from the linking record to `target`):

| from \ relationship | `supported_by` | `contradicted_by` | `qualified_by` | `motivated_by` | `explains` | `supersedes` | `related_to` |
|---|---|---|---|---|---|---|---|
| observation | → observation | → observation | → observation | | | → observation | → any |
| claim | → observation, claim | → observation, claim | → observation, claim | | | → claim | → any |
| hypothesis | | → observation, claim | | → observation, claim | → observation, claim | → hypothesis | → any |

The observation row is the chosen symmetric closure reported in step 3 (the spec tabulates claim and hypothesis only); it is pending user adjudication.

**Sources reference provenance without copying it.** A source entry is `{type, ref}` plus optional `locator` and `digest`, with `type` one of `file`, `entity_property`, `task`, `workflow`, `external`. Local `file`/receipt refs must resolve at registration time (a broken local path is a hard error); `external` URLs are never fetched by the validator (reachability is a warning only); unknown-but-well-formed types are accepted as opaque with a warning.

The authoritative contract for schemas, lifecycle and validation is [research/path-kinds-spec.md](research/path-kinds-spec.md); the implementation lives in `lib/Research/path_kinds/`.

## Testing

From the repository root, run `ruby -Itest test/Research/tasks/test_registration.rb` for workflow/task registration, and the record-kinds suites `ruby -Itest test/Research/path_kinds/test_records.rb`, `.../test_path_kinds_engine.rb`, `.../test_spec9_matrix.rb` (the last includes fork-based concurrency tests). Together they cover workflow loading, task registration and aliases, deterministic local excerpting, and the full scientific-record Path-kinds contract. They do not require network services, LLM credentials, or document-conversion programs.

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

The `searxng`, `docx2md`, and `html2md` tasks are exported for use by other workflows. The remaining tasks are registered on `Research` but are not declared as exports.

The PDF conversion dependency preserves docling's image placeholders in `pdf2md_full`; `pdf2md` removes only lines beginning with `![Image]`. The retrieval tasks build their excerpt and index dependencies from the supplied document and options, so Scout can reuse cached steps when the inputs have not changed.

For exact input types and all dependency-propagated inputs, consult the task definitions or `task_inputs`.

This README describes the tasks registered by `Research/workflow.rb` and its required task files.
