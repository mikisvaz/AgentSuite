---
provenance: extracted verbatim from Planned request job Default_d677f25a46c831a377a9c295783ced8a
  source-of-raw-user-request: /home/mvazque2/.scout/var/jobs/Planned/request/Default_d677f25a46c831a377a9c295783ced8a.chat.files/User.chat (the stage job file itself carries no `user:` message; the raw user request lives in its User.chat sidecar)
  embedded-document-marker: <WritingBlock id="73184" variant="document"> ... </WritingBlock>
  extractor-role: Worker (v7 instruction editor, setup bout 1)
  date: 2026-11-02
  byte-fidelity: body below is lines 6085-6518 of User.chat with ONLY the two
    WritingBlock tags stripped from their lines; no other byte altered.
    sha256 of body: 689247069120ca9ffae8e17db4474a918392a549efee277344fc28a64f2ed2ab
    body size: 21530 bytes / 434 lines / 14 top-level sections.
  boundary-decisions: the mandate starts at the opening WritingBlock marker line
    (its first content byte is the `#` of the title) and ends at the closing
    `</WritingBlock>` marker, which shares its line with the mandate's final
    sentence. The two lines immediately following the document in the source
    (`So that is the brief.` / blank) are excluded as chat prose, not document
    content. No other boundary ambiguity found: markers are unique for id 73184.
---

# AgentSuite Doctrine v7 - consolidation mandate

## Objective

Prepare a candidate AgentSuite Doctrine v7 and revised agent `start_chat` instructions, consolidating the lessons from the doctrine6 AGS mission, its independent ChatAnalyst process X-ray, the remediation backlog, and the subsequent AGS scientific-integration pilot.

This is an architecture and operating-protocol revision, not a general prompt expansion.

The objective is to make the agents better at:
- choosing the least costly adequate way to accomplish scientific work;
- recognising when execution evidence invalidates a plan;
- respecting decision authority and approval gates;
- separating scientific investigation, general computation and infrastructure development;
- transmitting evidence and deviations faithfully;
- verifying the actual capabilities and interfaces available to each role.

Produce a candidate v7 in a separate branch or staging area. Do not silently replace the active doctrine or deployed role prompts.

## 1. Source review before editing

Inspect the current AgentSuite repository and identify the actual deployed configuration.

Read and reconcile:

1. The current General Agent Doctrine and its history.
2. Every existing agent `start_chat` used by AgentSuite.
3. The actual role definitions, tool introductions, imports and tool provisioning.
4. The shared agent collaboration/delegation documentation.
5. The relevant ScoutCoder, Workspace, Research, Semantics and Cortex documentation.
6. The doctrine6 process X-ray, including its decision reconstruction, role audit, epistemic-value analysis and remediation backlog RB-1..RB-7.
7. The AGS scientific-integration pilot, including the Research scoping result and its evaluation.

Do not assume that a documented role, tool or capability is actually deployed. Inspect the current configuration and, where necessary, test it in a fresh agent context.

For every important source-derived statement, distinguish:
- implementation verified;
- runtime tested;
- observed in a particular mission;
- proposed but not implemented;
- estimated or inferred.

The existing General Agent Doctrine v1 and Agent Context Architecture v2 are starting points, not automatically authoritative deployed configurations. Verify their current status.

## 2. Consolidate the actual lessons

Create a decision ledger before rewriting anything. Each entry must connect:

`observed evidence → failure or success mechanism → general lesson → document/role that owns it → behavioural acceptance test`

Do not generalise every AGS-specific problem into universal doctrine. Make a doctrine change only where the principle is cross-project. Keep project-specific constraints in project instructions.

The following lessons must be addressed.

### A. Plans must respond to execution evidence

A plan is an initial hypothesis about how to accomplish a task. It is not a commitment to continue investing regardless of what consumers discover.

When an execution branch reports evidence that contradicts a build assumption, the next dependent investment must be reconsidered.

Do not continue a large implementation wave simply because the preceding design or implementation task completed.

The Manager must detect decision-relevant deviations and route them to the appropriate authority. It must not silently absorb, filter or normalise contradictory information.

This is the central lesson of RB-1.

### B. Decision gates must have enforceable states

A status such as `PROPOSED - awaiting Lead endorsement` is a real precondition, not descriptive text.

Before consuming a gated deliverable, verify that the gate has actually been passed by the authorised decision-maker.

A gate may be:
- approved;
- rejected;
- returned for revision;
- explicitly waived or renegotiated by the appropriate authority;
- still pending.

A completed delegated task does not imply approval. A missing response does not imply approval. A Manager cannot silently waive a ScientificLead decision.

This is RB-3.

### C. Validate infrastructure through actual consumers

