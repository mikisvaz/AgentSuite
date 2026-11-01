# FitAgent: an agent fitness harness for testing and evaluating agents in any repository

FitAgent is a Scout workflow that measures how well an LLM agent "fits" a
task. It currently offers two avenues of investigation:

1. **Scenario avenue — `use_case` + `analyze`.** Define a use case
   scenario (a blind task chat plus supporting data) and run an agent
   end-to-end against it inside an isolated job sandbox. `analyze` then
   reuses the `use_case` step and has a `ChatAnalyst` agent review the
   run: it walks the chat provenance (nested jobs, tool calls, agent
   delegations, token usage) and returns a written assessment.
2. **Response avenue — `agent_ask` + `evaluate_agent`.** Do a single
   inference step by an agent on a chat you supply — with the agent's own
   `start_chat` and optional additional doctrine — to see how it reacts,
   then have the `FitAgent` evaluator persona grade that response against
   a rubric file.

Both avenues work against any agent definition directory and, for the
scenario avenue, any target repository.

## Active tasks

| Task | Avenue | What it does |
| ---- | ------ | ------------ |
| `use_case` | scenario | Stage a sandbox (use case + agent defs + endpoints + optional repo) and run the agent via `scout-ai agent ask`; the job result is the agent's final answer |
| `analyze` | scenario | Let `ChatAnalyst` evaluate a completed run, following the chat and job provenance |
| `agent_ask` | response | One-step inference: the named agent answers the supplied chat once; tool calls are returned, not executed |
| `evaluate_agent` | response | Grade the `agent_ask` response against a rubric file using the `FitAgent` evaluator persona |

The fit-era tasks (`compare`, `evolve`, `catalogue`, `override`, `score`,
`run_arms`, `fit`) live in `lib/FitAgent/tasks/other.rb`, are not required
by `workflow.rb`, and are currently deactivated. The retired README
sections that documented them are preserved verbatim in
`research/12-readme-retired-fit-era.md`.

Use `scout workflow task FitAgent <task> --help` or the ScoutCoder
`list_tasks` / `task_inputs` tools to see every input.

## The scenario avenue in detail

A use case directory holds `main.chat` (the blind task in Scout-AI
chat-file format), an optional `analyze.chat` (scoring criteria for the
analyst), and any data the task needs. Agent directories (passed with
`--agents`) hold one `<name>/start_chat` per agent; `--main_agent` selects
which one the inner run asks.

`use_case` stages everything the inner agent needs into a per-job sandbox
(see the layout below), then executes `scout-ai agent ask` inside it. The
inner run's stdout — the agent's final answer — becomes the job result;
the full transcript is left in the sandbox `main.chat`.

`analyze` depends on `use_case`, so it inherits every `use_case` input and
can re-run or reuse an existing run. The analyst's instructions resolve in
this order: an explicit `instructions` input, the sandbox `analyze.chat`,
or a built-in default criteria message (success, tool use, token usage
including cached tokens, multi-agent patterns, and an instruction to
follow job and agent dependencies for the full provenance). The analyst
receives the `use_case` job's result file plus the sandbox and `main.chat`
locations, and may follow the run's job links.

## The response avenue in detail

`agent_ask` loads the named agent (its `start_chat` persona, plus the
standard job context Scout adds), optionally appends `doctrine` as an
extra system message, and forwards the task chat with `assistant`,
`system` and `tool` roles stripped — the scenario arrives as user turns.
It asks exactly once: `return_tool_calls: true` makes the backend return
the model's first response without chaining or executing tool calls, so
the result shows the agent's immediate reaction, tools requested included.

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

When a repo is staged, the sandbox root is that repo copy and the use
case files are copied into it; otherwise the sandbox root is
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

## The run sandbox layout

```
<job>.files/sandbox/          (or <job>.files/<repo-name>/ when repo is given)
  main.chat                   the blind task, left holding the full transcript
  analyze.chat                optional scoring criteria consumed by analyze
  <use case data files>       anything else the use case directory contains
  etc/AI/                     endpoint definitions, keys materialized from env
  etc/path_maps               path-map config (default: :current) so inner
                              jobs and caches resolve inside the sandbox
  Agent/                      agent definitions copied from --agents
  workflows/                  MiniTools (always) plus every workflow named in
                              an introduce:/tool: line of main.chat or the
                              agents' start_chat files, symlinked in when
                              found under FitAgent/workflows, the AgentSuite
                              parent directory, ./workflows, or the
                              configured workflow dir
  var/cache/ask/              inner ask cache
<job>.files/log.txt           inner scout-ai log (tailed live during the run)
```

The inner agent always gets `MiniTools` (shipped under `workflows/`), a
portable minimal tool workflow (sh, read, write, list), so the agent under
test has execution primitives no matter which checkout the run started
from. The inner `scout-ai agent ask` runs with `BWRAP_PATH=false` because
the run already executes inside the outer sandbox and nested user
namespaces are denied; ask caching is disabled for the inner run
(`SCOUT_NO_ASK_CACHE=recursive`, `ASK_PERSIST=false`), so reruns are
clean.

# Tasks

## agent_ask

One-step inference: the named agent answers the supplied chat exactly
once, so you can see how it reacts given its own `start_chat` and any
additional doctrine.

| Input | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `agent` | string | | Agent name. The special value `none` is currently ineffective (an internal nil assignment is immediately overwritten) and raises `No agent found with name none`; leave the input unset to get a bare model with no persona |
| `doctrine` | text | | Additional doctrine, incorporated as a system role message on top of the agent's start_chat |
| `chat` | text | | The task chat in Scout-AI chat-file format; `assistant`, `system` and `tool` roles are stripped before it is forwarded, so the scenario arrives as user turns |

