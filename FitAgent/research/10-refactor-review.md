# Refactor review: FitAgent library vs script separation (note 10, v1)

Date: 2026-09-06. Status: decision document for the refactor round; verdicts
here are consumed by the subsequent spike and cleanup steps. Verified against
the live checkout at `/bulk/mvazque2/git/AgentSuite/FitAgent` (commit
`7010ab4` + uncommitted working tree; `git status` shows the new-loop files
untracked, see §6.4). Baseline: suite green per prior step (69 tests / 499
assertions / 0 failures / 0 errors / 1 gated live omission — not re-run this
turn). Reference input: Cortex artifact `design/refactor-reference-pack.md`
(v1, 2026-09-05).

## 1. Purpose of the round and scope

**Purpose.** The new code under `lib/FitAgent/` grew script-shaped: an
embedded child-process session script duplicated across two files, hand-rolled
environment staging (temp HOME, etc/AI copy, BWRAP_PATH, CU_CHECKOUT), and
ad-hoc drivers under `tmp/`. This round (a) justifies every element with a
verdict, (b) resolves the sandboxing convolution at its root — possibly by
replacing hand-rolled child-process execution with framework-native execution
(`AgentWorkflow` chat-task / workflow-job), (c) separates library from script,
**preserving behavior** throughout.

**Scope boundaries.**

- No behavior change: rubric/scenario fixture bytes and `manifest.json`
  digests must not drift; scores for identical inputs stay identical.
- Task names and inputs stay backward compatible this round (no renames —
  external compatibility unconfirmed).
- Canonical agent definitions (`agents/`, `Agent/` suites outside staged arm
  boxes) are never touched.
- Scoring stays pure Ruby over recorded evidence (work trees + chat
  transcripts); no model calls enter the scorer.

**Deferred (out of scope this round, recorded):**

- C02 rubric `output_contains` reachability fix — a rubric design change,
  versioned separately from this refactor (see `scenarios.rb` C02 note: under
  bwrap the sandboxed run loses GNU patch's own message; the current
  `['FAILED', 'Hunk #1 FAILED']` pair is the live-verified compromise).
- C-series fold into the default fit scenario selection (the F/E mini-set is
  baseline-saturated at 1.0; C-series is currently opt-in via `ids:`).

**Hard constraints restated for every later step:** no endpoint or inference
point anywhere in the loop (glm5 by omission — no `ENV['ASK'] =` assignment
may survive into tasks or library code); scoring pure; canonical agents
untouched; task surface frozen; frozen digests stable.

## 2. Element-by-element review (verified this turn)

Sizes are `wc -l` on the live files. Callers verified by grep across
`lib/ workflow.rb test/ tmp/ research/ README.md` this turn.

