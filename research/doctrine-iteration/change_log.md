# Doctrine-iteration change log (review items to dispositions)

Bout: 2025-09-01, final work step.
Inputs: research/doctrine-iteration/baseline.md (sections 1-7) and the
verified scout-ai facts recorded in the bout context.

## 0. Checksum re-verification before writing this log

Command: md5sum doctrine society Manager/start_chat Planner/start_chat
Worker/start_chat User/start_chat ScoutCoder/start_chat

    ed65e5d3d519648b373ca2515c4d52a0  doctrine
    f27a57383920f8a5dc2cf973cf420111  society
    1bb8609c487db00958381f02d7d74344  Manager/start_chat
    849e850f6b1f53469d3db3f3e3b48f3b  Planner/start_chat
    3e2340c4c08331a5dd04a45c26242c16  Worker/start_chat
    11fddce176d444dd81f9380af4c8a0ce  User/start_chat
    17ee44c17f3c906fe387bd9f6860c9ec  ScoutCoder/start_chat

All seven match the values recorded at the end of step 4. No drift; proceed.

## 1. Summary table

| Item | Short name | Disposition |
|------|------------|-------------|
| 1  | Section 10 exception protocol + precedence order | ALREADY_SATISFIED |
| 2  | Section 11 friction vs blocker rewrite | ALREADY_SATISFIED |
| 3  | Remove tool-specific mechanics from doctrine | ALREADY_SATISFIED |
| 4  | Relax artifact requirements | ALREADY_SATISFIED |
| 5  | Correct delegation semantics | VERIFIED_CORRECT |
| 6  | Refine evidence rule | ALREADY_SATISFIED |
| 7  | Persistence relevance-gated | ALREADY_SATISFIED |
| 8  | Verification by risk | ALREADY_SATISFIED |
| 9  | Planner entry in society | ALREADY_SATISFIED |
| 10 | Sol in roster? | ALREADY_SATISFIED (resolved: no Sol) |
| 11 | Three-category taxonomy | ALREADY_SATISFIED |
| 12 | ComputerUse conversational front end | ALREADY_SATISFIED |
| 13 | Planned/Branched claims vs implementation | VERIFIED_CORRECT |
| 14 | Routing guidance | ALREADY_SATISFIED |
| 15 | Manager role (gate, roster, artifact wording) | APPLIED_NOW (partly; residue fixed this bout) |
| 16 | Planner owners from roster | ALREADY_SATISFIED |
| 17 | Worker conditional permissions, unit stepping | ALREADY_SATISFIED |
| 18 | User conditional unverified label | ALREADY_SATISFIED |
| 19 | ScoutCoder obligations + gap convention | ALREADY_SATISFIED |
| 20 | Decomposition steps 1-4 as work items | APPLIED_NOW (recorded status) |
| 21 | Decomposition step 5 = six conformance checks | APPLIED_NOW (this file, section 4) |
| 22 | Decomposition step 6 evaluation matrix | DEFERRED |
| 23 | Flag A (enforcement in workflow code) | DEFERRED (flag, no action) |
| 24 | Flag B (risk inputs / workflow gates) | DEFERRED (flag, no action) |
| 25 | Bonus observations from documentation pass | DEFERRED (record only) |

Counts: APPLIED_NOW 3, ALREADY_SATISFIED 15, VERIFIED_CORRECT 2,
DEFERRED 5. (25 items total.)

## 2. Per-item detail

### 1. Section 10 escape hatch - ALREADY_SATISFIED
Doctrine lines 108-127 already carry the constrained protocol and the
precedence order, not an old escape hatch.
- doctrine:108-111 `Adapt the doctrine's defaults to the work at hand, never its invariants. Defaults (planning depth, search scope, delegation, persistence, and verification effort) scale with risk and task size...`
- doctrine:113 `If a prescribed procedure is inapplicable or blocks progress, choose the smallest safe alternative and report the deviation and its reason.`
- doctrine:115 `When instructions conflict, the order is: the user objective and constraints, then the role contract (authority and exclusions), then doctrine invariants, then doctrine defaults, then workflow and tool mechanics.`
- doctrine:116-117 `A narrower role rule specializes a general default; it never waives an invariant.`
- Baseline section 3, check c recorded the same verdict (ALREADY_FIXED).

