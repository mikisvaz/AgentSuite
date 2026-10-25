# Scientific-record Path kinds — implementation specification (verbatim record)

Provenance: copied verbatim from the request-stage job chat of the Planned pipeline,
var/jobs/Planned/request/Default_6e7ff786749025132377ef6194d3f976.chat
(stored input segment ...chat.files/User.chat, assistant turn, lines 993-1349).
That turn is the authoritative requirement document for the `observation`, `claim`,
and `hypothesis` Path kinds; this file is its durable in-repo copy. Persisted by
plan step 1 of 7, before any implementation. This step is documentation only:
no code, no schema design, no tests.

# Implementation specification (verbatim)

I would give the implementing agents the following specification. It deliberately separates the minimal record schema from the validation and lifecycle behaviour, so the three Path kinds remain generic and reusable beyond AGS.

# Scout Research Record Path Kinds — Implementation Specification

## 1. Objective

Implement three typed Path kinds for scientific records:

- `observation`
- `claim`
- `hypothesis`

They must use the existing Scout Path lifecycle and conventions. They must provide stable identifiers, structured records, validation, reference resolution, and predictable read/write/edit/list behaviour.

The purpose is to let agents maintain a durable, inspectable scientific record in which findings have traceable sources, conclusions reference findings, and hypotheses retain their predictions and evidential status.

Do not build a new workflow engine, database, general-purpose graph framework, or parallel CRUD interface. Reuse the existing Path machinery wherever possible.

The schema must be domain-independent. Do not introduce fields specific to AGS, cancer biology, transcription factors, experimental arms, time courses, or any particular computational workflow.

## 2. Common record conventions

Each record must have:

- A stable, unique identifier managed by the system.
- A concise human-readable `title`, if useful.
- A required `statement` describing the finding, assertion, or hypothesis.
- An optional `scope` describing where the statement applies.
- Kind-specific fields defined below.

Use the canonical Path identifier as the record identity if the existing system already provides one. Do not maintain an independently editable ID field that can diverge from the actual path. If the Path interface requires a record ID, generate it when the record is created; agents must not allocate IDs manually.

ID allocation must be safe under concurrent creation. Sequential IDs are acceptable if the existing mechanism allocates them atomically.

Use the existing Path and artifact metadata for creation time, modification history, authorship, and provenance wherever available. Do not duplicate these fields without a concrete need.

### Scope

`scope` is optional and generic. Represent it as a flat mapping of descriptive keys to scalar values or lists of scalar values.

For example:

\scope:
  population: "cohort A"
  time: "8 h"
  analysis: "primary scheme"

These keys are illustrative, not reserved schema fields. The schema must not prescribe domain-specific dimensions.

Scope expresses the conditions under which a statement applies. It must not be confused with the evidence supporting it.

### Record relationships

Use a common `links` field wherever a record relates to other scientific records.

Each link has this structure:

- type: supported_by
  target: OBS-001
  note: "Optional explanation"

`target` must be an exact, resolvable identifier for another Observation, Claim, or Hypothesis. `note` is optional and should be used only when the relationship needs clarification.

Use a controlled vocabulary of relationship types, with explicit allowed source and target kinds. At minimum, support the relationships appropriate to each kind:

- `supported_by`
- `contradicted_by`
- `qualified_by`
- `motivated_by`
- `explains`
- `supersedes`
- `related_to`

For hypotheses, the implementation must also support predictions as described below. Do not add every conceivable relationship in advance.

Relationship direction is from the current record to its target. For example, a Claim with a `supported_by` link to an Observation is supported by that Observation.

Store the authoritative relationship once and derive reverse references or backlinks when needed. Do not require agents to update both sides of the same link.

## 3. Observation schema

An Observation records a specific finding derived from an identifiable source. It reports what was found, measured, retrieved, or computed; it must not silently turn the result into a mechanistic explanation.

Required fields:

- `statement`: a concise description of the finding.
- `sources`: one or more references identifying the evidence from which the finding was obtained.

Optional fields:

- `title`
- `scope`
- `value`: a compact, machine-readable scalar or structured value when useful.
- `limitations`: a list of relevant qualifications.
- `links`: relationships to other scientific records, where appropriate.
- `status`: an Observation lifecycle state, if the existing Path system does not already manage it.

A source entry has this minimal structure:

