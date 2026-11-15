Visualizer: image generation via an endpoint agent

A single-task workflow that creates an image from a prompt using an
endpoint-backed agent (endpoint `terra`, model `gpt-image-2.5-flare`).
The output path is resolved against the current path map and explicitly
authorized under `LLM::Sandbox` before the agent writes to it, so the
file lands only where the run is allowed to write. Inputs: `file_path`
(required path), `prompt` (required text), `size` (default
`1024x1024`), `quality` (default `medium`; declared but currently
unconsumed — the generated image always uses medium quality — a
documented finding, not an advertised feature). No `doc/` tree: the
workflow is this single task, and this file carries all of it.

# Tasks

## create_image

Create an image following a prompt

The image will be created in the path specified by the input file_path, and
will be subject to sandboxing rules.
