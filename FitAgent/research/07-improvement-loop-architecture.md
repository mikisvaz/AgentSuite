# Improvement-loop architecture and scenario catalogue (research note 07)

**Scope**: the end-to-end design for the auto-testing loop, consolidating
notes 01–06 into the architecture the implementation bout should follow.
Cortex receipts: `design/fitagent-improvement-loop-v1.md` (v2),
`design/patch-scenario-catalogue-v1.md` (v2). Status: design — validated
against source for every mechanism claim; loop behavior itself is untested
(no implementation yet).

## 1. Durable concepts (one artifact each)

| Concept | Durable form | Owner |
| --- | --- | --- |
| Scenario + fixtures | `scenarios/<id>/` with `scenario.yaml`, inputs, `patch.txt`, `expected/` | fixture generator |
| Candidate override | `candidates/<id>/Agent/<Agent>/start_chat` | proposal step (weak endpoint) |
| Rubric | `scenarios/<id>/rubric.yaml` (3 tiers per note 04 §4) | design step |
| Run record | FitAgent job + `results/<exp>/runs.tsv` | runner |
| Evaluation record | rubric JSON in-job + `results/<exp>/scores.tsv` | evaluator |

Baseline is candidate 0: a byte-copy of the global agent. Every arm
(baseline + candidates) runs the SAME scenarios and rubric version.

## 2. Loop (bounded)

```
for gen in 1..G (default 3):
  1. run all scenarios × current candidate (use_case jobs, digest names)
  2. evaluate: functional (file diff) + message rules (chat_tool_calls) + budget
  3. optional: ChatAnalyst qualitative report (strong endpoint, non-gating)
  4. score = Σ weighted tiers; write scores.tsv row per scenario+candidate
  5. stop if: all functional+message PASS ∧ no regression vs baseline,
     or proposal == previous (evolve's no-op guard), or budget exhausted
  6. propose next start_chat via weak endpoint from (current start_chat,
     rubric JSON, analyst rationale, prior scores) — tool wiring MAY change
  7. validate proposal (grammar: parseable header lines; required tools
     present; import: chain intact) — repair loop ≤ 2 attempts
  8. stage as candidates/<gen>; repeat
```

Determinism note: same scenario + candidate + rubric version ⇒ same job
digest ⇒ cache reuse across re-runs; changed start_chat ⇒ new digest ⇒ no
stale cache (note 05 §5).

## 3. Patch-scenario catalogue v1 (axes from the user's ask)

Dimensions: file size (S/L), edit size (s/l), line scope (1/multi),
content type (text/ruby/code), format (canonical/ChatGPT), difficulty
(clean/noisy context, stale counts, no trailing newline). Grid trimmed to
~14 scenarios (full grid 64 is waste):

Functional (expect exact after-state):

- F01 S-file, 1-line, text, canonical
- F02 S-file, 1-line, ruby, canonical
- F03 S-file, multi-line, text, ChatGPT
- F04 S-file, multi-line, ruby, ChatGPT
- F05 L-file, 1-line (needle-in-haystack, deterministic generator)
- F06 L-file, large-edit, text (near-rewrite → dry-run may fail,
  apply_direct fallback expected)
- F07 L-file, multi-line, ruby, noisy context (similar blocks)
- F08 S-file, fenced patch text (markdown-quoted)

Error/robustness (expect controlled failure):

- E01 bare `@@` hunk not in file (raises "Could not locate hunk context")
- E02 ambiguous context (two identical blocks)
- E03 stale `@@` counts (repaired → success)
- E04 no trailing newline (synthesized → success)
- E05 add-file via patch (docs say use write; expect failure/fallback)
- E06 delete-file via patch (same)

Each scenario records the PREDICTED tool behavior from note 03's table;
live probing (agenda O1) upgrades predictions to observations before the
rubric's expected-values are frozen.

Message-rule defaults for the scenario family: tools ⊆ {patch, read, write,
list_directory, bash}; `patch` calls ≤ 2; no `bash` fallback before a
patch attempt; final write via `patch` (not `write`) for functional
scenarios — soft rule (weight), since `write` also produces correct files
(note 04 §4: functional tier gates, message tier weights).

## 4. Where each existing piece slots in

- `use_case` — unchanged run primitive (stage candidate `Agent/`, link
  ComputerUse via sibling rule, record `main.chat`).
- `analyze` — tier-4 garnish, unchanged.
- `compare` — generalizes to the catalogue runner (arms = candidates).
- `evolve` — gains: rubric-JSON in the proposal prompt, tool-wiring
  freedom + validator, split endpoints, digest job names, stop rules.
- ChatAnalyst jobs — tier 2/3 evaluation (`chat_tool_calls`,
  `chat_report`).
- Cortex — investigation substrate (this research), plus per-experiment
  artifact with the final report; scenario catalogue reviewed as artifact
  before fixtures freeze.

## 5. Risks

1. Weak-model proposals corrupt `import:`/`tool:` syntax → validator +
   bounded repairs (loop step 7).
2. `apply_direct` fallback masks patch-format skill: functional tier
   cannot distinguish; message tier (patch-before-write ordering) and
   `applied_directly` flag in diagnostics carry the signal.
3. Nested-sandbox assumption: inner agents run unsandboxed
   (`BWRAP_PATH=false`); scenario fixtures must be inert directories.
4. Cost blow-up: budget caps per arm + weak-endpoint caps per generation.
5. Stale-cache fixpoints: digest job naming (note 05 §5).

## 6. Open decisions for the user

- `weak` backing model (note 06 §5 fallback if absent).
- G default (3 proposed), weights of tiers, budget caps.
- Whether ComputerUse-patch improvements found should be fed back to the
  ComputerUse repo itself (out of scope for v1; the loop produces agent
  overrides, not tool fixes — the user's schema ends at override design).

## ADDENDUM 2026-09-05 — revisions from the live probe round + user decisions

1. **No `weak` endpoint** (user): proposal path and loop bookkeeping use the
   default endpoint (glm5 here). New tasks should omit endpoint inputs;
   `evolve`'s `:qwen` default remains untouched for its own runs. See
   research/06 addendum for the scout-ai resolution mechanism (ask.rb:31).
2. **Probe findings wired in** (research/08): scenario fixtures live as
   `<sc>/` dirs with pristine copy + work/ + expected/; run_all.sh semantics
   (pristine re-copy before each probe) become the runner contract; rubric
   frozen per `verifications/patch-probe-matrix-v1.md` (F01..F08 all-pass
   shape, E01 stale-context reject with "Hunk #1 FAILED" stderr, E02
   "Ambiguous" error, E03 lenient header-recompute, E05b add-overwrites,
   E06 delete removes file, no .orig/.rej residue).
3. **BWRAP_PATH=false** must be set for any nested ComputerUse tool run —
   already true in FitAgent's `use_case` env block (workflow.rb:125-131),
   which is where the scenario runner plugs in; the probe harness confirmed
   the flag is necessary and sufficient (Finding A, research/08).
