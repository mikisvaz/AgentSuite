# Reader user documentation

Agent-facing usage of the Reader workflow: the retrieval path, examples,
bout discipline, and where outputs land. The task surface itself is in
[Reader/README.md](../../README.md); environment, dependencies and the
export surface are in [doc/developer/README.md](../developer/README.md).

## The retrieval path

The generic retrieval path is `excerpts` → `rag` → `query`: provide Markdown
text through `text` and a search `prompt`. `pdf_query` and `html_query`
convert their document input and feed the resulting text into the same
retrieval path. Inputs can be propagated through task dependencies; use
`task_inputs` to inspect the complete accepted inputs for a task.

To query supplied Markdown directly, pass it as `text` with a `prompt` to
`query`; the task builds its excerpt and RAG dependencies.

For a document plus questions, prefer the composite tasks — `pdf_query` /
`html_query` — over manually chaining `pdf2md` → `query` (see "Using Reader
in a bout" below).

## Which task for which source

| Source | Conversion | With retrieval | Notes |
|---|---|---|---|
| Web search | — | — | `searxng` (JSON results; `count` default 10) |
| HTML text or URL | `html2md` | `html_query` | html2markdown required; URLs fetched first |
| PDF | `pdf2md` / `pdf2md_full` | `pdf_query` | docling required; see image markers below |
| DOCX | `docx2md` | — | Pandoc required |
| Markdown you already have | — (`excerpts`/`rag`/`query`) | `query` | local excerpting; `rag` needs an embedding provider |

Prefer the composite retrieval tasks (`pdf_query`, `html_query`) when you
have questions to answer, and the bare conversion tasks (`pdf2md`,
`html2md`, `docx2md`) when you need the full converted text. Full-document
conversion is larger and costlier than targeted retrieval: run it when you
need the whole text (archiving, downstream tools), not to answer three
questions.

## Examples

CLI:

```bash
scout workflow task Reader pdf_query --pdf ./report.pdf --prompt 'What are the key findings?'
scout workflow task Reader searxng --query 'Scout workflow documentation' --count 5
scout workflow task Reader docx2md --docx ./report.docx
scout workflow task Reader pdf2md --pdf ./report.pdf
scout workflow task Reader html2md --html '<h1>Report</h1><p>Text</p>'
```

Ruby (chained, with Scout caching between the steps):

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

## Using Reader in a bout

- **Bout sizing.** Plan one conversion plus N targeted queries, not
  interactive loops. `searxng` `count` defaults to 10 and follows pages
  (each page is a request); `query`/`pdf_query`/`html_query` `num` defaults
  to 3; every `rag`/`query` run embeds text (provider cost). Reuse identical
  `text`/`strategy`/`chunk_words`/`overlap` inputs so Scout replays the
  cached excerpt and index steps instead of re-embedding.
- **Report placement.** Query results are JSON in the job, not a durable
  report. A bout that used Reader must persist its conclusions in a durable
  artifact (Cortex artifact or a `./research` note) and cite the producing
  job paths / receipts rather than transcribing excerpt text into chat.
- **Where outputs land.** Excerpts are stored as task files under the job's
  `files/` sidecar (the result is their digest list); the `rag` index is a
  binary job result; jobs land under `var/jobs/Reader/…` as resolved by
  Scout's path maps for the invoking process, and replay from cache when
  inputs are unchanged.
- **Prefer the composite tasks.** For a document plus questions, call
  `pdf_query`/`html_query` rather than manually chaining `pdf2md` →
  `query`; the composite task wires the dependency and inherits caching.
  The risk to avoid is the reverse one: `searxng` + manual reading instead
  of the retrieval path.
- **Availability probe first.** Pandoc, docling, html2markdown, and the
  embedding provider are external: one bounded availability check early in
  the bout beats discovering a missing converter mid-investigation.

## PDF image markers and caching

The PDF conversion dependency preserves docling's image placeholders in
`pdf2md_full`; `pdf2md` (and its target `pdf2md_no_images`) removes only
lines beginning with `![Image]`. The retrieval tasks build their excerpt
and index dependencies from the supplied document and options, so Scout can
reuse cached steps when the inputs have not changed.

For exact input types and all dependency-propagated inputs, consult the
task definitions or `task_inputs`.
