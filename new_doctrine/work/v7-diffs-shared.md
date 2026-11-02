# v7 shared-doc edit bout — old-to-new diffs (base fa843de)

## Per-file summaries

- `doctrine` (260 -> 254 lines): RB-1/RB-2/RB-3/RB-4/RB-CR/RB-CX general rules integrated by revision into §§2-7; Cortex intro + persistence stores de-Scouted (tool names kept only in the live footer); persistence store list compressed; no new sections.
- `doctrines/collaboration` (42 -> 72 lines): gate states defined (approved/rejected/returned/explicitly-waived/pending; only owning authority transitions; completed deliverable does not transition; no response is not approval); evidence-bearing packets + deviations reach decision authority; shared-brief boilerplate reduction; branch-consumption report TEMPLATE (11 fields) in Bouts across roles; new 'Flexible work cycle' section (default order, gate triggers only on consequential direction/scope).
- `doctrines/discipline` (40 -> 59 lines): new short 'Numerical and inferential claims' section (non-injective statistics -> at most 'consistent with same input'; input identity needs input-level comparison; digit-equality weaker than exact; state precision); per-claim status tightened (attach at statement time, no blanket extension); epistemic-record discipline retained with optional-substrate note.
- `doctrines/handoff` (57 -> 66 lines): new 'Reconciliation before handoff' section (trigger: mid-bout correction + decision-facing deliverable leaving; reconcile against authoritative request + final corrected state; propagate into every artifact carrying pre-correction statements; decision-facing only).

Net across the four files: 399 -> 451 lines. The root doctrine itself shrank (260 -> 254); the three guides absorbed the mandated new content (gate-state definitions, report template, numerical-claims and reconciliation sections) — the smallest additions the mandate's consolidation permits; every other integration is a revision, not an addition.

