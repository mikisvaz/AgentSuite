Visualizer: image generation via an endpoint agent

A single-task workflow that creates an image from a prompt using an
endpoint-backed agent. The output path is resolved against the current
path map and explicitly authorized under `LLM::Sandbox` before the
agent writes to it, so the file lands only where the run is allowed to
write.

# Tasks

## create_image

Create an image following a prompt

The image will be created in the path specified by the input file_path, and
will be subject to sandboxing rules.