| # | Element | Size | Purpose (one line) | Verified callers | Verdict | Reason |
|---|---------|------|--------------------|------------------|---------|--------|
| 1 | `lib/FitAgent/scenarios.rb` | 615 | Declarative catalogue: F/E/C definitions, materialize into scenario.yaml/rubric.yaml/patch.txt/work/expected + digest manifest | `workflow.rb:453` (catalogue), `:484` (score), runner/evolve indirectly; tests `test_scenarios`, `test_contrived_scenarios`, `test_scoring`, `test_runner`, `test_evolve`, `test_fit_task`; tmp drivers | **keep** | Pure seeded generator, digest-stable, no inference; exactly what a library should be. Only defect is a stale header comment (§5.2). |
| 2 | `lib/FitAgent/scoring.rb` | 228 | Pure tiered evaluator: functional (diff/absent/residue) + message rules (count, output_contains, applied, max_total_calls, forbid_after_failed) via `Chat.tool_calls` | `workflow.rb:506` (score), `runner.rb#run_arm`; tests `test_scoring`, `test_contrived_scenarios` | **keep** (absorb `scores_tsv` from runner, §5.3) | Pure, model-free, evidence-only; the round's constraints are already its invariants. Absorbing the TSV presentation keeps rubric semantics and their projection in one place. |
| 3 | `lib/FitAgent/runner.rb` | 325 | Stages pristine arm boxes (scenario copy + Agent override), runs one arm through an injected agent-turn object, writes scores.tsv/json + arms.json | `workflow.rb:468` (override → `write_override`), `:544` (run_arms); tests `test_runner`, `test_evolve`, `test_fit_task` | **keep, split** (§5.3) | Staging + run loop is genuine library code; `scores_tsv` (projection/policy) and the `Dir.pwd` default (§5.1) are the script-shaped parts to move/fix. |
| 4 | `lib/FitAgent/evolve.rb` | 409 | Loop policy: propose→stage→run→score + stop rules (budget / all_pass / no_op_twice / regression); evolution.json writer | `workflow.rb:563–580` (fit); tmp drivers (`tmp/contrived/run_fit_contrived_1.rb` re-wires it manually) | **keep** (fix `Dir.pwd` default, §5.1) | Deterministic, proposer-injected, fully testable offline. Loop logic must stay a library; only the PWD-dependent output default is a wart. |
| 5 | `lib/FitAgent/proposer.rb` | 134 | `DefaultProposer`: model proposal of instructions/tools, YAML/grammar validation hooks, ≤2 repairs | `workflow.rb:564` (fit); tests `test_proposer` | **keep** | Correct layering: the only model-touching library unit, injectable chat builder, endpoint by omission already enforced. |
| 6 | `lib/FitAgent/agent_turn.rb` | 290 | Two things: (a) `LiveAgentTurn` — single scripted ComputerUse `patch` tool call in a child process; (b) a **stale full `LiveAgentChat` class** (l.173–290) with its own `SESSION_SCRIPT` | `LiveAgentTurn`: `test_helper.rb:9` (require), `test_e2e_smoke.rb` (instantiated), `test_proposer.rb` (require only). Production callers: **none** (fit uses `FitAgent::LiveAgentChat`, which this file pre-defines and agent_chat.rb reopens). The stale `LiveAgentChat` half: no direct callers — shadowed by agent_chat.rb | **pending spike** (execution path) — but the stale `LiveAgentChat` class inside this file is **remove** regardless of the spike outcome | The reopen is the root of the "already initialized constant SESSION_SCRIPT" warning (confirmed: `tmp/fit_real/run_fit_pm2.err:1`). Two `LiveAgentChat` definitions across two files is exactly the convolution under review; whichever execution mechanism wins, there must be exactly one class in exactly one file. `LiveAgentTurn` itself (deterministic patch-call executor) is pending spike: keep if the e2e smoke still needs a no-model live path, fold otherwise. |
| 7 | `lib/FitAgent/agent_chat.rb` | 207 | `LiveAgentChat` (effective, reopened): full agent session per scenario — child Ruby, PWD=work/, temp HOME + etc/AI copy, BWRAP_PATH=false, CU_CHECKOUT, embedded SESSION_SCRIPT | `workflow.rb:572` (fit, agent_factory); tests `test_agent_chat` (asserts on SESSION_SCRIPT content), `test_fit_task` (require) | **pending spike** | This file exists BECAUSE agent-load and ComputerUse.root depend on the child's PWD/path maps; whether a framework-native chat-task/job provides the same isolation natively is the spike question (§3). Either way it must end as ONE thin file (no duplicate class, no duplicated script constant). |
| 8 | `lib/FitAgent/fitagent_live_chat.rb` | 70 | The child session script materialized as a repo file by `agent_chat.rb#session_script` (l.129) — byte-identical to the `SESSION_SCRIPT` constant after dedent (verified SHA1 this turn) | Written by `agent_chat.rb`; executed as the child program (`ruby <script> scenario_dir work out chat_out cu start_chat ai_dir`) | **fold** — becomes the single source of truth if the adapter is retained; **remove** if framework-native wins | Not in the reference pack (new since v1). Duplicating the script as BOTH a heredoc constant and a committed file is the worst of both; if an adapter survives, the script must be a real hand-maintained source file and the constant deleted. |
| 9 | `lib/FitAgent/scenarios.rb.orig` | — | Patch residue | none | **remove** | Junk; nothing references it. |
| 10 | `workflow.rb` — legacy quartet `use_case` / `analyze` / `compare` / `evolve` | 591 total (file) | Sandbox-staging + agent-run harness and LLM-analyst matrix from the pre-loop era (explicit `endpoint` inputs defaulting `:qwen`) | Internal: `compare`→`use_case`/`analyze` jobs (l.286–292), `evolve`→same (l.393–397), `analyze` dep→`use_case`. External/test callers: **none in-repo** (no test touches these four; README documents them as public CLI) | **keep-and-deprecate** (default) until a caller search proves otherwise | Backward compatibility is unconfirmed, so no removal this round; they are also the only place the older explicit-endpoint pattern lives. Record deprecation intent in comments/README; revisit removal after external caller evidence. |
| 11 | `workflow.rb` — loop tasks `catalogue` / `override` / `score` / `run_arms` / `fit` | (same file) | The deterministic loop surface: materialize, stage override, score evidence, run arms, evolve with winner.json | `fit` wires `Evolve` + `DefaultProposer` + `LiveAgentChat` (l.561–589); tests cover catalogue/score/run_arms/fit deterministically | **keep** | Correct layering: tasks are thin, library does the work, agent-turn injection (`agent_factory`) is already the seam the spike needs. `fit`'s winner.json/stop logic duplication with drivers is resolved by folding drivers (§5.4), not by changing the task. |
| 12 | `tmp/` drivers + probe trees (`tmp/fit_real/run_fit*.rb`, `run_catalogue_pm2.rb`, `tmp/contrived/run_fit_contrived_1.rb`, probe dirs) | ~4 drivers + trees | Sanctioned live-run drivers and historical probes; `run_fit*.rb` set `ENV['ASK']='glm53'`; `run_fit_contrived_1.rb` re-derives winner/stop logic instead of calling the `fit` task | manual invocation only | **fold/remove** (§5.4) | tmp/ is disposable by contract. Drivers must not be the way live runs are launched once the `fit` task covers the wiring; the ASK default is an endpoint wart that must not survive anywhere. |
| 13 | `test/FitAgent/tasks/*` (10 suites) + `test_helper.rb` | — | Unit + gated-live coverage of everything above | `rake`/`ruby -Itest` runs | **keep** | The safety net for "preserve behavior"; `test_helper.rb:9` requires agent_turn (updates with verdict 6). |
| 14 | `results/`, `sandbox/` (untracked) | — | Runtime outputs of local runs | — | **clean/gitignore** | Repo hygiene; outputs belong to runs, not the checkout. |

