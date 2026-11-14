---
name: fitagent-agent-evaluation
description: Choose the right FitAgent avenue and task when evaluating an LLM agent in this repo. Use when a question is about how well an agent fits a task, running a blind scenario end to end, re-analyzing an existing run, doing a single-step agent inference probe, or grading an agent response against a rubric. Triggers: FitAgent, use_case, analyze, agent_ask, evaluate_agent, fitness, blind task chat, rubric grading, agent evaluation scenario, scenario avenue, response avenue, job sandbox staging.
---

# Agent evaluation with FitAgent

## What this skill covers

Picking the right FitAgent avenue and task for an evaluation question,
and reading what each run leaves behind. Deep usage detail lives in
[FitAgent/doc/user/README.md](../../FitAgent/doc/user/README.md); the
workflow introduction and the four task entries are in
`FitAgent/README.md`.

## The decision: which task

| Question | Task (avenue) |
|---|---|
| "How does this agent behave on a whole blind task, end to end?" | `use_case` (scenario), then `analyze` for the ChatAnalyst assessment |
| "How does the agent react on its very first inference step?" | `agent_ask` (response) — one shot, `return_tool_calls: true`, tools requested but not executed |
| "Does this single response meet these grading criteria?" | `evaluate_agent` (response) — attaches your rubric file, judges with the FitAgent evaluator persona, tools detached |
| "I already have a completed run; I only want the assessment" | `analyze`, pointing `use_case` at the previous job path (it remaps to the staged sandbox) |

Rules of thumb:

- The scenario avenue exercises real tool execution inside an isolated
  job sandbox; the response avenue deliberately does not (one inference
  step, tool calls returned not run).
- `analyze` depends on `use_case` and inherits every `use_case` input —
  one call can both run and analyze a scenario.
- `evaluate_agent` depends on `agent_ask` and inherits `agent`, `doctrine`,
  `chat`.

## What the run leaves behind

- Job result of `use_case`: the agent's final answer (text).
- `<job>.files/sandbox/` (or `<job>.files/<repo-name>/`): the full
  sandbox, including the `main.chat` transcript of the inner run; the
  sandbox path is recorded in the job info (`sandbox` key).
- `<job>.files/log.txt`: the inner run's scout-ai log.
- `agent_ask` / `evaluate_agent` transcripts:
  `<job>.files/<agent>.chat`, `<job>.files/FitAgent.chat`.
- `analyze` writes `analysis.chat` relative to the process working
  directory at execution time.

## Operational cautions

- Pass agent definitions with `--agents <agent-suite-dir>` and pick the
  inner agent with `--main_agent`.
- `--endpoint` reaches the inner `use_case` run; `endpoint_analyst`
  reaches the ChatAnalyst only (it is NOT forwarded to the dep despite
  its description) — set both when one endpoint must serve the whole
  `analyze` call.
- The `agent='none'` special value on `agent_ask` is ineffective and
  raises; leave the input unset for a bare model.
- Keys are never expected in the target repo: set
  `SCOUT_AI_<NAME>_KEY` in the environment; it is materialized into the
  per-run sandbox.
- The fit-era tasks (`compare`, `evolve`, `catalogue`, `override`,
  `score`, `run_arms`, `fit`) are deactivated (unrequired in
  `workflow.rb`); do not call them.

## Common mistakes

- Running `evaluate_agent` when you wanted a full scenario — it grades a
  single `agent_ask` response, not a run.
- Expecting `endpoint_analyst` to also set the inner run's endpoint.
- Reading the job result as the whole evidence: the transcript and
  provenance live in the sandbox files and `main.chat`.
