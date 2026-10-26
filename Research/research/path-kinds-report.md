# Scientific-record Path kinds — consolidated implementation report

Status: verification gate PASSED (all eight acceptance criteria; gate
record in the final section). Step 7 of 7. This report consolidates the whole build: what was implemented,
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

## Addendum: H-011 path_edit corruption fix (steps 3-4)

The corruption cluster reconstructed from Hypothesis record H-011 (duplicated
folded-scalar text committed across v5-v12, fragment concatenation in v12->v13)
was initiated by caller coordinate/replacement misuse and persisted by this
module's `:full` edit override, which committed corruption-shaped candidates
after the YAML parse folded duplicated fragments into one value.

The fix adds two edit entry modes sharing one commit path in
`lib/Research/path_kinds/records.rb`:

- `edit_fields` (custom operation): parsed-record field assignments with the
  version the caller read; validates before any write, serializes through the
  record implementation, snapshots the previous body, bumps the version.
  Preferred for record-content edits.  Unknown fields and the system-managed
  `version` field are rejected; null assignments remove optional fields;
  every unmentioned field keeps its value exactly.
- `path_edit` text mode, now guarded: two structural rejections before any
  parse or write - boundary duplication (replacement re-pastes physical lines
  remaining untouched immediately before/after the span) and unterminated
  fragment (replacement's last physical line lacks a terminator, except at
  EOF of a final-newline-less document).  The generic engine splice is
  untouched and stays faithful; the override never rewrites a replacement.

Both modes commit through one shared method, so versioning, optimistic
concurrency, history snapshots and sidecar updates are identical.  Every
rejection raises before the snapshot step, leaving the record file, sidecar
and history byte-identical.

Regression coverage: `test/Research/path_kinds/test_h011_lines_edit.rb`
(incident reproducer) and `test/Research/path_kinds/test_h011_regression_matrix.rb`
(34 tests: both modes, boundaries, EOF and final-newline states, insertions,
deletions, successive edits, stale/schema/transition rejections, mutation
safety, unknown-key preservation).

## return_path citation implementation (bout 4)

Implements the return_path citation contract (research/return-path-citation-contract.md, rules R6-R8, R10-R12, R14) in lib/Research/path_kinds/records.rb. Plan steps 4+5; one verifiable unit with its tests.

### Files changed

- lib/Research/path_kinds/records.rb — tool_result joins LOCAL_SOURCE_TYPES (R6); the tool_result validation arm (R7/R10/R11: resolve → classify durability → ephemeral hits the verbatim promote-or-reject message); locator grammar kind:value (R8); DURABLE_NAMED_STORES (records-attachments, entity_property receipts); RECORDS_ATTACHMENTS_DIR; classify_durability / ephemeral_path? / durable_job_tree? / durable_named_store? helpers; promote_tool_result custom operation (R11; one per kind, identical schema — the PathEngine strict collision policy makes per-kind destinations impossible); digest mismatch = hard error at edit and validate (R12, check_digests flag threaded through validate_record → validate_sources); REGISTER_PARAMETERS source-type and locator descriptions updated (entity_property, task, workflow, file, tool_result; locator kind:value grammar).
- test/Research/path_kinds/test_return_path_citation.rb (new) — 20 unit tests per rule (durable accept, missing-digest warning, locator malformed error, digest mismatch error at register AND validate, ephemeral tmp-shaped ref rejected with the verbatim message naming both remedies, promote end-to-end: copy happens, record cites the promoted absolute path, bytes equal, R14 compatibility: existing types still validate, unknown type still warning-opaque).
- test/Research/path_kinds/test_return_path_lifecycle.rb (new) — 3 cross-session tests: (1) entity case — process A runs the real non-exec Semantics entity_property (probe module registered in-process, the same pattern the Semantics tests use) and registers an Observation citing receipt.job.path; process B (fresh ruby) resolves and reads it; (2) generality case — a non-entity non-exec task result (ScoutCoder help_list_workflows) cited as tool_result with a pinned digest, matched in process B; (3) temporary-result case — TmpFile scratch rejected with the verbatim message. Scratch jobs under ~/.scout/var/jobs are named rp_lifecycle_* and deleted in teardown.
- test/Research/path_kinds/test_spec9_matrix.rb — @wf_digest fixture recomputed against the real checkout workflow.rb (the old hard-coded digest 'd' became a hard error once R12 landed at validate time — the fixture was asserting the pre-contract behavior).
- test/Research/path_kinds/test_records.rb — same fixture fix (digest computed from the actual file).
- test/Research/path_kinds/test_integration_walkthrough.rb — same fixture fix (job.info digest computed from the real job tree the test builds).
- research/path-kinds-spec.md — appendix updated: grammar (tool_result; locator kind:value), three-state vocabulary, R12 mismatch semantics, R13 migration note, pointers to the new tests.
- README.md — tool_result citation section (path grammar, promote_tool_result remedy, digest semantics, contract pointer).

### Rule → locus mapping as implemented

