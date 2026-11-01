# Retired README content: fit-era sections (2026-11-01)

The README rewrite that documented the two active avenues
(`use_case`+`analyze`, `agent_ask`+`evaluate_agent`) removed the sections
that documented the fit-era tasks now living unrequired in
`lib/FitAgent/tasks/other.rb`. This checkout has no `.git`, so the removed
text is preserved verbatim below for reference. The source of truth for
that behavior remains `other.rb` itself.

---

## The four tasks (retired table)

| Task | What it does |
| ---- | ------------ |
| `use_case` | Stage a sandbox (use case + agent defs + endpoints + repo), run the agent via `scout-ai agent ask`, persist the transcript and a `verdict.yml` |
| `analyze` | Evaluate a completed run. Accepts `job_use_case:` (path of a previous `use_case` job) to re-analyze an existing run without re-running the agent |
| `compare` | Run N arms (agent + use case + repo variants) through `use_case` + `analyze` and emit a cross-arm table |
| `evolve` | Automated instruction evolution: seed agent -> generation matrix -> analyst feedback -> LLM-proposed instruction variant -> next generation. Records `agents/Gen*` and `lineage.tsv` |

Note: the `verdict.yml` and `job_use_case` claims predate the current
`use_case`/`analyze` implementation and were already stale at removal time.

## Comparing agentic substrates (three-arm blind experiment) (retired)

`sandbox/Cortex_eval` implemented the review's decisive experiment:
identical evidence payload, three arms (Cortex store, plain structured
filesystem, pasted reports), blind prompts, autonomy-ladder scoring:

```bash
scout workflow task FitAgent compare \
    --repo sandbox/Cortex_eval --experiment three_arm
```

Arms were defined in `arms/three_arm.yaml` (one entry per arm: agents,
use_case, repo, endpoint, repeats). Results landed in
`results/three_arm/{runs.tsv,results.tsv}`; each row cited the underlying
use_case and analyze job paths.

Scoring dimensions (in each arm's `analyze.chat`): retrieve relevant
evidence, avoid stale/obsolete values, discover cross-property
relationships, combine independent evidence, recognize failed hypotheses,
unprompted associations, avoid recomputation, plus an autonomy level 0-5.

## Evolving instructions (retired)

```bash
scout workflow task FitAgent evolve \
    --seed MiniBare --use_cases BugHunt \
    --repo sandbox/demo_repo --endpoint qwen --generations 2
```

Each generation: run a matrix (base + mutated agent), analyze both, let
the LLM propose the next instructions from the analyst feedback, write
`agents/<name>_Gen<N>` and append to `results/<exp>/lineage.tsv`.

Failure semantics: a run whose agent job errored (endpoint outage,
sandbox crash) was recorded with status `error` and the loop retried once
at the same content-addressed path; a verdict of FAIL advanced the lineage
normally, since failed runs are the signal the LLM mutated against.

No-op guard: when the proposed variant was byte-identical to its parent
(observed 2026-08-30 in lineage bug_evolve_v1), `evolve` refused to write
a new generation and recorded the run in `lineage.tsv` with verdict `noop`
so the lineage could not advance on empty mutations.

## Doctrines (validated instruction policies) (retired)

See `sandbox/doctrines.md`. Doctrines were instruction clauses that
survived a comparison: proposed (by LLM or by hand), run across at least
two use cases or endpoints, and either kept or refuted, with job receipts
recorded.
