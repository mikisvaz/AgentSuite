Reader

Web search, document conversion, Markdown excerpting, and retrieval-augmented querying for Scout workflows. Reader owns the source-acquisition half of the former Research workflow: the `searxng` search task and the document reading, excerpting and RAG retrieval tasks. Scientific interpretation of what Reader produces lives in the Research workflow (see [Research](../Research/README.md)), which consumes Reader dossiers and owns the durable scientific record.

Reader requires the Workspace workflow and runs its external converters through the merged Workspace helpers (see the developer documentation for the dependency and export surface). All 11 tasks are registered on `Reader`; the whole-workflow agent surface (`tool: Reader`) exposes the 4 exported tasks — `searxng`, `html2md`, `html_query`, `docx2md` — the rest are CLI/programmatic only.

**See also (verified pointers)**

- [Workspace README](../Workspace/README.md) — the required workflow: its helpers (`cmd_json` and friends) execute Reader's external converters, and its README documents the sandbox and command-execution semantics those helpers use.
- [Research README](../Research/README.md) — the consumer workflow: scientific interpretation over Reader dossiers and the durable scientific-record Path kinds.
- [doc/user/README.md](doc/user/README.md) — the retrieval path (`excerpts` → `rag` → `query`), CLI + Ruby examples, using Reader in a bout (sizing, cost, caching, report placement), which task for which source type.
- [doc/developer/README.md](doc/developer/README.md) — Workspace dependency (`cmd_json`), dependencies and environment (Pandoc/docling/html2markdown/embedding, SearXNG config), the corrected export surface (`tool: Reader` exposes the 4 exported tasks, not 11), testing.
- [skills/reader-doc-acquisition/SKILL.md](skills/reader-doc-acquisition/SKILL.md) — choosing the acquisition task for a source type.

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

## pdf2md_no_images
Image-stripped PDF→Markdown conversion; the task that `pdf2md` aliases.

Depends on `pdf2md_full` (docling conversion, image markers retained) and removes lines beginning with `![Image]` — identical behavior to `pdf2md`. The `pdf` input is taken through the `pdf2md_full` dependency; see `pdf2md_full` for the input and docling requirements.

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
