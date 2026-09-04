# AgentSuite doctrine-iteration baseline (on-disk state)

Date of inventory: 2025-09-01 session (bout: doctrine review implementation).
Repo root: /bulk/mvazque2/git/AgentSuite (working directory of this step).
Purpose: establish the true on-disk baseline before any start_chat rewrite or
doctrine/society delta edit. No instruction file was modified in this step.

## 1. Resolved on-disk paths

- The `import: Agent/doctrine` and `import: Agent/society` lines in every
  start_chat resolve to files at the repo root, not to an `Agent/` subdirectory:
  - doctrine: /bulk/mvazque2/git/AgentSuite/doctrine
  - society: /bulk/mvazque2/git/AgentSuite/society
- Verification: `find . -name doctrine -o -name society -not -path "./.git/*"`
  returns exactly `./doctrine` and `./society`; no `Agent` directory exists
  anywhere in the tree (checked with `find . -maxdepth 2 -name "Agent*"`).
- The `intro` file documents this layout explicitly:
  "This directory is the AgentSuite: a collection of agent directories usable as
  a drop-in replacement of an ./Agent or .scout/chats/Agent directory." and
  "The current shared instructions are: - `doctrine` ... - `society` ...".
  `intro` imports `doctrine` and `society` directly and is kept only for
  backward compatibility with older chats that still `import: Agent/intro`.
- The `chats` entry at the repo root is a symlink to
  /home/mvazque2/chats/AgentSuite/ (not readable from this sandbox; not needed,
  since the shared files live at the repo root).
- File checksums (md5) captured for later drift detection:
  - doctrine: 79f9c112360a4d21821ccfac2d796f15
  - society: f27a57383920f8a5dc2cf973cf420111
  - Manager/start_chat: 0ebcf6c20b79e6893a8bafbba6e59a9a
  - Planner/start_chat: 849e850f6b1f53469d3db3f3e3b48f3b
  - Worker/start_chat: 3e2340c4c08331a5dd04a45c26242c16
  - User/start_chat: 11fddce176d444dd81f9380af4c8a0ce
  - ScoutCoder/start_chat: 17ee44c17f3c906fe387bd9f6860c9ec

## 2. Agent directories found

Exactly 11 start_chat files exist, confirming the expected list:

- ChatAnalyst (imports Agent/doctrine)
- ComputerUse (imports Agent/doctrine)
- Cortex (imports Agent/doctrine + Agent/society)
- Critic (imports Agent/doctrine)
- Manager (imports Agent/doctrine + Agent/society; `socialize: true`)
- Planner (imports Agent/doctrine + Agent/society)
- ScoutCoder (imports Agent/doctrine)
- Searcher (imports Agent/doctrine)
- User (imports Agent/doctrine + Agent/society)
- Worker (imports Agent/doctrine)
- WorkflowCoder (imports Agent/doctrine)

Additional top-level directories without start_chat (workflow-only, listed in
society as inference engines): `Branched/` (workflow.rb only) and `Planned/`
(workflow.rb + README.md). `lib/` and `sandbox/` are empty; `research/` exists
with one prior artifact (doctrine-revision-conformance.txt).

## 3. Verdicts per check

Verdict key: OLD_TEXT_PRESENT = the old/target-for-removal text is on disk;
ALREADY_FIXED = the desired replacement text is on disk; NOT_FOUND = neither
the named old text nor its named replacement is present.

### a. doctrine section 4 backslash line-wrap artifact - OLD_TEXT_PRESENT

doctrine line 43-44, `cat -A` shows the backslash as a literal character at the
start of line 44 followed by a real newline:

    large or generated content over fragile line-level edits. Keep results$
    \reproducible: record commands, save outputs to files, and report failures$

Section heading context: "## 4. Work in the smallest verifiable step".
This is the only backslash artifact of this kind (grep for "reproducible"
finds it at line 44; line 52 is the normal occurrence in section 5).

### b. doctrine section 6 omitted conversation id sentence - ALREADY_FIXED

The exact desired sentence is present, doctrine lines 67-70:

    Prefer one-shot asks or branch-specific named conversations such as
    `work_A` or `critic_A`: an omitted conversation id is an independent
    one-shot, and a named conversation persists across calls and is scoped per
    agent; the `inherit` option controls only how a call or named conversation
    is initialized.

