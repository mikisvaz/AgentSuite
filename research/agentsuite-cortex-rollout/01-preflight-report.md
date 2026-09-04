# AgentSuite Cortex rollout - section 5 preflight report

Date: 2026-09-04. Repo: /bulk/mvazque2/git/AgentSuite (read-only probing; no
repo file other than this report and the tmp/ scripts was created or
modified). Spec: Cortex artifact `plans/agentsuite-rollout-spec.md` (314
lines, read in full).

Evidence-strength legend used below:

- STRONG (runtime): executed through the production scout-ai 2.0.0 code path
  in a Ruby process (`Chat.parse` -> `Chat.imports` -> `Chat.tools`, the same
  functions `AgentWorkflow` uses); outputs quoted from the probe logs.
- WEAK (source): static reading of gem source; function and file quoted.
- SANDBOX DEVIATION: where the sandbox forced a deviation from the exact
  production entry point, the deviation and its justification are recorded
  inline. The two deviations (scratch import dir, stubbed
  `Workflow.require_workflow`) are argued to be neutral in
  "Deviations" at the end.

Probes and logs (all under tmp/):
- tmp/p1_directives.txt - probe 1 byte-level output
- tmp/p2_import_resolution.rb - probe 2
- tmp/p4hermetic_doctrine_propagation.rb -> tmp/p4_out.txt - probe 4
- tmp/p568_hermetic.rb -> tmp/p568_out.txt - probes 5, 6, 8
- tmp/p7_hermetic.rb -> tmp/p7_out.txt - probe 7
- tmp/p8_dup_check.rb - probe 8 duplicate-line check
- tmp/p6_cortex_self_reference.rb, tmp/p8_cortex_agent_tools.rb - earlier,
  superseded variants that hit the broken `chats` symlink (kept for the
  record)

Scout-ai gem paths (read from the installed gem, not from a git checkout):
- /home/mvazque2/.rvm/gems/ruby-3.3.1/gems/scout-ai-2.0.0/lib/scout/llm/chat.rb
- .../scout/llm/chat/process/files.rb
- .../scout/llm/chat/process/tools.rb
- .../scout/llm/agent.rb
- .../scout/llm/agent/workflow.rb
- scout-essentials-1.9.0 .../scout/path/find.rb (caller_lib_dir)

## Probe 1: directive spelling and system-block boundaries

Method: `cat -A` byte dumps of the trailing lines of ./doctrine and of the
head/tail of Searcher/start_chat and Worker/start_chat (tmp/p1_directives.txt).

./doctrine is 160 lines; it opens with an empty line, then `system:`, blank,
then the doctrine text; it ends (outside the system block) with two
directives. Byte dump of the tail (the trailing space after "Cortex" on the
tool line is real, shown by `cat -A`):

    $ (doctrine lines 150-160, cat -A)
    missing tool, or a malformed input is friction until no authorized$
    alternative can satisfy the task with the available tools. On apparent$
    blockage, perform one bounded diagnostic matched to the failure, such as$
    inspecting the available permissions or the relevant tool documentation, and$
    do not repeat the same failed operation. Abort only when no authorized$
    alternative remains. When aborting, report the failed operation, the$
    available evidence, the diagnostic attempted, and the smallest action that$
    would unblock the work.$
    $
    tool: Cortex $
    introduce: Cortex$

    $ (doctrine lines 1-6, cat -A)
    $
    system:$
    $
    # Agent doctrine - core operating rules$
    $
    You are one agent in a community that collaborates through chats. Your role$

Searcher/start_chat (51 lines) opens with the import, then a system block:

    $ (lines 1-6, cat -A)
    import: Agent/doctrine$
    $
    system:$
    $
    You are the Searcher agent.$
    $

and ends with (lines 38-51):

    help_get_repo_document, help_overview, and help_workflow$
    tool: ScoutCoder help_list_repos$
    tool: ScoutCoder help_list_repo_documents$
    tool: ScoutCoder help_get_repo_document$
    tool: ScoutCoder help_overview$
    tool: ScoutCoder help_workflow$
    $
    You also have access to the Cortex$
    introduce: Cortex$
    tool: Cortex$
    $
    Use the Cortex to make sure that you are incorporating advice from the cortex and $
    updating it with relevant information for those who come after.$
    $

