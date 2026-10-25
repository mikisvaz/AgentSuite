# Scientific-record Path kinds — consolidated implementation report

Step 7 of 7. This report consolidates the whole build: what was implemented,
where it lives, what was tested, what deviated, and what remains. The
authoritative contract is `research/path-kinds-spec.md`; this report
complements it with the build's decisions, evidence, and limitations.

## Summary

The scientific-record Path kinds were implemented **in the Research checkout
(`/bulk/mvazque2/git/AgentSuite/Research`), not in scout-ai core** — this
placement is a recorded decision that may be vetoed by the user (see
Deviations). The work added three agent Path kinds — `observation`, `claim`,
`hypothesis` — that give agents a versioned, scientifically-meaningful record
store over the checkout's `var/records/<kind>/`: records are created only
through a shared `register` operation that allocates system IDs
(`OBS-###`/`C-###`/`H-###`) atomically, modified only through a guarded
whole-record `edit` that snapshots prior versions, validated by a
spec-faithful checker that separates hard errors from advisory warnings
(warnings never block), and linked through a typed cross-record vocabulary
whose backlinks and reference resolution are derived at validate/list time
rather than stored. The surface registers through `Research::PATH_KINDS` and
appears to agents on whole-workflow `tool: Research` incorporation; the full
spec §9 matrix and a one-story integration walkthrough are green, and the
Critic's independent verification passed all ten acceptance tests.

## Files changed

| File | Purpose |
|---|---|
| `lib/Research/path_kinds/records.rb` | The record engine: kind schemas, relationship tables, register/edit/list/validate, §7 error/warning split, derived backlinks |
| `lib/Research/path_kinds.rb` | Aggregator defining `Research::PATH_KINDS` from the engine's definitions |
| `workflow.rb` | One added line wiring `lib/Research/path_kinds` into the workflow |
| `test/Research/path_kinds/test_records.rb` | Unit tests over the engine: ID allocation, bad input, edit CAS, status transitions, errors vs warnings |
| `test/Research/path_kinds/test_path_kinds_engine.rb` | Engine-dispatch tests: definition shape, capabilities, register/edit/validate/list through `path_dispatch` |
| `test/Research/path_kinds/test_spec9_matrix.rb` | Full spec §9 matrix: round-trips, systematic relationship matrix, source variants, history, stale evidence, concurrency |
| `test/Research/path_kinds/test_integration_walkthrough.rb` | One-story integration dry run through the real engine funnel with domain-neutral fixtures |
| `README.md` | New section `## Scientific record Path kinds` (agent-facing usage) and updated `## Testing` entry |
| `research/path-kinds-spec.md` | The verbatim specification plus step-1 decisions and step-2 verdicts (pre-existing; body untouched this step) |
| `research/sandbox-symlink-visibility-scout-agent.md` | Durable note on the sandbox symlink visibility difference discovered during the build |

## Schema decisions

**Register parameter contract** (one shared `register` operation; identical
schema and description on all three kinds, so exactly one tool installs):

| Parameter | Requiredness | Notes |
|---|---|---|
| `statement` | required | non-empty String |
| `title` | optional | String |
| `scope` | optional | mapping, free keys, scalar or scalar-list values |
| `sources` | required-in-effect for `observation` (validator rejects empty); optional elsewhere | entries `{type, ref, locator?, digest?}` |
| `links` | optional | entries `{type, target, note?}` |
| `value` | optional | `observation` only (unknown key elsewhere) |
| `limitations` | optional | list of Strings |
| `predictions` | optional | `hypothesis` only |
| `test_ideas` | optional | `hypothesis` only |
| `assessment` | optional | `claim`/`hypothesis` only, String |

