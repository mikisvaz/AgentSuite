# Scientific use-case launch template

## Mission objective

State the scientific question and why answering it matters.

## Scientific scope

- treatments / conditions / entities:
- measurements and timepoints:
- primary outcomes:
- controls:
- known limitations:
- explicit no-go claims:

## Current evidence and prior work

List existing reports, datasets, records, models and receipts that should be reused. Identify what is already settled and what must not be repeated without new evidence.

## Preflight results

| Capability | Intended role | Actual availability tested | Consumer-context test (role + run id) | Fallback |
|---|---|---|---|---|
| Semantic properties | Research | | | |
| Epistemic registration | Research | | | |
| General computation | Analyst | | | |
| Document retrieval | Reader | | | |
| Native Scout tasks/provisioning | ScoutCoder, if needed | | | |

Preflight must be performed in the intended consumer's own context, not the
builder's. Record the exact operation invoked and its receipt.

## Standing environment facts

Execution surfaces, mounts, tool availability and known environment
constraints every branch would otherwise rediscover. Update when the
environment changes.

## Computation scale plan

- largest item to compute:
- largest item already validated end-to-end:
- workload ratio (10x or more requires a capped probe or waiver before batch dispatch):
- capped probe / waiver record (sha, timeout, result):

## Research scoping request

Research must provide the questions, alternatives, required evidence, computation contracts, tools and stopping criteria.

## ScientificLead authorisation

Record explicit gate state, authorised scope, no-go areas and reopening conditions.

## Data package

Specify the actual package root, read-only inputs, manifest, permitted work/results locations and whether the package is shared or copied between agent runs.

## Branches

For each branch specify:
- owner role;
- question/objective;
- inputs and accessible paths;
- actual tools/capability surface;
- outputs and acceptance criteria;
- dependencies and gate state;
- stopping condition.

## Required handoffs

Material branches return result, evidence, actual tools/surfaces used, deviations, fallbacks, correctness/performance caveats and whether the original plan remains justified.

## Record and gate vocabulary

Record the ScientificLead's adjudication vocabulary (decision states, status
words and their meanings) supplied to Research before Gate-1, and note every
Critic correspondence check performed at a gate ruling.

## Final evaluation

Evaluate scientific quality, record integrity, semantic and epistemic API consumption, Analyst independence, justified ScoutCoder investment, gate compliance, deviation transmission, reproducibility, resource use and Critic findings.
