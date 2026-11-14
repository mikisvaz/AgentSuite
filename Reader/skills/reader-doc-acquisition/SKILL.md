---
name: reader-doc-acquisition
description: Acquire documents and web sources with the Reader workflow - pick the right task for each source type (web search, HTML, PDF, DOCX), plan conversions vs targeted retrieval, and avoid re-embedding costs. Use when a bout needs to find sources on the web, convert a document to Markdown, or answer questions against a document via the excerpts-rag-query retrieval path. Triggers: searxng, html2md, html_query, pdf2md, pdf_query, docx2md, excerpts, rag, query, "web search", "convert PDF", "convert docx", "read a document", "RAG", "retrieval", "excerpt".
---

# Reader document acquisition and conversion

## What this skill covers

Choosing the Reader task for a source, the retrieval path versus full
conversion, cost/caching discipline, and the environment caveats (external
converters, service configuration, sandbox paths).

## Which task for which source

| Need | Task | External requirement |
|---|---|---|
| Web search results (JSON) | `searxng` | reachable SearXNG service |
| Convert HTML or a URL to Markdown | `html2md` | html2markdown |
| Questions against HTML/URL | `html_query` | html2markdown + embedding provider |
| Convert PDF to Markdown | `pdf2md` (alias `pdf2md_no_images`) | docling |
| PDF with image markers | `pdf2md_full` | docling |
| Questions against a PDF | `pdf_query` | docling + embedding provider |
| Convert DOCX | `docx2md` | Pandoc |
| Questions against Markdown you have | `query` (path: excerpts→rag→query) | embedding provider |
| Split text only | `excerpts` | none (local) |

**Retrieval vs full conversion**: for questions, prefer the composite
retrieval tasks (`pdf_query`, `html_query`, `query`); they embed once per
identical input set and return only relevant excerpts. Full conversion
(`pdf2md`, `html2md`, `docx2md`) is for when you need the whole text —
archival, downstream tools, or exhaustive reading. Do not convert a whole
PDF to answer three questions.

## Cost and caching discipline

- Every `rag`/`query` run embeds text (provider cost). Reuse identical
  `text`/`strategy`/`chunk_words`/`overlap` inputs so Scout replays the
  cached excerpt and index steps.
- `searxng` `count` defaults to 10 and follows pages (each page a
  request); retrieval `num` defaults to 3.
- Plan one conversion plus N targeted queries, not interactive loops.
- Probe converter availability early (Pandoc, docling, html2markdown,
  embedding provider) — one bounded check beats a mid-bout failure.

## Path and sandbox caveats

- PDF/DOCX inputs are file paths resolved by the executing process; inside
  a sandboxed tool the `/bulk/...` realpath spelling may be visible where a
  `/home/...` symlink spelling is not — use the realpath.
- Remote URLs (`html2md` input, `html_query`) need network access from the
  executing environment.
- Query results are JSON in the job, not a durable report: persist
  conclusions in a durable artifact and cite job paths, do not transcribe
  excerpts into chat.

## Where outputs land

- Excerpts: task files under the job's `files/` sidecar (result = digest
  list); `rag` index: binary job result; jobs under `var/jobs/Reader/…`
  as resolved by Scout path maps; replay from cache on unchanged inputs.

## Environment configuration

- SearXNG URL: `SEARXNG_URL` env or `url` setting (default
  `http://localhost:8181`); optional key: `SEARXNG_API_KEY` or `key`
  setting.
- Reader requires the Workspace workflow (load-time); converters run
  through Workspace's `cmd_json` helper.

## Common mistakes

- Calling `pdf2md` then `query` by hand instead of `pdf_query` — the
  composite wires the dependency and inherits caching.
- Re-embedding the same document with different `chunk_words` on every
  query — fix chunking once per document.
- `searxng` + manual reading instead of the retrieval path when questions
  are the goal.
- Assuming the converters exist — probe first.

## Going deeper (repo-relative pointers, optional)

- `Reader/doc/user/README.md` — retrieval path, examples, bout discipline.
- `Reader/README.md` — the 11 task entries.
- `Reader/doc/developer/README.md` — dependencies, export surface (only
  `searxng`, `html2md`, `html_query`, `docx2md` are agent-exposed),
  testing.