### 2. Section 11 friction vs blocker - ALREADY_SATISFIED
Doctrine lines 129-144.
- doctrine:130-131 `Distinguish recoverable friction from a true blocker: a rejected path, a missing tool, or a malformed input is friction until no authorized alternative can satisfy the task with the available tools.`
- doctrine:133-134 `On apparent blockage, perform one bounded diagnostic matched to the failure, such as inspecting the available permissions or the relevant tool documentation, and do not repeat the same failed operation.`
- doctrine:143-144 `When aborting, report the failed operation, the available evidence, the diagnostic attempted, and the smallest action that would unblock the work.`
- Baseline section 3, check d = ALREADY_FIXED.

### 3. Tool mechanics removed from doctrine - ALREADY_SATISFIED
The four mechanics named by the review are absent as obligations:
- write-vs-patch tool names: `grep -n -e write -e patch doctrine` matches only `write` in `Never write emojis` (line 79) and `write into` prose (line 39: `Prefer robust editing methods for large or generated content over fragile line-level edits. Keep results` / `reproducible:...`); no `patch` occurrence and no tool-pair instruction.
- `sandbox_paths`: zero matches in doctrine (the only occurrence in the suite is ComputerUse/start_chat:10, a role file, which is where it belongs).
- Cortex upkeep obligations: doctrine section 8 now says relevance-gated consult and environment-invariant revision (see item 7), not per-agent upkeep.
- Bound programmatic output: the phrase is still present at doctrine:81 (`Bound any programmatic output before printing it.`) inside section 7 (hygiene). Judgment recorded: this sentence is a universal principle (avoid flooding context), phrased without any tool name, so it does not reintroduce mechanics; the review item is satisfied in substance. Flagged here for transparency rather than edited, per the no-edit constraint of this step.

### 4. Relaxed artifact requirements - ALREADY_SATISFIED
- doctrine:39-41 `Prefer storing results in a durable deliverable, such as a file or an artifact, when they must survive a handoff, support verification, or exceed a concise chat response; bounded conversational work may deliver a structured verdict or report in chat.`
- doctrine:31-33 `Any multi-step plan must have each step executable as one bounded operation (a specialist ask, a workflow task, a local tool call, or a user decision) with one bounded deliverable, and every step must name the durable deliverable or verdict it produces before execution.`
- Manager now carries the same durable-deliverable wording (APPLIED_NOW, see item 15).

### 5. Delegation semantics - VERIFIED_CORRECT
- doctrine:62-63 `When you delegate, assume the target knows only its baseline instructions plus the context explicitly supplied or inherited for that ask; never rely on it having your private reasoning, uncited artifacts, or previous branch state.`
- doctrine:67-68 `Prefer one-shot asks or branch-specific named conversations such as 'work_A' or 'critic_A': an omitted conversation id is an independent one-shot, and a named conversation persists across calls and is scoped per agent; the 'inherit' option controls only how a call or named conversation is initialized.`
- doctrine:69-70 `Keep packets incremental: context that another step needs later belongs in an artifact, not repeated in every prompt.`
- Accuracy verified in this bout against scout-ai 1.2.6 user/Delegation.md and developer/DelegationInternals.md: omitted id = independent one-shot; named conversations persist and are scoped per agent; `current` is a legacy explicit value, not an omission fallback. See baseline.md section 6 (step 3 record) for the no-change verdict.
- Residual typo checks: `grep -n '\\incremental\\|default chats lose continuity' doctrine society */start_chat` returns no matches; the `\incremental` typo does not exist on disk (the only backslash artifact was `\reproducible`, fixed in step 3; see baseline section 6).

