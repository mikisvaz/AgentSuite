# Phase 2 — shared instruction layer (AgentSuite redesign)

- **Date:** 2026-11-01 (Phase 2 bout, ~15:30 +0100)
- **Repo:** `/bulk/mvazque2/git/AgentSuite`, branch `ags-redesign`
- **Scope:** shared documents + doctrine additions + bundling script only.
  Frozen upstream: `new_doctrine/work/redesign-role-contracts.md` (§3
  import sets, size caps, C-4 obligation, §8 preconditions).
- **Constraint honored:** no start_chat, society, scout, doctrines/advice,
  or workflow-file edits (task §5). No model turns used; all verification
  hermetic.

## Files changed

| File | Change | Size (before → after) |
|---|---|---|
| `doctrines/collaboration` | new shared doc (7 importers) | — → 1868 B |
| `doctrines/investigation` | new shared doc (6 importers) | — → 2390 B |
| `doctrines/discipline` | new shared doc (3 importers) | — → 1716 B |
| `doctrines/handoff` | new shared doc (7 importers) | — → 2429 B |
| `doctrines/catalogue` | new shared doc (3 importers) | — → 1453 B |
| `doctrine` | new section `## 10. Working across agents` before the footer | 12201 → 13534 B (+1333 B, cap +1536 B) |
| `bin/bundle_doctrine.sh` | **flagged shared-infrastructure edit**: bundle `doctrines/` | 194 → 272 B |
| `new_doctrine/work/change-report-redesign-doctrine.md` | this report | new |

All five new docs parse as a single `system:` message with **no**
directive lines — the requirement that they contribute no tooling held
(see probe). `doctrines/advice` untouched (1622 B), `society` (6954 B)
and `scout` (25060 B) untouched.

## Files deliberately not changed

- `*/start_chat` — Phase 3 adds the import lines (role contracts §3);
  until then no agent imports the new docs, so **all agents are
  unaffected** (compatibility by construction, not by assertion).
- `society`, `scout`, `doctrines/advice` — frozen this phase per task.
- Workflow files, `chats` store, `cortex_path_map.yaml` — out of scope.
- `doctrine_bundle/` — regenerated artifact of the script, not an edit
  target; re-bundled once to prove the script works (see below).

## Content decisions (with contract pointers)

1. **Doctrine additions** map one-to-one onto the six content
   requirements, phrased at contract level with no operational detail:
   need-to-know context; three planning levels (ScientificLead /
   Manager / ScoutCoder) that advise but do not substitute;
   persist-and-reference; compaction placeholders as pointers, never
   evidence; tool success ≠ correctness (cross-referenced to §7
   verification rather than restating it); artifacts as default
   inter-agent handoff. Inserted as `## 10` after §9, before
   `# Appendices` — the footer (advice import, Cortex introduce/tool
   block) is byte-identical to the pre-edit snapshot.
2. **collaboration** carries the work-order packet (objective, current
   state, design, task, output required), one-owner rule, cross-role
   bout discipline, branch summaries, verification gates (gate verifies,
   does not re-execute) — contract level only, per the design's "without
   duplicating the Manager start_chat's operational detail".
3. **investigation** states the loop at contract level: question
   ownership, hypothesis framing (framing owned by the scientific
   direction owner), evidence chains with citations,
   discriminating-experiments-before-breadth, selective curation with
   stated reasons, bounded conclusions with reopening conditions.
   Domain-tooling-free as required.
4. **discipline** covers the four labels, verification status per claim
   (validated / independently reviewed / unverified), no silent
   adoption of unattributed prior work, reopen on new evidence only.
5. **handoff** is the context contract: self-contained packets, durable
   path citations over duplication, work-order format, resume packets,
   and the **C-4 NO_SEARCH_NEEDED paragraph** (below) — relocated here
   from `collaboration` by the Phase 2 Critic gate because Research, the
   named direct Searcher caller, imports handoff but not collaboration.
   It no longer states any mission artifact layout: the Critic found the
   `mission/<name>/` lines had no authority in the frozen contracts, and
   the Manager ruling was strip-and-defer to the AGS route configuration
   (Phase 5), where the layout will be defined with provenance.
6. **catalogue** defines the five-part entry (capability, owner role,
   evidence type produced, typical inputs, limitations), citation of
   entries by name + owner rather than restatement, and the "catalogue
   describes what the society can do, not what any single agent may
   decide" clause.