`version` and `status` are system-managed and rejected as inputs; status is
set to the kind's initial value (`observation: current`, `claim`/`hypothesis:
proposed`). Unknown input fields are rejected with an actionable message.

**ID scheme.** `OBS-NNN` / `C-NNN` / `H-NNN`, zero-padded to width 3 (growing
naturally past 999), allocated inside `Open.lock(<kind-root>/register.lock)`
from a plain-integer counter file; collision on a raced ID still fails
loudly. Agents never allocate IDs.

**Data-root layout** (one authoritative root per kind, absolute at
registration, single `project` location, no promote):

```
<checkout>/var/records/<kind>/<ID>.yaml             record body
<checkout>/var/records/<kind>/<ID>.info.json        sidecar (version, timestamps, job)
<checkout>/var/records/<kind>/history/<ID>.v<N>.yaml prior bodies
<checkout>/var/records/<kind>/counter               integer counter
<checkout>/var/records/<kind>/register.lock         allocation lock
<checkout>/var/records/<kind>/edit-<ID>.lock        per-record edit lock
```

**Status vocabularies.** `observation`: current → invalidated | superseded.
`claim`: proposed → supported | qualified | contradicted | superseded
(terminal states retain no outgoing transitions; same-status edits always
allowed). `hypothesis`: proposed → under_test → consistent_with_evidence |
weakened | rejected | unresolved | superseded. Invalid transitions are hard
errors that name both sides and the allowed set.

**Link vocabulary** (direction from the citing record; target must resolve):

| From \ Relationship | supported_by | contradicted_by | qualified_by | motivated_by | explains | supersedes | related_to |
|---|---|---|---|---|---|---|---|
| observation | → obs | → obs | → obs | — | — | → obs | any |
| claim | → obs/claim | → obs/claim | → obs/claim | → hyp | — | → claim | any |
| hypothesis | → obs/claim | — | — | → obs | → claim | → hyp | any |

The **observation row is a chosen symmetric closure, not spec-tabulated**:
the spec gives tables for Claim (§4) and Hypothesis (§5) only. This deviation
is awaiting user adjudication and is marked as such in the README table.

**Serialization.** YAML bodies (human-auditable, ordered fields), JSON
sidecars. All writes go through `Open.lock` + `Open.sensible_write`
(atomic). No new gems.

## Tests executed

Final state of the tree (fresh process per file, `run_test`):

| File | Tests | Assertions | Exit class |
|---|---|---|---|
| `test/Research/path_kinds/test_records.rb` | 10 | 63 | clean_pass |
| `test/Research/path_kinds/test_path_kinds_engine.rb` | 9 | 81 | clean_pass |
| `test/Research/path_kinds/test_spec9_matrix.rb` | 14 | 111 | clean_pass |
| `test/Research/path_kinds/test_integration_walkthrough.rb` | 1 | 67 | clean_pass |
| `test/Research/tasks/test_registration.rb` | 3 | 16 | clean_pass |
| `test/test_helper.rb` | — | — | load_error (helper file, not a test; suite-selector noise) |

Critic's independent verification (separate environment, fresh processes):
test_records 10/63 green; test_spec9_matrix 14/111 green; an independent
engine-dispatch probe exercising register/read/edit/stale-edit/disabled
capabilities/validate/list through real `path_dispatch` — 9/9 checks passed;
verdict PASS on all ten acceptance tests, no repair round. Also verified:
scout-ai core contains no modification from this work (one pre-existing
unrelated `path.rb` change predates the work window).

**Environment caveat.** `test_path_kinds_engine.rb` (9/81) and
`test_integration_walkthrough.rb` (1/67) were last executed in an environment
where the Workspace workflow resolves (their `workflow.rb` requires
`Workspace` through `Workflow.require_workflow`). Both are corroborated by
run receipts in this session and by the Critic's independent engine-dispatch
probe, but the Critic's own sandbox could not execute those two files
directly.

## Deviations from the specification

1. **Placement in the Research checkout, not scout-ai core (user-vetoable).**
   The restatement assumed the work lands in the scout stack repo owning
   Path. Step-1 decision: the path engine supports workflow-declared
   `PATH_KINDS`, ScoutCoder's own kinds set the precedent, and the suite
   philosophy keeps scientific semantics out of the substrate. This is the
   most consequential deviation and stands prominently in the Summary above.
2. **Observation relationship table is a chosen symmetric closure.** The spec
   tabulates Claim (§4) and Hypothesis (§5) link vocabularies only;
   Observation's row above was chosen as the minimal symmetric closure.
   Awaiting user adjudication; flagged in the README.
3. **`write`/`move`/`rename`/`delete` capabilities are disabled** even though
   spec §6 mentions write: records are born only through `register` and
   mutate only through `edit` (step-1 decision 2 / step-2 verdict b), so
   identity and history stay reliable. The engine honored the capability
   flags without forcing any deviation.
4. **Body-version CAS instead of an explicit `expected_version` argument**
   (step-2 verdict e said "expected_version guard"): the engine's edit flow
   hands the handler current content plus the caller's selector/replacement,
   and the edited body carries the version line it was read with — the same
   compare-and-swap with zero extra plumbing. Pinned by the stale-edit tests
   in three files, including the deterministic forked race.
5. **YAML bodies, JSON sidecars** per step-1 decision 4.
6. **Defect-fix history (step 3).** Six validator type-check branches were
   dead code from Ruby negation precedence (`!String === x` parses as
   `(!String) === x`, always false); fixed during step 3 and pinned by tests.
   No implementation defects were found in steps 4–6.
7. **Hygiene fix (step 7).** The `|| true` no-op tail in
   `test_path_kinds_engine.rb#test_shared_register_installs_one_tool_with_one_parameter_contract`
   (flagged by the Critic) was replaced with a real sorted comparison; the
   file re-ran clean_pass (9/81).

## Unresolved limitations and follow-ups

- **Per-combination link-warning text is spot-checked only.** The step-4
  matrix asserts accept/reject for all 63 relationship combinations, but the
  warning text of accepted links is not exhaustively asserted.
- **Adversarial many-writer edit races are deliberately untested.** The CAS
  guarantee is pinned by a deterministic sleep-serialized forked race; a
  free-for-all many-writers race would be inherently flaky as a test.
- **`test/test_helper.rb` reports `load_error` under `scope: suite`** —
  pre-existing suite-selector noise (a helper file inside the discovered
  tree), not from this work.
- **Relative source refs anchor to the Research checkout root**, so an
  out-of-checkout caller must cite sources absolutely. Documented in the
  walkthrough test; possibly worth a README sentence.
- **Ergonomics.** The whole-record edit flow (read → mutate → serialize →
  full-replace with a `chars` selector) is correct and safe but mechanical; a
  thin `set_status` convenience operation may be worth adding later.
- **Out of scope per spec §10 (fenced, not built):** any Research-protocol
  automation above record storage, automatic capture/registration of
  observations from task results, challenge automation for claims, and
  report generation from the record graph.

## Pointers

- **Authoritative contract:** `research/path-kinds-spec.md` (verbatim
  specification §1–§11, step-1 decisions, step-2 verdicts).
- **Agent-facing usage:** `README.md` → `## Scientific record Path kinds`.
- **Engine reference:** scout-ai `doc/developer/PathEngine.md` (kind
  registration, capabilities, custom operations, parameter-collision policy).