\sources:
  - type: file
    ref: "results/example.tsv"
    locator: "row key or relevant section"
    digest: "optional content digest"

Supported source types must cover at least:

- Entity-property execution or receipt.
- Task execution or result.
- Workflow execution or result.
- Filesystem artifact.
- External source, such as a document or URL.
- Other existing Scout artifacts where required.

The type vocabulary must be extensible without changing the overall Observation schema.

The source `ref` is the canonical reference to the actual evidence artifact or execution record. `locator` identifies the relevant part when necessary. `digest` records content identity where available and useful.

Reuse provenance already captured by execution receipts. Do not copy receiver identities, property arguments, workflow parameters, or other execution metadata into the Observation unless the reference cannot otherwise resolve that information.

A file reference alone may be insufficient when its contents can change. Preserve a content digest, immutable artifact reference, or equivalent identity where practical. Do not require every source to have a digest if Scout cannot provide one; report the limitation instead.

The optional `value` field is for compact results that are useful to query or inspect directly. Do not embed large tables or complete result datasets in an Observation. Reference those artifacts through `sources`.

An Observation cannot enter its registered/current state without at least one source reference. Unreferenced exploratory ideas belong in working notes, not in the scientific Observation record.

An Observation does not require an explicit Claim to exist. Findings can be recorded before their implications are understood.

### Observation lifecycle

Support these states, unless equivalent existing Path lifecycle semantics already provide them:

- `current`
- `invalidated`
- `superseded`

Invalidation means the record should no longer be relied upon as valid evidence. Supersession means another record replaces it as the authoritative representation. Neither operation should silently erase the historical record or its prior links.

## 4. Claim schema

A Claim is a proposition that can be assessed against evidence. It may be descriptive or interpretative, but its scope must not exceed what the evidence warrants.

Required field:

- `statement`

Optional fields:

- `title`
- `scope`
- `links`
- `limitations`: relevant qualifications or known limitations.
- `assessment`: a concise explanation of the current evidential assessment.
- `status`

The `links` field should typically reference supporting, contradictory, or qualifying Observations. It may also reference other Claims where a conclusion depends on intermediate conclusions.

Allowed relationships for Claims:

- `supported_by`: an Observation or Claim.
- `contradicted_by`: an Observation or Claim.
- `qualified_by`: an Observation or Claim.
- `supersedes`: an earlier Claim.
- `related_to`: another Claim.

A Claim may be registered while still proposed and under investigation. Do not require it to be established before allowing registration.

### Claim lifecycle

Use a controlled status vocabulary:

- `proposed`
- `supported`
- `qualified`
- `weakened`
- `rejected`
- `superseded`

The initial status should be `proposed`.

Statuses must have documented meanings. In particular:

- `supported` means the available evidence warrants the stated proposition within its declared scope; it does not imply universal truth.
- `qualified` means the proposition is defensible only with an explicit restriction or qualification.
- `weakened` means relevant evidence or analysis has reduced confidence in the proposition without necessarily refuting it.
- `rejected` means the proposition is not supported under the stated scope or has been contradicted by the available evidence.
- `superseded` means a newer Claim replaces this record as the authoritative formulation.

Changing a Claim's status is a scientific judgement, not an automatic consequence of adding a link. Record the assessment rationale and preserve history through the existing Path versioning or artifact-history mechanism.

## 5. Hypothesis schema

A Hypothesis is a proposed explanation of observations or patterns. It should remain distinguishable from an established finding.

Required field:

- `statement`

Optional fields:

- `title`
- `scope`
- `links`
- `predictions`: a list of expected findings that would follow if the hypothesis were correct.
- `test_ideas`: a list of concise proposed tests or discriminating analyses.
- `limitations`
- `assessment`
- `status`

Allowed relationships for Hypotheses:

- `motivated_by`: an Observation or Claim that prompted the hypothesis.
- `explains`: an Observation or Claim whose pattern the hypothesis attempts to explain.
- `supported_by`: an Observation or Claim consistent with the hypothesis.
- `contradicted_by`: an Observation or Claim inconsistent with the hypothesis.
- `supersedes`: an earlier Hypothesis.
- `related_to`: another scientific record.

`predictions` and `test_ideas` should be plain strings initially. Do not introduce a separate prediction ontology or a complex nested schema for the first implementation.

