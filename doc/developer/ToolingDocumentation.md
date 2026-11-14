# Tooling documentation convention (AgentSuite)

**Status:** convention, self-hosted (this file lives in the layout it defines).
**Audience:** agents and contributors restructuring the AgentSuite workflow
READMEs (plan steps 4/6) and authoring skills (step 7), plus future
maintainers of those documents.
**Authority:** Manager rulings 1–8 (decision owner: Manager, execution
coordination) recorded in the [decisions log](#decisions-log) below, over the
parser contract pinned in `doc_redesign/contract.md` (code-cited,
live-probed), the Reader step-2 dispositions (`doc_redesign/*.dossier.md`,
`doc_redesign/source_map.tsv`, 140 rows), and the scout-gear audience split
(`scout-gear/doc/developer/WritingDocumentation.md`).
**Change rule:** this convention governs until a new ruling changes it; record
any later change as a new numbered decision.

## 1. What is machine-consumed versus free (pinned facts)

The Scout parser (scout-gear `lib/scout/workflow/documentation.rb`,
`parse_workflow_doc` L30-39; full grammar in `doc_redesign/contract.md` §2)
reads exactly three things from a workflow's `README.md` (or `workflow.md`
when present — none in scope has one):

| README region | Machine rule | Who else reads it |
|---|---|---|
| First line up to the first blank line | becomes the **title** in the introduced header (`# Documentation for the 'W' workflow: <title>`) | humans |
| Everything after that blank line up to the first `/^# Tasks/i` line | becomes the **description** injected verbatim as one user message on `introduce:` (today up to ~8 KB per workflow) | humans |
| The `# Tasks` section: each `## <name>` heading plus its chunk | each entry is assigned to the Task object's description (`documentation.rb` L64-82) — **the per-task text agents see on `tool:` exposure** (after `documentation` has run in the process) | humans |

Everything else in the file — sections after `# Tasks`, any file outside the
README — is **free**: no machinery parses it. Consequences that shape every
rule below:

- The description is an **agent-context budget item**, not a document: every
  line placed above `# Tasks` costs tokens in every introduction of that
  workflow.
- Task entries are the **only per-task documentation that can change what an
  agent sees** without touching code; they must stay aligned with in-code
  `desc`s (rules 4–5).
- Sections after the task section are invisible to agents but visible to
  humans; they are the escape hatch for developer-facing material that must
  stay near the README.

## 2. README content rules

### 2.1 Structure (decision 1)

Every restructured workflow README has exactly this shape:

```markdown
<Plain-text title line>

<Lean agent-facing description — one or a few short paragraphs; see 2.3>

# Tasks

## <task_name>
<one-line description>

<optional body paragraphs: usage, inputs, outputs, caveats>

## <task_name>
…

<Developer-facing sections, strictly AFTER the tasks section>
```

Rules:

- **Plain-text title line** (decision 3): the first line must not begin with
  `# `. The parser takes that line verbatim as the introduced title, so a
  markdown `# ` prefix surfaces literally in agent context
  (`# Documentation for the 'Semantics' workflow: # Semantics`). Write
  `Semantics`, not `# Semantics`. (Dropping the prefix changes an
  agent-visible string; itemize it in the report — decision 3.)
- **`# Tasks` on its own line, exactly once** (`# Tasks` in that spelling and
  case — see the `document_task` divergence below). Everything after it is
  parsed for entries. No second `# Tasks` heading anywhere in the file.
- **Developer-facing content goes after the tasks section** or — preferred —
  into `<Workflow>/doc/developer/` with a one-line pointer in the README.
  Nothing developer-facing may sit above `# Tasks`: it would be injected into
  every introduction (decision 1, from contract.md §2: the parser consumes
  everything up to `# Tasks` as the description).
- Material before `# Tasks` is limited to the title line and the lean
  description. Pointers (see-also links, doc/user references) may follow the
  description paragraphs; keep them short — they, too, enter the
  introduction.

### 2.2 Title rule

Title = first line of the file, up to the first blank line. Therefore:

