# Change report: Reader/Research split (round close-out)

Date: 2026-10-25 (23:24 CET). Executor: Worker. Working tree only; no
commits, tags, or pushes (owner commits). This report consolidates the
round; the receipts carry the detail and are cited by path and heading.

## 1. Summary

The round moved the document/PDF/web reading, conversion, and retrieval
tooling out of Research into a new Reader agent + workflow, so that
Research could be the suite's scientific-interpretation agent (durable
scientific record via Path kinds, the Semantics interface, and
domain tooling) while Reader owns source acquisition. The move was
implemented (11 tasks relocated, Research stripped to its scientific core),
every adjacent routing surface was brought in line (society, ./scout,
Manager/Worker/Searcher/Research/Reader start_chats), and this close-out
validated the tree for dangling references and consolidated the evidence.

## 2. Deliverables map

| Deliverable | File | Receipt |
|---|---|---|
| Git baseline, task inventory, environment facts | `new_doctrine/work/preflight-reader-split.md` (§1 baseline, §4 inventory) | itself |
| Reader/Research/Searcher start_chat edits + parse profiles + tool resolution | `new_doctrine/work/startchat-receipts-reader-split.md` (§1 Files written, §2 Chat-parse probe, §3 Tool-line Resolution, §4 Grep for moved task names, §5 Deviations) | itself |
| ./scout vocabulary entries, Manager/Worker start_chat fixes, ./doctrine no-edit rationale | same file (§6 Doctrine-layer receipts; 6.1–6.9) | itself |
| Society roster update + sanity checks | Cortex artifact `work/society-receipt-reader-split.md` | itself |
| Reader agent + workflow (new tree) | `Reader/` (untracked; owner commits) | §3 Tool-line Resolution of the start-chat receipts (Reader loads with all 11 tasks) |
| Research stripped to scientific core | `Research/` tracked changes | §3 of the same receipts (Research loads, 0 tasks) + `Research/test/Research/tasks/test_registration.rb` (moved tasks absent, Path kinds present, Workspace helpers merged) |
| This report + Cortex mirror | `new_doctrine/work/change-report-reader-split.md`; Cortex artifact `work/change-report-reader-split.md` | itself |

## 3. Tool move inventory (11 tasks)

`searxng` (from `tasks/web.rb`), and from `tasks/documents.rb`:
`docx2md`, `pdf2md_full`, `pdf2md_no_images`, `pdf2md`, `html2md`,
`excerpts`, `rag`, `query`, `pdf_query`, `html_query`.

Move confirmed by, in order of authority:
- `Reader/test/Reader/tasks/test_registration.rb` — asserts all 11 names
  are registered on `Reader` (plus aliases `pdf2md`, `pdf_query`,
  `html_query`) and runs `excerpts` locally.
- `Research/test/Research/tasks/test_registration.rb` — asserts none of
  the 11 is registered on `Research`, that `Research::PATH_KINDS` still
  defines observation/claim/hypothesis, and that the Workspace helpers
  (`cmd_json`) stay merged.
- Fresh-process resolution recorded in start-chat receipts §3 (symlinked
  `tmp/wfcheck/workflows/` scratch method): `Reader: loaded, 11 tasks`;
  `Research: loaded, 0 tasks`.

Known execution caveat (recorded, environment-level, not a code defect):
the registration tests must run in an environment that can resolve the
Workspace workflow. From the Research checkout root, plain
`ruby -Itest test/Research/tasks/test_registration.rb` fails at load time
with `Workflow Workspace not found` (workflows are not installed at the
suite root); the receipts' symlinked scratch method is the working shape.
This is the same environment fact as Research README's testing note.

## 4. Doctrine-layer placement rationale