**Differences from the reference pack found this turn** (pack v1, 2026-09-05):

1. **New element 8**: `lib/FitAgent/fitagent_live_chat.rb` exists as a
   committed-by-side-effect repo file — the pack only knew the duplicated
   constant. The script now exists in three places effectively
   (agent_turn.rb constant, agent_chat.rb constant, lib file).
2. **The duplication is worse than "constant duplicated"**: `agent_turn.rb`
   contains a complete stale `LiveAgentChat` class (l.173–290) that
   `agent_chat.rb` *reopens* (Ruby class reopening, not namespacing);
   `workflow.rb` requires agent_turn **before** agent_chat (l.12–13), so the
   live class is a merged franken-class and every load emits the constant
   warning (confirmed in `tmp/fit_real/run_fit_pm2.err:1`).
3. **Two different script materialization sites**: agent_turn writes its
   script to `Scout.var.tmp`, agent_chat writes to `lib/FitAgent/` —
   inconsistent durability policy for the same kind of artifact.
4. **`Dir.pwd/results` default is in `runner.rb#run_arm` too** (l.172:
   `out_root = out_dir || File.join(Dir.pwd, 'results')`), not only in
   `evolve.rb:249` as the pack listed. Both tasks currently pass `out_dir`
   explicitly, so in-repo behavior is safe to tighten.
5. Line counts confirmed; the suite total (69/499) was **not** re-run this
   turn — accepted from the round's verified-green statement.

## 3. Sandboxing decision criteria (the spike)

The spike builds a minimal framework-native session runner — an
`AgentWorkflow` `chat_task` (Cortex-style) per scenario session, with the arm
box staged as the job's working directory, the override staged as the
agent's `start_chat`, ComputerUse introduced as tooling — and runs it over
the gated mini-set (F01, E01, E06) alongside the current `LiveAgentChat`.

**Adopt framework-native if ALL of A1–A5 are observable in one spike run**
(A6–A7 desirable, not blocking):

- **A1 — no hand-rolled staging survives**: FitAgent's session code contains
  no temp-HOME creation, no etc/AI copy, no `BWRAP_PATH` export, no
  `CU_CHECKOUT` constant; isolation comes from the framework's own job
  environment. Observable: grep of the retained session file shows none of
  those tokens (except pass-through documentation).
