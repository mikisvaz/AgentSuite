# Start-chat receipts: Reader/Research split (round step 3)

Date: 2026-10-25. Executor: Worker. Working tree only; no commits; no
reverts of pre-existing changes. Scope held: only `Reader/start_chat` (new),
`Research/start_chat`, `Searcher/start_chat`, and this file. Society,
READMEs, code, and doctrine untouched (the concurrent actor's
`Research/lib/Research/path_kinds/records.rb` and
`Research/research/return-path-probes.md` were not touched).

## 1. Files written

- `Reader/start_chat` — created (77 lines). Mirrors Worker/Research
  structure: `import: Agent/doctrine`, one role system block plus system
  subsections (role and output, fidelity requirements, boundaries, working
  the tools), no society import, then tooling lines `introduce: Reader` /
  `tool: Reader` (whole-workflow form), `introduce: Workspace` /
  `tool: Workspace`, `introduce: Cortex` / `tool: Cortex`.
- `Research/start_chat` — edited, nothing removed: new "Delegate
  acquisition, not epistemology" paragraph inside "## Working with other
  agents" (Searcher for discovery, Reader for acquisition/close reading;
  consume search briefs and Reader dossiers; dossier is source material,
  not a registered Observation — register your own Observation citing the
  dossier and its locators; Research retains epistemic ownership, decides
  what the evidence establishes, owns the interpretation via Path kinds /
  Semantics / domain tooling, Workspace when necessary). The run_probe /
  Semantics-no-live-reload sentence was added next to the ScoutCoder
  boundary paragraph.