- **Routing → `./society`** (owner-edited in step 4; receipt
  `work/society-receipt-reader-split.md`). The routing block now reads,
  verbatim: "- Source documents to read, convert, or extract: Reader." and
  "- Scientific investigation and evidence-grounded interpretation:
  Research.", with the Worker line recast as "Concrete task execution on
  that tooling: Worker." The Research entry encodes the owner's sentence:
  conducts research leveraging the scientific Path kinds, the Semantics
  interface, and domain-specific tooling, with Workspace tooling when
  necessary; registers observations, assesses claims, challenges
  hypotheses, produces traceable syntheses.
- **Vocabulary → `./scout`** (start-chat receipts §6.1). Two compact
  entries, each heading + one paragraph, added at the end of "## 7.
  Working knowledge and scientific reasoning": `### Source acquisition`
  (Reader's work; citable dossiers as Cortex artifacts; feeds Research,
  does not replace it) and `### Scientific investigation` (Research's
  work through the Semantics interface, the scientific Path kinds
  Observation/Claim/Hypothesis, and domain tooling, with Workspace when
  necessary; traceable syntheses citing result addresses). Placement
  rationale: section 7 is where the vocabulary names the scientific work
  layers, and the split divides exactly that work. No standalone
  Semantics entry — the Scout vocabulary routes work, it is not an API
  reference (decision made upstream, recorded in §6.1).
- **`./doctrine`: NO EDIT** (§6.2). The owner's sentence is routing plus
  vocabulary; routing already lives in society, vocabulary in ./scout, and
  the doctrine's generic rule "Prefer the specific tool over the general
  one" already covers the behavior. Doctrine is the generic kernel read
  by every agent including tool-less ones and deliberately carries no
  agent names. The flagged-contradiction case was checked with a targeted
  grep and did not fire.
- **`./doctrines/advice`: frozen, untouched.** Its header forbids
  additions; no tool read or wrote it in this round.

## 5. Consistency fixes (Manager/Worker start_chat)

- `Manager/start_chat` routing list: "- Research execution on that
  infrastructure: Worker." → "- Concrete task execution on that tooling:
  Worker." plus two new society-consistent lines (Reader for source
  documents to read/convert/extract; Research for scientific
  investigation and evidence-grounded interpretation). Minimal diff
  (1 line removed, 3 added).
- `Worker/start_chat` opening: "the suite's research executor: … concrete
  steps of a scientific investigation …" → "the suite's execution agent:
  … concrete tasks on the infrastructure ScoutCoder builds … any concrete
  task not explicitly another agent's responsibility", matching society's
  Worker entry. One paragraph changed, nothing else.
- Post-edit fresh-process `Chat.parse` profiles (receipts §6.5): both
  files 6 messages, identical pre/post role sets, stray-role scan clean.
- Sweeps for moved-tool names and wrong routing in both files: clean.

## 6. Sweep results (this bout)

Receipts-file integrity (checked before the sweep, per instruction):
heading scan shows `# Start-chat receipts…` + `## 1.`–`## 6.` with
subsections 6.1–6.9, 395 lines, no other top-level heading; spot rereads
of head, section-5 tail, and file tail match the recorded content.
**Verdict: intact.** The §6.9 incident is closed — restoration verified
independently by this bout.

Per-tool hit counts outside the excluded trees (Reader/, test files
covering the moved tasks, new_doctrine/work/, var/, tmp/, Claude/, .git,
.vimproject, ScoutCoder submodule, and additionally .save/ and
ComputerUse/, both of which are pre-existing copies of the same task
implementations — see acceptable mentions):

| tool | live-tree hits |
|---|---|
| searxng | 3 (Research/README.md, Research test_registration.rb, Searcher/start_chat) |
| docx2md | 1 (test_registration.rb) |
| pdf2md_full | 1 (test_registration.rb) |
| pdf2md_no_images | 1 (test_registration.rb) |
| pdf2md | 1 (test_registration.rb) |
| html2md | 2 (test_registration.rb, Searcher/start_chat) |
| excerpts | 2 (Research/README.md, test_registration.rb) |
| rag | 1 (test_registration.rb) |
| query | test_registration.rb + benign generic-word hits |
| pdf_query | 1 (test_registration.rb) |
| html_query | 1 (test_registration.rb) |