Hypotheses can be registered before predictions or tests have been fully formulated. The validation and Research-checking layers should distinguish an exploratory hypothesis from one ready for systematic testing.

### Hypothesis lifecycle

Use the following controlled states:

- `proposed`
- `under_test`
- `consistent_with_evidence`
- `weakened`
- `rejected`
- `unresolved`
- `superseded`

The initial status should be `proposed`.

`consistent_with_evidence` does not mean proven. It means the currently available evidence is compatible with the hypothesis. A hypothesis can remain unresolved when available evidence does not discriminate adequately between competing explanations.

Do not automatically promote a Hypothesis based on the number of supporting records.

## 6. Path behaviour and integration

Each kind must integrate with the existing Path implementation and use the same ordinary lifecycle operations and conventions as other supported kinds.

Implement:

1. **Write:** create a record and validate its schema.
2. **Read:** retrieve the exact record with its current content, status, and links.
3. **Edit:** update a record, validating the complete resulting record rather than only the changed fields.
4. **List:** enumerate records of the kind, returning stable identifiers and useful summaries.
5. **Reference resolution:** resolve linked record identifiers and report missing or invalid targets.
6. **Lifecycle handling:** enforce the relevant status vocabulary and preserve history.
7. **Validation:** return actionable errors that tell the agent which field, reference, or invariant failed.

Follow existing Scout Path discovery, loading, naming, path-resolution, and error-handling conventions. Do not invent a separate class registry or duplicate the generic Path engine.

Do not add a new general-purpose CRUD tool family for scientific records. The existing Path interface should be sufficient to operate on them.

The physical representation may follow the existing conventions used by Scout's Path kinds. YAML examples in this specification are conceptual; do not introduce a new serialization format if the existing system already has an established one.

## 7. Validation requirements

Separate structural validity from scientific assessment.

### Hard validation failures

Reject operations that would produce a malformed or internally inconsistent record, including:

- Missing required fields.
- Invalid status values.
- Invalid field types.
- Malformed link entries.
- Invalid relationship types for the source and target record kinds.
- Broken references to required local artifacts or scientific records.
- Duplicate identifiers.
- Invalid lifecycle transitions, where transitions are enforced.

An Observation being registered without any source is a hard failure.

Unknown top-level fields should be rejected or handled according to established Scout schema conventions, so misspelled fields do not silently pass validation. Flexible keys are permitted inside `scope` and the compact structured `value`.

### Warnings, not automatic failures

Do not conflate missing scientific certainty with malformed records.

Examples of warnings include:

- An exploratory Hypothesis has no predictions yet.
- A proposed Claim has not been challenged.
- An external source cannot currently be retrieved.
- A mutable source has no recorded content identity.
- A Claim has not yet considered relevant counterevidence.
- The source is available, but its original derivation cannot be re-executed.

An unavailable URL must not be treated like a missing local file. Validation should distinguish syntactic/reference integrity from live network availability.

The Path validator must not claim to establish whether a biological interpretation is scientifically correct. It validates record integrity and provenance, not scientific truth.

## 8. Concurrency, history, and authority

Identifiers must remain unique when several agents create records concurrently.

Record edits must not silently overwrite a different record or destroy historical versions. Reuse Scout's existing versioning and conflict-handling conventions. If optimistic concurrency or equivalent protection already exists, use it.

When an Observation is invalidated or superseded, existing Claims must not be silently rewritten. Checks and reports should be able to detect that a Claim depends on an invalid or superseded Observation.

Use one authoritative writable location for each record. Generate indexes, backlinks, ledgers, and report views from the records rather than requiring agents to maintain duplicate editable copies.

## 9. Automated tests

Add tests for each Path kind covering:

- Valid creation, reading, editing, listing, and lifecycle operations.
- Required fields, optional fields, types, and status validation.
- Stable identifiers and collision-safe creation.
- Correct serialization and round-trip preservation.
- Valid and invalid inter-record links.
- Relationships between all three kinds, including prohibited combinations.
- Missing and unresolved references.
- Observation source references for files, entity-property receipts, tasks/workflows, and external sources.
- Optional locators and content digests.
- Invalidated and superseded records remaining historically inspectable.
- Claims whose evidence becomes invalid or superseded.
- Concurrent creation and conflicting edits, to the extent supported by the existing filesystem and Path mechanisms.
- Actionable error messages for agent callers.