- **A2 — PWD/path-map parity**: the framework job's process PWD (and hence
  ComputerUse.root / agent path-map anchoring) is the scenario work tree;
  the agent's writes land inside `work/` and nowhere else. Observable: F01
  run mutates only `work/notes.txt`; `sandbox_paths`-equivalent evidence in
  the job shows the allowlist root == the work tree.
- **A3 — endpoint by omission, for real**: inference succeeds in the spike
  with NO endpoint named anywhere and NO `ENV['ASK']` assignment in FitAgent
  code (ambient config only). Observable: ≥1 completed session with token
  meta in its transcript; grep confirms no ASK/endpoint assignment.
- **A4 — transcript parity**: the job produces a chat artifact that
  `Scoring.tool_calls` parses, and mini-set scores match the LiveAgentChat
  baseline run exactly (same verdicts/scores; rubric manifest digests
  identical before/after).
- **A5 — override provenance**: a staged `Agent/<name>/start_chat` is picked
  up by the framework session and recorded as provenance in or beside the
  transcript (equivalent of today's `meta: staged_agent=` line), and the
  baseline arm runs with NO override staged.
- **A6 — per-session timeout**: a hung model call cannot stall the arm loop
  unbounded (framework timeout or job abort observable in a forced-hang
  probe).
- **A7 — debuggability parity**: per-arm session stdout/stderr/logs are
  retrievable from the job record (today: `session.stdout`/`session.stderr`
  in the arm box).

**Retain ONE thin adapter if any of R1–R4 materializes** (after bounded
remediation attempts, i.e. the spike may fix, not just observe):

- **R1 — degenerate port**: achieving A1–A5 in the framework path requires
  FitAgent to re-implement equivalent string-script/env-staging code
  elsewhere (the "framework-native" version is the same script moved).
- **R2 — PWD anchoring impossible**: the chat-task/job cannot be made to run
  with PWD == the scenario work tree (agent resolves the wrong root;
  ComputerUse.root != work) — the exact reason LiveAgentChat exists.
- **R3 — transcript impedance**: the framework chat artifact needs a
  FitAgent-side converter comparable in size to the adapter to become
  parseable by `Scoring.tool_calls`.
- **R4 — control loss**: per-session timeout/resource control (today:
  `timeout N` prefix) is weaker in the framework path and a hung session
  blocks the loop.

In the retain outcome the adapter collapses to: **one file**, one
`LiveAgentChat` class, **one** session script kept as a real source file
(today's `fitagent_live_chat.rb`), no constant duplication, no second class
in `agent_turn.rb`. In the adopt outcome `agent_chat.rb`/`agent_turn.rb` are
replaced by a thin wrapper that constructs and runs the framework job
through the existing `agent_factory` seam; the SESSION_SCRIPT mechanism and
all env staging are deleted.

## 4. Target-state structure map

```
lib/FitAgent/
  scenarios.rb      catalogue (unchanged bytes -> identical digests)
  scoring.rb        pure scorer + scores_tsv projection (absorbed from runner)
  runner.rb         arm staging + run loop only (no TSV projection, explicit out_dir)
  evolve.rb         loop policy (explicit out_dir)
  proposer.rb       DefaultProposer (unchanged)
  session.rb        THE ONE execution mechanism (name illustrative):
                    - adopt outcome: thin wrapper over framework-native
                      chat_task/job (no child script, no env staging)
                    - retain outcome: one LiveAgentChat + the single
                      hand-maintained child script (fitagent_live_chat.rb
                      becomes the source of truth; heredoc constant deleted)
  fitagent_live_chat.rb   only in the retain outcome (real source file);
                          deleted in the adopt outcome
  (agent_turn.rb    removed, or reduced to LiveAgentTurn only if the gated
                    e2e smoke still needs a no-model live path — spike decides)

workflow.rb         9 tasks, same names/inputs (backward compatible):
                    use_case/analyze/compare/evolve  kept, marked deprecated
                    catalogue/override/score/run_arms/fit  kept as-is
                    fit stays the single loop entry; execution mechanism is
                    injected via the existing agent_factory seam

tmp/                disposable only: probes, one-shot drivers; nothing here
                    is load-bearing after drivers fold into `scout workflow
                    task FitAgent fit` invocations
results/, sandbox/  runtime outputs, gitignored, never committed
research/           this review + spike report + cleanup reports
```

The single execution mechanism sits in `lib/FitAgent/session.rb` (one file,
whichever form the spike selects) and is reached only through
`Runner.run_arm`'s injected agent-turn object — never required ad hoc by
tasks or drivers.

## 5. Cleanup verdicts NOT depending on the spike

1. **`Dir.pwd` output defaults (`evolve.rb:249`, `runner.rb:172`) — fix.**
   Both default to `File.join(Dir.pwd, 'results')`; both in-repo callers
   (`run_arms`, `fit` tasks) pass `out_dir` explicitly, so tightening the
   default to `FITAGENT_ROOT/results` (or making `out_dir` required) changes
   no in-repo behavior while removing silent PWD coupling. Tests relying on
   the default are updated in the same commit; suite must stay green.
2. **`scenarios.rb:16` stale header comment — fix.** The header still says
   "E01 … (exit 1, not applied)"; the live rubric (l.316–324, v1.1
   correction) expects `applied=false` + `output_contains: ['FAILED']`
   because the numeric exit code is not observable through the nested CMD
   layer. Comment-only edit; cannot affect fixture bytes or manifest
   digests.
3. **`runner.rb` policy/reporting split — fold.** Move `scores_tsv` (and its
   `message_ok` aggregation comment) into `Scoring`, keeping output bytes
   identical (same fields, same order). Rationale: the count_ok/message_ok
   bug lived exactly in this projection; co-locating projection with rubric
   semantics prevents the next drift. `runner.rb` keeps staging + run loop.
4. **`tmp/` drivers — fold; `ENV['ASK']` wart — eliminate.**
   `run_fit.rb`/`run_fit_pm2.rb` already call the `fit` task (good) but
   still stage `ENV['ASK']='glm53'`; `run_fit_contrived_1.rb` re-derives
   winner/stop wiring that the `fit` task now owns. Verdict: future
   sanctioned live runs go through `scout workflow task FitAgent fit ...`
   with the ambient default endpoint configured by the operator OUTSIDE
   FitAgent; drivers are deleted once nothing references them (tmp/ is
   disposable by contract). No ASK assignment may survive into tasks or
   library code.
5. **`agent_turn.rb` stale `LiveAgentChat` — remove regardless of spike.**
   The shadowed class + duplicate SESSION_SCRIPT constant (l.173–290) is
   dead weight producing the load warning; deleting it is behavior-neutral
   (agent_chat.rb's reopen becomes the single definition) and independent of
   the framework-native decision.
6. **`lib/FitAgent/scenarios.rb.orig` — remove; `results/`, `sandbox/` —
   gitignore.** Hygiene; no references.
7. **Legacy quartet (`use_case`/`analyze`/`compare`/`evolve`) —
   keep-and-deprecate.** No in-repo production callers outside each other;
   no test coverage; README-documented public surface. Default is keep with
   a deprecation note until a caller search (outside this repo) proves
   otherwise. Their explicit `endpoint` inputs stay untouched this round
   (backward compatibility).
8. **`fit` task winner logic — keep in task, do not duplicate.** The
   winner.json/stop/best computation lives in the `fit` task body only;
   drivers that re-derive it are folded per 5.4.

## 6. Verification status of this document

- Element sizes: `wc -l` live files (2026-09-06).
- Callers: grep per module/class name across `lib/ workflow.rb test/ tmp/
  research/ README.md` (commands in the round log; key hits quoted in §2).
- Script triplication: SHA1 comparison of the heredoc constants (dedented)
  vs `lib/FitAgent/fitagent_live_chat.rb` — identical (agent_chat variant);
  agent_turn variant differs (older version).
- Constant-warning: observed at `tmp/fit_real/run_fit_pm2.err:1`,
  `run_fit.err:1`, `run_fit3.err:1`.
- Suite totals (69/499): **not re-run this turn**; accepted from the round's
  verified-green baseline. First cleanup step must re-run the suite before
  and after its change.
- Spike outcomes A1–A7 / R1–R4: hypotheses only — that is their role; they
  are decided empirically in the next step, not here.

*No code was changed in this step. Documents only.*