Worker/start_chat (74 lines): same shape - `import: Agent/doctrine` line 1,
`system:` block from line 3, and at the end:

    introduce: ScoutCoder$
    tool: ScoutCoder$

Full directive inventory per start_chat (grep over all 13; see probe 3):

    -- Cortex/start_chat:      1 import Agent/doctrine; 2 import Agent/society;
                               89 introduce ComputerUse; 90 tool ComputerUse
    -- Searcher/start_chat:    1 import Agent/doctrine; 35 introduce ScoutCoder;
                               39-43 five granular tool: ScoutCoder <task>;
                               46 introduce Cortex; 47 tool Cortex
    -- WorkflowCoder/start_chat: 1 import Agent/doctrine; 28 exec_task ComputerUse pwd;
                               30 introduce ComputerUse; 31 introduce ScoutCoder;
                               32 introduce WorkflowCoder; 33 tool WorkflowCoder;
                               34 introduce Cortex; 35 tool Cortex

Verdict: on disk the directives are spelled `tool:`, `introduce:`, `import:`
and `exec_task:` with NO leading backslash and no other escaping (backslashes
are an artifact of chat transcripts quoting them); a real trailing space
exists after "Cortex" in doctrine line 159; directives outside the system
block are what the parser consumes.

## Probe 2: resolution of `import: Agent/doctrine`

Method: source reading of `Chat.find_file` (production resolver) plus a
runtime probe (tmp/p2_import_resolution.rb).

Source (scout-ai 2.0.0 lib/scout/llm/chat/process/files.rb lines 14-36),
resolution order:

    def self.find_file(file, original = nil, caller_lib_dir = ...)
      path = Scout.chats[file]
      ...
      if relative && Open.exist?(relative)          # 1. dirname(original)/<file>
      elsif relative_lib && Open.exist?(relative_lib) # 2. caller_lib_dir/<file>
      elsif Open.exist?(file)                        # 3. literal
      elsif Open.remote?(file)                       # 4. remote
      elsif path.exists?                             # 5. Scout.chats[<file>]
      end

and `Chat.imports` (same file, lines 38-59) replaces each `import:` message
with the parsed content of the found file.

Runtime output:

    Scout.chats lookup dir: /home/mvazque2/.scout/chats
    Scout.chats['Agent/doctrine'] resolves to: "/home/mvazque2/.scout/chats/Agent/doctrine"
    Scout.chats['Agent/doctrine'].exists?: false
    for Cortex/start_chat:
      1) dirname(original)/Agent/doctrine -> /bulk/.../Cortex/Agent/doctrine (exists? false)
      5) Scout.chats[Agent/doctrine] -> "/home/mvazque2/.scout/chats/Agent/doctrine"
    for Worker/start_chat: (same shape)
    repo ./chats symlink: /home/mvazque2/chats/AgentSuite/
    repo ./chats/Agent/doctrine reachable? false

Which branch wins in production depends on where the deployed start_chat
lives: if agents are served from the repo's own store behind the `chats`
symlink (chats -> /home/mvazque2/chats/AgentSuite/), the physical file is
/home/mvazque2/chats/AgentSuite/Agent/doctrine (branches 1/2 territory);
if agents are installed user-level, `LLM.load_agent` itself looks in
`Scout.chats.Agent[<name>]` (= /home/mvazque2/.scout/chats/Agent/...) and then
the import resolves through branch 5 to
/home/mvazque2/.scout/chats/Agent/doctrine. In this sandbox NEITHER target
exists (`/home/mvazque2/chats/` is absent and `/home/mvazque2/.scout/chats`
is absent), so `Chat.chat` raises "Import not found: Agent/doctrine"
(reproduced by the superseded tmp/p6_cortex_self_reference.rb).

Resolution rule (source-verified, WEAK for the exact winning branch, STRONG
for the algorithm): `import: <file>` is resolved by `Chat.find_file` in the
order relative-to-importing-chat-file, caller_lib_dir, literal path, remote
URL, and finally the user-level Scout.chats pathmap; the search is not
restricted to the importing repo.

