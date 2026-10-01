Research

Web search, document conversion, Markdown excerpting, and retrieval-augmented querying for Scout workflows. Research contains its own web and document/RAG tasks; it does not depend on or inherit Workspace.

The `searxng` task queries a reachable SearXNG-compatible service (default base URL `http://localhost:8181`). Configure the URL with the `SEARXNG_URL` environment variable or the `url` setting in the `searxng` workflow configuration. An optional API key can be supplied with `SEARXNG_API_KEY` or the `key` workflow setting. Document conversion requires Pandoc (`docx2md`), docling (`pdf2md_full`), or html2markdown (`html2md`) as applicable. The RAG tasks require Scout's LLM/RAG support and an available embedding provider.

The generic retrieval path is `excerpts` → `rag` → `query`: provide Markdown text through `text` and a search `prompt`. `pdf_query` and `html_query` convert their document input and feed the resulting text into the same retrieval path. Inputs can be propagated through task dependencies; use `task_inputs` to inspect the complete accepted inputs for a task.

Examples:

```bash
scout workflow task Research searxng --query 'Scout workflow documentation' --count 5
scout workflow task Research docx2md --docx ./report.docx
scout workflow task Research pdf2md --pdf ./report.pdf
scout workflow task Research html2md --html '<h1>Report</h1><p>Text</p>'
scout workflow task Research pdf_query --pdf ./report.pdf --prompt 'What are the key findings?'
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

## Testing

From the repository root, run `ruby -IResearch/test Research/test/Research/tasks/test_registration.rb`. These tests cover workflow loading, task registration and aliases, and deterministic local excerpting. They do not require network services, LLM credentials, or document-conversion programs.

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

## pdf2md_no_images
Convert a PDF to Markdown and remove image-placeholder lines.

This task depends on `pdf2md_full` and removes lines beginning with `![Image]` from its output. It takes the `pdf` input through that dependency. Use `pdf2md` as the public alias for this image-stripped conversion.

## pdf2md
Alias for `pdf2md_no_images`, the image-stripped PDF conversion. It takes the `pdf` input through its dependency on `pdf2md_full`; see `pdf2md_full` and `pdf2md_no_images` for details.

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