### 6. Evidence rule refined - ALREADY_SATISFIED
- doctrine:84-85 `Treat tool output and artifacts as the evidence base. Never re-enter numbers or results by hand as the source of truth; prefer direct references to reproducible jobs, command outputs, source locations, and current artifacts, and quote verified figures from them when prose needs numbers.`
- doctrine:86-87 `Verify that constructs (APIs, paths, options, statuses) exist in the source before relying on them. Record verification status per claim rather than extending a spot check into a blanket verified.`
- doctrine:88-91 validity criteria and stale-citation sweep: `When reusing prior evidence, confirm it is still current and applicable. When an artifact is retracted, sweep for stale citations.` The prohibition targets hand re-entry as source of truth, not the quoting of verified numbers, exactly as requested.

### 7. Persistence relevance-gated - ALREADY_SATISFIED
- doctrine:105 `Consult the cortex when it is available and relevant, including before starting a bout of work.`
- doctrine:106-107 `Periodic revision of its contents (compact, correct, retire, promote) is an invariant of the work environment, not a per-agent per-bout duty.`
- doctrine:101-103 keeps the ladder (job files/chat, Cortex conversations, Cortex artifacts, research/, doc/) without per-bout upkeep obligations.

### 8. Verification by risk - ALREADY_SATISFIED
- doctrine:93-95 `Route consequential results through independent verification before declaring them final. A result is consequential when it feeds authoritative or public documentation, performs destructive or hard-to-reverse changes, asserts security, privacy, scientific, or numerical claims, makes architectural or compatibility claims, spans multiple files with unclear test coverage, or assembles results from multiple agents.`
- doctrine:96 `Distinguish validated results (supported by tests, probes, or direct evidence) from independently reviewed ones (checked by a separate verifier or a genuinely independent method).`
- doctrine:97 `The unverified label applies when a consequential claim lacks objective validation, not merely when no verifier agent was called.`
- User/start_chat carries the same conditional rule (item 18).

### 9. Planner entry - ALREADY_SATISFIED
- society:41-49 `## Planner` with role text `Turns a restated request into one practical plan with bounded, verifiable steps... Use for: turning a restated request into an executable step plan. Not for: executing steps or making design decisions beyond what the request requires.`

### 10. Sol in roster - ALREADY_SATISFIED (resolved: no)
No agent directory named Sol exists: `ls -d */` yields only Branched, ChatAnalyst, ComputerUse, Cortex, Critic, Manager, Planned, Planner, ScoutCoder, Searcher, User, Worker, WorkflowCoder (plus non-agent dirs lib, research, sandbox). The only `Sol` matches in the suite are the word "Solve" inside Cortex/doc prose. Society has no Sol entry and needs none.

### 11. Three-category taxonomy - ALREADY_SATISFIED
- society:17 `# Conversational agents` (User, Searcher, Manager, Planner)
- society:51 `# Conversational agents with an associated tool or orchestration workflow` (Worker, Critic, ChatAnalyst, Cortex, ComputerUse, ScoutCoder, WorkflowCoder)
- society:111 `# Inference engines` (Planned, Branched)

### 12. ComputerUse as conversational front end - ALREADY_SATISFIED
- society:89-95 `## ComputerUse` / `Conversational front end to the ComputerUse workflow, exposing filesystem access, code execution, document conversion, patching, and Playwright through its tasks. Sandbox-limited.` Listed under the second heading, not under inference engines. Baseline section 3, check e recorded the same.