Verdict: `import: Agent/doctrine` is resolved by `Chat.find_file` to the
AgentSuite chat store's Agent/doctrine file - either the repo's
`chats/Agent/doctrine` (symlink -> /home/mvazque2/chats/AgentSuite/Agent/
doctrine) or the user-level /home/mvazque2/.scout/chats/Agent/doctrine,
depending on deployment; inside this sandbox both are absent (dangling
symlink), so the import currently raises "Import not found" here. That is a
sandbox artifact, not a repo defect; no fallback is needed for the rollout
decision because probes 4/6/8 prove the propagation semantics with the same
file contents.

## Probe 3: full agent inventory

Method: `find . -maxdepth 2 -name start_chat`.

    ChatAnalyst/start_chat
    ComputerUse/start_chat
    Consultant/start_chat
    Cortex/start_chat
    Critic/start_chat
    Manager/start_chat
    Planner/start_chat
    ScoutCoder/start_chat
    Searcher/start_chat
    User/start_chat
    Visualizer/start_chat
    Worker/start_chat
    WorkflowCoder/start_chat
    count: 13

Exactly the 13 expected agents; no extra, no missing. Beyond the expected 13
the repo root also holds: Branched/ (a workflow, no start_chat), FitAgent/ (a
separate workflow checkout; its start_chats live under FitAgent/.crap/... /
sandbox/ dirs and are not AgentSuite agents), Planned/ (workflow), lib/ (empty),
plus repo-level files doctrine, society, intro, cortex_path_map.yaml, and one
stray empty untracked file named `]` (git status `?? ]`, zero bytes - worth
deleting at some point, not part of this task).

Verdict: inventory matches the expected 13; nothing to flag except the stray
zero-byte file `]` and the non-agent dirs Branched/, FitAgent/, Planned/
which carry no start_chat.

## Probe 4 (GO/NO-GO): do `tool:`/`introduce:` lines inside the imported doctrine take effect for the importing agent?

Evidence strength: STRONG (runtime, production functions; two documented
sandbox deviations, see "Deviations").

Script: tmp/p4hermetic_doctrine_propagation.rb (output tmp/p4_out.txt). It
copies doctrine and society into a scratch `tmp/p4_chats/Agent/` dir, places
copies of each start_chat next to it, and runs the production chain
`Chat.parse -> Chat.indiferent -> Chat.imports -> Chat.tools` on Critic,
ComputerUse, and Worker (agents whose own start_chats carry NO Cortex tool
line). Output verbatim:

    preloaded: ["AgentWorkflow", "ComputerUse", "ComputerUse", "Cortex", "ScoutCoder"]

    == Critic
      own start_chat tool lines:      ["tool: ComputerUse"]
      own start_chat introduce lines: ["introduce: ComputerUse"]
      effective tool table (41 tools): [:bash, :copy, :cortex_activity, :cortex_brief, :cortex_continue, :cortex_edit, :cortex_entity_property, :cortex_list, :cortex_move, :cortex_property_define, :cortex_property_history, :cortex_property_list, :cortex_property_read, :cortex_property_remove, :cortex_property_update, :cortex_property_validate, :cortex_read, :cortex_read_list, :cortex_remove, :cortex_rename, :cortex_search, :cortex_write, :cortex_write_list, :current_time, :delete, :docx2md, :file_stats, :html2md, :html_query, :list_directory, :patch, :playwright, :pwd, :python, :r, :read, :ruby, :sandbox_paths, :search, :searxng, :write]
      cortex_* tools present: 21 -> [:cortex_activity, ..., :cortex_write_list]

    == ComputerUse
      own start_chat tool lines:      []
      own start_chat introduce lines: ["introduce: ComputerUse"]
      effective tool table (21 tools): [21 cortex_* tools]
      cortex_* tools present: 21 -> [:cortex_activity, ..., :cortex_write_list]

    == Worker
      own start_chat tool lines:      ["tool: ScoutCoder"]
      own start_chat introduce lines: ["introduce: ScoutCoder"]
      effective tool table (47 tools): [:bash, ... 21 cortex_* ..., :help_get_repo_document, :help_list_repo_documents, :help_list_repos, :help_list_workflows, :help_overview, :help_workflow, ...]
      cortex_* tools present: 21 -> [...]