- R6 tool_result type — registration-time hard error on shape violations; joins LOCAL_SOURCE_TYPES.
- R7 ref grammar — registration-time hard error: ref must resolve to an existing FILE (directory refs are not result refs); absolute resolves as-is, relative anchors to the Research root.
- R8 locator — registration-time hard error on malformed kind:value (kind in {row, range, line, section}) for tool_result sources only; existing types keep free-form locators (R14).
- R10 durability — registration-time classification: ephemeral_path? (TmpFile dir, tmp path-map segments, /tmp roots) vs durable_job_tree? (shape-based: var/jobs ancestor + sibling .info/.json evidence) vs durable_named_store? (records-attachments, entity_property receipt dirs) vs unverifiable-but-durable (warning).
- R11 promote-or-reject — registration-time hard error with the contract's verbatim message; promote_tool_result operation copies bytes to var/records-attachments/<destination>/ and returns the durable path.
- R12 digest — registration-time warning when absent; hard error at edit/validate when a recorded digest mismatches the recomputed SHA-256 (check_digests=true from edit_record and validate_path).
- R14 compatibility — five existing types unchanged (entity_property refs additionally now recognize the AGS receipt-tree shape as a durable named store, warning-only); unknown well-formed types stay warning-opaque; the full pre-existing suite passes unchanged apart from the three digest fixtures that were asserting the pre-contract behavior.

### Decisions

- Promote mechanics: an explicit promote_tool_result custom operation (per-kind, same schema) rather than a register-time option. Rationale: PathEngine custom ops install one tool per name with strict parameter-collision policy, so a register-time option would either bypass the tool schema or collide across kinds; an explicit op also keeps promote observable and idempotent. Per-kind op names would need distinct schemas; identical schemas on three kinds install one tool whose implementation dispatches on the path — matching the register design precedent already in the codebase.
- Digest computation: SHA-256 hex of the resolved file bytes, exact string equality. The record carries the hex; no algorithm field (contract keeps digest a single string; adding an algorithm column would change SOURCE_KEYS and break R14).
- Ephemeral detection is path-shape-based (TmpFile.tmpdir, tmp path-map segments, /tmp roots) because content cannot prove transience; this is the closest enforceable rule and matches the contract's tolerance.

### Deviations and open items

- None of the four pending adjudications (placement in Research, observation link vocabulary, register-only creation, CAS edits) were resolved or needed resolution in this bout; the implementation sits entirely inside the existing register/CAS structure they question.
- R9 (one execution one receipt) is contract-level only, as planned; no validator can know which execution produced a path.
- C5 (backend independence) deferred, as planned.
- Migration of incumbent AGS receipts (R13) is the next bout; this bout only ensures absolute AGS receipt paths validate warning-only (durable named store), which the lifecycle test does not exercise — the migration bout must.
- The bwrap sandbox cannot see the real Workspace checkout (workflow.rb requires it), so the engine/integration tests are run through run_probe children (unsandboxed, caller authority) with plain ruby -Itest -Ilib; inside Workspace bash they fail on workflow load, not on behavior. Recorded as friction, not as a defect.

### Migration (R13) — bout 6

`research/return-path-migration.md` records the migration outcome: the
Research record store is EMPTY (0 records, 0 sources; `var/records/` does
not exist), the checkout holds no record bodies and no AGS-citing refs
outside research/ documentation, and the design-conversation examples
(OBS-010 record, observations-ledger.md OBS-105/106/107 lines) have no
live counterpart anywhere (ledger absent from the sandbox, searches quoted
in the note). Zero migrations were needed or applied; no CAS edits exist.
Sandbox integrity recheck: 417 receipt leaves (probe baseline preserved),
newest mtime 2026-10-24 — nothing from this line of work wrote there.
R13's absolute-citation arm is therefore contingency, not repair: it first
applies to records born elsewhere and later moved into Research.

## Verification gate (return_path citation)

Round 1: BLOCKED — sibling-checkout visibility (AgentSuite vanished from
the Critic's view) plus the demo.json test leak in the citation suite.
Recovery round: checkouts re-observed by the producer's probes, flip
survived in place, one-execution proof re-run, teardown fixed, lifecycle
omit-guard added, Semantics commit landed, four sibling-dependent suites
logged under research/test-logs/.
Round 2: BLOCKED persisted — producer-visible vs critic-sandbox mount
divergence (expected fragmentation, not a defect), and the proof artifact
was then deleted.
Final round: PASS — commit landed, kept durable proof, deterministic
lifecycle suite, auditable test logs.

Final verdicts (E1 independently executed by Critic, E2 audited persisted
record, E3 producer-attested behind the sandbox boundary):
- A1 PASS E3 (kept proof job; E1-grade on one host spot check)
- A2 PASS E1+E3
- A3 PASS E1+E3
- A4 PASS E1
- A5 PASS E1
- A6 PASS E1+E2
- A7 PASS E1
- A8 PASS E1/E2

E3 flags verbatim: Semantics commit
980d809b43e01b58868afced5cba1f49f07bb226; kept proof
/home/mvazque2/.scout/var/jobs/Semantics/entity_property/rp_a1_durable_proof_401cef0564c8084a5af90bd0ffc16f98.json
(+ .info). Both are one host-side spot check away from full E1.

Known minor items: the environment oscillation of
/bulk/mvazque2/git/AgentSuite (differing per-tool views — expected sandbox
fragmentation, not data loss); the lifecycle cross-session cases omit when
sibling checkouts are invisible (guards semantics_present? /
scoutcoder_present?).

Still open, unchanged by this branch: the four pending user adjudications
(record placement in Research; observation link vocabulary; register-only
creation; CAS edits) and the deferred contract items (R9
one-execution-one-receipt is contract-level; C5 backend independence
deferred; observation-capture convenience op deferred).