Behavior: the agent is loaded with its persona and standard job context,
the optional doctrine message is appended, and the model is asked once
with `return_tool_calls: true` — its first response is returned without
chaining or executing tool calls. The task result is a chat; the
transcript is saved at `<job>.files/<agent>.chat` (the job's files
directory, named after the agent; nested conversations land under
`<job>.files/<agent>.society/`).

```bash
scout workflow task FitAgent agent_ask \
    --agent ScoutCoder \
    --doctrine "Prefer the smallest change that resolves the requirement." \
    --chat "$(cat <use-case-dir>/main.chat)"
```

## evaluate_agent

Evaluate the performance of an agent in a scenario based on an evaluation
rubric. Depends on `agent_ask` (same inputs: `agent`, `doctrine`, `chat`)
and grades its response.

| Input | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `rubric` | text | required | File path to the rubric; the file is attached to the evaluator's chat |
| `agent` | string | | Forwarded to `agent_ask` |
| `doctrine` | text | | Forwarded to `agent_ask` |
| `chat` | text | | Forwarded to `agent_ask` |

Behavior: run the `FitAgent` evaluator persona (this repository's
`start_chat`) with its workflow detached, so it judges purely from the
chat. Its prompt is assembled as: the task chat, the rubric file, the
agent's response from the `agent_ask` dependency, and a request to return
the evaluation. The task result is a chat; the transcript is saved at
`<job>.files/FitAgent.chat`.

```bash
scout workflow task FitAgent evaluate_agent \
    --agent ScoutCoder --chat "$(cat <use-case-dir>/main.chat)" \
    --rubric my-rubric.md
```
## use_case

Stage a self-contained use case inside an isolated job sandbox and run the
agent under test against it, end to end, through `scout-ai agent ask`.

| Input | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `use_case` | path | required | Path to the use case directory (`main.chat`, optional `analyze.chat`, data). May also point at a previous `use_case` job path or result file: it is remapped to that job's staged use case directory (`<job>.files/sandbox/use_case`) so a scenario can be re-run without re-staging. The remap applies to `sandbox`-rooted runs; when `repo` staging was used, point at the staged copy inside `<job>.files/<repo-name>/` directly |
| `agents` | path | | Path to agent definitions; copied into the sandbox as `Agent/` so the inner run resolves them locally |
| `main_agent` | string | `MainAgent` | Which agent (directory under `--agents`) the inner run asks |
| `endpoint` | select | | Endpoint name resolved from the sandbox `etc/AI/` (hidden input; on `analyze` it reaches only the inner `use_case` run — pair it with `endpoint_analyst` to use one endpoint everywhere) |
| `repo` | path | | Optional target repository staged inside the sandbox |
| `repo_mode` | select | `copy` | How to stage `repo`: `copy`, `link` or `git` (see the deployment section) |
| `exclude` | array | `["var", ".git", "tmp"]` | Declared exclusion patterns for copy mode; the current rsync invocation applies a fixed set (`.git`, `tmp`, `etc/AI`, `main.chat.files`) and does not consume this input |

Behavior: stage the sandbox (use case files, endpoints, path maps, agents,
linked tool workflows including MiniTools), then run
`scout-ai agent ask <main_agent> -c main.chat -e <endpoint>` inside it.

Artifacts:

- job result (text): the agent's final answer;
- `<job>.files/sandbox/` (or `<job>.files/<repo-name>/`): the full
  sandbox, including the `main.chat` transcript left by the inner run; the
  sandbox path is recorded in the job info (`sandbox` key), which is how
  `analyze` finds it;
- `<job>.files/log.txt`: the inner run's log.

```bash
scout workflow task FitAgent use_case \
    --agents <agent-suite-dir> --use_case <use-case-dir> --endpoint qwen --main_agent Planned
```

## analyze

Evaluate a completed scenario run with the `ChatAnalyst` agent, walking
the chat provenance of the run (nested jobs, tool calls, delegations,
token usage).

Depends on `use_case` and inherits all of its inputs (`use_case`,
`agents`, `main_agent`, `endpoint`, `repo`, `repo_mode`, `exclude`), so a
single call both runs and analyzes a scenario.

| Input | Type | Default | Description |
| ----- | ---- | ------- | ----------- |
| `instructions` | text | | Instructions for the ChatAnalyst; defaults to the use case's `analyze.chat` or, failing that, the default criteria message (success, tool use, token usage, multi-agent patterns, follow the provenance) |
| `experiment` | string | `Default` | Experiment tag for cross-repo bookkeeping; affects the job identity, the current analysis text does not embed it |
| `endpoint_analyst` | select | | Hidden input; endpoint used by the `ChatAnalyst` itself. Its description claims it is forwarded to the `use_case` dep (fixpoint of `endpoint`), but job-digest evidence shows it does not change the dep's inputs: set `endpoint` as well when the inner run must use the same endpoint |

Behavior: load `ChatAnalyst`, allow it to follow the `use_case` job's
links, feed it the analyst instructions, the `use_case` job's result file
(the agent's final answer), and the sandbox and `main.chat` locations;
return the analyst's assessment.

Artifacts: the job result carries an `.md` extension (the assessment
text); the analyst conversation is saved as `analysis.chat` relative to
the process working directory at execution time (the FitAgent checkout
when the task is invoked from it with `scout workflow task`).

```bash
# run + analyze in one call
scout workflow task FitAgent analyze \
    --agents <agent-suite-dir> --use_case <use-case-dir> \
    --endpoint qwen --endpoint_analyst qwen \
    --instructions "Focus on tool discipline"
```
