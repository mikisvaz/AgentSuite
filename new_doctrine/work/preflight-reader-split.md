# Pre-flight: Reader/Research split (round step 1)

Date: 2026-10-25. Executor: Worker. Scope: read-only except this file.
Suite root: /bulk/mvazque2/git/AgentSuite (= /home/mvazque2/git/AgentSuite).

## 1. Git status baseline (quoted)

Command: `git -C /bulk/mvazque2/git/AgentSuite status`

```
On branch main
Your branch is ahead of 'origin/main' by 1 commit.
  (use "git push" to publish local commits)

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
  (commit or discard the untracked or modified content in submodules)
	modified:   .vimproject
	modified:   ScoutCoder (modified content)
	modified:   doctrine
	modified:   scout

Untracked files:
  (use "git add <file>..." to include in what will be committed)
	Claude/

no changes added to commit (use "git add" and/or "git commit -a")
```

Porcelain: ` M .vimproject / M ScoutCoder / M doctrine / M scout / ?? Claude/`.
HEAD: `912766a Add scientific path kinds to Research agent` (1 ahead of origin/main).

Unattributed pre-existing changes — do NOT misattribute to this round, do NOT revert:

- `doctrine` (root file, +17/−7): prose refinements (task-contract reading rule,
  scratch-note pinning rule, failed-call discipline, plan-per-bout rule). Content
  matches the doctrine text this round's agents are running under, i.e. it
  appears to be the live, intentional doctrine state.
- `scout` (root file, +4): adds "### Workflow input inheritance" section
  (dependency input propagation; agent tool input presentation).
- `.vimproject` (root file): project-tree bookkeeping (removes stale chat names,
  adds ScoutCoder file entries).
- `ScoutCoder` submodule: modified content — `README.md` (+66: "Property
  dispatch types (arity) and receiver shape", "Production versus development
  dispatch", input-propagation section), `start_chat` (+7: run_probe dispatch
  verification guidance), `.vimproject` (+1). Submodule itself on a clean HEAD,
  dirty working tree.
- `Claude/` (untracked): new workflow dir with a single `workflow.rb`
  (`chat_task :ask` shelling out to the `claude` CLI with logging). No
  README/start_chat. Unattributed.
- `Cortex` submodule: **clean**, HEAD `2cae3a4 Cleaned entity stuff from cortex`.
- `Research/`: tracked in the root repo, itself clean.

## 2. D1 probe: `record_computation_use`

Prescribed command (from suite root):

```
scout workflow task Cortex cortex_continue --conversation reader-split-preflight-probe --agent Worker --prompt hello
```

Outcome from the suite root (quoted):

```
RuntimeError: Workflow Cortex not found
```

(exit 255). The Cortex workflow is not resolvable from the suite root
(`SCOUT_WORKFLOW_AUTOINSTALL=false`; no installation entry). Re-run with CWD =
`Cortex/` (the workflow checkout): the job itself ran (step status `done` in
`.info`, elapsed 0.03 s) but the agent turn failed with:

```
ScoutException: No agent found with name Worker
```

(b/t `/home/mvazque2/git/scout-ai/lib/scout/llm/agent.rb:257:in 'load_agent'`).
Reason: with CWD inside the Cortex checkout, `Scout.Agent["Worker"]` resolves to
`{PWD}/chats/Agent/Worker`-style paths (`find_all` → `[]`); the suite's
agents live in `/bulk/mvazque2/git/AgentSuite/Worker/` etc. and are not on that
path map. A second CLI attempt on the same conversation was then rejected by the
claim guard: `Cortex conversation continuation already in flight for
"reader-split-preflight-probe"` — my first CLI probe left a claim JSON under
`Cortex/var/cortex/conversations/.claims/` whose recorded `job_path` is the bare
job name, so `claim_status` cannot resolve it (status `""`) and the claim is
never recoverable. I did not touch the store directly (doctrine forbids it);
the stale claim blocks only that one throwaway name in the Cortex-submodule
store.

Control probe through the agent tool surface (this chat, suite-root agent
context): `cortex_continue --conversation reader-split-preflight-probe-2 --agent
Worker --prompt hello` **succeeded**, returning a real assistant answer
("Hello! Received — no tools used. Ready when you are.") and writing the
conversation into the suite-root store
(`AgentSuite/var/cortex/conversations/reader-split-preflight-probe-2`).

**D1 verdict: NOT LIVE (repaired).** Evidence, labeled:
- `record_computation_use` is defined at
  `Cortex/lib/Cortex/execution_operation.rb:171` and called at
  `Cortex/lib/Cortex/tasks/entity.rb:541`; `Cortex/workflow.rb:13` loads the
  former unconditionally (validated by direct grep of the checkout).
- A full `cortex_continue` round trip through the tool surface completed
  without that error (validated, live run).
- Neither failure observed in the CLI path is D1: workflow resolution and agent
  resolution both fail earlier than any entity/execution code.

**Channel recommendation for later bouts:** use named Cortex conversations via
the *agent tool surface* (`cortex_continue` tool as exposed in agent chats),
never the suite-root CLI form. The tool surface resolves suite agents and writes
to the suite-root store (`AgentSuite/var/cortex/conversations/`), which already
holds this suite's active conversations (`bout-d-verify-run`, `tooling-doc`,
`bout-e-readonly-probe`). The prescribed CLI form fails at the suite root
(`Workflow Cortex not found`) and, from `Cortex/`, cannot load suite agents
(`No agent found with name Worker`). Direct ask-style conversations inside the
executing agent's own chat remain fine for one-shot delegation; reserve named
Cortex conversations for investigations that must persist or branch.