A builder testing its own interface is not enough.

Before a substantial build wave, run a small vertical slice from the actual consumer-facing execution context. It must establish:

- the interface is available to the consumer;
- the representative operation can actually be performed;
- the outputs are correct and inspectable;
- performance is acceptable for the intended workload;
- the fallback route is understood.

A successful import or smoke test is not proof of operational suitability.

Distinguish:
- interface unavailable;
- interface available but defective;
- interface correct but inefficient;
- interface usable but inappropriate for the workload;
- interface deliberately bypassed for a justified reason.

Do not call all these cases "loadability failure".

This is RB-2.

### D. Handoffs must preserve decision-relevant information

A branch must report both its result and how it obtained that result.

The Manager must forward important deviations, failed assumptions, workarounds, fallback use and relevant performance findings into the next review packet.

A self-contained packet must contain the evidence required for the decision, not merely describe where the evidence supposedly exists.

Avoid gratuitous repetition of large boilerplate. Use shared briefs or durable artifacts where the actual recipient can read them. Never assume that a path in one agent's repository copy is accessible from another agent's run.

This addresses RB-4 and the observed Lead information-starvation problem.

### E. Preserve epistemic discipline; simplify mandatory computational infrastructure

The doctrine6 audit found real value in the epistemic record discipline:
- observations linked to supporting evidence;
- claims separated from observations;
- status authority preserved;
- defective registrations caught before downstream use;
- explicit contrary evidence and falsifiers.

Preserve those behaviours.

Do not make a particular Path-kind API, Cortex resource or storage mechanism mandatory merely because it was intended to implement the discipline.

Likewise, do not make the Scout computational substrate the mandatory data plane for exploratory work. A file-based computation can be entirely appropriate.

Promote computations to reusable Scout infrastructure when actual recurring need and consumer value justify it.

### F. Cortex is optional infrastructure

Cortex is useful when it provides genuine cross-session or cross-project persistence, retrieval and reuse.

It is not a mandatory step in every investigation. Do not create pointer artifacts that nobody consumes, duplicate files without purpose, or route evidence through Cortex when an ordinary project artifact is sufficient.

Keep the responsibilities separate:
- Cortex: conversations, briefs, durable workspace artifacts and persistence.
- Research: scientific evidence, observations, claims and their relationships.
- Semantics: domain entities, properties, associations and related computational interfaces.

### G. Scientific conclusions require valid inference

Preserve distinctions between:
- experimental evidence;
- computational results;
- external database knowledge;
- literature evidence;
- hypotheses and interpretations.

Do not mistake an exact scalar collision for proof that two inputs are identical. Different input vectors can yield the same scalar under a non-injective statistic. Rounded equality is weaker still.

For a numerical conclusion, establish the actual input, transformation, statistic and relevant uncertainty before making a stronger claim.

Corrections made during a work session must propagate into final artifacts and handoff packets. Do not let a mid-bout correction disappear from the final report.

### H. Distinguish doctrine, role, tooling, harness and environment failures

A failed operation does not automatically imply a failed tool, a sandbox limitation or an agent error.

Identify the actual execution surface, the exact operation, the evidence of failure and the scope of the conclusion.

Do not infer that Workspace can access a workflow merely because a Scout-native tool can, or vice versa.

When a tool failure is opaque, report that uncertainty and escalate it. Do not advise proceeding on the basis of an untested assumption.

RB-5 should be addressed in the relevant harness/tooling documentation and failure-reporting contract, not hidden in general doctrine.

## 3. Rewrite the General Agent Doctrine

Keep it short, stable, framework-agnostic and applicable across projects.

It should own:
- understanding the objective and acceptance criteria;
- choosing the simplest adequate approach;
- distinguishing facts, inferences, assumptions and unknowns;
- verifying the actual claim being made;
- reconsidering plans when evidence contradicts assumptions;
- respecting authorised decisions and preconditions;
- preserving useful, inspectable work;
- reporting completion and uncertainty honestly;
- following the actual role and tool contracts.

Add the build-execute-evaluate-revise principle explicitly.

Do not put Scout, ScoutCoder, Cortex, Entities, Path kinds, AGS or tool-specific procedures into General Doctrine.

Do not duplicate delegation mechanics here. Those belong in the shared collaboration guide.

Do not turn the doctrine into a checklist for every conceivable task. It should express principles that change decisions.

## 4. Rework the role contracts and start_chats

Inspect the actual roles in the repository. Preserve useful existing roles and do not introduce unnecessary new ones. At minimum, reconcile the responsibilities below with the current implementation.

### Manager

Owns orchestration, delegation, information delivery and execution of declared gates.