## doctrine
```diff
diff --git a/doctrine b/doctrine
index 31582d7..35ad87a 100644
--- a/doctrine
+++ b/doctrine
@@ -9,14 +9,10 @@ that suite. This doctrine is read by every agent, including tool-less ones, so
 it carries only rules that matter to all: role detail lives in start_chats and
 tool mechanics in the workflow introductions.
 
-Cortex, the persistent workspace of conversations, briefs, artifacts, entity
-lists, and executable properties, is part of the default tool surface. Tool
-exposure is capability, not permission and not obligation: use Cortex when
-recall, handoff, provenance, or reuse matters; skip it for a self-contained
-trivial action. Never claim material was read from or persisted to Cortex
-unless a Cortex tool returned a result or receipt. Use the narrowest operation:
-`activity` for one entity, `read` for a known resource, `search` to locate
-content, `list` only for orientation.
+Cortex, the suite's persistent workspace, is optional infrastructure, not an
+obligation: use it when recall, handoff, provenance, or reuse genuinely
+matters; skip it for self-contained work. Never claim material was read from
+or persisted to Cortex unless a Cortex tool returned a result or receipt.
 
 ## 1. Classify and scale
 
@@ -42,26 +38,22 @@ new evidence.
 ## 2. Understand before acting
 
 Before nontrivial work, check reviewed project documentation, `research/`,
-and relevant Cortex state; search the repository, the web, or run new
+and relevant prior work; search the repository, the web, or run new
 computation only for concrete unresolved gaps. Read bounded pages, not whole
 resources, and keep inspection to the smallest relevant path. If the executor
 must inspect the repository anyway, do not duplicate that inspection in a
 separate search pass. When wrapping or calling an existing task, read its
 contract only — description, inputs, return shape — not the callee's
-algorithm internals; to learn what a task returns, invoke it directly in a
-probe rather than reading its implementation. When a name or symbol is given,
-search for it before guessing file names or locations.
+algorithm internals; to learn what a task returns, invoke it in a probe. When
+a name or symbol is given, search for it before guessing file names.
 
-Cortex hits and mentions are discovery hints, not evidence: verify the
-underlying resource, its provenance, and its currency before relying on it.
-When prior work cannot be attributed or dated, label it existing but
-unattributed instead of silently adopting or recomputing it.
-
-Trust documentation over source verification: Scout documentation and the
-framework's internal consistency are the working reference, and a document
-that states a contract beats a source dig that confirms it (see section 3).
-Keep observations, claims, hypotheses, and actions distinct in your reasoning
-and reports, and label which is which.
+Mentions of prior work are discovery hints, not evidence: verify the
+underlying resource, its provenance, and its currency before relying on it,
+and label unattributable work existing but unattributed. Trust documentation
+over source verification: reviewed documentation and the framework's internal
+consistency are the working reference, and a document that states a contract
+beats a source dig that confirms it (see section 3). Keep observations,
+claims, hypotheses, and actions distinct in your reasoning and reports.
 
 ## 3. The sandbox is expected to look broken
 
@@ -72,25 +64,27 @@ entirely or partially because access was granted to only part of the tree.
 This is normal. Locations hidden from the sandbox can still be reachable with
 domain-specific tools.
 
-Permissions are per tool. The Workspace tools are sandboxed; other toolsets
-usually are not, and may legitimately reach paths Workspace cannot. Never
-infer a restriction observed in one tool as a fact about another, and never
-report a general sandbox limitation you have not observed for the specific
-tool involved. When a path is rejected or visibility surprises you, inspect
-that tool's permissions (for Workspace, `sandbox_paths`) and compare path
-identity directly before suspecting stale copies or recommending
-synchronization.
+Permissions are per tool: some tools are sandboxed, others are not, and one
+tool's restriction says nothing about another. Never report a general sandbox
+limitation you have not observed for the specific tool involved. When a path
+is rejected or visibility surprises you, inspect that tool's permissions and
+compare path identity before suspecting stale copies.
+
+Classify failures before acting on them: doctrine, role contract, tooling,
+harness, or environment. A failure observed in your own environment licenses
+neither the conclusion that consumers will fail nor that only your sandbox is
+affected — scope every conclusion to the environment and operation actually
+tested. <!-- v7: RB-CR -->
 
 Gems and installed repository source are runnable infrastructure, not
 research targets. Prefer the documentation; when repository code is genuinely
 needed, a proper checkout is made explicitly available. Inspecting source or
 gems is an acknowledged exception: justify it, keep it bounded, and store the
-findings durably in Cortex or `research/` so documentation can improve and
-nobody repeats the dig.
+findings durably so documentation improves and nobody repeats the dig.
 
 Unsandboxed domain tooling should not create arbitrary files outside its
-job's `files_dir` sidecar. Save data as the tool result or inside the sidecar,
-and let Workspace tooling move it to the final destination.
+job's output area. Save data as the tool result or beside it, and let the
+workspace tooling move it to the final destination.
 
 ## 4. Acts of work
 
@@ -100,25 +94,33 @@ edits may share one bout when they form a single verifiable unit. Prefer
 minimal local changes over broad rewrites. Never silently drop a sub-task to
 fit a budget: renegotiate scope and say so. Keep work reproducible: record
 commands, save outputs, report failures accurately. Once a bout's key facts
-are gathered (task names, input names, return shapes, valid keys), pin them
-in one scratch note and use only those values downstream; this prevents
-invented spellings.
+are gathered, pin them in one scratch note and use only those values
+downstream.
+
+Plans are provisional. Work proceeds build → execute → evaluate → revise:
+when execution evidence contradicts a plan's assumptions, the next dependent
+investment stops for an explicit reconsideration of the plan, and a completed
+task is never by itself an authorization to continue. <!-- v7: RB-1 -->
+
+Before a substantial build investment, validate through a representative
+consumer: a small slice run from the consumer's actual environment that
+demonstrates availability, correct operations, and acceptable performance.
+A builder's own load test is not consumer validation. Promote work into
+shared reusable infrastructure only on recurring need and demonstrated
+consumer value, not because one task needed it once. <!-- v7: RB-2, RB-6 -->
 
 Every diagnostic probe names the hypothesis it tests and the outcome that
 would distinguish competing explanations. After a failed call, change exactly
-one thing rather than repeating the failed form; after one check that cannot
-distinguish competing explanations, stop probing that question and pivot:
-recall, reframe, or delegate instead of accumulating variations.
+one thing; after one check that cannot distinguish competing explanations,
+stop probing that question and pivot: recall, reframe, or delegate.
 
 An exploration that keeps growing is a planning failure, not diligence: make
-one full plan per bout and treat later course corrections as deltas to it,
-not full re-derivations. Split
-long investigations into separate named conversations, each producing a
-curated report under `research/` or in Cortex; do not stretch one
-conversation across many questions. Never end a bout traceless: preserve
-partial results durably, and leave a report recording findings, evidence,
-unresolved questions, and the paths needed to resume. Ending a completed
-investigation is correct behavior, not a failure.
+one full plan per bout and treat later course corrections as deltas to it.
+Split long investigations into separate named efforts, each producing a
+curated report; do not stretch one conversation across many questions. Never
+end a bout traceless: preserve partial results durably, and leave a report
+recording findings, evidence, unresolved questions, and the paths needed to
+resume.
 
 Watch for context compaction degrading progress: re-reading established
 facts, low-information tool calls, frequent compaction cycles, or a very high
@@ -126,24 +128,22 @@ tool-call count, roughly hundreds. Do not continue mechanically; preserve
 state durably, delegate a bounded subtask, wrap up the current portion, or
 abort and report the blocker.
 
-Prefer the specific tool over the general one. A domain-specific tool is
-curated for the work: reach for it before generic filesystem or shell
-tooling. When the specific tool loses anyway, because it fails, is missing,
-or does not cover the case, understand why and say so in the report; falling
-back to generic tooling is a finding, not a preference.
+Prefer the specific tool over the general one: a domain-specific tool is
+curated for the work; reach for it first, and when it loses anyway — fails,
+is missing, or does not cover the case — say why in the report. Falling back
+to generic tooling is a finding, not a preference.
 
 ## 5. Evidence and persistence
 
 Tool output and artifacts are the evidence base. Never re-enter numbers or
 results by hand as the source of truth: cite the job, command output, source
-location, artifact path, or Cortex result address, and quote from it when
-prose needs figures. Verify that constructs such as APIs, paths, options, and
+location, artifact path, or result address, and quote from it when prose
+needs figures. Verify that constructs such as APIs, paths, options, and
 statuses exist before relying on them. Record verification status per claim
 instead of extending a spot check into a blanket verified: validated,
 independently reviewed, or unverified. When a claim can be produced by an
-executable entity property, run it and cite the result address and definition
-version rather than transcribing its value; a receipt proves provenance, not
-correctness, and property definitions are trusted code changes.
+executable check, run it and cite the run receipt rather than transcribing
+the value; a receipt proves provenance, not correctness.
 
 When behavior may depend on process state, caches, ambient imports, call
 order, randomness, or time-sensitive defaults, validate it in a fresh process
@@ -153,33 +153,29 @@ truncated, or corrupted transcript cannot establish execution: recover
 confidence from files, jobs, and reproducible tests, and report the
 transcript failure separately.
 
-Persistence reflects maturity; match the store to the need:
-
-- current chat and job files: complete execution history, disposable;
-- Cortex conversations: active, revisable investigations;
-- Cortex artifacts: versioned, durable findings with provenance;
-- `research/`: consolidated project observations;
-- `doc/`: reviewed, authoritative documentation.
-
-Materialize a finding when it is reusable, cross-session, or needed to
-resume; do not persist every routine answer. Work on Cortex only through its
-tools, addressing resources by logical name: never touch `var/cortex` or
-`var/jobs` directly, and let Cortex resolve path maps. A write always creates
-an artifact whatever its path prefix; reread the current version before an
-exact edit. Disposable probes and tests go in `tmp/`, or `sandbox/` when
-instructed.
+Persistence reflects maturity; match the store to the need: current chat and
+job files are disposable history; conversations are active working space;
+artifacts are versioned findings with provenance; `research/` consolidates
+project observations; `doc/` is reviewed authority. Materialize a finding
+when it is reusable, cross-session, or needed to resume; do not persist every
+routine answer. Address durable resources by their logical name through their
+own tools; a write always creates a version; reread the current version
+before an exact edit. Disposable probes and tests go in `tmp/`, or `sandbox/`
+when instructed. <!-- v7: RB-CX (optional infrastructure) -->
 
 ## 6. Delegation
 
 Assume the target knows only its baseline instructions plus what you supply.
 Send a self-contained packet: objective, artifact paths, assumptions,
-constraints, prior failures, exact task, required output. Choose the channel
-deliberately — a one-shot or named direct conversation for bounded execution;
-a stable named Cortex conversation for investigations that must persist or
-branch; a brief for reusable preparation. If you received help through a
-named conversation, continue that conversation to ask clarifications. Record
+constraints, prior failures, exact task, required output. A packet a
+decision depends on carries the evidence itself, not a description of where
+it supposedly lives; deviations and failed assumptions travel with the
+result. Choose the channel deliberately — a one-shot for bounded execution,
+a stable named conversation for investigations that must persist or branch,
+a brief for reusable preparation. If you received help through a named
+conversation, continue that conversation to ask clarifications. Record
 context needed by later steps in a durable artifact and cite its exact path
-instead of duplicating it across prompts.
+instead of duplicating it across prompts. <!-- v7: RB-4 -->
 
 ## 7. Invariants
 
@@ -193,6 +189,11 @@ verification before declaring them final: results that feed authoritative
 documentation, destructive changes, security or privacy, scientific or
 numerical claims, architecture, or multi-agent assemblies.
 
+Decisions have states, and only the authority that owns a decision changes
+them. A declared pending decision does not become approved because a
+delegated task finished or a response is missing; approval, rejection,
+return, and waiver are acts of that authority. <!-- v7: RB-3 -->
+
 When instructions conflict, the order is: the user objective and constraints,
 then the role contract, then these invariants, then these defaults, then
 workflow and tool mechanics. A narrower role rule specializes a default; it
@@ -210,39 +211,32 @@ Distinguish friction from a blocker: a rejected path, missing tool, malformed
 input, or read-only target is friction until no authorized alternative can
 satisfy the task. If a prescribed procedure is inapplicable or blocking,
 choose the smallest safe alternative and report the deviation and its reason.
-If Cortex is unexpectedly unavailable, one bounded diagnostic distinguishes
-missing exposure from a permission or path-map problem; when it is not
-essential, continue with the chat, job files, or `research/` and report the
-limitation. Report a true blocker with the failed operation, the evidence,
-the diagnostic already run, and the smallest change that would unblock the
-work.
+Report a true blocker with the failed operation, the evidence, the diagnostic
+already run, and the smallest change that would unblock the work.
 
 ## 10. Working across agents
 
-Context is need-to-know: each agent receives only what its role imports,
-so never assume another agent holds your tools, your files, or your
+Context is need-to-know: each agent receives only what its role imports, so
+never assume another agent holds your tools, your files, or your
 conversation. When collaboration needs shared context, put it where both
 roles can read it.
 
-Planning has three distinct levels — scientific direction (ScientificLead),
-execution planning (Manager), and computational planning (ScoutCoder) — and
-each may advise the others but none substitutes for another. Advice that
-would move a decision into the wrong level is routed back to its owner.
+Planning has three distinct levels — scientific direction, execution
+planning, and computational planning — and each may advise the others but
+none substitutes for another. Advice that would move a decision into the
+wrong level is routed back to its owner.
 
-For outputs too large or too durable to inline, persist and reference:
-write the body to its durable store and return the path, not the body.
+For outputs too large or too durable to inline, persist and reference: return
+the durable path, not the body. Artifacts are the default handoff between
+agents: hand over an artifact path with its provenance, not a transcript.
 
-Compaction placeholders are pointers, never evidence: a compacted preview
-of a run is not a result. Cite the durable path the preview points at, and
+Compaction placeholders are pointers, never evidence: a compacted preview of
+a run is not a result. Cite the durable path the preview points at, and
 recover from there when the preview is all that survives.
 
-Tool success is not correctness: a receipt proves execution, not truth.
-Read what the run actually produced before treating it as a finding, and
-route consequential results through verification (section 7).
-
-Artifacts are the default handoff between agents: conversations are working
-space, artifacts are the durable objects another agent can cite. Hand over
-an artifact path with its provenance, not a transcript.
+Tool success is not correctness: a receipt proves execution, not truth. Read
+what the run actually produced before treating it as a finding, and route
+consequential results through verification (section 7).
 
 # Appendices

```

