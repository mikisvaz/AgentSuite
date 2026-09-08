# Implementation report: FitAgent scenario-driven improvement loop (note 09)

Date: 2026-09-05. Working context: Cortex conversations `fitagent-impl`
(Worker execution) and `fitagent-auto-test-investigation` (investigation +
Critic verification). Design followed:
`design/fitagent-improvement-loop-v1.md` (v3) + `research/07` + frozen
rubric `verifications/patch-probe-matrix-v1.md` (v2, with the E01 v1.1
correction).

## What was built

Four bounded Worker units, each delivered green and reported with quoted
commands:

1. **Deterministic catalogue + scorer** — `lib/FitAgent/scenarios.rb`
   (seeded fixture generator; 15 scenarios E01–E06/F01–F08 with
   `scenario.yaml`, `rubric.yaml`, `patch.txt`, `work/`, `expected/`,
   digest-stable manifest), `lib/FitAgent/scoring.rb` (tiered pure-Ruby
   evaluation: functional file-diff/absent/residue + message rules over
   `Chat.load`/`Chat.tool_calls`; no model calls), tasks `catalogue` +
   `score`.
2. **Multi-arm runner + override staging** — `lib/FitAgent/runner.rb`
   (arms = staged `Agent/<agent>/start_chat` overrides; baseline = no
   override; pristine re-copy contract from the probe harness;
   pluggable agent turn), tasks `run_arms` + `override`.
3. **Evolve loop** — `lib/FitAgent/evolve.rb` (`propose_prompt`,
   `validate_proposal`/`validate_with_repairs` with the tool-grammar
   check, `stop?` truth table: budget/all-PASS/no-op-twice/regression;
   `evolve_loop` stages `candidates/<gen>`, runs baseline + best +
   candidate, records `evolution.json`). Proposers pluggable; no model
   needed to test the loop.
4. **Live proposer + real agent turn + e2e smoke** —
   `lib/FitAgent/proposer.rb` (`DefaultProposer`: bare `LLM::Agent.new`,
   **no endpoint option** — default glm5; YAML reply → validator),
   `lib/FitAgent/agent_turn.rb` (`LiveAgentTurn`: child Ruby process,
   PWD=work/, BWRAP_PATH=false, real ComputerUse patch jobs, scout-ai
   chat transcript with provenance), and
   `test/FitAgent/tasks/test_e2e_smoke.rb` (live mini-set F01/E01/E06).

## Verification status

- **Validated**: full suite 46 tests / 360 assertions / 0 failures /
  0 errors, including a live end-to-end smoke against real ComputerUse
  patch jobs (F01 PASS, E06 PASS, E01 FAIL-refuse per frozen rubric).
- **Independently reviewed**: Critic re-ran the whole suite in a cold
  process, matched the totals exactly, audited the endpoint surface
  (grep: no endpoint anywhere in `lib/FitAgent/*`; the evolve validator
  actively rejects `endpoint`/`model` keys in proposals), audited write
  sites (overrides only under caller-provided arms/scenario dirs; no
  canonical Agent or other-workflow sources touched), and confirmed
  seeded digest determinism and model-free scoring. Verdict PASS.
- **Known deviation (recorded)**: rubric E01 was corrected from
  `exit_status == 1` to `applied=false` + `output_contains: ['FAILED']`
  because the numeric exit code is not faithfully observable through the
  nested CMD layer; consistent across scenarios.rb, test_scoring.rb, and
  the verification artifact (v2 note). Cosmetic residue: the
  `scenarios.rb:16` header comment still describes the unsandboxed view.

## Open (small) — updated 2026-09-05 evening

- ~~Wire `DefaultProposer` into the `evolve` task surface~~ DONE: `fit`
  task (workflow.rb:561) + `LiveAgentChat` (lib/FitAgent/agent_chat.rb).
- ~~Live fit run~~ DONE: `patch-mini-2` survived generation 1 first-shot
  after the tools-grammar prompt fix; `winner.json` produced
  (`status/2026-09-05-two-units-closure.md` v2). Suite now 55 tests /
  405 assertions green.
- Next: a harder scenario set (failure-class scenarios) to demonstrate
  instruction *improvement* (the mini-set is saturated: baseline 1.0).
- Optional ChatAnalyst tier (qualitative review arm) — not built.
- Annotate the `scenarios.rb:16` comment with the v1.1 nuance; dedupe the
  `SESSION_SCRIPT` constant warning (agent_chat.rb vs agent_turn.rb).

## Reproduce

```
cd /bulk/mvazque2/git/AgentSuite/FitAgent
BWRAP_PATH=false SCOUT_WORKFLOW_AUTOINSTALL=false \
  ruby -Itest -Ilib -I. test/FitAgent/tasks/<suite>.rb   # per suite
```

Evidence: suite outputs quoted in the `fitagent-impl` conversation; the
Critic cold-process run is recorded in
`fitagent-auto-test-investigation` (both in this workspace's Cortex).