- One short line, plain text, no `# ` prefix (decision 3).
- A blank line must follow it, and nothing else may precede the blank line —
  the title is everything up to that blank line, so a two-line "title" leaks
  line 2 into the introduced title (ChatAnalyst's baseline defect).
- The workflow's module name is what names the workflow in the introduced
  header and in tool naming; the title line is prose, not an identifier.

### 2.3 Description rules (decision 2)

The description block (between the blank line after the title and `# Tasks`)
is what every `introduce:` of the workflow injects into agent context.
Shrinkage is intended: **what enters agent context should be small.**

- **Capability-complete, detail-lean.** The condensed description must state
  every capability of the workflow — what it is and when to use it — in a few
  short paragraphs. It is a routing card, not a manual.
- **Preserve every capability statement** (what it is, when to use it) from
  the baseline description. Relocated detail — dependencies, environment,
  internals, long examples, output-format notes, testing — lands in
  `<Workflow>/doc/user/` or `doc/developer/` per the dossier dispositions.
  This is the reconciliation of the step-1 acceptance check "description
  equivalent in meaning to baseline": meaning-preserving at the capability
  level, with detail relocated rather than deleted.
- **No code blocks above `# Tasks`** beyond, at most, one tiny example if it
  is itself a capability statement (e.g. "CLI: `scout workflow task W t`");
  prefer prose.
- **Verifiable claims only.** Any factual claim in the description must hold
  against the current checkout (task lists, registration, exports). Where the
  dossier marked a claim stale, apply its `correct-to:` disposition — never
  carry a stale claim into the rewritten description.

### 2.4 Task-entry grammar (from contract.md §2)

- Entry heading: `## <task_name>` — exactly two `#`, one space, the
  registered task name. `task_name` must be the Ruby symbol name of a
  **registered task** (e.g. `read`, `tsv_read`).
- One-line description immediately after the heading, then optional body
  paragraphs.
- **No `## ` headings inside an entry body** — the next line matching `## `
  (two hashes, one space) ends the entry. Note the asymmetry: only `## `
  splits entries; a `##nospace` or `### ` line inside a body is *absorbed
  verbatim into the entry text* (probed, contract.md §2), so while `###`
  subheadings are safe from splitting, they still pollute the per-task text
  agents see — avoid them in entries; use bold text or lists instead. Also:
  any `/^##/` line (including `###`) appearing *before the first entry
  heading* terminates the pre-entry prose capture, so keep the region between
  `# Tasks` and the first `## <task>` free of `##`-prefixed lines entirely.
- **Never leave a trailing entry with no body** (an entry heading at the very
  end of the section with nothing after it is silently dropped by the odd-
  chunk rule) and **never an entry with an empty description** (deleted).
- Entry names may be `W#task` to document another workflow's task; use only
  when deliberate and rare.
- Non-task prose must never use a `##` heading inside `# Tasks` (decision 4 —
  phantom entries): a heading that matches no registered task is silently
  ignored by the parser but would bind to any future task of that name.
  Convert such prose to bold text, a list, or move it out of the section.

### 2.5 Alignment with in-code `desc` (decisions 4–5)

- **Invariant for pre/post comparison: for every REGISTERED task, its applied
  description is unchanged** unless an explicit, itemized change is made.
  This is the safety check for every restructure (see Migration, step 5).
- Where a README entry and the in-code `desc` of the same task differ, **align
  the README entry to the in-code desc** — the in-code text is what surfaces
  today (tool-only exposure in a fresh process shows the `desc`, per
  contract.md §2.6; aligning to it is the conservative direction). Itemize
  every alignment in the report.
- This pass fixes **mechanical defects only** (decision 5): ComputerUse's
  doubled `# Tasks` heading (0 entries parsed) and ChatAnalyst's
  prose-heading phantoms get corrected so parsing works; **no new per-task
  entries are authored this pass** (ComputerUse's 36, ChatAnalyst's 25 stay
  desc-only). Gaps in per-task coverage — Workspace's `tsv_*` family: one
  entry for 8 tasks — are flagged in the report as open decisions, not filled
  now.
- Phantom-entry removal is allowed and must be itemized (decision 4).

## 3. Roles of doc/developer/ and doc/user/

Anchored on scout-gear `doc/developer/WritingDocumentation.md` (audience
split) and self-hosted in this layout (`doc/developer/` singular — decision 7):

| Area | Audience | Content | Normative? |
|---|---|---|---|
| `<Workflow>/README.md` | agents (machine) + humans | Title, lean description, task entries, post-tasks dev sections / pointers | Yes (machine contract) |
| `<Workflow>/doc/user/` | agents/people **using** the workflow | Task-oriented how-to: usage patterns, examples, options, common mistakes, the detail moved out of README descriptions | Yes (normative guidance) |
| `<Workflow>/doc/developer/` | agents/contributors **changing** the workflow | Implementation, architecture, layout, testing internals, extension points, environment/dependency notes | Yes (implementation truth) |
| `<Workflow>/research/` | future investigations | Non-normative evidence, probes, bout records | No |
| `doc/developer/` (repo root) | all workflow maintainers | Repo-wide conventions (this file) | Yes |
| `skills/` (repo root) | agent skill discovery | SKILL.md directories (step 7) | Yes (format rules) |

- `doc/user` files answer *how do I use this*; `doc/developer` files answer
  *how does this work / how do I change it*. The dossier dispositions
  (`doc_redesign/source_map.tsv` destinations) are the per-block assignment
  — apply them as written; the `correct-to:` notes carry the required
  factual fixes.
- Developer content that must stay discoverable from the README goes **after
  the tasks section** (never above `# Tasks`), kept brief, as a pointer into
  `doc/developer/`.
- The repo-wide "every Scout project adopts doc/developer + doc/user"
  convention is **documented here for later adoption, not applied now**
  (decision 6). The restructured set this pass: the 9 tooling workflows
  (ChatAnalyst, ComputerUse, Cortex, Planned, Reader, Research, ScoutCoder,
  Semantics, Workspace). FitAgent and Decider (persona/orchestration) are out
  of restructuring scope; Visualizer (workflow.rb, no README) is a recorded
  gap. All three are report follow-ups.

## 4. Skills format (repo root `skills/`, decision 7)

One directory per skill at the repo root, Agent Skills spec
(agentskills.io) format only — **no loader, no tooling** in this pass.

- `skills/<skill-name>/SKILL.md` is the only required file. Optional
  `scripts/`, `references/`, `assets/` subdirectories may hold supporting
  material.
- **Frontmatter:** `name` — 1–64 chars, lowercase alphanumeric plus hyphens,
  must match the directory name; `description` — ≤1024 chars, states **what**
  the skill does **and when** to use it, and includes trigger keywords
  (progressive-disclosure level 1).
- **Body:** recommended <500 lines; progressively disclose: the frontmatter
  description decides *whether* to load, the body teaches *how* to act
  (level 2), and `references/` files carry exhaustive detail read on demand
  (level 3).
- **Self-sufficiency + pointer policy (decision 8):** every SKILL.md body
  must be **self-sufficient for the what/when decision** — because
  `<Workflow>/doc/user` files will often be unreachable from agent sandboxes,
  the skill cannot rely on them for its own discoverability or trigger
  decision. Pointers into `<Workflow>/doc/user/` (and elsewhere) are
  **enhancements**, expressed as **repo-relative paths**
  (e.g. `Workspace/doc/user/TSV.md`), never as absolute paths, and never as
  the sole carrier of information the skill needs at load time.
- Skills follow this convention's correction rules (§6) like any other
  documentation.

## 5. Pointer / reference policies

- **Reference, do not copy.** A pointer names one authoritative location.
  When the same fact must appear in two places (e.g. a capability line in a
  README description and the full how-to in `doc/user/`), the README carries
  the summary and points to the file that owns the detail.
- **When duplication is unavoidable, say so.** If two documents must both
  state the same normative rule (this file and a workflow's own doc tree,
  say), mark each copy with a short line naming the other
  (e.g. *"Mirrors `doc/developer/ToolingDocumentation.md` §5; that file
  owns the rule."*). Unmarked duplication silently rots.
- **Pointers must name real targets.** A link is a claim that a file exists;
  verify the target path exists before writing the pointer (the step-2
  dossiers verified current pointers — carry the `verified` notes forward).
- **Stale pointer = stale claim.** Correcting or removing a pointer follows
  the correction rules in §6.

## 6. Correction rules

- **Stale → correct with evidence, or mark unverified; never assert.** Any
  claim that disagrees with the current checkout (task registration, export
  lists, file existence, cited line numbers) is either (a) corrected to the
  verified fact, citing the evidence (the dossier `correct-to:` dispositions
  are pre-verified evidence), or (b) explicitly marked as unverified
  (`mark-unverified`) where verification was not possible — never silently
  carried forward as fact.
- **Never invent.** Documentation may not state behavior that was not
  observed or read from current source; a *mark-unverified* statement beats a
  confident false one.
- **Corrections are itemized.** Every correction made during a restructure
  (stale facts fixed, title normalizations, phantom removals, desc
  alignments) is listed in that step's report — the report is the audit trail
  connecting the dossier evidence to the new text.
- **Verification statuses travel.** A dossier row's `mark-unverified` or
  `verified` status follows its content into the destination file (as a
  parenthetical note where it matters), so unverified claims remain visible
  as such.

## 7. Migration procedure (per workflow)

Steps 4/6 are mechanical applications of this procedure. Inputs: the
workflow's dossier (`doc_redesign/<Workflow>.dossier.md`), its source-map
rows, its baseline (`doc_redesign/baseline/<Workflow>.json`), this
convention.

1. **Dossier.** Read the dossier block inventory and dispositions; every
   block of the current README must have a row (missing rows → flag, do not
   improvise). Apply each row's `correct-to:` fix verbatim where given.
2. **README rewrite.** Rebuild the README per §2: plain title line, lean
   description assembled from the `keep` rows (capability-complete per
   §2.3), `# Tasks` exactly once with entries per §2.4, alignment per §2.5,
   developer sections after the tasks section or a pointer into
   `doc/developer/`.
3. **Doc splits.** Create `<Workflow>/doc/user/` and
   `<Workflow>/doc/developer/` files from the `move` rows, per §3 audiences;
   apply §5 pointer policy and §6 correction rules; record verification
   statuses.
4. **Baseline re-probe.** Re-run the probe capture
   (`run_probe baseline_snapshot_v2` or its updated equivalent) and compare
   against `doc_redesign/baseline/<Workflow>.json`:
   - **Invariant:** for every registered task, the applied description is
     unchanged (§2.5) — any difference must be an itemized, authorized
     change.
   - Title normalization (dropped `# `) and phantom-entry removal are
     expected diffs, itemized.
   - Entry count changes must be only the itemized mechanical fixes.
5. **Map update.** Update `doc_redesign/source_map.tsv` rows for the
   restructured workflow to reflect the new layout (source locators now
   pointing into the new files), so the map stays the current index of where
   every block lives.
6. **Report.** Per-workflow report entry: corrections itemized, alignments
   itemized, phantoms removed, expected baseline diffs, open decisions
   (e.g. per-task coverage gaps flagged per §2.5/decision 5).

## Decisions log

Recorded rulings with rationale. Decision owner: Manager (execution
coordination); scientific direction N/A. These rulings govern steps 4/6/7;
later changes append new numbered decisions rather than editing these.

1. **README structure follows the parser contract.** The parser consumes
   everything up to the first `# Tasks` line as the introduced description
   (contract.md §2), so the README layout must be: plain-text title line →
   lean agent-facing description → `# Tasks` with `## <task>` entries → any
   developer-facing sections strictly after the tasks section (preferred:
   `doc/developer/` with only a pointer in README). Rationale: no
   developer-facing material may ever enter agent context uninvited.
2. **Description shrinkage is intended; meaning-preservation is at the
   capability level.** What enters agent context should be small. The
   condensed description must preserve every capability statement (what it
   is, when to use it); relocated detail lands in `<Workflow>/doc/user/`.
   This reconciles the step-1 acceptance check "description equivalent in
   meaning to baseline". Rationale: the description is an agent-context
   budget item; capability routing must survive, detail must not.
3. **Title normalization: drop the `# ` prefix.** READMEs whose first line
   begins `# ` (Cortex, Planned, Semantics) yield introduced titles
   containing the literal `# ` (contract.md §2.1, observed live). Normalize
   to plain text. Recorded as a correction; listed in the report as a changed
   agent-visible string. Rationale: the title is prose for the introduced
   header, not a markdown heading; the prefix leaks into agent context.
4. **Phantom entries must be converted to non-heading formatting.** `##`
   prose headings inside `# Tasks` that match no registered task (Semantics,
   ChatAnalyst, Workspace's TSV task reference) are silently ignored today
   but would bind to any future task of that name. The pre/post invariant is:
   for every REGISTERED task, its applied description is unchanged.
   Phantom-entry removal is allowed and must be itemized in the report.
   Rationale: an unbound `## name` inside `# Tasks` is a latent binding, not
   inert prose.
5. **Mechanical fixes only; no new per-task entries this pass.** ComputerUse
   (0 entries applied — doubled `# Tasks` heading) and ChatAnalyst (25 tasks,
   prose-heading phantoms) get their mechanical defects fixed; no new
   per-task entries are authored this pass. Where an existing entry differs
   from the in-code desc of the same task, align the README entry to the
   in-code desc (the in-code text is what surfaces today — conservative) and
   itemize any alignment. Coverage gaps (Workspace `tsv_*`: one entry for 8
   tasks) are flagged as open decisions, not filled now. Rationale: keep this
   pass mechanical and reversible; authoring new task docs is a separate
   decision.
6. **Scope: 9 tooling workflows; persona workflows and Visualizer out.**
   Restructured this pass: ChatAnalyst, ComputerUse, Cortex, Planned, Reader,
   Research, ScoutCoder, Semantics, Workspace. FitAgent and Decider
   (persona/orchestration) are out of restructuring scope; Visualizer
   (workflow.rb, no README) is a recorded gap. All three are report
   follow-ups. The repo-wide "every Scout project adopts doc/developer +
   doc/user" convention is documented for later adoption, not applied now.
   Rationale: match the tooling surface agents consume; keep the pass
   bounded.
7. **Naming: `doc/developer/` singular; skills at repo root `skills/`.** The
   user wrote both `developers` and `developer`; singular is chosen for
   ecosystem consistency with scout-gear/scout-ai/Cortex (all use
   `doc/developer/`). Flagged in the report for confirmation. Skills: repo
   root `skills/`, one directory per skill, standard Agent Skills format
   only (no loader/tooling). Rationale: consistency with the ecosystem the
   AgentSuite workflows are consumed from; standard format avoids bespoke
   tooling this pass.
8. **Skills pointer policy with the sandbox constraint.** `doc/user` files
   will often be unreachable from agent sandboxes, so every SKILL.md body
   must be self-sufficient for the what/when decision; pointers to
   `<Workflow>/doc/user/` files are enhancements, expressed as repo-relative
   paths. Rationale: a skill that must read an unreachable file to know when
   to fire fails exactly when it is needed.

## Appendix: parser-grammar quick reference

From `doc_redesign/contract.md` §2 (scout-gear
`lib/scout/workflow/documentation.rb` L4-39); cite that file for the full
pinned detail and evidence.

- Title: text before the first blank line (`/^([^\n]*)\n\n/`); everything up
  to the first blank line, wherever it falls.
- Description: everything after, up to the first `/^# Tasks/i` line,
  `.strip`ped.
- `# Tasks` is matched case-insensitively (`/i`), with the space — `#tasks`
  does not match.
- Task section ends at the next level-1-ish heading `/^#[^#]/i` or EOF.
- Entries: split on `/^## (.*)/` (two hashes + one space); heading text =
  entry name; the following chunk = description. An odd number of parts
  drops the trailing entry; an empty-body entry is deleted; the first `## `
  line inside a body ends the entry; `##nospace` and `### ` lines do NOT
  split entries (they are absorbed into entry text or, before the first
  entry, terminate the pre-entry capture); `W#task` names cross workflows.
- `document_task` (AgentSuite ScoutCoder) requires the literal exact spelling
  `# Tasks` (`/^# Tasks\s*$/`) — stricter than the parser; write the heading
  exactly as `# Tasks` so both agree.
