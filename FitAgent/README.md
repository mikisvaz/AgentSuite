# FitAgent: an agent fitness harness for testing and evolving agents in any repository

FitAgent is a Scout workflow that measures how well an LLM agent "fits" a
task. It runs a named agent (`FitMain`) against a self-contained use case
inside an isolated job sandbox, then delegates evaluation of the resulting
chat to a `ChatAnalyst` agent that walks the chat provenance (including
nested jobs and agent-to-agent delegations) and returns a verdict.
Verdicts are machine-readable YAML, which makes FitAgent a fitness
function over (agent instructions, use case, endpoint, repository).

## The four tasks

| Task | What it does |
| ---- | ------------ |
| `use_case` | Stage a sandbox (use case + agent defs + endpoints + repo), run the agent via `scout-ai agent ask`, persist the transcript and a `verdict.yml` |
| `analyze` | Evaluate a completed run. Accepts `use_case_job:` (path of a previous `use_case` job) to re-analyze an existing run without re-running the agent |
| `compare` | Run N arms (agent + use case + repo variants) through `use_case` + `analyze` and emit a cross-arm table |
| `evolve` | Automated instruction evolution: seed agent -> generation matrix -> analyst feedback -> LLM-proposed instruction variant -> next generation. Records `agents/Gen*` and `lineage.tsv` |

Use `scout workflow task FitAgent <task> --help` or the WorkflowCoder
`list_tasks` / `task_inputs` tools to see every input.

## Deploying FitAgent against another repository

FitAgent ships with a `repo` input on `use_case` (and everything that
depends on it) so you can evaluate agents inside any checkout:

```bash
# 1. Copy the agent-fit harness (workflow only) into the target repo
cd /path/to/target-repo
cp -r /path/to/FitAgent/workflow.rb .           # or git subtree / submodule
mkdir -p use_case/Probe agents/Bare
#    put a main.chat in use_case/Probe and a start_chat in agents/Bare/FitMain

# 2. Run one arm
scout workflow task FitAgent use_case \
    --agents agents/Bare --use_case use_case/Probe --endpoint qwen \
    --repo /path/to/target-repo --repo_mode copy

# 3. Analyze / compare / evolve as usual
scout workflow task FitAgent analyze --use_case_job <job-path>
# compare: arm definitions live in <repo>/arms/<experiment>.yaml
scout workflow task FitAgent compare --repo /path/to/target-repo --experiment three_arm
# evolve: writes agents/<name>_Gen* and results/<exp>/lineage.tsv in the repo
scout workflow task FitAgent evolve --seed Seed \
    --use_cases BugHunt --experiment my_evolve
```

`repo_mode`:

- `copy` (default) -- rsync the repo into the run sandbox, excluding
  `var/`, `.git/`, `tmp/` and `etc/AI/`; each run is a pristine snapshot.
- `link` -- symlink the repo; cheap but writes can leak into the original.

## Endpoints and credential hygiene

Endpoints are resolved from `etc/AI/<name>` inside the sandbox. Keys are
never expected in the target repository: set `SCOUT_AI_<NAME>_KEY` in the
environment (for example `SCOUT_AI_QWEN_KEY`) and FitAgent materializes it
into the run sandbox at execution time. Job directories are private
scratch space; do not commit them.

## The sandbox layout

```
sandbox/
  demo_repo/     -- tiny Ruby repo with two use cases (BugHunt, StatsCheck)
  Cortex_eval/   -- staged Cortex blind-comparison experiment
  doctrines.md   -- validated instruction policies (doctrines)
  STATE.md       -- running log of the investigation
```

Each use case directory holds `main.chat` (the blind task), optional
`analyze.chat` (scoring criteria), and any data the agent needs. Agent
directories hold `FitMain/start_chat` with the instructions under test.

## Doctrines (validated instruction policies)

See `sandbox/doctrines.md`. Doctrines are instruction clauses that
survived a comparison: they were proposed (by LLM or by hand), run across
at least two use cases or endpoints, and either kept or refuted, with job
receipts recorded.

## Comparing agentic substrates (three-arm blind experiment)

`sandbox/Cortex_eval` implements the review's decisive experiment:
identical evidence payload, three arms (Cortex store, plain structured
filesystem, pasted reports), blind prompts, autonomy-ladder scoring:

```bash
scout workflow task FitAgent compare \
    --repo sandbox/Cortex_eval --experiment three_arm
```

Arms are defined in `arms/three_arm.yaml` (one entry per arm: agents,
use_case, repo, endpoint, repeats). Results land in
`results/three_arm/{runs.tsv,results.tsv}`; each row cites the underlying
use_case and analyze job paths.

Scoring dimensions (in each arm's `analyze.chat`): retrieve relevant
evidence, avoid stale/obsolete values, discover cross-property
relationships, combine independent evidence, recognize failed hypotheses,
unprompted associations, avoid recomputation, plus an autonomy level 0-5.

## Evolving instructions

```bash
scout workflow task FitAgent evolve \
    --seed MiniBare --use_cases BugHunt \
    --repo sandbox/demo_repo --endpoint qwen --generations 2
```

Each generation: run a matrix (base + mutated agent), analyze both, let
the LLM propose the next instructions from the analyst feedback, write
`agents/<name>_Gen<N>` and append to `results/<exp>/lineage.tsv`.

Failure semantics: a run whose agent job errors (endpoint outage,
sandbox crash) is recorded with status `error` and the loop retries once at
the same content-addressed path; a verdict of FAIL advances the lineage
normally, since failed runs are the signal the LLM mutates against.

No-op guard: when the proposed variant is byte-identical to its parent
(observed 2026-08-30 in lineage bug_evolve_v1), `evolve` refuses to write
a new generation and records the run in `lineage.tsv` with verdict `noop`
so the lineage cannot advance on empty mutations.