7. **C-4 paragraph** (exact text, in `doctrines/handoff`, heading
   `## Reply sentinel from discovery roles`; moved verbatim from
   `doctrines/collaboration` §Search sentinel by the Phase 2 Critic
   gate — Research imports handoff, not collaboration, so the paragraph
   must live where every Searcher consumer reads it; not duplicated in
   both):

   > A search brief may return exactly NO_SEARCH_NEEDED: no targeted
   > search was required for this request. That is a valid completion —
   > not an error, not a failure, and not an empty result. Callers
   > consume it as-is: do not re-dispatch the same request to the
   > searcher or another discovery role on the strength of the sentinel
   > alone. The staged pipeline's search stage is one consumer of this
   > rule; every direct caller is bound by it the same way.

8. **Bundle script** (`bin/bundle_doctrine.sh`) — the flagged
   shared-infrastructure edit, minimal and backward-compatible:

   ```diff
    cp doctrine scout society  doctrine_bundle/
   +mkdir -p doctrine_bundle/doctrines
   +cp doctrines/*  doctrine_bundle/doctrines/
    for a in *; do cp $a/start_chat doctrine_bundle/$a.start_chat; done
   ```

   It bundles every extension-less file under `doctrines/` (all six,
   including the pre-existing `advice`) into
   `doctrine_bundle/doctrines/`. Behavior for existing outputs is
   unchanged; the script's pre-existing noise (cp errors for
   non-agent top-level dirs from the `for a in *` loops) is unchanged
   and was not "fixed" — out of scope for a minimal edit.

## Verified configuration (probe evidence)

Production Chat pipeline (`Chat.parse` → `Chat.imports`) over a staged
`Agent/` mirror in `tmp/redesign-probes/chats_phase2` (the repo's
`chats` symlink target is not visible from this sandbox — technique
established by the packet-B chain probe). Evidence paths:

- Probe script + output: `tmp/redesign-probes/redesign_doctrine_probe.rb`,
  `tmp/redesign-probes/redesign_doctrine_probe.out` (JSON).
- Direct-parse role check: `tmp/redesign-probes/direct_parse_roles.txt`.
- Pre/post doctrine role tallies:
  `tmp/redesign-probes/doctrine_pre_post_roles.txt`.
- Pre-edit snapshots: `tmp/redesign-probes/doctrine.pre-edit`,
  `doctrines/footer.pre.txt` / `footer.post.txt` (byte-identical).
- Bundle script pre-edit copy + diff:
  `tmp/redesign-probes/bundle_doctrine.sh.pre`, diff in §Content
   decisions item 8.

## Verification

1. **Imports resolve, no directive leakage** (each new doc):
   `import: Agent/doctrines/<name>` resolves with 0 leftover
   `import:` messages; 0 directive-role messages (tool/introduce/kb/mcp/
   option/continue/last/endpoint/model/attachments/persist/socialize/
   exec_task); 0 directive-looking lines at line starts inside bodies;
   own `system:` marker and the doc's heading both present. **All five
   pass.**
2. **Direct parse** of each new doc standalone: exactly one `system:`
   message, no other roles. **All five pass.** One defect was found and
   fixed during verification: a colon construction in `discipline`
   (`investigation: an investigation says...`) parsed as an
   `investigation:` directive message; reworded to an em-dash, re-probed
   clean (`tmp/redesign-probes/discipline_messages.txt` records the
   anomaly before the fix).
3. **Doctrine**: parses through the same pipeline (8 messages), body and
   advice chain present (`Classify and scale`, `Advice appendix`), the
   footer's directives reach the message list in identical shape
   pre/post (`introduce: Cortex` + three `tool: Cortex …` lines),
   footer byte-identical (`cmp` on pre/post appendix slices). **Pass.**
4. **Sizes**: each new doc ≤ 5120 B (max 2390 B, `investigation`);
   doctrine growth +1333 B ≤ 1536 B cap. After the Phase 2 Critic
   repairs: collaboration 1868 B, handoff 2429 B (all docs still under
   cap). **Pass.**
5. **Research projected four-doc payload** (collaboration excluded —
   Research does not import it): start_chat 13035 + doctrine 13534 +
   society 6954 + investigation 2390 + discipline 1716 + handoff 2429 +
   catalogue 1453 = **41 511 B ≈ 40.5 KB**. This exceeds the ~35 KB
   target stated in the brief (which modeled a ~20.8 KB Research
   payload). Note the brief's arithmetic carried the pre-growth
   doctrine; the new-doc addition itself (7736 B) is within the "roughly
   5 KB each" cap. The residual overshoot is ~5 KB and is a Phase 3
   question — Research's start_chat is a Phase 3 edit target, and the
   overshoot is reported here rather than silently absorbed by shrinking
   content below its contract requirements.
