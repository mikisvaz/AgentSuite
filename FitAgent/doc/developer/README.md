# FitAgent developer documentation

Implementation mechanics for the FitAgent fitness harness: the run
sandbox layout, agent-def and tool staging, and the environment variables
that control the inner run. The workflow introduction and the four task
entries live in `FitAgent/README.md`; user-facing usage is in
[doc/user/README.md](../user/README.md).

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

The search list for tool-workflow staging is exactly: `FITAGENT_ROOT/workflows`,
the AgentSuite parent directory (`dirname(FITAGENT_ROOT)`), `./workflows`, and
the configured workflow dir (`Workflow.workflow_dir`).

## MiniTools and the inner execution environment

The inner agent always gets `MiniTools` (shipped under `workflows/`), a
portable minimal tool workflow (sh, read, write, list), so the agent under
test has execution primitives no matter which checkout the run started
from.

The inner `scout-ai agent ask` runs with:

- `BWRAP_PATH=false` — the run already executes inside the outer sandbox
  and nested user namespaces are denied;
- `SCOUT_NO_ASK_CACHE=recursive` and `ASK_PERSIST=false` — ask caching is
  disabled for the inner run, so reruns are clean;
- a sandbox-local `var/cache/ask` and `etc/path_maps` (default `:current`)
  so inner jobs and caches resolve inside the sandbox instead of the
  user's read-only `~/.scout`.

## Key materialization

Endpoint definitions are copied from the staged repo's `etc/AI/` into the
sandbox; when `SCOUT_AI_<NAME>_KEY` is set in the environment, the key is
materialized into the sandbox copy at execution time. When absent, the
`etc/AI` file is copied verbatim and a warning is logged (keeps offline
and other setups working). `etc/AI` is always removed from a staged
repository copy before use, so credentials never travel with a repo.

## agent-defs and sandbox wiring

Agent definitions passed with `--agents` are copied into the sandbox as
`Agent/` so the inner run resolves them locally; `--main_agent` selects
which `<name>/start_chat` the inner run asks. `use_case` records the
effective sandbox path in the job info (`sandbox` key), which is how
`analyze` finds it.

## Task implementation map

| Task | Defined at | Notes |
|---|---|---|
| `use_case` | `lib/FitAgent/tasks/use_case.rb:9` | staging + `scout-ai agent ask` subprocess; remaps a previous `use_case` job path to its staged `<job>.files/sandbox/use_case` |
| `analyze` | `lib/FitAgent/tasks/use_case.rb:177` | `dep :use_case`; ChatAnalyst instruction resolution order: `instructions` input → sandbox `analyze.chat` → built-in default criteria |
| `agent_ask` | `lib/FitAgent/tasks/agent_ask.rb:4` | `return_tool_calls: true`; strips `assistant`/`system`/`tool` roles from the task chat |
| `evaluate_agent` | `lib/FitAgent/tasks/agent_ask.rb:15` | `dep :agent_ask`; runs the `FitAgent` evaluator persona with `agent.workflow = nil` (tools detached) |
| (fit-era, unrequired) | `lib/FitAgent/tasks/other.rb` | `compare`, `evolve`, `catalogue`, `override`, `score`, `run_arms`, `fit` — not reachable from `workflow.rb` |

## Testing

Tests live under `test/FitAgent/tasks/` (scenarios, scoring, runner,
evolve, golden replay, e2e smoke) with fixtures under `test/fixtures/`.
`test/test_helper.rb` requires the fit-era `lib/FitAgent/scenarios.rb`
stack and by default loads `examples/computeruse-patch/target.yaml`, a
directory that does not exist in this checkout — run the suite with
`FITAGENT_NO_DEFAULT_TARGET=1` or restore the examples directory first.
Known quirks, verified against code, that the tests exercise:

- `agent='none'` on `agent_ask` is ineffective (the nil assignment at
  `agent_ask.rb:6` is immediately overwritten by the reassignment at L7)
  and raises `No agent found with name none`;
- the `exclude` input on `use_case` is declared but unconsumed: the rsync
  call at `use_case.rb:35` applies its own fixed `--exclude` set;
- `endpoint_analyst` on `analyze` does not reach the `use_case` dep — pair
  it with `endpoint` when the inner run must use the same endpoint;
- `analysis.chat` is saved relative to the process working directory at
  execution time (`analyst.save('analysis.chat')`).
