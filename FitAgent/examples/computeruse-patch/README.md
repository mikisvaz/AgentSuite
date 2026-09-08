# Example target: ComputerUse patch workflow

This directory is the shipped example of a FitAgent **target**: a workflow
the harness fits. FitAgent itself (`lib/FitAgent/`) names no concrete
workflow — every target-specific value lives here as data:

- `target.yaml` — the `FitAgent::TargetSpec` config: target checkout,
  agent name, default tool specs, default success-message rules, and the
  catalogue file.
- `catalogue.rb` — the F/E/C scenario `define` calls, moved VERBATIM from
  `lib/FitAgent/scenarios.rb`. Do not reformat; manifest digests are
  computed over the materialized fixture bytes and are frozen (asserted by
  `test/FitAgent/tasks/test_target_digests.rb`).

## One-line demo

    scout workflow task FitAgent catalogue

Materializes the whole frozen catalogue through this target (the repo-level
default `examples/computeruse-patch/target.yaml`) into `./scenarios` and
prints the manifest digests. Everything downstream (`run_arms`, `fit`)
resolves the same default target.

## Pointing at a different target

Any target works with no `lib/` edit: write a `target.yaml` naming another
`workflow_dir` (absolute, or relative to the config file), its `tools`,
its `message_rules`, and a `catalogue` file, then pass the config path:

    scout workflow task FitAgent catalogue --target path/to/target.yaml

`${VAR}` sequences in string values expand from the environment at load
time; `workflow_dir: ${FITAGENT_COMPUTERUSE_DIR}` restores the legacy env
override. The target checkout is treated as **read-only** — the harness
never writes into it.