## 3. Society match verdict: MATCHES the expected version (all three markers)

File `/bulk/mvazque2/git/AgentSuite/society` (5516 bytes, dated Oct 21 17:09).

(a) Searcher entry, present (lines 35–38, quoted):

```
## Searcher
Targeted-search agent producing a short search brief, or NO_SEARCH_NEEDED
when no search is required; prefers local documentation and repository
files over the web.
```

(b) No Research agent entry anywhere: the only section headings are
`## User, ## Searcher, ## Planner, ## Manager, ## Consultant, ## Critic,
## Worker, ## ChatAnalyst, ## ScoutCoder, ## Planned` plus
`# Conversational agents...` group headings. `grep -n "^##"` lists no Research
heading. The string "Research" occurs only inside prose (routing line 22
"Research execution on that tooling: Worker", Worker's description "Research
executor", "scientific research", "web research") — no `## Research` entry.

(c) Manager entry, present (lines 51–58, quoted):

```
## Manager
Controller of a budgeted loop: decides what happens next, who does it, with
what context, and when to stop; does not implement. Inside Planned its
context is exactly the three upstream reports. Schedules ScoutCoder when
supporting code infrastructure must be extended, and Worker when that
infrastructure is used for scientific research; recruits Critic for
verification gates.
```

## 4. Pinned task inventory (11 tasks — CONFIRMED, no mismatch)

`Research/lib/Research/tasks/web.rb` (1 task):

| task | declaration | exported how |
|---|---|---|
| `searxng` | `task :searxng => :json` | `export_exec :searxng` |

`Research/lib/Research/tasks/documents.rb` (10 tasks):

| task | declaration | exported how |
|---|---|---|
| `docx2md` | `task docx2md: :text` | `export :docx2md` |
| `pdf2md_full` | `task pdf2md_full: :text` | not exported (dep-only) |
| `pdf2md_no_images` | `task pdf2md_no_images: :text` (dep :pdf2md_full) | not exported |
| `pdf2md` | `task_alias :pdf2md, self, :pdf2md_no_images` | via alias |
| `html2md` | `task html2md: :text` | `export :html2md, :html_query` |
| `excerpts` | `task excerpts: :array` | not exported |
| `rag` | `task :rag => :binary` (dep :excerpts) | not exported |
| `query` | `task query: :json` (dep :rag) | not exported |
| `pdf_query` | `task_alias :pdf_query, self, :query, text: :pdf2md` | via alias |
| `html_query` | `task_alias :html_query, self, :query, text: :html2md` | via alias + `export :html2md, :html_query` |

Both files are required by `Research/workflow.rb` (lines 11–12);
`lib/Research/path_kinds*.rb` declares no tasks. Total = 1 + 10 = 11, exactly
the expected list, with the two alias spellings matching
("pdf2md [alias]" = `task_alias :pdf2md, self, :pdf2md_no_images`;
"html_query [task_alias over query]" = `task_alias :html_query, self, :query,
text: :html2md`). Useful for the move: `pdf2md_full`, `pdf2md_no_images`,
`excerpts`, `rag`, `query` carry **no export declaration** — they are reachable
only as dependencies/aliases of the exported five (`searxng`, `docx2md`,
`html2md`, `html_query`, plus `pdf2md`/`pdf_query` via aliases).

## 5. Unexpected tree state (beyond items 1–4)

- `new_doctrine/` did **not** exist before this bout; this file creates
  `new_doctrine/work/`. Matches the round description ("recreates
  new_doctrine/work/").
- Two live Cortex stores coexist: the suite-root `AgentSuite/var/cortex/`
  (active conversations, artifacts, entities — the one agent tooling writes to)
  and the Cortex submodule's own `Cortex/var/cortex/` (older investigations:
  property-redesign, placement-validation, foreign-adoption). Later bouts
  should treat the suite-root store as the coordination store.
- A stale conversation claim (`reader-split-preflight-probe`, agent Worker,
  bare job_path) sits in the submodule store's `.claims/`; it blocks only that
  throwaway name. Left in place deliberately (no direct store edits).
- Suite-root `var/jobs/` already contains `Research/`, `Cortex/`, `Workspace/`,
  `Claude/` etc.; the Research job caches are the expected future stale
  history once tasks move — not a defect.
- `scout` file, `doctrine` file, ScoutCoder README/start_chat carry
  uncommitted-but-coherent documentation improvements (see §1); they look like
  the tail of the prior tooling round rather than accidents, but they are
  unattributed — flag for the owner before any round commit.

## Resume pointers

- Inventory sources: `Research/lib/Research/tasks/web.rb`,
  `Research/lib/Research/tasks/documents.rb`, `Research/workflow.rb`.
- Probe artifacts: `Cortex/var/jobs/Cortex/continue/reader-split-preflight-probe_0846718d46287be315375e0c334bf539.chat{,.info}`
  (CLI failure evidence), `AgentSuite/var/cortex/conversations/reader-split-preflight-probe-2`
  (tool-surface success evidence).
- Society file: `/bulk/mvazque2/git/AgentSuite/society`.