### 13. Planned/Branched claims vs implementation - VERIFIED_CORRECT
- Planned stages in order and ask last: society:115 `Staged pipeline: request, search, plan, work, ask.` matches Planned/README.md and Planned/workflow.rb (chat_task :request, :search, :plan, :work, :ask).
- Default worker and option precedence: society states Manager default, `Planned_worker_agent` over `worker_agent`; Planned/workflow.rb implements `self.agent :Manager ...` with the option lookup.
- use_search redirect: Planned/workflow.rb `dep :search do |jobname,options|` redirects to :request when use_search is false, matching the README.
- Branched: `spliter` spelling, default Worker with `Branched_worker_agent` precedence, Critic review of sub-reports, tools-disabled ask stage all match Branched/workflow.rb; `spliter` is the ad-hoc anonymous agent registered by the workflow (self.agent nil), so the spelling in society is the implementation spelling and is correct. Recorded in baseline.md section 6 as the no-change verdict for society.

### 14. Routing guidance - ALREADY_SATISFIED
- doctrine:7-8 `Consult the 'society' import when you need to route work to another agent; other agents can also exist outside the suite.`
- society:5-6 `This file lists the agents defined in this suite. It is not exhaustive...` (discovery through the roster rather than memorized lists), and Manager/start_chat:16-19 now sources the roster from the import: `The society import is the authoritative roster... recruit outside the suite only when the user requests a particular agent.`
- doctrine:14 limits clarification to ambiguity that would change the work, which keeps user questions to material routing choices.

### 15. Manager role - APPLIED_NOW
Partly pre-satisfied, with the residual defect fixed this bout.
- Adaptive gate (pre-existing, verified this bout): Manager/start_chat:30-35 `a bounded task with a single deliverable goes straight to the right specialist with no plan round; a task with a clear path gets one plan; a task with genuine alternatives or a disputed approach gets 2 to 4 candidate plans scored by Critic before execution. Critic pre-scoring is reserved for high-risk or disputed plans.`
- Proportional verification (pre-existing): Manager/start_chat:40-43 `verify proportionally: ask Critic to verify every consequential step... low-risk steps may settle for a lighter check or the step's own acceptance evidence.`
- Roster from import, no hard-coded specialist list: the residual "Other notes:" capability list naming Worker/Critic/Searcher/ScoutCoder was replaced this bout with the two society-sourced bullets; before/after diff recorded in baseline.md section 7. Note: the review's cited typo "search the intenet" was not on disk; the actual line read `- Searcher can search the internet and find documentation` (corrected quote recorded in section 7).
- Durable-deliverable artifact wording: applied this bout; Manager/start_chat:69-71 `- Prefer durable deliverables such as files and named artifacts over long chat summaries; bounded conversational work may settle for a structured verdict in chat.` (diff in baseline.md section 7.)
- Manager/start_chat md5 before this bout 0ebcf6c2c43555cb3775338b136c5c5c, after 1bb8609c487db00958381f02d7d74344.

### 16. Planner owners from roster - ALREADY_SATISFIED
- Planner/start_chat:31-32 `- Owner agent: any named specialist in the society roster, chosen by capability so the Manager can route it`
- The literal `Searcher | Worker | Critic | User` list returns no matches (`grep -n "Searcher | Worker | Critic | User" Planner/start_chat` rc=1). Baseline section 3, check g = NOT_FOUND.

### 17. Worker conditional permissions, unit stepping - ALREADY_SATISFIED
- No unconditional preflight: `grep -n -e sandbox -e "before the first" -e Declare Worker/start_chat` returns no matches.
- Conditional diagnosis: Worker/start_chat:26-28 `When uncertain about access to a location, or after a path is rejected, inspect the available permissions and diagnose the denial rather than retrying it.`
- Unit stepping: Worker/start_chat:10-11 `When possible, execute one independently verifiable unit at a time.`
- Step-level request retained: Worker/start_chat:14-16 `If you are asked to implement an entire plan at once, either: - identify the next highest-value step and execute only that, or - request a clearer step-level task if the request is too ambiguous.`