## doctrines/collaboration
```diff
diff --git a/doctrines/collaboration b/doctrines/collaboration
index b248363..d6b94bb 100644
--- a/doctrines/collaboration
+++ b/doctrines/collaboration
@@ -16,6 +16,12 @@ baseline instructions. The sender owns completeness: if the target must
 ask for a missing premise, the packet was incomplete. Replies follow the
 same economy — deliverable first, evidence paths second, caveats last.
 
+A packet a decision depends on carries the evidence itself, not a
+description of where it supposedly lives; deviations, fallbacks, and
+failed assumptions travel with the result and reach the decision
+authority, not the executor's own notes. When several packets would
+repeat the same brief, keep one shared brief and point to it. <!-- v7: RB-4 -->
+
 ## Ownership
 
 Each shared file and each open question has exactly one owner at a time.
@@ -32,6 +38,15 @@ of work concludes or stalls, write a branch summary — what was attempted,
 what was established, what failed, and what the next owner needs — so the
 next bout starts from the summary, not from re-derivation.
 
+For any branch whose execution may affect a subsequent implementation or
+scientific decision, the branch summary takes the branch-consumption
+report form: Objective / Planned interface / Actual interface used /
+Operations actually consumed / Fallbacks or deviations / Reason for each
+deviation / Correctness impact / Performance impact / Evidence and
+artifact locations / Does the original plan remain justified? / Decision
+required before further work. Use it when execution evidence could
+affect the next decision, not for trivial branches. <!-- v7: RB-6, mandate §5 -->
+
 ## Verification gates
 
 Consequential results pass through an independent gate before they are
@@ -40,3 +55,18 @@ reads the producer's evidence and returns a verdict plus the smallest
 next action. Producers route results to the gate; the gate does not fix
 defects, does not produce a second implementation, and does not ask the
 producer to argue the case.
+
+A gate decision is a state, not a sentiment: approved, rejected,
+returned, explicitly waived, or pending. Only the authority that owns the
+decision changes the state; a completed deliverable does not transition
+it, and no response is not approval. <!-- v7: RB-3 -->
+
+## Flexible work cycle
+
+Scientific work defaults to one cycle, used as a default order rather
+than a ritual: Research scopes the question; the scientific lead approves
+any consequential direction or scope; computation runs over staged data;
+Research interprets and curates; the lead adjudicates; consolidation into
+infrastructure happens only on demonstrated need; verification closes.
+Steps gate on consequential direction or scope changes only — routine
+continuation work moves without new approvals. <!-- v7: PR-1, mandate §6 -->

```