Use existing Scout test conventions and standard test tooling. Do not introduce additional dependencies solely for these records.

Test both the Path contract and the actual lifecycle behaviour, not only standalone schema-validation functions.

## 10. Scope boundaries

The deliverable for this implementation is the three Path kinds, their schemas, their lifecycle behaviour, their validation, and their tests.

Do not implement a general scientific graph database, a universal ontology of evidence, numeric confidence calibration, a separate review-record type, a new Research orchestration framework, or a dedicated tool for every possible source type.

The design must leave room for Research to add an Observation-capture convenience operation later. For now, the schemas and reference conventions must make that operation possible without requiring another schema redesign.

Do not make AGS-specific fields mandatory. The same records must work for a different scientific domain with different data sources, analysis methods, and definitions of scope.

## 11. Acceptance criteria

The implementation is complete when:

1. Agents can create and retrieve all three kinds through the existing Path interface.
2. Each kind has a small, documented, validated schema.
3. An Observation can reference an actual source without copying all source metadata into the record.
4. Claims and Hypotheses can reference Observations and other appropriate scientific records through typed links.
5. Invalid references and malformed records are rejected with actionable errors.
6. Status and lifecycle semantics are documented and enforced.
7. Record identity, history, and references remain reliable under concurrent work and subsequent edits.
8. Automated tests cover the lifecycle, schema, reference, and failure cases.
9. The implementation introduces no AGS-specific schema requirements and no unnecessary parallel infrastructure.

Report the files changed, schema decisions, tests executed and their results, any deviations from this specification, and any unresolved limitations. Do not claim a test or verification passed unless it was actually executed.

My main implementation preference is to keep the initial schema this small and let the Research workflow provide the richer scientific protocol later. In particular, don't ask these agents to implement Observation capture, automated scientific challenges, or report generation as part of the Path-kind task. Make sure the record formats can support those operations, but first establish the durable data contract.

## Decisions (plan step 1)

1. Placement: the Research checkout (~/AgentSuite/Research), not scout-ai core. Rationale: the path engine supports workflow-declared PATH_KINDS (per scout-ai doc/developer/PathEngine.md), ScoutCoder's own six kinds (lib/ScoutCoder/path_kinds.rb) set the precedent, and the suite philosophy keeps scientific semantics out of the substrate. This deviates from the restatement's assumption that the work lands in the scout stack repo owning Path; the deviation is to be reported to the user and may be vetoed.
2. ID allocation: a shared-name register custom operation on all three kinds (engine-sanctioned extension surface; run_probe precedent), allocating OBS-### / C-### / H-### from an atomic per-kind counter and returning the ID. Agents never allocate IDs themselves.
3. Concurrency/history: atomic counter allocation (lock utility if one exists in the stack, else a simple O_EXCL-style fallback); versioning via adjacent .info JSON sidecar plus history/ snapshots (Cortex artifact convention); edits guarded by an expected_version-style check.
4. Serialization: YAML record bodies (human-auditable), strict unknown-top-level-key rejection in the validator; JSON only for sidecars. No new dependencies.

## Engine facts to pin (step 2)

Verdicts recorded by the step-2 bout. (a)–(c) are settled by documentation
(scout-ai `doc/developer/PathEngine.md`), (d) by documentation plus one
throwaway probe, (e) by a bounded search that found no helper. Step 3's unit
tests exercise the actual behavior and will fail loudly if the documentation
misleads.

- [x] (a) YES — confirmed-by-documentation. PathEngine.md §4 "Declaring kinds
  in a workflow: `PATH_KINDS`": "The declaration is part of the workflow's
  Ruby, and the grant happens at incorporation: merely loading a workflow's
  files registers nothing anywhere, and the constant alone grants nothing."
  Same section, and pinned by
  `test/scout/llm/agent/test_path_workflow_integration.rb`
  (`test_task_level_tool_line_registers_nothing`): whole-workflow `tool:
  Research` registers the kinds; task-level lines register nothing. Note the
  sequencing consequence: an agent must incorporate whole-workflow `Research`
  BEFORE any task-level `tool: Research <task>` line is processed for the
  kinds to be present — task-level-only incorporation gives the tasks without
  the kinds.
