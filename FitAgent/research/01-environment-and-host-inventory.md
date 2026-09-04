# FitAgent environment and host inventory (research note 01)

**Scope**: where FitAgent runs, what its sandbox can see, and which host
components the auto-testing improvement loop can rely on.
**Status**: validated by direct filesystem probes and full source reads
(2026-09-04). Evidence receipts in Cortex
`findings/agentsuite-components-available.md` (v1) and
`findings/sandbox-execution-model.md` (v2).

## 1. The AgentSuite host layout

FitAgent lives at `/bulk/mvazque2/git/AgentSuite/FitAgent` as one project in
the AgentSuite git superproject. The full suite is present as submodules
(`.gitmodules`): ComputerUse, ScoutCoder, WorkflowCoder, Cortex, ChatAnalyst,
plus in-tree agents (Worker, Critic, Manager, Searcher, User, Planner,
Consultant) and inference engines (Planned, Branched, Visualizer).

Verified inventory (2026-09-04):

| Component | Path (canonical) | Key facts |
| --- | --- | --- |
| ComputerUse | `.../AgentSuite/ComputerUse` | `workflow.rb` 23 lines; `lib/ComputerUse/tasks/{filesystem,exec,patch,documents,playwright,web}.rb`; patch.rb **453 lines, read in full**; `start_chat` imports `Agent/doctrine`, `introduce: ComputerUse`; tests exist under `test/ComputerUse/tasks/` |
| ChatAnalyst | `.../AgentSuite/ChatAnalyst` | `workflow.rb` 1159 lines; 11 deterministic `export_exec` tasks (see research note 04); provisions `tool: ScoutCoder`, `tool: Cortex cortex_write`, `tool: Cortex cortex_edit` |
| Worker | `.../AgentSuite/Worker` | `start_chat` 3730 bytes; step-executor role; already carries patch/write guidance |
| FitAgent | `.../AgentSuite/FitAgent` | `workflow.rb` 433 lines; 4 tasks (use_case/analyze/compare/evolve); `etc/AI` = {glm53, qwen} — **no `weak`**; `workflows/MiniTools` shipped; `research/`, `chats/` empty; `test/` has only test_helper |

A chats anchor exists (`AgentSuite/chats -> /home/mvazque2/chats/AgentSuite`)
and a per-project `cortex_path_map.yaml` attaches the FitAgent and Cortex
cortex stores.

## 2. The sandbox-visibility lesson (why an earlier investigation concluded absence)

An earlier investigation round concluded "ComputerUse source is NOT present
on this machine". That was a **mount-view artifact**: the searching process
saw `/home/mvazque2/git` containing only `FitAgent`, because a thread-level
bwrap bind (`/home/mvazque2/chats/Agent -> /bulk/mvazque2/git/AgentSuite`)
was absent in that view, and the searches never probed the canonical
`/bulk/...` spelling.

Durable evidence rules established (independently reviewed by Critic):

- Cite the **mount plan + realpath + content hash** (e.g. identical md5 of
  `workflow.rb` through both spellings), not `stat` device:inode — user
  namespace bind mounts remap `st_dev`, so the same directory shows
  different `st_dev` per spelling.
- `/home/...` spellings of AgentSuite are thread-mount-dependent (this
  chat's sandbox); the canonical host path is `/bulk/mvazque2/git/AgentSuite`.
- **Sandbox visibility is not host state.** Before concluding a checkout is
  absent, probe both spellings and run `sandbox_paths`. This matters doubly
  for FitAgent: its own improvement loop will run agents inside nested
  sandboxes whose mount views differ from the orchestrator's.

## 3. What the FitAgent run sandbox looks like (from workflow.rb)

`FitAgent#use_case` stages, inside the job dir:

1. `sandbox/use_case/` — copied use case (task prompt `main.chat`, optional
   `analyze.chat`).
2. `sandbox/var/cache/ask` — local ask-cache (needed because `~/.scout` is
   read-only in run environments; sandbox-local `var` wins resolution
   order).
3. `sandbox/etc/AI/*` — endpoint files copied from the FitAgent repo, with
   keys materialized from `SCOUT_AI_<NAME>_KEY` env (openwebui backend
   cannot resolve `env:` placeholders, so the file must carry the literal
   key; the file lives only in the per-run job, never committed).
4. `sandbox/Agent/<Name>/` — agent definitions copied from the `agents:`
   input. The sandbox is the run PWD, so **repo-local agent shadowing**
   applies: `Scout.Agent[name]` resolves the `:current` (PWD) map first,
  meaning a staged `sandbox/Agent/Worker/...` shadows the global one.
5. Optional target repo staged under `sandbox/<repo-name>` via `repo_mode`
   (`git clone --no-hardlinks` for git repos, `rsync` otherwise, always
   stripping `etc/AI` from the staged copy; `link` mode symlinks).
6. `sandbox/workflows/` — referenced workflows linked in. The search list
   is `wf_search = [FITAGENT_ROOT/workflows, File.dirname(FITAGENT_ROOT),
   'workflows', Workflow.workflow_dir]`. Because `FITAGENT_ROOT` is
   `__FILE__`-derived, the second entry is the **AgentSuite directory
   itself**: `AgentSuite/ComputerUse` links directly, independent of the
   launch directory. MiniTools is always linked.

Then the inner agent runs as
`scout-ai agent ask <main_agent> -c main.chat -e <endpoint> --log 0 -ck 'directory <jobs> workflow_jobs'`
inside `Misc.in_dir sandbox` with env `SCOUT_NO_ASK_CACHE=recursive`,
`ASK_PERSIST=false`, `SCOUT_WORKFLOW_AUTOINSTALL=false`, `BWRAP_PATH=false`
(nested user namespaces are denied — one level of bwrap only), producing
`sandbox/main.chat` and `sandbox/main.chat.files/` transcripts.

## 4. Consequences for the improvement loop

- The agent-under-test can be provisioned with the real ComputerUse
  workflow (including `patch`) by linking through the sibling-entry rule —
  no host prerequisite, no autoinstall. This was previously believed
  blocked; it is not.
- An Agent override directory staged at `sandbox/Agent/<Name>` is the
  override mechanism: instructions (system text) and tooling
  (`introduce:`/`tool:` lines) both live in `start_chat`, so both kinds of
  mutation the user asked for are expressible in one file per candidate.
- The sandbox-local `etc/AI` staging is where a `weak` endpoint file must
  land for inner runs; the FitAgent repo currently lacks it (only `qwen`,
  `glm53`).
- Deterministic scoring can run in the OUTER job over the staged sandbox
  (files + `main.chat`), avoiding any nested-sandbox complication.

## 5. Open items

- `weak` endpoint credentials (which model) — user decision.
- Whether inner runs need `HOME` redirection for the agent CLI (commented
  out `SCOUT_WORKFLOW_DIR`/`HOME` lines in workflow.rb suggest past
  experimentation).
