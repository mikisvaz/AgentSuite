# Deterministic transcript evaluation: ChatAnalyst task surface (research note 04)

**Scope**: which existing tools can implement the user's "rubric ... at the
level of the message array, using ChatAnalyst tooling" — deterministically,
without an LLM in the loop. **Evidence**: full read of
`/bulk/mvazque2/git/AgentSuite/ChatAnalyst/workflow.rb` (1159 lines) task
signatures and bodies (spot sections read in depth: `message_index`,
`chat_tool_calls`, `chat_report`), plus its `start_chat`. Cortex receipt:
`findings/agentsuite-components-available.md` (v1).

## 1. Task inventory (all `export_exec`, all deterministic Ruby)

| Task | Purpose | Key inputs |
| --- | --- | --- |
| `message_index` | flat message list with roles, fingerprints, lineage ids, truncated meta | `file`, `role`, `page/per_page`, `follow` |
| `message_content` | full content of selected messages | `file`, `ids` (addresses) |
| `chat_overview` | high-level shape of a session tree | `file`, `follow` |
| `chat_tool_calls` | **tool-call index**: total/successes/failures/incomplete, `by_tool` histogram, per-call records (address, tool, success, arguments), `dedupe` for socialized copies | `file`, `follow`, pagination, `dedupe` |
| `chat_tokens` | token usage with evidence locations, receipt coverage | `file`, `follow` |
| `chat_agents` | which agents ran where | `file`, `follow` |
| `meta_evidence` | provenance resolution of meta lines | `file`, `origin`, `full` |
| `chat_reasoning` | reasoning trace segments | `file`, `addresses` |
| `chat_report` | combined provenance/token/delegation snapshot incl. `delegation` rollup and deduplicated totals | `file`, `follow` |
| `provenance_relationships` | edge list (job, dependency, log, result, agent_job) | `file` |
| `chat_accounting` | scoped accounting | `file`, `follow`, `scope` |

The universal input `file` accepts **a root chat file OR a chat-producing
job** (`jobname: true, nofile: true`), and `follow` selects provenance
relations to traverse (`all` default). So pointing these tasks at a
`use_case` job automatically pulls in delegated sub-agent chats — exactly
the shape FitAgent's runs produce.

## 2. Mapping to the user's rubric levels

**Level 1 — functional/deterministic file checks** (does the patched file
match expected): NOT ChatAnalyst. This is plain filesystem comparison in
the outer job (`File.read` vs `expected/` fixtures). The rubric runner owns
it.

**Level 2 — message-array checks** (e.g. "one or two tool calls to `patch`,
then a `write` call with parameter X"): `chat_tool_calls` supplies the raw
material: per-call `tool` name, ordering (array order), `success`, and
arguments. A thin rule layer on top (JSON rules: expected tool sequence,
count ranges, argument matchers) completes it. `by_tool` gives instant
histogram assertions. `dedupe: true` handles the historically documented
double-recording of tool calls (once in chat file, once in agent.chat
projection).

**Level 3 — cost bounds**: `chat_tokens` / `chat_report.tokens` give
deduplicated totals incl. delegated subtrees; `chat_report.delegation`
splits root vs delegated spend. This supports per-arm budget caps and the
"weak inference point used for proposals" audit (which endpoint produced
each inference is recorded in meta evidence).

**Level 4 — qualitative ChatAnalyst assessment**: the existing
`FitAgent#analyze` task already does this (LLM agent + yaml verdict block).
Keep as optional garnish; not part of deterministic scoring.

## 3. Calling convention for FitAgent

ChatAnalyst is a Workflow; from the outer FitAgent job the deterministic
level-2/3 evaluation is a normal dependency or `Workflow.require_workflow`
call, e.g. `ChatAnalyst.job(:chat_tool_calls, nil, file: <use_case job>,
follow: 'all', dedupe: true).produce` → JSON result in-job, cacheable, with
provenance. No LLM, no endpoint needed. Alternatively the CLI:
`scout workflow task ChatAnalyst chat_tool_calls --file <job> --dedupe`.

Alternatively — and lighter for v1 — parse `sandbox/main.chat` directly with
`Chat.parse` / `Chat.tool_calls` gem primitives; ChatAnalyst adds
provenance-walking and dedup on top, which matters once the agent-under-test
delegates (nested chats, receipts). Recommendation: use ChatAnalyst jobs for
the rubric's transcript level from the start; the `file:`-accepts-job
convention makes it a one-liner and it future-proofs delegation.

## 4. Rubric schema implication

A rubric file should therefore express three tiers:

```yaml
functional:            # evaluated by the rubric runner (filesystem)
  - scenario: F01-small-one-line
    expect_file: src/hello.rb        # after-state must equal expected/
    verdict_when_diff: FAIL_CONTENT
message_rules:         # evaluated via chat_tool_calls (deterministic)
  - tools: ["patch"]                 # allowed tools for the run
    counts: { patch: 1..2 }
    sequence: [ {tool: patch}, {tool: read, optional: true} ]
    args: { patch: { dry_run: false } }
budget:
  max_tokens: 200000                 # via chat_report.tokens.deduplicated_total
analyst:              # optional, tier 4
  enabled: true
  verdict_from: analyze.yaml_block
```

Each tier scores independently; the combined verdict is
`functional PASS ∧ message_rules PASS (budget = advisory cap, breach =
FAIL_BUDGET)`; `analyst` is reported alongside, not gating.

## 5. Verified caveats

- `chat_tool_calls` returns raw counts alongside `dedupe` marking; summary
  counts stay raw by design — the rule layer should use `unique_calls`
  when dedupe is on.
- The `.save` legacy note (SC26 era) about transcripts under
  `~/.rbbt/var/jobs/...` no longer applies to FitAgent runs:
  `use_case` records `sandbox/main.chat` in-job, which is the `file:`
  argument to pass.
