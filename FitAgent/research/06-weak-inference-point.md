# The `weak` inference point: mechanism and use in the loop (research note 06)

**Scope**: how a named cheap endpoint ("weak") is selected, configured, and
enforced for recommendation/proposal steps while stronger endpoints run the
agent-under-test. **Evidence**: Cortex `verifications/weak-endpoint-mechanism.md`
(v1); FitAgent `workflow.rb` endpoint plumbing; `etc/AI` on disk.

## 1. Endpoints are named files

An inference point = a file under `etc/AI/<name>` (repo-level) or
`~/.scout/etc/AI/<name>` (user-level), YAML with provider params (`type`,
`host`, `model`, `key`...). Selection: the `-e <name>` flag of `scout-ai
agent ask`, an `endpoint:` line in a chat file header, or
`LLM.chat.endpoint` in code. A chat that omits it uses the user default.
`weak` is therefore **just another endpoint file** — nothing about it is
special to the framework; the FitAgent loop makes it special by policy.

## 2. What exists today

- FitAgent `etc/AI` contains only `qwen` and `glm53` — **no `weak`** (gap;
  needs the user's credentials/model choice).
- FitAgent tasks take a single `endpoint` select input and forward it to
  BOTH the run and the analyst/propose steps (`evolve`'s `propose` lambda
  calls `l.endpoint endpoint`). So today the proposal step uses the same
  endpoint as the run — a fixpoint the user explicitly wants broken
  ("recommendations based on a weak and cheap model").
- `use_case` materializes sandbox `etc/AI` from the repo copy with keys
  injected from `SCOUT_AI_<NAME>_KEY` env vars (openwebui backend cannot
  resolve `env:` placeholders). A `weak` file must exist in the repo's
  `etc/AI` (or be staged per-run) for inner runs to select it.

## 3. Design: split endpoints by role

Introduce two distinct selects:

```
endpoint   — agent-under-test runs (strong; e.g. qwen)
weak_endpoint — proposals, analyst summaries, scenario/rubric drafts
```

Where the weak point is actually invoked:

1. `evolve`-style proposal of the next `start_chat` (feed rubric JSON +
   analyst rationale; request full start_chat text) — today's `propose`
   lambda, minus its "keep tool wiring unchanged" instruction, plus a
   post-hoc validator.
2. Rubric/feedback summarization when deterministic output is too large to
   paste raw into the proposal prompt (compress failures to patterns).
3. NOT for: the agent-under-test itself, or the final ChatAnalyst
   qualitative verdict (that one benefits from strength; keep it on the
   strong endpoint, or drop it — it does not gate the score).

## 4. Verification and audit requirements

- The proposal job's chat must record which endpoint produced it (meta
  evidence carries endpoint/model per inference; `chat_agents` /
  `meta_evidence` can audit it post-hoc). The candidate directory should
  record `proposed_by: <endpoint>@<job>` so lineage is self-describing.
- Budget enforcement: `chat_tokens`-based caps per arm; weak-endpoint calls
  are cheap but unbounded retries are not — cap proposals per generation
  (e.g. 1 proposal, 2 repair attempts on validator failure).

## 5. Fallback if no credentials for a second model

Policy degenerates gracefully: `weak_endpoint` may point at the same
backing model as `endpoint` (e.g. `qwen` with a smaller model name on the
same openwebui host). The loop semantics (cheap proposals, strong runs)
are preserved as long as the two files select different models. If only
one model exists at all, set both to it and record the limitation in the
experiment header — the loop remains functional, only the
cost-tiering claim is lost.

## ADDENDUM 2026-09-05 — user decision: weak endpoint dropped

"For now forget about the weak endpoint, don't specify an endpoint at all, it
should use the default, glm5."

Consequences:
- O5 is CLOSED. The proposal path (evolve) and any recommendation step run
  with NO endpoint option: `LLM.chat` without `.endpoint`, and no `-e` flag
  in agent launches — resolution falls to the global default (this host:
  glm5 via etc/AI `glm53`, model glm-5.3; verified `etc/AI/` listing).
- Mechanism note (scout-ai 2.0.0 `lib/scout/llm/ask.rb:31`): `endpoint ||=
  Scout::Config.get :endpoint, :ask, :llm, env: 'ASK_ENDPOINT,...'`; when
  nil/empty no etc/AI overlay is applied and the chat's own options stand.
  So "no endpoint specified" is a real, supported state — nothing to build.
- FitAgent's existing `:endpoint` inputs (`:qwen` defaults on use_case/
  analyze/compare/evolve) remain for the *run* arms; the improvement loop
  must simply not pass one. Any new loop task should omit endpoint inputs
  entirely rather than defaulting them.