6. **Bundle script**: `bash bin/bundle_doctrine.sh` runs; all six
   extension-less `doctrines/` files land in
   `doctrine_bundle/doctrines/` byte-identical to source (`cmp`
   verified for `collaboration`). **Pass.**

## Phase 2 Critic gate — repairs applied (post-bout)

The Phase 2 gate returned NEEDS_WORK with two findings; both repairs
were applied minimally in a follow-up bout and re-verified with the same
hermetic probe (no model turns).

1. **Sentinel relocation (C-4).** The Critic found the sentinel
   paragraph in `doctrines/collaboration`, but Research — the named
   direct caller of Searcher — does not import collaboration. The
   paragraph moved **verbatim** (heading changed from `## Search
   sentinel` to `## Reply sentinel from discovery roles`, body text
   unchanged; `diff` of the bodies confirms byte equality) into
   `doctrines/handoff` §Reply sentinel, adjacent to the resume-packet
   and work-order content, where the importer set covers both Planned's
   search stage consumers and Research. Not duplicated into both docs:
   `NO_SEARCH_NEEDED` now occurs in exactly one shared doc
   (`doctrines/handoff`, `grep -c` = 1). Sizes after move:
   collaboration 2333 → 1868 B, handoff 2177 → 2429 B.
2. **AGS layout strip-and-defer.** The Critic found the
   `mission/<name>/` layout lines had no authority in the frozen
   contracts or the audits. Manager ruling: the lines originated from
   the redesign plan's Phase 4/7 intent but were never ratified — strip
   and defer to Phase 5 (route configuration), where the layout will be
   defined with provenance. `doctrines/handoff` now carries only the
   one-line pointer: "The layout for mission-scoped Cortex artifacts is
   defined by the AGS route configuration (Phase 5); this contract
   states only that mission artifacts are cited by their durable path."
   No layout details remain.
3. **Re-verification.** Full hermetic probe re-run:
   `tmp/redesign-probes/redesign_doctrine_probe.out` — all five docs
   still resolve (2 messages: doc `system:` + probe prompt), 0 leftover
   imports, 0 directive messages, 0 body directive lines, own marker
   and heading reached; doctrine still parses (8 messages), footer
   byte-identical, growth +1333 B unchanged. Standalone parse:
   collaboration and handoff are each exactly one `system:` message
   (`tmp/redesign-probes/phase2b_parse.txt`). Bundle re-run:
   `doctrine_bundle/doctrines/` byte-matches both edited docs (`cmp`).
   Updated four-doc Research projection: 41 511 B ≈ 40.5 KB (still
   over the ~35 KB aim; unchanged Phase 3 question).

## Compatibility

No agent imports any new doc today: start_chats are untouched, so every
role's effective context is bit-identical to pre-Phase 2 (verified
against the packet-C effective-tools matrix inputs). The doctrine edit
adds one section to every agent's context (+1333 B) — that is the only
globally visible change, and it contains no directives. Phase 3 turns
the docs on by adding `import: Agent/doctrines/<name>` lines per role
contracts §3.

## Next work (Phase 3)

- Add import lines per role contracts §3 (collaboration → Manager,
  Planner, User, Critic, Worker, Investigator, ScientificLead;
  investigation → Research, Searcher, Reader, Critic, ScientificLead,
  Investigator, not Manager; discipline → Research, Critic,
  ScientificLead; handoff → Manager, Planner, User, Worker,
  Investigator, ScientificLead, Research; catalogue → Research, Reader,
  Consultant).
- Open item for Phase 5: define the mission artifact layout in the AGS
  route configuration, with provenance back to the redesign plan (the
  stripped `mission/<name>/` lines of this bout are its raw material;
  see `tmp/redesign-probes/handoff.pre-phase2b` snapshot).
- Open item for Phase 3 sizing: Research's projected shared payload is
  ~40 KB, above the ~35 KB aim; resolve by trimming Research's
  start_chat during its Phase 3 edit or by re-deriving the target from
  the role contract, and record the decision.
- Runtime check #1 (host chat-store sync path for the bundle) remains
  unverified from this sandbox, as in packet B; it must be closed
  outside the sandbox when the bundle is next published.
