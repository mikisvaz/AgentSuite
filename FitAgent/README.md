FitAgent: an agent fitness harness for testing and evaluating agents in any repository

FitAgent is a Scout workflow that measures how well an LLM agent "fits" a
task. It offers two avenues of investigation:

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

| Task | Avenue | What it does |
| ---- | ------ | ------------ |
| `use_case` | scenario | Stage a sandbox (use case + agent defs + endpoints + optional repo) and run the agent via `scout-ai agent ask`; the job result is the agent's final answer |
| `analyze` | scenario | Let `ChatAnalyst` evaluate a completed run, following the chat and job provenance |
| `agent_ask` | response | One-step inference: the named agent answers the supplied chat once; tool calls are returned, not executed |
| `evaluate_agent` | response | Grade the `agent_ask` response against a rubric file using the `FitAgent` evaluator persona |

The fit-era tasks (`compare`, `evolve`, `catalogue`, `override`, `score`,
`run_arms`, `fit`) live in `lib/FitAgent/tasks/other.rb`, are not required
by `workflow.rb`, and are currently deactivated; the retired README
sections are preserved in `research/12-readme-retired-fit-era.md`.

Keys are never expected in the target repository: set
`SCOUT_AI_<NAME>_KEY` in the environment (for example `SCOUT_AI_QWEN_KEY`)
and `use_case` materializes it into the per-run job sandbox at execution
time.

Use `scout workflow task FitAgent <task> --help` or the ScoutCoder
`list_tasks` / `task_inputs` tools to see every input.

Agent-tool caveat: due to a scout-ai tool-definition bug triggered by the
hidden `endpoint_analyst` input on `use_case` (`LLM.workflow_tools` raises
`NoMethodError`; reproduction:
`doc_redesign/consolidation/tmp/pin_hidden_input_bug.rb` and its
`.out.json`), an agent given `tool: FitAgent` currently receives NO
FitAgent tools. The tasks remain fully runnable via the CLI and
programmatic job routes until the framework defect is fixed.

Usage detail (use case layout, analyst instruction resolution, repo
staging with `repo_mode`, endpoint and credential hygiene) is in
[doc/user/README.md](doc/user/README.md); the run sandbox layout,
MiniTools staging, environment variables and testing are in
[doc/developer/README.md](doc/developer/README.md); the
`fitagent-agent-evaluation` skill under `skills/` helps pick the right
avenue and task for an evaluation question.

# Tasks

## agent_ask
One-step inference: the named agent answers the supplied chat exactly
once, so you can see how it reacts given its own `start_chat` and any
additional doctrine.

Inputs: `agent` (agent name; leaving it unset yields a bare model with no
persona — `none` is not a supported value), `doctrine` (additional
doctrine, appended as a system message), `chat` (the task chat in
Scout-AI chat-file format, with `assistant`/`system`/`tool` roles
stripped). The model is asked once with `return_tool_calls: true` — the
first response is returned without chaining or executing tool calls. The
result is a chat; the transcript is saved at `<job>.files/<agent>.chat`.
Behavior detail, input semantics and the CLI example:
[doc/user/README.md](doc/user/README.md) § "Response avenue".

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