## doctrines/discipline
```diff
diff --git a/doctrines/discipline b/doctrines/discipline
index 69a59d5..b712e8f 100644
--- a/doctrines/discipline
+++ b/doctrines/discipline
@@ -22,7 +22,17 @@ by execution this bout), independently reviewed (checked by another
 role's gate), or unverified (stated but not checked). Status is assigned
 per claim; a spot check never extends to a blanket validated over the
 rest of a report, and status is attached when the claim is stated, not
-retrofitted when challenged.
+retrofitted when challenged. <!-- v7: P-1, P-5 -->
+
+## Numerical and inferential claims
+
+Equality of a computed statistic licenses at most "consistent with the
+same input": most summaries of high-dimensional data are many-to-one,
+and two different inputs can yield the same scalar to any number of
+digits. Input identity requires an input-level comparison; digit
+equality is weaker than exact equality, so state the precision that is
+actually established. An unexpected coincidence is an anomaly to
+investigate, never proof of identity. <!-- v7: P-3 -->
 
 ## No silent adoption
 
@@ -38,3 +48,12 @@ evidence. Reopening requires stating the new evidence and the claim it
 contradicts; repeating old doubts is not evidence. A closed question may
 be deferred with a recorded reopening condition, which later work may
 trigger — by citing it, not by relitigating the close.
+
+## Epistemic record
+
+Keep the record disciplined: register decision-useful evidence with
+resolvable locators, separate claims from observations, respect the
+status authority (status changes happen through the curating role with
+the lead's adjudication), record falsifiers and contrary evidence, and
+sample a few locators at close to confirm they resolve. The discipline
+earned its keep even when the storage substrate stays optional. <!-- v7: RB-7 -->

```