Acceptable mentions, each with location and reason:
1. `Research/test/Reader/tasks/…`-side: `Research/test/Research/tasks/test_registration.rb`
   — the negative registration test asserting the 11 tasks are NOT on
   Research. Excluded by design.
2. `Research/README.md:9` — the "See also" pointer naming `searxng`,
   document conversion, excerpting and RAG retrieval as "formerly
   Research's tasks" now living in Reader. Correct post-split
   documentation, not a dangling reference.
3. `Searcher/start_chat:46-47` — `tool: Reader searxng` /
   `tool: Reader html2md`, the repointed tool lines. Reader-prefixed, so
   they route correctly; verified resolving in receipts §3.
4. `.save/bundle/`, `.save/Read/` — editor stash of pre-edit Research
   README/lib/test files. Git-ignored (`git check-ignore .save` → IGNORED),
   not part of the tracked tree; the historical Research README snapshot
   in it is the same file D5 of the previous round asked to delete.
5. `ComputerUse/` — the upstream workflow that still legitimately owns
   identical `web.rb`/`documents.rb` tasks (the files Research's were
   derived from). Different workflow, different namespace; not a
   dangling reference.
6. `research/agentsuite-cortex-rollout/01-preflight-report.md` —
   historical investigation report listing an old effective tool table.
   Frozen research record.
7. `Cortex/research/notes-tools.md` — investigation note quoting an error
   string that happens to contain `searxng` inside `/etc/passwd`-like
   noise. Frozen research record.
8. `Manager/start_chat:11`, `./scout:161`, Semantics/, Workspace/ hits
   for `query` — the common English word in unrelated contexts
   ("any provided query", "query or lookup interface", entity-query
   tasks). Not the moved RAG task.

Handoff-phrase sweep (documents routed to Research for reading, Research
offering document tools): only the four correct post-split locations
matched — `./scout:333` (the new Source acquisition entry itself),
`society:23` (routing line), `society:43`/`society:101` ("Not for…"
boundary clauses), `Manager/start_chat:39` (routing line). A
`Research <tool>`-prefixed reference sweep across the live tree: none.
The pre-split README text "it does not depend on or inherit Workspace"
survives only inside `Research/var/jobs/…` chat transcripts (excluded
tree — job history) and `.save/` (ignored stash); the live README's
corresponding line now states the opposite, correctly.

**Fixes applied: none.** Every live hit is either a correct post-split
mention, a deliberate negative test, or an excluded/ignored copy. No live
documentation or start_chat text contradicts implemented reality.