### c. doctrine section 10 adaptive wording - ALREADY_FIXED

Section "## 10. Adapt" opens with the desired sentence (doctrine line 120):

    Adapt the doctrine's defaults to the work at hand, never its invariants.

No escape-hatch/struggling wording remains: grep for "struggle", "cannot
follow", "ignore the doctrine", "deviate" returns no matches in doctrine. The
precedence chain and "smallest safe alternative" sentence are also present.

### d. doctrine section 11 friction-vs-blocker wording - ALREADY_FIXED

Section "## 11. Abort and Report in blockers" (doctrine lines 135-142) contains
both required elements verbatim:

    Distinguish recoverable friction from a true blocker: a rejected path, a
    missing tool, or a malformed input is friction until no authorized
    alternative can satisfy the task with the available tools. On apparent
    blockage, perform one bounded diagnostic matched to the failure, such as
    inspecting the available permissions or the relevant tool documentation, and
    do not repeat the same failed operation. Abort only when no authorized
    alternative remains.

### e. society roster details

- Planner entry: PRESENT, section heading `## Planner` at society line 41, body:
  "Produces one short, concrete plan that other agents can follow. Single path by
  default, alternatives only when requested. ... draws step owners from this
  roster. Carries the ScoutCoder documentation-lookup tools for framework
  questions."
- ComputerUse heading: listed under the group heading at society line 51,
  "# Conversational agents with an associated tool or orchestration workflow"
  (entry `## ComputerUse` at line 89), NOT under "# Conversational agents"
  (line 17) and NOT under "# Inference engines" (line 111).
- Branching agent spelling: OLD_TEXT_PRESENT, society line 124 still reads
  "spliter agent divides the job into parallel sub-tasks, one worker runs each"
  (typo for "splitter"; the section is `## Branched (inference engine)`).
- Planned stage names in order, society line 114:
  "Staged pipeline: request, search, plan, work, ask."
- Stated default worker, society line 115-116:
  "the default Manager worker executes, and the final stage reports back."
- Stated options, society lines 118-119 and 125:
  "Stages can be switched off with chat options such as `use_search false`, and
  the worker can be changed with `worker_agent` or `Planned_worker_agent`, the
  latter taking precedence." and "(`Branched_worker_agent` takes
  precedence over `worker_agent`)".
  All four option names are present: use_search, worker_agent,
  Planned_worker_agent, Branched_worker_agent.

### f. Manager/start_chat pipeline and roster

- Numbered control loop with 2 to 4 candidate plans and Critic pre-scoring:
  PRESENT, step 1 (Manager/start_chat lines 30-34):

      1. Classify the task and choose the process weight before doing anything
         else: a bounded task with a single deliverable goes straight to the right
         specialist with no plan round; a task with a clear path gets one plan; a
         task with genuine alternatives or a disputed approach gets 2 to 4
         candidate plans scored by Critic before execution. Critic pre-scoring is
         reserved for high-risk or disputed plans.

- Critic verification after each step: PRESENT, step 4 (lines 40-43):

      4. After each executed step, verify proportionally: ask Critic to verify every
         consequential step and return status, score, missing checks, smallest next
         action, and branch advice; low-risk steps may settle for a lighter check or
         the step's own acceptance evidence.

  Budget policy also hard-codes "- Candidate plans: 2 to 4" (line 61).