ComputerUse is the cleanest case: its own file declares only `introduce:
ComputerUse`, yet all 21 cortex_* tools appear in the effective table - they
can only have come from the imported doctrine's `tool: Cortex` line. (In the
probe, ComputerUse's own task tools are absent because its granular `exec_task:
ComputerUse pwd` is a task exec, not a `tool:` grant; `tool:`-less
`introduce:` alone adds docs, not tools - consistent with the source.)

Source corroboration (WEAK, quoted): `Chat.tools` in
.../scout/llm/chat/process/tools.rb iterates ALL messages and merges
`tool:`/`introduce:`/`kb:`/`mcp:` regardless of which file they came from:

    new = messages.collect do |message|
      role = message[:role]
      ...
      elsif role == 'tool'
        workflow_name, task_name, *inputs = content_tokens(message)
        ...
        if task_name
          definition = LLM.task_tool_definition workflow, task_name, inputs
          tool_definitions[task_name] = [workflow, definition]
        else
          tool_definitions.merge!(LLM.workflow_tools(workflow))
        end
        next

and `Chat.imports` (files.rb) splices the imported file's messages into the
message list BEFORE `Chat.tools` runs (chat.rb line 51-55 order: imports,
clear, clean, config, tasks, jobs, files, then tools). There is no per-origin
filter, so imported directives take effect exactly like local ones.

Verdict (GO): YES - `tool:`/`introduce:` lines inside the imported doctrine
propagate to every agent importing `Agent/doctrine`; runtime proof on three
agents with no Cortex tool lines of their own, corroborated by source.
Doctrine-carries-recall-tools works; per-file fallback (spec section 7) is
NOT needed.

## Probe 5: does `introduce: Cortex` inject the full Cortex README? Size?

Evidence strength: STRONG (runtime measurement of the exact injected string;
tmp/p568_hermetic.rb -> tmp/p568_out.txt).

Source (.../chat/process/tools.rb, introduce branch):

        workflow = Workflow.require_workflow workflow_name ...
        next if workflow.documentation.empty?
        content = <<-EOF
    # Documentation for the '#{workflow_name}' workflow: #{workflow.documentation[:title]}

    #{workflow.documentation[:description]}
        EOF
        {role: :user, content: content}

So `introduce: Cortex` injects ONLY title + description (the README's
front-matter `title` and `description` fields), NOT the task docs, not
`documentation_markdown`. Measured from the locally loaded Cortex workflow:

    title:      "# Persistent research workspace for agent conversations, briefs, and durable artifacts"
    description chars: 13862
    injected block chars: 13993
    injected block words: 1906
    approx tokens (chars/4): 3498
    documentation keys: [:title, :description, :task_description, :tasks]
    documentation_markdown chars: 32959

(The 13993-char injected block matches exactly the "Documentation for the
'Cortex' workflow" text this very agent received in its own context.)

Verdict: `introduce: Cortex` injects a ~14.0k-char (~1.9k word, ~3.5k token)
user message built from the README title+description; it does NOT inject the
full 33.0k-char documentation_markdown or the task list.

## Probe 6: self-reference safety (Cortex agent)

Evidence strength: STRONG (runtime; same probe file).

Loaded Cortex/start_chat (imports Agent/doctrine AND Agent/society; doctrine
ends with `introduce: Cortex` + `tool: Cortex`), then ran imports + tools:

    -- Cortex: after imports: tool=2 ["Cortex", "ComputerUse"]; introduce=2 ["Cortex", "ComputerUse"]
       introduce would resolve: Cortex
       introduce would resolve: ComputerUse
       user messages already carrying Cortex docs after imports: 0
       total messages after imports: 7
    (from p568_out.txt, probe 6 section)
       Chat.tools completed in 0.0s without error: 41 tool definitions
       cortex_* tools: 21
       Cortex doc user-messages after tools (dedup check): 1

- No recursion: `introduce: Cortex` resolves the WORKFLOW (its workflow.rb),
  never the agent chat file; the doctrine import chain terminates because
  imports are expanded once, before tools processing (chat.rb order above),
  and an `import:` inside the doctrine would be another file read, not a
  workflow load loop. Loading finished in 0.0s.
- No duplicate introductions: `Chat.tools` keeps an `introduced_workflows`
  list and `next if introduced_workflows.include? workflow_name`, so a second
  `introduce: Cortex` (e.g. one from the doctrine import plus one written
  later in the agent's own file) collapses to exactly 1 doc message
  (p8_dup_check.rb: "duplicate introduce: Cortex -> user doc messages: 1").
- No load errors: `Chat.tools` returned 41 definitions.

Verdict: the Cortex agent's start_chat is safe under self-reference: one
import expansion, one doc injection, 21 Cortex tools, no recursion and no
duplication.

## Probe 7: granular per-task tool syntax

Evidence strength: STRONG (runtime) + WEAK (source).

Precedents in the repo: `tool: ScoutCoder help_list_repos` etc. in
Searcher (lines 39-43) and Planner (lines 41-45). Note: ComputerUse carries
`exec_task: ComputerUse pwd` (line 18), which is a task EXECUTION directive,
not a granular tool grant - the closest granular `tool:` precedents are the
ScoutCoder lines. `grep -rn "tool: ComputerUse pwd"` over all start_chats:
no match (the task prompt's example does not exist verbatim on disk).

Source (.../chat/process/tools.rb):

    workflow_name, task_name, *inputs = content_tokens(message)
    ...
    if task_name
      definition = LLM.task_tool_definition workflow, task_name, inputs
      tool_definitions[task_name] = [workflow, definition]
    else
      tool_definitions.merge!(LLM.workflow_tools(workflow))
    end

`LLM.task_tool_definition` builds a single-task tool definition; the table is
keyed by task name, so per-task grants are exactly one entry each.

Runtime (tmp/p7_hermetic.rb -> tmp/p7_out.txt), applying Chat.tools to
`tool: Cortex cortex_list` / `cortex_search` / `cortex_read` / `cortex_activity`
plus `tool: ScoutCoder help_list_repos`:

    granular tool: results -> ["cortex_activity", "cortex_list", "cortex_read", "cortex_search", "help_list_repos"]
    cortex_* keys: ["cortex_activity", "cortex_list", "cortex_read", "cortex_search"]
    names collide with ScoutCoder help task? []
    cortex_read definition keys: [:name, :description, :parameters]

Verdict: granular `tool: <Workflow> <task>` is fully supported by the same
parser branch, works for Cortex exactly as for ScoutCoder, produces clean
one-entry-per-line tables; the only caveat is that entries are keyed by task
name alone, so two workflows must not expose same-named tasks (Cortex task
names are all `cortex_`-prefixed, so no collision with ScoutCoder/ComputerUse).

## Probe 8: how does the Cortex agent currently get its Cortex tools?

Evidence strength: STRONG (runtime) + WEAK (source).

Cortex/start_chat's own directive lines are (grep, verbatim):

    1:import: Agent/doctrine
    2:import: Agent/society
    89:introduce: ComputerUse
    90:tool: ComputerUse

There is no `tool: Cortex` line in the file, yet the agent resolves the full
21-task Cortex table - this comes ENTIRELY from the imported doctrine's
trailing `tool: Cortex` (probe 4 mechanism; p568_out.txt probe 8 section:
"Chat.load_workflow calls during tools: ["Cortex", "ComputerUse"]", and the
Cortex entry is produced while processing the doctrine-imported messages).

Resolution of the name "Cortex" in `tool:`/`introduce:` goes through
`Chat.load_workflow` (.../chat/process/tools.rb):

    def self.load_workflow(workflow)
      workflow = begin
                   Kernel.const_get workflow
                 rescue
                   if Scout.chats.Agent[workflow]['workflow.rb'].exists?
                     Workflow.require_workflow_file Scout.chats.Agent[workflow]['workflow.rb'].find
                     Workflow.main || Workflow.workflows.last
                   else
                     Workflow.require_workflow(workflow)
                   end
                 end
    end

i.e. a preloaded constant wins; otherwise the agent-dir workflow.rb
(chats/Agent/Cortex/workflow.rb) is loaded from file; otherwise the
installed-workflow autoinstall path (`Workflow.require_workflow`). There is
no agent-name-to-workflow special casing beyond this. Note also
`LLM.load_agent` (agent.rb lines 169-190) has its own independent lookup
(Scout.workflows[name], then Scout.var.Agent, Scout.chats.Agent,
Scout.chats[name]); in this sandbox that lookup failed with "No agent found
with name Cortex" (superseded probe tmp/p8_cortex_agent_tools.rb) because the
`chats` symlink target is missing - again a sandbox artifact.

Would appending an explicit `tool: Cortex` to Cortex/start_chat be correct
and harmless? Yes: `tool_definitions.merge!(LLM.workflow_tools(workflow))`
merges by task-name keys, so a duplicate grant is idempotent - p8_dup_check.rb
ran a doctrine-imported `tool: Cortex` plus an explicit second `tool: Cortex`:

    tool table size after duplicate 'tool: Cortex': 21
    keys: [:cortex_activity, ..., :cortex_write_list]
    duplicate introduce: Cortex -> user doc messages: 1

Same 21 tools, no error, no duplicated doc message (the introduce dedup list
from probe 6 covers the docs side). It is redundant once the doctrine carries
the four granular recall lines, but not harmful.

Verdict: the Cortex agent's tools come from the doctrine import today
(`tool: Cortex` at doctrine line 159) resolved via Chat.load_workflow; an
explicit `tool: Cortex` appended to Cortex/start_chat would be harmless and
idempotent (21 tools either way, single doc message) but redundant with the
doctrine lines after the rollout.

## GO/NO-GO decision

DECISION: GO for the doctrine-carries-recall-tools mechanism (spec section
2.9's primary path).

Basis: probe 4 (STRONG runtime evidence). Agents with no Cortex tool lines of
their own (Critic: only `tool: ComputerUse`; ComputerUse: none at all; Worker:
only `tool: ScoutCoder`) all ended with all 21 `cortex_*` tools in their
effective tool table after processing their start_chats through the
production `Chat.imports` + `Chat.tools` path; the only possible origin is
the imported doctrine's `tool: Cortex` line. Source inspection of
`Chat.tools`/`Chat.imports` corroborates that imported directives are
processed identically to local ones, with no per-origin filtering.

Consequence for the spec: put the four recall lines
(`introduce: Cortex` + `tool: Cortex cortex_list|cortex_search|cortex_read|
cortex_activity`) in the doctrine (section 2.9 primary), and do NOT fall back
to per-file wiring in section 7. Consequences verified by probes 5-8: each
importing agent gains one ~14k-char doc message and any subset of Cortex
tasks chosen per line; dedup protects double introductions; the Cortex agent
itself stays recursion-free.

## Deviations

1. Import resolution in probes 4/5/6/8 used a scratch `tmp/p4_chats/Agent/`
   (and `tmp/p568_chats/Agent/`) directory holding copies of `doctrine` and
   `society`, with the start_chat copies placed next to it. Reason: the
   production `chats -> /home/mvazque2/chats/AgentSuite/` symlink is dangling
   inside this sandbox (its target does not exist here), so branch 1/2 of
   `Chat.find_file` (dirname(original)/Agent/doctrine, caller_lib_dir) is
   simulated by co-locating the files. This exercises the same
   `Chat.find_file` -> `Chat.imports` code path with the same file contents;
   it does not change directive-processing semantics.
2. `Workflow.require_workflow("ComputerUse")` (called from
   ScoutCoder/workflow.rb) and the bare name lookup for ScoutCoder hang in
   this sandbox on a git-clone autoinstall attempt (ssh config unreadable,
   "Updating: ..." repeated in stderr, timeout rc=124). Probes therefore
   preloaded the repo's own ComputerUse/Cortex/ScoutCoder workflow.rb files
   with `Workflow.require_workflow_file` and aliased
   `Workflow.require_workflow` to `Kernel.const_get` fallback. This is the
   same resolution `Chat.load_workflow` performs first (`Kernel.const_get
   workflow`), so the tool-table result is unaffected.
3. Earlier probe variants (tmp/p6_cortex_self_reference.rb,
   tmp/p8_cortex_agent_tools.rb) tried `LLM.load_agent` and failed with
   "No agent found with name Cortex" / "Import not found: Agent/doctrine" -
   both consequences of the same dangling symlink, documented here rather
   than retried; the hermetic variants supersede them.
4. The task text cites `tool: ComputerUse pwd` as precedent in
   ComputerUse/start_chat; on disk the line is `exec_task: ComputerUse pwd`
   (an exec directive, not a tool grant). The granular-tool precedent used
   instead is the ScoutCoder line set in Searcher/Planner, which is a true
   `tool:` granular syntax. Reported as a deviation between task premise and
   disk state, not silently adopted.
5. No LLM inference was run at any point; all probes build agents/chats and
   resolve tool tables only, as instructed.