Scope check (exact `git status --short`, see §8 for pre-existing):
changed set == {society, scout (pre-existing +4 plus this round's 2
entries), doctrine (pre-existing only, +17/−7), Manager/start_chat,
Worker/start_chat, Searcher/start_chat, Research/* (README.md, start_chat,
workflow.rb, lib/tasks deletions, path_kinds/records.rb, tests, research
notes, .vimproject), Reader/* (untracked, new), new_doctrine/work/*
receipts (untracked)}, plus pre-existing `.vimproject`, ScoutCoder
submodule modified content, and untracked `Claude/`. Matches the expected
set; nothing extra, nothing missing.

Baseline movement: the preflight baseline was HEAD 912766a; mid-round the owner authored 980d809 (already equal to origin/main) from the concurrent return-path line — all round deliverables remain uncommitted working-tree changes stacking cleanly on 980d809, so no agent commit occurred (receipts §6.6).

## 7. Known deviations and incidents

1. **Missing method file.** `new_doctrine/work/startchat-validation.md`
   does not exist in the tree (verified this bout too). The start-chat
   parse method was taken from section 2 of the receipts file instead —
   same fresh-process `Chat.parse` probe with role counts and stray
   `^[a-z_]+:` scan. Recorded in §6.5 of the receipts.
2. **Receipts-file append incident.** The first attempt to append section
   6 used a whole-file `write` and briefly replaced sections 1–5; they
   were restored verbatim from the same read that established the append
   anchor and verified by heading scan + targeted rereads. Recorded in
   §6.9; integrity independently re-verified by this close-out bout.
3. **D3 open item — stated explicitly as NOT fixed.** Research/README.md
   previously claimed (L3 at the pre-split baseline) that Research "does
   not depend on or inherit Workspace", contradicting
   `Research/workflow.rb:4` (`Workflow.require_workflow 'Workspace'`) and
   the helpers merge. The split rewrote that line to the correct
   statement (README now says Reader and Research both require Workspace
   and merge its helpers), and the README's testing section documents the
   load-time environment failure mode. So the original D3 text is gone
   from the live README; what remains open under D3 is the environment
   fact itself — the registration tests still cannot run from the
   Research checkout root because Workspace is not resolvable there
   (reproduced this bout: `Workflow Workspace not found` at load, even
   with `-I../Workspace`). It was left flagged, not fixed: the fix is an
   install/path-map decision for the owner, not an agent edit.
4. **Round-close environment note.** Workflows are not installed at the
   suite root; every fresh-process workflow check in this round used the
   symlinked `tmp/wfcheck/workflows/` scratch method (receipts §3). No
   workflow `.rb` file changed in the close-out, so no re-check was
   needed here.
5. **Stale conversation claim** in the Cortex submodule store
   (`reader-split-preflight-probe`), blocking only that throwaway name —
   preflight §2; left in place, no direct store edits.

## 8. Pre-existing unattributed changes preserved (all confirmed intact this bout)

- `doctrine` +17/−7 — task-contract reading rule, scratch-note pinning,
  failed-call discipline, plan-per-bout rule. Byte-identical to the
  preflight description; not edited in this round.
- `scout` +4 — "### Workflow input inheritance" section. Verified
  verbatim under this round's diff (total `git diff --stat scout` = +12 =
  4 pre-existing + 8 this round).
- `.vimproject` — project-tree bookkeeping (untouched).
- ScoutCoder submodule — modified content only (README/start_chat/
  .vimproject), clean HEAD (untouched).
- `Claude/` — untracked workflow dir (untouched).

## 9. Resume pointers

1. **D3 environment fix (owner decision).** Make `Workspace` resolvable
   for Research's and Reader's registration tests (install entry,
   `SCOUT_WORKFLOW_AUTOINSTALL`, or a path-map entry), or accept the
   scratch-dir method as the documented way to run them. Once resolvable,
   re-run `Reader/test/Reader/tasks/test_registration.rb` and
   `Research/test/Research/tasks/test_registration.rb` from the suite
   root as the round's final green check.
2. **Owner commit of the round.** The changed set in §6/§8 is the round's
   commit candidate, including the untracked `Reader/` tree,
   `new_doctrine/`, and the four new Research path-kinds test files.
3. **D5 carry-over.** The `.save/` stash (pre-edit Research README/lib
   snapshot) is the same material the previous round's D5 asked to
   delete; still present, git-ignored, harmless but stale.
4. **Society entry for Claude/** — the untracked `Claude/` workflow has
   no society entry and no start_chat/README; if it is meant to be a
   suite member, roster it (out of scope here).
5. **Cortex submodule store hygiene** — the stale claim in §7.5 expires
   or is dropped by an owner action; agents cannot clear it directly.

## 10. Cortex mirror

This report is mirrored to the Cortex artifact
`work/change-report-reader-split.md` via the `cortex_write` tool (channel
available on this agent's tool surface). Read-back confirmation and the
receipt are recorded in the close-out summary turn of this bout; the
artifact name is `work/change-report-reader-split.md` in the suite-root
Cortex store.