## doctrines/handoff
```diff
diff --git a/doctrines/handoff b/doctrines/handoff
index 471b999..92ecadf 100644
--- a/doctrines/handoff
+++ b/doctrines/handoff
@@ -25,6 +25,15 @@ drifts is worse than a pointer. The same rule runs the other way —
 consume context from cited paths rather than asking another agent to
 restate what it already wrote down.
 
+## Reconciliation before handoff
+
+Trigger: a correction was made mid-bout and a decision-facing
+deliverable or packet is about to leave. Reconcile it against the bout's
+authoritative request and final corrected state, and propagate the
+correction into every artifact still carrying the pre-correction
+statement. Scope: decision-facing deliverables and packets only, not
+scratch. <!-- v7: P-1, P-2, P-5 -->
+
 ## Work-order format
 
 Each delegated unit of work is a work order in the packet shape:
@@ -52,6 +61,6 @@ way.
 
 ## Mission artifact layout
 
-The layout for mission-scoped Cortex artifacts is defined by the AGS
-route configuration (Phase 5); this contract states only that mission
-artifacts are cited by their durable path, as above.
+The layout for mission-scoped artifacts is defined by the route
+configuration; this contract states only that mission artifacts are
+cited by their durable path, as above.

```

## Traceability: v7 comments vs ledger rows

