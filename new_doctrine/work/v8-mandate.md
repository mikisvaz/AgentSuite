## Restated request

Implement the proposed scientific-agent design as AgentSuite doctrine version 8 (v8), from the draft package the user has staged at tmp/chat/scout_scientific_agent_design (relative to the AgentSuite checkout).

The draft package contains: a shared Scientific Investigation Doctrine (Agent/investigation), start_chat files for eight roles (Manager, ScientificLead, Research, Analyst, Reader, ScoutCoder, Critic, ChatAnalyst), role_capability_matrix.md, and mission_template.md. The design it encodes (already accepted by the user in discussion):

1. Research is the scientific centre: owns the investigation, semantic-domain reasoning, and the evidence record.
2. Analyst is a genuine Scout-agnostic computational alternative (general tools over staged data; no Scout framework surface).
3. Reader separates document/source acquisition from scientific interpretation.
4. ScoutCoder is demand-driven infrastructure (provisioning + consolidation only on demonstrated need; no speculative build waves).
5. Semantic and epistemic interfaces are explicit operational requirements, with a pre-mission preflight: Research must be able to evaluate entity properties through Semantics and register/retrieve/update records through the actual epistemic API before a substantial investigation starts.
6. Investigator, Planner and Searcher are no longer permanent central roles of the scientific route.

Two implementation tasks beyond copying files:

- Review and correct the wiring of the draft files. The drafts were written against remembered tool surfaces and are known-unverified in exactly these places: Research/Semantics/Reader tool declarations, Manager delegation-tool syntax, and path_kind: ScoutCoder declarations. Every tool:, import:, introduce: and path_kind: line must be reconciled against the mechanisms that actually work in this AgentSuite checkout (the v7-era wiring and hermetic probe method are the reference). Do not invent tool names; use what exists, and record any intended-but-missing tool as a gap.
- Quick integration, minimal checks. Do not run a full validation mission. The acceptance set is: the three integration checks from the proposal, plus a hermetic delivery matrix. The user wants to submit a new use case immediately after this work, so every additional check must justify itself; anything optional must be labeled optional.

## Deliverables requested

1. Branch doctrine-v8 cut from the correct baseline, with the eight roles + shared investigation doctrine implemented from the drafts, wiring corrected.
2. A wiring review report: each draft file, what was wrong/unverifiable, what was corrected, what was recorded as a gap (no invented tooling).
3. Updated society roster and any import/bundle regeneration (doctrine_bundle/), consistent with the role changes.
4. Disposition of Investigator, Planner, Searcher per the agreed default, recorded explicitly.
5. The three integration checks, executed and reported:
   a. Research evaluates a known entity property through the actual Semantics surface.
   b. Research registers, retrieves and updates one disposable record through the actual epistemic API (clean up after; or clearly mark as disposable).
   c. Analyst completes a known computation using only a staged package and general-purpose tools, with no Scout framework access attempted.
6. Hermetic delivery matrix (actual parsed fresh-agent contexts, not declarations) for all changed roles: PASS/FAIL per role.
7. A short v8 work-file set under new_doctrine/work/v8-*.md: mandate/pin, wiring corrections, integration-check results, matrix, migration note (old to new per role), and a one-page ready-to-launch statement listing exactly what (if anything) the user must still do before submitting the new use case.
8. At most a small number of one-step behavioral spot checks, only where wiring or role contracts changed materially. Sparing use of FitAgent; no full evaluation suite rerun.

## Success criteria

- Branch doctrine-v8 exists with the eight roles and shared investigation doctrine implemented, wiring-corrected; nothing merged.
- Every incorrect/unverifiable declaration in the drafts is either corrected against a verified mechanism or recorded as a named gap; zero invented tool names.
- The three integration checks each produce an explicit PASS or a documented blocker with evidence; a failed epistemic-API check is reported as a gap, not papered over.
- Hermetic delivery matrix: all changed roles PASS (or documented FAIL with cause).
- new_doctrine/work/v8-*.md set complete, including the one-page ready-to-launch statement enumerating any remaining user actions.
- The user can submit the new use case immediately after reading the ready-to-launch statement.