### 18. User conditional unverified label - ALREADY_SATISFIED
- User/start_chat:32-35 `A final report must label itself unverified when its consequential claims lack objective validation... need not carry the label.`
- User/start_chat:34 carries the validated/independently-reviewed distinction (`that has such validation, or that an independent verifier has checked, need`).
- User/start_chat:85-86 template echoes it: `including whether an independent verification pass occurred.`
- Baseline section 3, check i = NOT_FOUND for the old unconditional sentence "A final report based on results that no verifier has checked must say so explicitly".

### 19. ScoutCoder obligations + gap convention - ALREADY_SATISFIED
- Generic numbered procedure gone: `grep -n "^[0-9]" ScoutCoder/start_chat` returns no matches, and "Examine the tools" is absent.
- Obligations present (ScoutCoder/start_chat:11-18 bullet list "When asked to perform a task follow these obligations"): consult repo documentation when framework semantics are uncertain; inspect project conventions before changing code; choose the narrowest suitable tool; validate changes; record documentation gaps with the 'ScoutCoder:' comment convention.
- Convention confirmed in use: definition in ScoutCoder/README.md (the example comment block), obligation line in ScoutCoder/start_chat, and six real gap comments in ScoutCoder/lib/ScoutCoder/tasks/documentation.rb and ChatAnalyst/test/test_cross_consumer_tokens.rb (baseline.md section 4).