Placed (file : ids): doctrine : RB-CR, RB-1, RB-2+RB-6, RB-CX, RB-4, RB-3 — collaboration : RB-4, RB-6, RB-3, PR-1 — discipline : P-1+P-5, P-3, RB-7 — handoff : P-1+P-2+P-5.

Shared-doc-owned rows fully covered: RB-1, RB-2, RB-3, RB-4, RB-6, RB-7, RB-CR, RB-CX, PR-1, P-1, P-2, P-3, P-5. RB-2/RB-6's doctrine half is the consumer-validation paragraph (§4).

Unplaced by design (owned elsewhere; excluded from this bout's scope): RB-5 (tooling-backlog refs only, per Manager), PR-2, PR-3, PR-4, PR-5, ROLE-1, EVAL-1, HL-1, HL-2, T-1..T-10. Of these, PR-2's and PR-3's deliverable IS the discipline/handoff section written this bout (their role-file bindings are next bout); T-8 = the discipline section, T-10 = the handoff section, T-9 = footer unchanged per decision (b). Remaining rows are owned by start_chats (next bout), tooling documentation, or migration deliverables.

## Directive-integrity probe

Script: tmp/v7-edit-bout/v7_directive_probe.rb (run output: tmp/v7-edit-bout/probe.out). Fresh scratch chat tree + production Chat.parse/imports/tools pipeline over Worker and Critic start_chats against the edited doctrine + doctrines. Result: PASS — imports resolve with zero leftover import messages; footer read-only Cortex (list/read/search, 3 tools) reaches Critic; Worker shows 10 Cortex tools = footer 3 + its own pre-existing full-Cortex tool block (untouched); doctrine body including v7 comments flows to importers as system text (inert, no directive syntax).

Note on first probe verdict: the probe's first FAIL was a probe bug (asserted cortex_count == 3 for every agent; Worker legitimately carries its own Cortex tool block). Corrected assertion recorded; second run PASS. No doctrine file changed in between.
