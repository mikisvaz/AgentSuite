# Agent override directories and tool provisioning (research note 05)

**Scope**: the exact mechanism by which a scenario-local Agent override is
expressed, discovered, and mutated — the "create a Agent override folder"
step of the user's schema. **Evidence**: verified against scout-ai 2.0.0
gem internals (Cortex `verifications/scout-ai-2.0.0-internals.md` v1) and
AgentSuite agent definitions on disk.

## 1. What an agent IS

An agent is a directory `Agent/<Name>` containing at minimum
`Agent/<Name>/start_chat` (system instructions + wiring). `Scout.Agent[name]`
(or `Agent[name]` in code) resolves through **path maps**: `:current`
(PWD/`lib_dir`), then `:lib` (chat-anchor libdir), then `:user`
(`~/.scout/agents`), then configured maps — first match wins. This
resolution order is the override mechanism:

- Staging `sandbox/Agent/Worker/start_chat` and running the inner agent
  with PWD = sandbox makes `Agent['Worker']` resolve to the override, not
  the global Worker. Verified behavior in scout-ai 2.0.0 (`Agent.load`
  consults `Scout.agents` `:current` map first).
- FitAgent's `use_case` already stages exactly this shape
  (`Open.cp agents, sandbox.Agent`) and runs `Misc.in_dir sandbox`.

## 2. `start_chat` = instructions + tooling in one file

The file is compile-time chat configuration (see `.save` legacy
documentation and current agent files):

```
import: Agent/doctrine          # pull another chat as prefix
system: <instructions text>
introduce: ComputerUse          # expose workflow documentation
tool: ComputerUse patch         # expose a single task as a tool
tool: ComputerUse               # expose every task as tools
file: ./README.md               # attach a file to the prompt
```

Consequences:

1. **Instruction mutation** = editing the `system:` prose.
2. **Tooling mutation** = editing the `introduce:`/`tool:` lines — e.g.
   `tool: ComputerUse patch` (task-scoped, full inputs) vs `tool:
   ComputerUse` (whole workflow) vs removing a tool entirely. The Cortex
   brief `tools` grammar (`Workflow [task [input|name=value ...]]`,
   `noinputs`, hidden pre-filled inputs) is the richest existing
   description of this grammar and is directly reusable for override
   diffs.
3. `import:` chains (`Agent/doctrine`, role contracts) mean an override
   that changes only `system:` text still inherits doctrine; an override
   may also drop an `import:` — a valid but high-blast-radius mutation.

## 3. Tool resolution inside the sandbox

Inner agents resolve workflow tools from the sandbox's `workflows/` dir
(FitAgent links MiniTools always; the `wf_search` list includes
`dirname(FITAGENT_ROOT)` = the AgentSuite dir, so linking
`ComputerUse` is checkout-anchored). `SCOUT_WORKFLOW_AUTOINSTALL=false`
prevents GitHub autoinstall attempts offline. `BWRAP_PATH=false` means
inner exec tasks run unsandboxed children — scenario fixtures must not
rely on inner sandboxing for isolation; isolation comes from the staged
sandbox directory itself.

## 4. Candidate representation for the improvement loop

A candidate = one directory `<repo>/agents/<Gen>` (the `evolve` task's
convention) or, per the user's schema, a **scenario-local** override dir
(e.g. `<sandbox>/Agent/Worker/`). Recommended layout for the catalogue
experiment:

```
candidates/
  baseline/Agent/Worker/start_chat        # copy of the global agent
  gen1/Agent/Worker/start_chat            # weak-model proposal
  gen2/Agent/Worker/start_chat
```

with the runner staging `candidates/<c>/Agent` into `sandbox/Agent` per
arm — identical mechanism to `evolve`, but tool wiring is allowed to
change (v1 restriction lifted: the proposal prompt must NOT be told to
preserve `tool:` lines; instead a validator re-checks that required tools
for the scenario remain present, since a proposal that drops `patch`
outright will fail the functional rubric anyway).

## 5. Fixpoint/cache discipline

Editing a `start_chat` without changing task inputs can serve a stale
cached job (documented pitfall). The runner must therefore derive job
names from a digest of (scenario id, candidate id, generation, rubric
version) — as `evolve` does with `#{experiment}_#{agent}_g#{gen}` — never
from the fixed input set alone.

## 6. Open question

Whether `evolve`-style whole-start_chat rewrites (weak model) tend to
break the `import:`/`tool:` lines syntactically; mitigation is the
validator above plus a grammar check before staging. Empirical question
for the first iteration; the no-op guard in `evolve` (identical proposal
modulo whitespace stops the lineage) is the template for the stopping
rule.
