# FitAgent current capabilities and gap analysis (research note 02)

**Scope**: what FitAgent 0.x can already do (verified from `workflow.rb`,
433 lines, read in full) and the concrete gaps for the auto-testing loop the
user described. Evidence receipts in Cortex
`findings/fitagent-current-state-and-gaps.md` (v1) and
`design/fitagent-improvement-loop-v1.md` (v2).

## 1. Task inventory (verified)

### `use_case` — run one agent under test in an isolated sandbox

Stages `sandbox/{use_case,etc/AI,var/cache/ask,Agent,workflows}` plus an
optional staged repo, then runs
`scout-ai agent ask <main_agent> -c main.chat -e <endpoint> --log 0 -ck 'directory <jobs> workflow_jobs'`
inside `Misc.in_dir sandbox` with `SCOUT_NO_ASK_CACHE=recursive`,
`ASK_PERSIST=false`, `SCOUT_WORKFLOW_AUTOINSTALL=false`, `BWRAP_PATH=false`.
The transcript lands at `sandbox/main.chat` (+ `main.chat.files/`), the
command log at `sandbox/log.txt`. It also accepts a previous job path and
remaps to the staged copy (used by `analyze` for re-analysis without
re-running).

This task already implements most of the user's "create a sandbox directory
with the necessary materials" step.

### `analyze` — LLM-judged evaluation of a run

Attaches to a finished `use_case` job (dynamic dep; `use_case_job` input
avoids re-running the agent), escapes the `main.chat` transcript into a
single user message (role-like headers backslash-escaped so
`Chat.parse` does not split), and asks a `ChatAnalyst` agent
(`LLM::Agent.new` over `AgentSuite/ChatAnalyst/start_chat`) to produce a
markdown report ending in a fenced `yaml` block with
`experiment/verdict(PASS|PARTIAL|FAIL)/autonomy(0-5)/rationale`. The analyst
chat is saved as the job's own `main.chat`.

### `compare` — multi-arm matrix runner

Reads `<repo>/arms/<experiment>.yaml`, runs arms × repeats through
`use_case`+`analyze`, and writes a canonical
`<repo>/results/<experiment>/{runs.tsv,results.tsv}`.

### `evolve` — instruction-only improvement loop

From a seed agent dir (`<repo>/agents/<seed>/FitMain/start_chat`), runs
generations × endpoints × use cases through `use_case`+`analyze`, parses
each verdict, and proposes the next generation's `start_chat` with a single
LLM prompt ("rewrite start_chat fixing the problems, keep tool wiring
unchanged"), with a no-op guard (identical proposal modulo whitespace stops
the lineage). Produces `results/<experiment>/lineage.tsv` with columns
agent/generation/endpoint/use_case/verdict/autonomy/job.

## 2. What already maps onto the user's schema

| User's step | Existing support |
| --- | --- |
| investigate objective | nothing systematic (ad-hoc in chat) |
| scenario + rubric design | nothing |
| sandbox with materials | `use_case` staging (mostly complete) |
| Agent override folder | `agents:` input + `Agent/` shadowing in sandbox PWD; `evolve` writes candidate dirs |
| run scenarios vs overrides | `compare` (arms), `evolve` (generations) |
| deterministic evaluation | **gap** — only LLM verdict exists today |
| message-array-level checks | **gap** — `analyze` feeds transcript to LLM, no deterministic rules |
| ChatAnalyst assessment | `analyze` (LLM side) ✓; deterministic side unused |
| revise override from results | `evolve` (start_chat text only, tool wiring explicitly preserved) |
| cortex awareness | **gap** — no Cortex calls anywhere |

## 3. Gap list (ranked by centrality to the user's ask)

1. **Deterministic rubric engine.** Today the only verdict is an LLM's
   `yaml` block. The user explicitly wants deterministic function checks
   (patched file matches expected byte-for-byte) and message-array checks
   (tool-call counts/order/args). This is the core missing piece.
2. **Scenario catalogue + fixture generation.** No patch-scenario
   representation exists anywhere (see Cortex
   `design/patch-scenario-catalogue-v1.md` for the proposed v1).
3. **Override mutations limited to start_chat prose.** `evolve` preserves
   tool wiring by prompt instruction. The user wants instruction AND tooling
   changes (e.g. re-provision the patch tool, adjust tool docs). Note
   `start_chat` carries both — the whole file is the override surface.
4. **Fixpoint gap: same start_chat + same inputs = stale cache.** Known
   documented pitfall (`.save/research/howto_run.md`, SC26 era): editing a
   `start_chat` without changing task inputs can return cached results.
   `evolve` names jobs `#{experiment}_#{agent}_g#{gen}` which sidesteps it
   per generation; a new catalogue-driven runner must do the same.
5. **No `weak` endpoint file** in `etc/AI` (only `qwen`, `glm53`).
6. **No Cortex integration**: investigations, delegated probes, and
   findings do not persist beyond job dirs; the user wants a cortical
   substrate.
7. **Test scaffolding empty** (`test/` has only `test_helper.rb`);
   ComputerUse's `test/ComputerUse/tasks/test_patch.rb` shows the
   convention to follow.
8. **Agent-ask nesting depth**: `use_case` disables bwrap for inner agents
   (`BWRAP_PATH=false`) because nested user namespaces are denied —
   inner agents must not assume sandboxing.

## 4. `.save/research` legacy (historical context, not current state)

A prior experiment generation (SC26 step 3.1, scout-ai 1.2.2 era) lives in
`.save/research/`. It documents four recurring tool-use failure patterns
(`return_path` misuse, `write_artifact` filename confusion, grep exit-1
misread, tool-call duplication in logs) and hard rules (never `glm`/`glm5`;
version-pin `scout-ai _1.2.2_`). It is superseded as an environment
reference (current gem is scout-ai 2.0.0, `~/.scout` read-only handled by
sandbox-local staging) but remains a useful checklist of failure modes the
rubric's message-level rules can encode, and a reminder that recorded
transcripts historically live under `~/.rbbt/var/jobs/...` while today's
`use_case` keeps them in-job (`sandbox/main.chat`).

## 5. Design implication

The cheapest architecture is **additive**: keep `use_case` as the run
primitive, add a `scenario`/`fixture` representation and a deterministic
`rubric` evaluator that runs in the outer job over (a) staged sandbox files
and (b) the recorded `main.chat`, then extend `evolve` to feed rubric
output (not only the analyst report) into the override-proposal prompt, and
let tooling changes be part of the candidate `start_chat` diff.