- [x] (b) YES — confirmed-by-documentation. PathEngine.md §3 "Registering a
  kind": "`capabilities` accepts an Array of enabled operation names or a
  Hash merged over `DEFAULT_CAPABILITIES` (`read`, `write`, `edit`, `list`,
  `move`, `rename`, `delete` on by default; ...)." So each kind can disable
  any of `write`/`move`/`rename`/`delete` individually, e.g.
  `"capabilities" => {"move" => false, "rename" => false, "delete" => false}`.
- [x] (c) YES — confirmed-by-documentation. PathEngine.md §7 "Parameter
  collision policy": "When several kinds register the same operation name,
  exactly one tool is installed. Their parameter contracts must match exactly
  after normalization: ... `required` and `enum` are compared as unordered
  sets; `default` values are compared by equality." A shared `register`
  operation with identical parameter schemas on all three kinds installs one
  `register` tool; the `kind` argument selects the counter. Caveat carried to
  step 3: `description` is NOT compared and the LAST registration's
  description wins, so the three declarations must carry the same description
  text to avoid a misleading tool description.
- [x] (d) YES — confirmed-by-documentation and confirmed-by-probe. The stack
  exposes both primitives in scout-essentials:
  - `Open.sensible_write(path, content, force:)` — atomic write via
    tmp-file + rename, guarded by a lock, and it REFUSES to overwrite an
    existing file unless `force: true`. Documented in
    scout-essentials `doc/user/WorkingWithFiles.md` § "Atomic writes:
    `sensible_write`" (lines 119-129); implemented in
    `lib/scout/open/stream.rb` (`Open.sensible_write`, line 92) using
    `Open.lock`.
  - `Open.lock(file, ...) { ... }` — advisory lock around a critical
    section, defaulting to a `<file>.lock` sidecar lockfile
    (`lib/scout/open/lock.rb`, lines 15+; `Lockfile` engine in
    `lib/scout/open/lock/lockfile.rb`).
  - Probe (fresh process, `require 'scout'`; run from the Research checkout,
    scratch under tmp/, cleaned up after): four forked processes each
    incremented a counter file inside `Open.lock(counter.lock) { ...
    Open.sensible_write(counter, v+1, force: true) }`; plus
    `sensible_write` overwrite-refusal without `force`. Output:
    `counter_final=4 (expected 4)`; `once=v1 (expected v1)`;
    `once_forced=v2 (expected v2)`. Concurrent counter allocation through
    `Open.lock` + `Open.sensible_write(force: true)` is confirmed working.
- [x] (e) NO GENERIC HELPER — not-found-in-bounded-search. Bounded search
  (grep across scout-essentials/lib and scout-ai/lib for lock, Lock,
  O_EXCL, flock, sensible_write, atomic, history/, snapshot, version,
  backup, rotate) found: the lock/atomic-write layer above (question d);
  Scout's `Persist`/`Resource` caching layer (persist.rb, produce.rb),
  which versions cache databases, not user-editable record files; and
  scout-ai's agent save (`lib/scout/llm/agent/save.rb`), which refreshes a
  complete recovery artifact via `sensible_write(force: true)` and keeps no
  per-edit history. No helper snapshots prior versions of arbitrary
  record-like files and no file-level CAS/expected-version utility exists.
  VERDICT: the planned adjacent `.info` JSON sidecar + `history/` snapshots
  + `expected_version` guard is a justified small addition, not a duplicate
  of existing machinery. It should be built ON TOP of the (d) primitives:
  `Open.lock` around read-modify-write, `Open.sensible_write` for the atomic
  file replacement.

### Step-2 conclusion (basis for step 3)

Concurrency/history mechanism for step 3: allocate every identifier inside
`Open.lock(<kind-root>/register.lock)` with the per-kind counter persisted
through `Open.sensible_write(force: true)` (primitives confirmed by probe,
verdict d). Version each record with an adjacent JSON `.info` sidecar plus
`history/` snapshots, and guard edits with an `expected_version` check
implemented inside the kind's own code (no stack helper exists, verdict e);
all record writes go through `Open.lock` + `Open.sensible_write` so no
partial state is ever visible. Assumptions step 3 carries: the
documentation verdicts (a)-(c) are taken on the documentation's word until
the step-3 unit tests exercise them; the three kind declarations of the
shared `register` operation must carry identical parameter schemas and the
same description text (verdict c caveat).