- Hard-coded specialist roster "User/Planner/Searcher/Worker/Critic":
  NOT_FOUND as such (grep for "User/Planner/Searcher/Worker/Critic" and for
  "specialist roster" returns nothing). Instead the roster is deferred to
  society (line 16: "The society import is the authoritative roster. It lists
  the intake and reporting, planning, research, execution, and verification
  agents and says when each fits; recruit outside the suite only when the user
  requests a particular agent."). RESIDUAL: a partial hard-coded capability
  list survives under "Other notes:" (lines 54-58):

      - The Worker agent has access to the ComputerUse capabilities that can
        access the filesystem and execute commands.
      - Critic also has limited abilities to access the filesystem
      - Searcher can search the internet and find documentation
      - ScoutCoder knows how to code for Scout and can act as in place of the Worker

  Note it names Worker/Critic/Searcher/ScoutCoder (not User/Planner), and it
  overlaps with the society roster rather than deferring to it.

### g. Planner/start_chat hard-coded step owners - NOT_FOUND

"Searcher | Worker | Critic | User" does not appear. The current wording
(Planner/start_chat lines 31-32) is roster-based:

    - Owner agent: any named specialist in the society roster, chosen by
      capability so the Manager can route it

### h. Worker/start_chat phrases

- "Declare or confirm sandbox path permissions before the first filesystem call
  on a location": NOT_FOUND. Repo-wide grep (excluding .git, chats, sandbox)
  finds it only as a recorded command inside
  research/doctrine-revision-conformance.txt (line 154), never in instruction
  files. The current wording is conditional (Worker/start_chat lines 26-28):

      - When uncertain about access to a location, or after a path is rejected,
        inspect the available permissions and diagnose the denial rather than
        retrying it.

- "one well-defined step at a time": NOT_FOUND in Worker/start_chat. The
  current phrasing (lines 10-11) is:

      When possible, execute one independently verifiable unit at a time; several
      tightly coupled bounded edits may be completed in one invocation when they

  (The phrase "One well-defined step at a time;" does appear in society under
  `## Worker`, society line 58-59, describing the agent.)

### i. User/start_chat explicit-unchecked-report sentence - NOT_FOUND

"A final report based on results that no verifier has checked must say so
explicitly" is absent. The current wording (User/start_chat lines 32-35) is the
conditional-label version:

    - A final report must label itself unverified when its consequential claims
      lack objective validation such as tests, probes, or direct evidence; work
      that has such validation, or that an independent verifier has checked, need
      not carry the label merely because no verifier agent was invoked.

### j. ScoutCoder/start_chat generic four-step procedure - NOT_FOUND

There is no numbered list starting "1- Examine the tools" and no "Examine the
tools" string at all. The current structure is a bullet obligations list
(ScoutCoder/start_chat lines 11-18):

    When asked to perform a task follow these obligations:

    - Consult the framework documentation when Scout semantics are uncertain.
    - Inspect the existing project conventions before changing code.
    - Use the narrowest suitable tool for the job.
    - Validate your changes before reporting completion.
    - Record documentation gaps with a 'ScoutCoder:' comment where you had to
      figure out something the documentation should have explained.

## 4. ScoutCoder: documentation-gap convention grep

Command (bounded, .git/chats/sandbox excluded):

    grep -rln "ScoutCoder:" --exclude-dir=.git --exclude-dir=chats --exclude-dir=sandbox .

Verdict: PRESENT and in active use. Matches:

- Convention definition: ScoutCoder/README.md (line 55 describes the
  "ScoutCoder:" comment tag; line 61 shows the TSV.traverse :stream example).
- Instruction requiring it: ScoutCoder/start_chat line 17 (obligation quoted
  in check j above).
- Actual gap comments in code: ScoutCoder/lib/ScoutCoder/tasks/documentation.rb
  lines 8, 22, 37, 68, 142.
- Actual gap comment in tests: ChatAnalyst/test/test_cross_consumer_tokens.rb
  line 21.
- Incidental non-marker matches (the token "ScoutCoder:" as name+colon, not a
  documentation-gap marker): society line 105 ("Scout workflow development
  specialist layered on ScoutCoder: list_tasks, ...") and
  WorkflowCoder/README.md line 21 ("- ScoutCoder: `help_list_repos`, ...").
  These are prose, not gap comments.
- research/ has one prior conformance artifact mentioning the tag:
  research/doctrine-revision-conformance.txt.

## 5. Summary table of deltas still to implement

| Check | File | Verdict |
|---|---|---|
| a | doctrine (sec 4) | OLD_TEXT_PRESENT: stray `\reproducible` line 44 |
| b | doctrine (sec 6) | ALREADY_FIXED |
| c | doctrine (sec 10) | ALREADY_FIXED |
| d | doctrine (sec 11) | ALREADY_FIXED |
| e | society | Planner entry ok; ComputerUse under "Conversational agents with an associated tool or orchestration workflow"; "spliter" typo present; stages/options/default-worker all stated |
| f | Manager/start_chat | Pipeline present (2 to 4 plans, Critic pre-score, post-step verify); no User/Planner/Searcher/Worker/Critic roster, but residual hard-coded "Other notes:" capability list (Worker/Critic/Searcher/ScoutCoder) |
| g | Planner/start_chat | NOT_FOUND (owners now society-based) |
| h | Worker/start_chat | Both target phrases NOT_FOUND (replaced by conditional permission wording and "one independently verifiable unit") |
| i | User/start_chat | NOT_FOUND (replaced by conditional unverified-label rule) |
| j | ScoutCoder/start_chat | NOT_FOUND (replaced by obligations bullet list) |

## 6. Step 3 diff record (shared-file deltas)

Date: 2025-09-01, same bout, step 3.

### doctrine: line 44 backslash artifact - FIXED

Before (doctrine line 44, literal backslash at line start breaking the word
"reproducible" across lines):

    large or generated content over fragile line-level edits. Keep results
    \reproducible: record commands, save outputs to files, and report failures

After (single character removed, wrapping and all other content unchanged):

    large or generated content over fragile line-level edits. Keep results
    reproducible: record commands, save outputs to files, and report failures

Scope of edit: exactly one character (the leading backslash) on one line.
Verified after the edit with `sed -n '40,48p' doctrine | cat -A`: line 44 now
ends with a plain `$`, no `\` prefix. File length unchanged (144 lines).

Artifact-relic grep (both shared files), run after the edit:

    grep -n '\\$' doctrine   -> no matches (rc=1)
    grep -n '\\$' society    -> no matches (rc=1)
    grep -n '^\\' doctrine society -> no matches (rc=1)

Verdict: no further backslash line-wrap artifacts of this kind exist in either
shared file.

Checksums after the edit:

    ed65e5d3d519648b373ca2515c4d52a0  doctrine   (was 79f9c112360a4d21821ccfac2d796f15)
    f27a57383920f8a5dc2cf973cf420111  society    (unchanged)

### doctrine section 6 - NO CHANGE (correct as written)

The delegation-packet sentence is accurate per the scout-ai 1.2.6 documentation
(user/Delegation.md, developer/DelegationInternals.md): an omitted conversation
id is an independent one-shot; named conversations persist across calls and are
scoped per agent; `current` is a legacy explicit value, not an omission
fallback. Current on-disk text (doctrine lines 66-69, re-read after the step 3
edit and unchanged by it):

    output. Prefer one-shot asks or branch-specific named conversations such as
    `work_A` or `critic_A`: an omitted conversation id is an independent
    one-shot, and a named conversation persists across calls and is scoped per
    agent; the `inherit` option controls only how a call or named conversation

### society - NO CHANGE (verified against implementation)

Every society inference-engine claim was confirmed against the code:
- Planned (Planned/README.md, Planned/workflow.rb): stages in order
  request, search, plan, work, ask; final stage `ask` runs the User agent with
  tools disabled; default worker is the Manager agent; `Planned_worker_agent`
  takes precedence over `worker_agent`; `use_search false` redirects the search
  dependency to the request job.
- Branched (Branched/workflow.rb): inherits the request, search, and plan
  stages from Planned, then a `spliter` agent divides the job into parallel
  sub-tasks; one worker runs each sub-task (default Worker;
  `Branched_worker_agent` takes precedence over `worker_agent`); a Critic
  reviews the sub-reports before the tools-disabled User ask stage.
- The spelling `spliter` is the implementation spelling: the Branched workflow
  registers that ad-hoc anonymous agent (its `self.agent` is nil) under exactly
  that name. It is therefore correct as written and is not a typo to fix.

Checksum unchanged: society f27a57383920f8a5dc2cf973cf420111.

### Files touched in step 3

- /bulk/mvazque2/git/AgentSuite/doctrine (1 line, 1 character)
- /bulk/mvazque2/git/AgentSuite/research/doctrine-iteration/baseline.md
  (this appended section)

No other file was modified.

## 7. Step 4 record (start_chat work)

Date: 2025-09-01, same bout, step 4. Only Manager/start_chat was edited, with
exactly the two specified changes. The other four files were verified only.

### Manager/start_chat change 1: "Other notes:" capability bullets replaced

Before (lines 52-58):

    Other notes:

    - The Worker agent has access to the ComputerUse capabilities that can
      access the filesystem and execute commands.
    - Critic also has limited abilities to access the filesystem
    - Searcher can search the internet and find documentation
    - ScoutCoder knows how to code for Scout and can act as in place of the Worker

After:

    Other notes:

    - The society import is the authoritative roster: it states each agent's
      role, tooling, and fit, so consult it rather than a remembered capability
      list when choosing a delegation target.
    - Scout-stack specialists such as ScoutCoder and WorkflowCoder may
      substitute for the Worker on tasks inside their specialty.

Note: the baseline had reported the Searcher bullet as containing a
"search the intenet" typo; on-disk the bullet read "search the internet"
(already correct). The bullet is replaced regardless, so the outcome is
unchanged; only the quoted before-text is corrected here.

### Manager/start_chat change 2: "Artifact policy:" first bullet

Before:

    - Prefer files and named artifacts over long chat summaries.

After:

    - Prefer durable deliverables such as files and named artifacts over long
      chat summaries; bounded conversational work may settle for a structured
      verdict in chat.

### Scope confirmation for Manager/start_chat

Everything else is unchanged. Section order and anchors verified after the
edit: "Default control loop:" (line 29), step 1 classify (30), step 4 verify
(40), "Other notes:" (52), "Budget policy:" (60), "Artifact policy:" (68),
"When delegating, use this structure in your prompt:" (78), "Decision
priorities:" (95), "Output discipline:" (102), "socialize: true" (110, last
line). File is 110 lines, ASCII-only (LC_ALL=C grep for non-ASCII returns 0
lines). The patch tool's automatic `.orig` backups (doctrine.orig,
Manager/start_chat.orig) were deleted after verification; they are not part of
the change set.

### Fresh md5 checksums after step 4

    1bb8609c487db00958381f02d7d74344  Manager/start_chat  (was 0ebcf6c20b79e6893a8bafbba6e59a9a)
    849e850f6b1f53469d3db3f3e3b48f3b  Planner/start_chat  (unchanged)
    3e2340c4c08331a5dd04a45c26242c16  Worker/start_chat   (unchanged)
    11fddce176d444dd81f9380af4c8a0ce  User/start_chat     (unchanged)
    17ee44c17f3c906fe387bd9f6860c9ec  ScoutCoder/start_chat (unchanged)

### Verification-only verdicts

Planner/start_chat: PASS.
- Hard-coded list absent: grep for "Searcher | Worker | Critic | User" -> no
  matches (rc=1).
- Roster/capability routing present (lines 31-32):
  "- Owner agent: any named specialist in the society roster, chosen by
  capability so the Manager can route it"

Worker/start_chat: PASS.
- No unconditional pre-filesystem sandbox check: grep for "sandbox", "before
  the first", "Declare" -> no matches (rc=1).
- Conditional permission diagnosis present (lines 26-28):
  "- When uncertain about access to a location, or after a path is rejected,
  inspect the available permissions and diagnose the denial rather than
  retrying it."
- Unit-based stepping present (lines 10-11):
  "When possible, execute one independently verifiable unit at a time; several
  tightly coupled bounded edits may be completed in one invocation when they
  form a single verifiable unit."
- Step-level-task option retained (lines 14-16):
  "- identify the next highest-value step and execute only that, or
  - request a clearer step-level task if the request is too ambiguous."

User/start_chat: PASS.
- Conditional rule (lines 32-35):
  "- A final report must label itself unverified when its consequential claims
  lack objective validation such as tests, probes, or direct evidence; work
  that has such validation, or that an independent verifier has checked, need
  not carry the label merely because no verifier agent was invoked."
- Validated / independently-reviewed distinction appears (line 34: "that has
  such validation, or that an independent verifier has checked") and the report
  template asks for it again ("## Caveats ... including whether an
  independent verification pass occurred."). Related rules at lines 20 and 31
  remain about validated outputs only.

ScoutCoder/start_chat: PASS.
- Generic numbered four-step procedure gone: grep for lines starting with a
  digit -> no matches (rc=1); "Examine the tools" absent.
- Obligations list present (lines 11-18):
  "- Consult the framework documentation when Scout semantics are uncertain.
  - Inspect the existing project conventions before changing code.
  - Use the narrowest suitable tool for the job.
  - Validate your changes before reporting completion.
  - Record documentation gaps with a 'ScoutCoder:' comment where you had to
  figure out something the documentation should have explained."

All four verification-only files are byte-identical to their step-1 baseline
checksums; no edits were made to them in this step.