### 20. Decomposition steps 1-4 - APPLIED_NOW (status record)
- Step 1 (repair contradictions): DONE pre-bout; evidenced by items 1-8 all ALREADY_SATISFIED or VERIFIED_CORRECT on current disk, plus the section 4 artifact fix (step 3).
- Step 2 (separate principles from mechanics): DONE pre-bout; doctrine carries no tool-pair or sandbox mechanics (item 3); role files retain role-appropriate mechanics (ComputerUse/start_chat:10 keeps `sandbox_paths`, which is that role's own tool).
- Step 3 (mechanical society audit): DONE pre-bout; confirmed this step by checks B and C below and item 13.
- Step 4 (resolve role conflicts): DONE this bout; the last conflict (Manager's residual hard-coded roster vs the society import) was removed (item 15, baseline.md section 7).

### 21. Decomposition step 5 (six conformance checks) - APPLIED_NOW
Executed and recorded in section 4 below: A PASS, B PASS, C PASS, D PASS, E PASS with one judgment recorded, F PASS with two candidates reviewed.

### 22. Decomposition step 6 (evaluation matrix) - DEFERRED
Reason: building and running the six-scenario matrix (direct answer, one-file fix, Scout workflow change, ambiguous multi-agent task, sandbox denial, Cortex research continuation) requires agent runs and evaluation harnessing beyond this bout's scope. No file or instruction currently encodes it.

### 23. Flag A - DEFERRED (flag, no action)
Reason: conditional by definition ("if agents still misapply universal guidance after mechanics removal"). Requires evidence from evaluation runs that the failure mode persists; move enforcement into workflow code or typed task interfaces only then. No evidence collected yet.

### 24. Flag B - DEFERRED (flag, no action)
Reason: conditional ("if the adaptive Manager skips necessary planning or verification in evaluation"). Requires the evaluation matrix (item 22) to produce the signal before adding explicit risk inputs or workflow gates. Restoring an unconditional pipeline now would undo item 15's adaptive gate.

### 25. Bonus observations - DEFERRED (record only)
- `socialize:` chat-file role: used by Manager/start_chat:110 (`socialize: true`). Not documented in scout-ai 1.2.6 doc/user/WritingChats.md (`grep -n socialize` on that file returns no matches). Recorded as a scout-ai documentation gap; no action in this suite.
- Branched has no README.md or doc tree (`ls Branched/` shows only workflow.rb), so its society entry can only be checked against Branched/workflow.rb; done in item 13.

## 3. File inventory used by the checks

Agent directories with start_chat (11): ChatAnalyst, ComputerUse, Cortex,
Critic, Manager, Planner, ScoutCoder, Searcher, User, Worker, WorkflowCoder.
Non-agent top-level dirs: Branched, Planned (workflows, no start_chat),
lib, research, sandbox.

## 4. Conformance checks

### A. Every agent start_chat imports Agent/doctrine - PASS
Command: `for f in */start_chat; do printf "%-25s " "$f"; head -1 "$f"; done`
Result: all 11 files print `import: Agent/doctrine` as their first line.

### B. Only routing agents import Agent/society - PASS
Command: `grep -l "import: Agent/society" */start_chat`
Result: 4 files import society: Cortex, Manager, Planner, User.
Duty check (a start_chat whose duties involve choosing or naming other agents):
- Manager: yes, explicit control loop choosing delegation targets (Manager/start_chat:8-10 `decide what should happen next, which agent should do it, what context that agent needs`).
- Planner: yes, assigns step owners (Planner/start_chat:31 `Owner agent: any named specialist in the society roster`).
- User: yes, liaises and may name agents when restating requests (User/start_chat:20 `When given validated outputs from other agents, synthesize them into a clear final answer.`), and it imports society precisely so it can describe agents without executing tools.
- Cortex: yes, orchestrates and names agents for continuity work (Cortex/start_chat describes conversations and agents recorded in the memory; the import supplies the roster it refers to).
The 7 non-importers (ChatAnalyst, ComputerUse, Critic, ScoutCoder, Searcher, Worker, WorkflowCoder) are executors or single-purpose roles whose duties do not require choosing agents; each of them can still see the roster via the doctrine's pointer if needed. No import exists without a matching duty: PASS.

### C. Society entries correspond to agent directories (and vice versa) - PASS
Evidence: society `## ` headings at lines 19, 26, 33, 41, 53, 63, 72, 80, 89, 96, 104, 113, 122:
User, Searcher, Manager, Planner, Worker, Critic, ChatAnalyst, Cortex, ComputerUse, ScoutCoder, WorkflowCoder, Planned (inference engine), Branched (inference engine).
Removing the two inference engines leaves exactly the 11 agent directories listed in section 3, one-to-one, no extras on either side. (Also matches research/doctrine-revision-conformance.txt: "13 roster entries equal 11 start_chat directories plus Planned and Branched.")

### D. No start_chat carries a hard-coded roster contradicting the society import - PASS
Command: `grep -rn "User/Planner/Searcher/Worker/Critic" --exclude-dir=.git .` (rc=1, no matches) plus per-file review of the 11 start_chats for capability lists that contradict the roster.
Manager (fixed this bout) now says the roster is authoritative (Manager/start_chat:54-56 `The society import is the authoritative roster... consult it rather than a remembered capability list`). The remaining capability mention, Manager/start_chat:57-58 (`Scout-stack specialists such as ScoutCoder and WorkflowCoder may substitute for the Worker on tasks inside their specialty.`), is consistent with society's ScoutCoder/WorkflowCoder entries, not a contradiction. No other start_chat enumerates a competing roster.

### E. No role instruction requires a tool that role does not carry - PASS (one judgment recorded)
Command: `grep -n "^introduce:\|^tool:" */start_chat` for the carried set, then per-file tool-token scan.
- ChatAnalyst: introduces/tool ScoutCoder; `file: README.md`; the only tool-like token is `read` in line 18 (`must be read from the evidence`) - English verb, not a tool call. PASS.
- ComputerUse: introduces ComputerUse; references pwd, read, write, search, sandbox_paths - all ComputerUse tasks. PASS.
- Cortex: introduces Cortex (and ComputerUse per the check's allowance); references cortex_* task names plus `write` in prose about filesystem tiers. All carried. PASS.
- Critic: introduces ComputerUse; the only token is `search` used as an English noun/verb (`over repeating searches`, `targeted search/verification`), not a required tool invocation; its structured verdict wording says recomputed numbers come from executed checks. PASS.
- Manager: no tool/introduce lines; tokens `search` in `targeted search` (46), `Broad search rounds` (63), `Prefer targeted search` (96) refer to delegating search to the Searcher, not to calling a search tool itself. PASS.
- Planner: introduces ScoutCoder with help_list_repos, help_list_repo_documents, help_get_repo_document, help_overview, help_workflow (Planner/start_chat:38-45); tokens found are exactly those five; `search` appears only as prose. PASS.
- ScoutCoder: introduces ComputerUse and ScoutCoder; references help_list_repo_documents/help_get_repo_document (its own tools) and `pwd` (ComputerUse intro line 50), `ruby` in prose about the Ruby language. PASS.
- Searcher: no tool/introduce lines in its own start_chat; its chat-level tooling comes from the harness (Planned/workflow.rb:21 loads the Searcher agent with tooling passed in, and the Planned search stage receives the chat's introduced workflows). Its start_chat only asks for search-like behavior in prose with no required tool name; `read`/`search` occurrences are English. Judgment recorded: PASS, on the grounds that the file names no specific tool and the harness supplies tooling; if a stricter reading is wanted, the smallest repair would be adding the intended `introduce:` lines, but that is an enhancement, not a defect.
- User: no tool references at all; rules forbid tool execution. PASS.
- Worker: introduces ScoutCoder (which includes ComputerUse); references write, patch, delete - all ComputerUse tasks. PASS.
- WorkflowCoder: introduces ComputerUse, ScoutCoder, WorkflowCoder; references list_tasks, task_inputs, run_task, job_info, clean_job (WorkflowCoder tasks, WorkflowCoder/start_chat:21-23), bash/ruby/python, pwd. PASS.

### F. No role instruction weakens a doctrine invariant - PASS (two candidates reviewed, neither a weakening)
Invariant scan terms: honesty (invent/fabricate/claim), authority (boundaries, sandbox, exclusions), evidence integrity (silently, drop, omit), no silent dropping (budget, drop).
Candidates:
- User/start_chat:29 `Do not solve the task yourself unless explicitly asked only for restatement or reporting.` - a role exclusion, not an honesty weakening; it strengthens the doctrine's role-contract rule.
- Worker/start_chat:36-37 `If you cannot complete a sub-task, say so explicitly rather than dropping it silently.` - reinforces the no-silent-dropping invariant.
- Cortex/start_chat:34 `mistakes or invent results` appears inside a rule against inventing results (evidence integrity, reinforcing).
- Critic/start_chat:14 `Treat the Worker's conclusions as claims to verify, not as facts to trust.` - reinforces evidence integrity.
- Manager/start_chat:49 `Stop when acceptance tests pass or the budget is exhausted.` - budget stopping is not silent dropping because step 7 (`If blocked, produce the smallest set of questions for the user`) and the doctrine's renegotiation rule (doctrine:45-46) govern the report.
No start_chat contradicts honesty, authority boundaries, role exclusions, evidence integrity, or no-silent-dropping. PASS.

## 5. Deferred work

- Item 22 evaluation matrix (direct answer, one-file fix, Scout workflow change, ambiguous multi-agent task, sandbox denial, Cortex research continuation): DEFERRED to a follow-up bout; needs agent runs and an evaluation harness; no current file encodes it.
- Item 23 Flag A: DEFERRED, conditional on evaluation evidence that mechanics removal still causes misapplication; remedy would be workflow-code or typed-task enforcement.
- Item 24 Flag B: DEFERRED, conditional on evaluation evidence that the adaptive Manager skips necessary planning/verification; remedy would be explicit risk inputs or workflow gates, not an unconditional pipeline.
- Item 25 bonus observations: recorded, no action. (a) `socialize:` role undocumented in scout-ai 1.2.6 doc/user/WritingChats.md while Manager/start_chat:110 uses it - candidate upstream doc fix. (b) Branched has no README/doc tree, so its society entry is verifiable only against Branched/workflow.rb; consider a short README in a later bout.
- Check E judgment (Searcher tooling supplied by harness, not by its start_chat) is recorded above as a potential enhancement, not a defect.