- `Searcher/start_chat` — the block `introduce: Research` /
  `tool: Research searxng` / `tool: Research html2md` replaced by
  `introduce: Reader` / `tool: Reader searxng` / `tool: Reader html2md`;
  one guideline added ("Hand off documents needing substantial extraction
  or close reading to Reader ... do not extract document contents
  yourself"). NO_SEARCH_NEEDED contract, output format block, all other
  tool lines, and the Cortex-use footer are untouched.

## 2. Chat-parse probe (fresh process each)

Command (one fresh `ruby` process per file, three processes total):

```
ruby -e '
require "scout-ai"
require "scout/llm/chat/parse"
msgs = Chat.parse(Open.read("<file>"))
counts = Hash.new(0)
msgs.each { |m| counts[m[:role]] += 1 }
# ... prints role counts, then scans every message body for lines
# matching /^[a-z_]+:\s/ that would parse as unintended roles
'
```

Results:

```
== Reader/start_chat == messages: 8
  import: 1
  introduce: 3
  system: 1
  tool: 3
  stray role-like line starts: none
== Research/start_chat == messages: 17
  exec_task: 1
  import: 2
  introduce: 2
  socialize: 1
  system: 4
  tool: 7
  stray role-like line starts: none
== Searcher/start_chat == messages: 18
  import: 1
  introduce: 3
  system: 2
  tool: 12
  stray role-like line starts: none
```

- Searcher matches the expected profile exactly: system 2 / import 1 /
  introduce 3 / tool 12, contents swapped (introduce set: Workspace,
  Reader, ScoutCoder).
- Reader: system 1 / import 1 / introduce 3 / tool 3 — consistent with its
  design (single system block; Reader, Workspace, Cortex tooling).
- Research: system 4 / import 2 / introduce 2 / tool 7 / exec_task 1 /
  socialize 1. Note the parser folds consecutive system blocks; its
  pre-edit profile was system 5 / tool 7 (and message count 19 → 17 after
  two blocks merged), so the count drop is a parser-merge artifact of
  inserting text between system blocks, not a lost message. All pre-edit
  roles are still present; nothing was removed.

Probe notes: three mid-edit parse runs caught and fixed real defects —
a `responsibility:` line start, then a `burden:` line start (both would
have parsed as unintended roles), and a duplicated heading/paragraph from
an imprecise insert anchor. All three fixed; final runs clean.

## 3. Tool-line Resolution (fresh process)

Entry point note: `Workflow.require_workflow` could not load
`Reader/workflow.rb` from the suite root directly
(`ERROR: Workflow Workspace not found` from `Reader/workflow.rb:4`) — the
suite has no `workflows/` install dir and `SCOUT_WORKFLOW_AUTOINSTALL` is
false (same root cause as the pre-flight's `Workflow Cortex not found`).
Resolution used the standard lookup form instead: a scratch
`tmp/wfcheck/workflows/` with symlinks to the suite's workflow dirs,
exactly how Scout resolves installed workflows (removed after probing).

```
cd tmp/wfcheck && ruby -e '
require "scout-ai"
%w[Reader Workspace Research Semantics ScoutCoder Cortex].each do |w|
  wf = Workflow.require_workflow(w)
  puts "#{w}: loaded, #{wf.tasks.length} tasks: #{wf.tasks.keys.sort.inspect}"
end'

Reader: loaded, 11 tasks: [:docx2md, :excerpts, :html2md, :html_query,
  :pdf2md, :pdf2md_full, :pdf2md_no_images, :pdf_query, :query, :rag, :searxng]
Workspace: loaded, 23 tasks: [...]
Research: loaded, 0 tasks: []        # tasks moved out; Path kinds remain
Semantics: loaded, 3 tasks: [:entity_list_property, :entity_property, :list_entities]
ScoutCoder: loaded, 17 tasks: [...]
Cortex: loaded, 17 tasks: [...]
```

- Reader loads with all 11 tasks — so `tool: Reader` (whole workflow),
  `tool: Reader searxng`, and `tool: Reader html2md` all resolve.
- Research loads (0 workflow tasks is correct post-move: `tool: Research`
  keeps registering the Path kinds via `require_relative
  'lib/Research/path_kinds'` in `Research/workflow.rb`).
- Every workflow named in a tool/introduce/exec_task line across the three
  files resolves: Reader, Workspace, Cortex, Research, Semantics,
  ScoutCoder (verified per line, output above in the resolution run).
- Named-task spot check: `searxng, html2md, pdf2md, docx2md, pdf_query,
  html_query` all "resolves" as Reader tasks.

## 4. Grep for moved task names

```
for f in Reader/start_chat Research/start_chat Searcher/start_chat; do
  grep -n -E "searxng|pdf2md|pdf2md_no_images|pdf2md_full|docx2md|html2md|html_query|pdf_query|excerpts|rag|query" "$f"
done
```

Output:

```
== Reader/start_chat ==
53:- Prefer the composite tasks — `pdf_query`, `html_query` — when a document
55:  and inherit Scout's caching. Use `pdf2md`/`docx2md`/`html2md` when the
56:  whole converted document is the deliverable, and `searxng` for discovery.
62:- interactive loops. Defaults are `searxng` `count` 10 and `query` `num` 3;
63:  every `rag`/`query` run embeds text, so reuse identical inputs to replay
== Research/start_chat ==
(no matches)
== Searcher/start_chat ==
46:tool: Reader searxng
47:tool: Reader html2md
```

- Research-prefixed tool lines referencing the moved tasks: none (Research
  has no task-name matches at all).
- The only tool-line references are Reader-prefixed (`tool: Reader searxng`,
  `tool: Reader html2md`); the remaining Reader/start_chat matches are
  backticked prose guidance about its own tasks, as designed.

## 5. Deviations and surprises

- Root-cause friction (not a blocker): workflows are not installed at the
  suite root, so both the direct `require` and the CLI form fail there;
  the symlinked scratch dir is the documented Scout resolution shape and
  was used for the fresh-process probe, then deleted. `tmp/` contains many
  probe leftovers from prior rounds (listed, not touched).
- Research pre-edit parse profile: system 5 / import 2 / introduce 2 /
  tool 7 / exec_task 1 / socialize 1 (19 messages) → post-edit system 4
  (17 messages) via parser merge of adjacent system blocks. Reported above;
  nothing lost.
- Concurrent actor observed, not touched: `Research/lib/Research/path_kinds/records.rb`
  (modified), `Research/research/return-path-probes.md` (new), plus other
  Research/ changes (README, path-kinds reports, tests, workflow.rb task
  removal, `Research/share/` draft dir). All consistent with the split;
  nothing surprising beyond the expected concurrent edits.
- `Reader/` is untracked at the suite root (`?? Reader/`) — expected: the
  owner commits, agents do not.

## 6. Doctrine-layer receipts: ./scout vocabulary, Manager/Worker start_chat (round step 5)

Date: 2026-10-25 (23:19 CET). Executor: Worker. Working tree only; no
commits. Scope held: `./scout` (stacked on the pre-existing +4),
`Manager/start_chat`, `Worker/start_chat` (both clean before this edit),
and this file. `./doctrine`, `./doctrines/advice`, `./society` untouched
by this bout.

### 6.1 ./scout edits — two vocabulary entries

Both entries landed at the end of section "## 7. Working knowledge and
scientific reasoning", immediately after the `### Investigation` entry and
immediately before "## 8. Context given to an agent". Placement rationale:
section 7 is where the vocabulary names the scientific work layers
(Observation, Claim, Hypothesis, Evidence, Investigation) and the society
split is exactly a division of that work (acquisition versus investigation)
across two agents; section 5 "Building and extending the environment" names
suite capabilities but its ScoutCoder entry is about construction, not
routing work, so section 7 is the correct home. Style matches the
established ScoutCoder-entry precedent: heading + one compact paragraph.

Entry 1 — `### Source acquisition` (verbatim):

> Source acquisition is the Reader workflow's work: reading, converting,
> and extracting supplied or discovered documents, PDFs, and web pages, and
> producing citable source dossiers preserved as Cortex artifacts, with
> source identity, page or section locators, retrieval context, and
> extraction limitations. Route documents to read, convert, or extract
> there; the dossiers feed scientific investigation rather than replacing
> it, and deciding what the sources warrant belongs to Research.

Entry 2 — `### Scientific investigation` (verbatim):

> Scientific investigation is the Research agent's work, conducted through
> the Semantics interface, the scientific Path kinds (Observation, Claim,
> Hypothesis), and the domain-specific tooling, with Workspace tooling when
> necessary: observations are registered, claims assessed against them,
> hypotheses challenged, and the result is a traceable synthesis citing
> result addresses. Route scientific investigation and evidence-grounded
> interpretation there; sources are acquired upstream and enter the
> epistemic record as registered observations.

Recorded decisions (made upstream, not re-litigated): no standalone
Semantics entry — the Scout vocabulary routes work and is not an API
reference; the Semantics interface is covered inside entry 2. One paragraph
per entry, per the ScoutCoder-entry shape.

`git diff scout`: +12 lines net on top of the pre-existing +4
("### Workflow input inheritance" block preserved verbatim; total
`git diff --stat scout` = 12 insertions, of which 4 are the pre-existing
unattributed block and 8 are this bout's two entries).

### 6.2 ./doctrine disposition: NO EDIT

The owner's sentence is routing plus Scout vocabulary. Routing already
lives in `./society` (owner-edited in step 4; receipts confirm the
Reader/Research/Worker lines and entries are in place). Vocabulary went to
`./scout` (section 6.1). The doctrine's existing generic rule — section 4,
"Prefer the specific tool over the general one. A domain-specific tool is
curated for the work: reach for it before generic filesystem or shell
tooling." — already covers the reader/researcher behavior generically.
Doctrine was retuned for brevity this round and deliberately carries no
agent names (its header: "it carries only rules that matter to all:
role detail lives in start_chats and tool mechanics in the workflow
introductions").

Contradiction scan (the flagged-contradiction case): `grep -n -E
'Research|Reader|Worker|ScoutCoder|Searcher|pdf|searxng|docx|html|document'
doctrine` — every hit is generic prose ("research targets",
"`research/`", "documentation", "scientific or numerical claims"); no line
routes document reading or scientific work to any agent, and no agent name
or moved-tool name appears. The case did not fire; no edit made.

### 6.3 Manager/start_chat — routing-list fix

Pre-edit routing block (excerpt) / post-edit (diff):

```
-- Research execution on that infrastructure: Worker.
+- Concrete task execution on that tooling: Worker.
+- Source documents to read, convert, or extract: Reader.
+- Scientific investigation and evidence-grounded interpretation: Research.
```

Three insertions/deletions total (`git diff --stat Manager/start_chat` =
4 lines changed: 1 removed, 3 added), list style and surrounding lines
(ScoutCoder, Critic, ChatAnalyst, Consultant) untouched. The Worker line
now matches society's casting ("Concrete task execution on that tooling:
Worker."), and the Reader and Research lines are society-verbatim.

Sweeps: `grep -n -E
'pdf2md|pdf2md_full|pdf2md_no_images|searxng|docx2md|html2md|excerpts|\brag\b|pdf_query|html_query|Reader|Research'
Manager/start_chat` post-edit matches only the new Reader/Research routing
lines — no moved-tool names, no other document/science routing. Nothing
else needed fixing.

### 6.4 Worker/start_chat — opening rewording

Diff (the only change to the file):

```
-You are the Worker agent, the suite's research executor: you run the concrete
-steps of a scientific investigation on the infrastructure ScoutCoder builds —
-experiments, analyses, evidence production — and any concrete task not
-explicitly another agent's. You produce tangible artifacts; you are a step
-executor, not a project manager.
+You are the Worker agent, the suite's execution agent: you run concrete tasks
+on the infrastructure ScoutCoder builds — experiments, analyses, evidence
+production — and any concrete task not explicitly another agent's
+responsibility. You produce tangible artifacts; you are a step executor, not
+a project manager.
```

"Suite's execution agent", "concrete tasks on the infrastructure ScoutCoder
builds", and "any concrete task not explicitly another agent's
responsibility" mirror society's Worker entry ("Execution agent: runs
concrete tasks on the infrastructure ScoutCoder builds ... Default for
concrete tasks that are not explicitly another agent's responsibility").
Sweeps: the same grep over Worker/start_chat returns no matches for any
moved-tool name, Reader, or Research — the rest of the file is role
mechanics (bouts, evidence, tooling, coding, output format) with no
document/science routing to fix.

### 6.5 Post-edit parse profiles (fresh process)

Probe: `tmp/parse_probe_reader_split.rb` (new, disposable), one fresh
`ruby` process per file, method as in section 2 of this file. Command:
`ruby tmp/parse_probe_reader_split.rb Manager/start_chat Worker/start_chat`.

```
== Manager/start_chat == messages: 6
  import:     2
  socialize:  1
  system:     1
  tool:       2
  stray role-like line starts: none
== Worker/start_chat == messages: 6
  import:     1
  introduce:  2
  system:     1
  tool:       2
  stray role-like line starts: none
```

Pre-edit profiles (captured before any edit, same probe): identical counts
and identical role sets — the Manager and Worker edits are prose-only
replacements inside the single system block, so the message-count profile
is unchanged by construction, and the stray-role scan is clean on both
sides. Note: `new_doctrine/work/startchat-validation.md` (the method file
named by the round description) does not exist in the tree; the method was
taken from section 2 of this receipts file, which documents the identical
fresh-process `Chat.parse` probe (role counts + stray `^[a-z_]+:` scan).
This is the only deviation and it is method-preserving, not
method-changing.

### 6.6 Scope check (git status before/after)

Pre-bout `git status --short` (baseline, HEAD `980d809`): the preflight
baseline plus the step-3/4 rounds already in the tree
(`Research/*` split changes, `Searcher/start_chat`, `society`,
`?? Reader/`, `?? new_doctrine/`, `?? Claude/`). `Manager/start_chat` and
`Worker/start_chat` were clean before this bout (verified:
`git diff --stat -- Manager/start_chat Worker/start_chat` = empty).

Files changed by this bout (and only these):
- `scout` — 2 new entries stacked on the pre-existing +4.
- `Manager/start_chat` — routing-list fix (6.3).
- `Worker/start_chat` — opening rewording (6.4).
- `new_doctrine/work/startchat-receipts-reader-split.md` — this section
  (appended; see 6.9 for the append incident and verified restoration).
- `tmp/parse_probe_reader_split.rb` — disposable probe (tmp/, not part of
  tracked scope).

Unchanged by this bout and confirmed intact: `doctrine` (+17/-7
pre-existing unattributed diff verified intact — task-contract reading
rule, scratch-note rule, failed-call discipline, plan-per-bout rule),
`scout` pre-existing "### Workflow input inheritance" block (verified
verbatim in `git diff scout`), `.vimproject`, `ScoutCoder` submodule
content, `?? Claude/`, `society` (not edited; see 6.7),
`doctrines/advice` (not touched — no read, no write; its frozen header
was respected).

### 6.7 Society vs implementation: no inconsistency found

`./society` was read in full and cross-checked against the receipts
(preflight §4 task inventory; step-3 §3 fresh-process resolution of Reader
with all 11 tasks, Research 0 tasks). Every routing line and the Reader,
Research, Worker, Manager, Searcher entries match the implemented state:
Reader owns the 11 moved document/PDF/web tasks; Research carries the
scientific Path kinds, Semantics, and domain tooling with Workspace when
necessary and delegates acquisition to Searcher/Reader; Worker is generic
concrete execution. No factual inconsistency; no society edit made.

### 6.8 Residual: one Workflow-resolution quirk (informational)

Head check on `Reader/workflow.rb` shows it requires `Workspace` via
`Workflow.require_workflow` from the suite root install path, so loading
it fresh requires the symlinked `tmp/wfcheck/workflows/` scratch method
(documented in section 3 of this file). No `.rb` file was changed by this
bout, so that method was not needed here; the quirk stands exactly as
recorded in section 5 for the owner's report.

### 6.9 Incident: receipts-file overwrite caught and restored

The first attempt to append this section used the Workspace `write` task,
which replaces whole-file content, so section 6 initially landed alone and
the step-3 sections 1–5 were briefly absent from the file. The full
original content was restored verbatim in the same bout from the bout's
own earlier bounded read of the file (the same read that established the
append anchor), and the combined file was re-verified by heading scan
(`# Start-chat receipts` + `## 1.`–`## 6.` present; no other top-level
heading) and targeted rereads of the head and tail. Lesson recorded: use
an append mechanism (or prepend the original content explicitly), never a
whole-file `write`, when adding a dated section to an existing receipt.