Must:
- check preconditions before dispatching dependent work;
- track pending approvals explicitly;
- collect the actual execution surface and deviations from each branch;
- transmit contradictory evidence to ScientificLead;
- stop dependent work when a required decision is pending;
- verify that handoff artifacts and tools are accessible to recipients;
- report what was actually completed.

Must not:
- make scientific adjudications on behalf of ScientificLead;
- waive a declared gate silently;
- omit a fallback because it makes a branch report look cleaner;
- infer that a child agent has the same tools or filesystem as the parent.

A branch's return report should include both scientific/computational results and execution facts.

### ScientificLead

Owns scientific direction, hypothesis framing, evidence standards, go/no-go decisions and scientific sufficiency.

Must:
- make important approval decisions before expensive or consequential work;
- receive the full decision-relevant evidence, including failures and deviations;
- state what result would change the preferred scientific interpretation;
- distinguish an interim decision from a final adjudication;
- maintain explicit status of hypotheses and claims.

Keep the role tool-less if that remains the intended architecture. In that case, require complete, self-contained evidence packets rather than sending the Lead inaccessible paths or summaries that omit the supporting data.

ScientificLead should not become a relay agent or be asked to perform routine computation.

### Research

Owns active scientific investigation, domain-specific reasoning and epistemic curation.

Must:
- use relevant scientific databases, domain tools and literature interfaces actually provisioned;
- interpret numerical results in the context of biological knowledge;
- distinguish external prior knowledge from new experimental evidence;
- evaluate alternatives and limitations;
- register decision-relevant observations and propose claims where warranted;
- use inspectable source references and computation receipts;
- preserve contrary evidence.

Research should not build general-purpose computational infrastructure simply because an analysis needs a calculation.

Research should not turn every intermediate result into an epistemic record. Registration must serve the scientific question.

### Analyst / computational worker

Define or revise a role for general-purpose computational work, consistent with the current AgentSuite design.

Its default responsibility is computation over staged, inspectable files.

It should have the general tools needed for computation, such as Bash, Python, Ruby or relevant libraries, but should not receive broad Scout framework access by default.

Its work should:
- consume an explicit input package and manifest;
- keep inputs unchanged;
- write scripts, logs, tables, figures and results to a designated work/results area;
- make transformations and denominators reproducible;
- report missing inputs and assumptions;
- distinguish exact reproductions from approximations;
- return a concise computational contract and the evidence needed for Research to interpret the result.

It should not implement Scout tasks, entities or workflow infrastructure. It may recommend reusable computations for later consideration.

A prompt prohibition is not a security boundary. If the whole project repository is mounted, say so. Genuine tool or filesystem isolation must be implemented through configuration and mounts, not claimed in prose.

### ScoutCoder

Owns Scout-specific infrastructure development, not every instance of scientific computation.

Use ScoutCoder when:
- a required data-provisioning operation is missing;
- a useful computation recurs and has demonstrated reusable value;
- a native Scout interface provides a genuine advantage over staged files;
- a framework-level defect needs correction.

Require:
- a minimal design;
- a representative consumer-facing vertical slice;
- explicit input/output contracts;
- appropriate tests;
- a fresh-context availability check;
- a consumer-use test before broad implementation waves.

ScoutCoder should distinguish data provisioning from computation and reusable infrastructure from one-off analysis.

Do not start large build waves before the relevant approval gate and consumer test are complete.

Keep Workspace sandbox semantics separate from ScoutCoder Path-engine semantics. Verify tool introductions and actual availability rather than inferring them from documentation.

### Critic

Owns independent verification.

Must:
- verify claims against source evidence and actual outputs;
- test the relevant consumer-facing surface when assessing usability;
- distinguish an environment-specific failure from a general interface failure;
- report the exact environment and operation tested;
- challenge unsupported inferences, including mathematical assumptions;
- verify that corrections and caveats reach final artifacts.

If it cannot test the actual consumer context, it must state the limitation. It must not treat a failure in its own environment as proof that the consumer will fail, or proof that the consumer will succeed.

### Other roles

Retain and revise Investigator, Worker, Reader, ChatAnalyst, Planner, Searcher and other existing roles only where they have a distinct purpose.

For all execution roles, define a compact return contract:
- result;
- evidence and artifact locations;
- actual tools and execution surfaces used;
- deviations and fallbacks;
- correctness and performance limitations;
- unresolved decisions.

ChatAnalyst should keep target-session findings separate from its own process/performance findings.

## 5. Adopt a common branch-consumption report

Use this compact structure for any branch whose execution may affect a subsequent implementation or scientific decision:

Objective:
Planned interface:
Actual interface used:
Operations actually consumed:
Fallbacks or deviations:
Reason for each deviation:
Correctness impact:
Performance impact:
Evidence and artifact locations:
Does the original plan remain justified?
Decision required before further work:

This is not additional reporting bureaucracy. Use it when execution evidence could affect the next decision. Do not require it for trivial tasks.

The Manager must carry relevant entries into ScientificLead review.

## 6. Adopt a flexible scientific work cycle

Use the following as a default pattern, not a rigid universal workflow:

1. Research scopes the question, relevant evidence and domain-tool requirements.
2. ScientificLead approves consequential scientific direction and the planned investigative scope.
3. Analyst performs general computation over staged data where needed.
4. Research interprets the results using domain knowledge, literature and relevant tools, then curates decision-relevant evidence.
5. ScientificLead adjudicates claims, hypotheses and sufficiency.
6. ScoutCoder develops or consolidates reusable Scout infrastructure only when demonstrated need justifies it.
7. Critic verifies the consequential outputs and process claims.

Data provisioning may occur earlier when required. Use existing native tasks or narrow staging operations when available. Do not force every task through ScoutCoder before it can be investigated.

The essential constraints are authority, evidence and gates, not the exact number or order of agents.

## 7. Keep documentation layered

Maintain the distinction between:

- General Doctrine: universally applicable principles.
- Shared collaboration guide: delegation semantics, authority, gates, handoffs and inheritance.
- Role `start_chat`: role responsibilities, operational rules and references.
- Subsystem references: ScoutCoder, Workspace, Cortex, Research, Semantics, Entities, TSVs and other specialist interfaces.
- Project documentation: local data, workflows, paths and scientific context.
- Task prompt: the objective, constraints, acceptance criteria and required outputs for this assignment.

Do not replicate whole manuals into every role prompt.

For each reference, record its owner, source revision, evidence status, last verification and the conditions that require re-verification.

For each role, record how its instructions and required tools are actually delivered. Check the fresh agent context rather than assuming an `import:`, `introduce:` or `tool:` declaration worked as intended.

## 8. Produce these deliverables

1. A short change ledger mapping doctrine6 and pilot findings to their owning documents and tests.
2. General Agent Doctrine v7.
3. Revised role `start_chat` files for all relevant existing roles.
4. A shared collaboration/gate/hand-off guide, revised only as needed.
5. A role-to-context and role-to-tool delivery matrix.
6. A deployment and capability-verification report.
7. A behavioural evaluation suite and its results.
8. A migration note explaining what was removed, retained, moved to references or newly introduced.

Show the old-to-new diff. Avoid rewriting material simply to make the files look uniform.

## 9. Test behaviour, not vocabulary

Retain the existing 12-case concept-catalogue evaluation where applicable. Do not replace it with a new vague rubric.

Add specific behavioural tests for the doctrine6 failure modes:

- A design is returned as `PROPOSED`; the Manager must not dispatch implementation.
- A consumer reports a fallback; the Manager must transmit it to ScientificLead before the next dependent wave.
- A builder's interface loads, but the consumer prefers a different method for performance reasons; the strategy must be reconsidered.
- The Critic sees a sandbox failure; it must scope the conclusion and avoid unsupported advice to proceed.
- A Lead receives a decision packet; all essential evidence and relevant contradictions must actually be present.
- An Analyst performs computation with staged files without attempting to construct Scout infrastructure.
- Research registers useful evidence without promoting unsupported interpretation into a claim.
- Different input vectors yield the same scalar; the agent must not infer input identity.
- Cortex is not used when ordinary project files suffice.
- An agent reports completion; the stated verification must match what was actually executed.

Test actual tool exposure separately from conceptual correctness. A role that writes "I have ScoutCoder access" but does not receive the required tool has failed the test.

## 10. Validation and rollout

Have an independent Critic review the change ledger, doctrine, role contracts and acceptance results.

Keep the candidate separate from live configuration until the review passes.

Then conduct a new AGS-class mission with v7. Keep the token-accounting methodology comparable to doctrine6. Measure:
- total and role-level inference/token use;
- ScoutCoder investment before and after real consumer evidence;
- interface operations actually consumed;
- fallback and deviation transmission;
- gate compliance;
- handoff completeness;
- scientific-result reproducibility;
- useful epistemic records;
- unnecessary persistence or infrastructure construction.

Treat the doctrine6 counterfactual saving of 28-35% as a bounded estimate, not an expected guaranteed saving. Do not claim success solely because token use fell: compare scientific quality, reproducibility and decision quality as well.

The purpose of v7 is to demonstrate that the system changes direction when evidence warrants it, not merely to produce a cheaper version of the same workflow.

**Do not broaden the implementation scope beyond the evidence-backed changes. Prefer fewer, clearer rules that are actually delivered, understood and followed.**
