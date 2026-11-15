# FitAgent user guide

How to run the two FitAgent avenues end to end. The workflow introduction
and the four task entries live in `FitAgent/README.md`; the run sandbox
layout, MiniTools staging and environment variables are in
[doc/developer/README.md](../developer/README.md).

## Scenario avenue: `use_case` + `analyze`

A use case directory holds `main.chat` (the blind task in Scout-AI
chat-file format), an optional `analyze.chat` (scoring criteria for the
analyst), and any data the task needs. Agent directories (passed with
`--agents`) hold one `<name>/start_chat` per agent; `--main_agent`
selects which one the inner run asks.

`use_case` stages everything the inner agent needs into a per-job sandbox
(see [doc/developer/README.md](../developer/README.md) for the layout),
then executes `scout-ai agent ask` inside it. The inner run's stdout —
the agent's final answer — becomes the job result; the full transcript is
left in the sandbox `main.chat`.

`analyze` depends on `use_case`, so it inherits every `use_case` input and
can re-run or reuse an existing run. The analyst's instructions resolve in
this order: an explicit `instructions` input, the sandbox `analyze.chat`,
or a built-in default criteria message (success, tool use, token usage
including cached tokens, multi-agent patterns, and an instruction to
follow job and agent dependencies for the full provenance). The analyst
receives the `use_case` job's result file plus the sandbox and
`main.chat` locations, and may follow the run's job links.

## Response avenue: `agent_ask` + `evaluate_agent`

`agent_ask` takes three inputs: `agent` (the agent name; leaving it unset
yields a bare model with no persona — `none` is not a supported value),
`doctrine` (extra doctrine appended as a system message) and `chat` (the
task chat in Scout-AI chat-file format).

The task loads the named agent (its `start_chat` persona, plus the
standard job context Scout adds), optionally appends `doctrine` as an
extra system message, and forwards the task chat with `assistant`,
`system` and `tool` roles stripped — the scenario arrives as user turns.
It asks exactly once: `return_tool_calls: true` makes the backend return
the model's first response without chaining or executing tool calls, so
the result shows the agent's immediate reaction, tools requested included.
The transcript is saved at `<job>.files/<agent>.chat` (nested
conversations land under `<job>.files/<agent>.society/`). CLI example:

```bash
scout workflow task FitAgent agent_ask \
    --agent ScoutCoder \
    --doctrine "Prefer the smallest change that resolves the requirement." \
    --chat "$(cat <use-case-dir>/main.chat)"
```

`evaluate_agent` depends on `agent_ask` (same inputs), attaches the rubric
file, and runs the `FitAgent` evaluator persona over: the task chat, the
rubric, and the agent's response. The evaluator runs with its workflow
detached, so it judges purely from the material in its chat — no tools.
The rubric is a file path to a rubric document you supply (Markdown
criteria for grading, for instance a rubric describing what a good
code-review response contains).

The same `FitAgent` persona, driven interactively with the scenario, the
rubric and the result already in hand, is told to judge directly instead
of calling `evaluate_agent` again (see `start_chat`).

## Deploying FitAgent against another repository

`use_case` (and `analyze`, which reuses it) accepts a `repo` input so the
agent under test works inside any checkout:

```bash
scout workflow task FitAgent use_case \
    --agents <agent-suite-dir> --use_case <use-case-dir> --endpoint qwen \
    --repo /path/to/target-repo --repo_mode copy --main_agent Planned
```

`repo_mode`:

- `copy` (default) — rsync the repo into the sandbox under
  `<job>.files/<repo-name>/`, excluding `.git`, `tmp`, `etc/AI` and
  `main.chat.files`; `etc/AI` is always removed from the copy so endpoint
  credentials never travel with it. (The `exclude` input is declared but
  the current rsync call applies this fixed set.)
- `link` — symlink the repo into the sandbox; cheap, but writes can leak
  into the original. The use case directory must be empty in this mode:
  files are never copied onto a live repo, so the use case chat must
  already live inside the repo.
- `git` — when the repo contains a `.git`, clone it; otherwise the copy
  behavior applies.

When a repo is staged, the sandbox root is that repo copy and the use case
files are copied into it; otherwise the sandbox root is
`<job>.files/sandbox/`.

## Endpoints and credential hygiene

Endpoints are resolved from `etc/AI/<name>` inside the run sandbox. Keys
are never expected in the target repository: set `SCOUT_AI_<NAME>_KEY` in
the environment (for example `SCOUT_AI_QWEN_KEY`) and `use_case`
materializes it into the sandbox copy at execution time. When the
variable is absent, the repo's `etc/AI` file is copied verbatim and a
warning is logged (keeps offline and other setups working). The
materialized key lives only in the per-run job sandbox, which is private
scratch space; do not commit job directories.
