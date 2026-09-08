# ComputerUse decoupling round record — FitAgent (2026-09-06)

Final, durable record of the round that took ComputerUse out of FitAgent's
`lib/` and made the target a parameter. Companion documents: the previous
round record `10-refactor-round.md`, the pre-round reference artifact in
Cortex (`design/computeruse-in-lib-reference.md`), and the read-only audit
turn (`fitagent-cu-audit`). Everything below cites paths verified on disk
this turn or facts recorded with receipts in the round's session
transcripts.

## 1. Question and verdict

Question: why did ComputerUse look baked into `lib/`, and is the harness
actually generic?

Verdict: **`lib/ComputerUse` never existed** — no directory, no symlink, no
copy (`ls -la lib/`, repo-wide `find`, `git status --porcelain lib/`,
`git ls-files lib/` all empty of it; the only ComputerUse checkout is the
sibling AgentSuite submodule `../ComputerUse`). The *appearance* of coupling
came from four real, smaller couplings (old `file:line` = pre-decoupling
numbering, from the audit turn):

| # | Coupling | Kind / reach |
|---|---|---|
| a | `agent_chat.rb:42-43` `CU_CHECKOUT = ENV['FITAGENT_COMPUTERUSE_DIR'] \|\| '/home/mvazque2/git/AgentSuite/ComputerUse'`; consumed at `:73` as the child's checkout ARGV (`require File.join(cu, 'workflow.rb')`) | hardcoded path + env override; consumed only at live-session time; load-time-safe (fresh-process probe `tmp/cu_audit_require_probe.rb` with a hostile `FITAGENT_COMPUTERUSE_DIR`, exit 0, no ComputerUse in `$LOADED_FEATURES`) |
| b | `scenarios.rb:52-55` patch-flavored `SUCCESS_MESSAGE_RULES` (`'tool' => 'patch'`, `expect: applied/exit_status/used_strip`), applied as `define()` fallbacks at `:525-528`; explicit `tool: 'patch'` at E01 `:323`, E02 `:346`, C01 `:477`, C02 `:506` (+ `forbid_after_failed` `:511`) | example-shaped defaults leaking into lib/ |
| c | `evolve.rb:96` `'  ComputerUse patch'` tools-grammar example line; `evolve.rb:381` StubProposer `tools: ['ComputerUse patch']`; `proposer.rb:42` `REPAIR_EXAMPLE_SPEC = 'ComputerUse patch'`; `:44` grammar help text | prompt text naming one workflow |
| d | generated child script materialized INSIDE lib/ as `lib/FitAgent/fitagent_live_chat.rb` (byte-identical to `SESSION_SCRIPT`, rewritten on every `session_script` call) | runtime write into lib/ |

**Location correction vs the earlier reference artifact** (Cortex
`design/computeruse-in-lib-reference.md`): the patch-flavored
`SUCCESS_MESSAGE_RULES` lived in `lib/FitAgent/scenarios.rb`, **not** in
`workflow.rb` (workflow.rb's only hit was a comment). The artifact framed
the location wrong; this record is authoritative on that point.

Install side effects found (neither is a checkout copy):
`FitAgent/var/jobs/ComputerUse/{patch,python,search}` runtime job trees
(git-ignored, deletable at any time) and `~/.scout/workflows`, a dangling
symlink → `/home/mvazque2/.rbbt/workflows` (target absent; nothing to
record or clean).

## 2. Why the coupling existed

- The live adapter needs the target workflow's `workflow.rb` on the child's
  load path, and at the time ComputerUse was the only target ever run — a
  discoverable sibling-checkout constant (`CU_CHECKOUT`) was the cheapest
  correct mechanism for that one case.
- The scenario catalogue and its success-message rules were born from live
  ComputerUse patch probes (research/08), so patch semantics became the
  DSL's *defaults* instead of target *data*.
- The tools grammar in proposer/evolve prompts illustrated itself with the
  one real example available.

## 3. Decision

**Parameterize + relocate.** Every target-specific value became data
(`FitAgent::TargetSpec`), the example moved to `examples/computeruse-patch/`,
and nothing under `lib/` names a concrete workflow any more.

- Rejected: keep-as-is — the user explicitly wants ComputerUse to be **one
  example** among possible targets, not the harness's built-in target.
- Rejected: deleting the ComputerUse example — it is the frozen,
  live-proven catalogue (digest-pinned); it stays as the shipped example
  target and the repo-level default.
- The generated child script moved from `lib/` to `<repo>/var/` (git-ignored
  via `var/`), so runtime materialization no longer writes inside lib/.

## 4. Old → new map

| Old | New |
|---|---|
| `CU_CHECKOUT` in `agent_chat.rb` | `FitAgent::TargetSpec#workflow_dir!` (`lib/FitAgent/target.rb`); `LiveAgentChat.new(target:)` accepts a spec or a config path (`agent_chat.rb:47-49`, checkout at `:57`) |
| patch `SUCCESS_MESSAGE_RULES` in `scenarios.rb` | `message_rules` block of the target config (merged as the `define()` fallbacks); per-scenario overrides stay in the catalogue |
| F/E/C catalogue inside `scenarios.rb` | `examples/computeruse-patch/catalogue.rb` (485 lines, moved VERBATIM — do not reformat, digests are frozen) |
| `'ComputerUse patch'` grammar examples/defaults | derived from the loaded target: `Evolve.default_tool_example` = `Scenarios.loaded_target&.primary_tool \|\| 'Workflow task'` (`evolve.rb:95`); `DefaultProposer.repair_example_spec` (`proposer.rb:56`) |
| generated `lib/FitAgent/fitagent_live_chat.rb` | `<repo>/var/fitagent_live_chat.rb` (git-ignored; md5 `02251d7ae9d8a3fd29fc3d6a125b6634`, 2659 bytes after the round, byte-identical to `SESSION_SCRIPT`) |
| (nothing) | `lib/FitAgent/target.rb`: frozen `FitAgent::TargetSpec` — fields `name/workflow_dir/agent/tools/message_rules/catalogue`; `${VAR}` env expansion; relative paths resolve against the config file |
| (nothing) | `workflow.rb`: `:target` inputs on `catalogue` (`:471`), `run_arms` (`:570`), `fit` (`:589`); `DEFAULT_TARGET` (`:24`) = `examples/computeruse-patch/target.yaml`; `target.yaml` `workflow_dir: ../../../ComputerUse` (relative; `${FITAGENT_COMPUTERUSE_DIR}` restores the legacy env override) |

Gate (must stay empty): `grep -rn "ComputerUse\|CU_CHECKOUT\|FITAGENT_COMPUTERUSE_DIR" lib/`
→ **empty**, exit 1 — re-verified after this turn's pathname edit.

## 5. Frozen-semantics evidence (digests)

- 17 materialized fixture digests (C01, C02, E01–E06 incl. E05b, F01–F08) +
  set digest `4942cacdda221373327b296526c4155f`, version `patch-v2`, seed
  `fitagent-v1` — byte-identical across the catalogue move:
  `tmp/digests-before.txt` == `tmp/digests-after.txt` (diff empty,
  re-diffed this turn).
- Enforced permanently by `test/FitAgent/tasks/test_target_digests.rb`
  (1 test / 3 assertions): materializing through the relocated catalogue
  must reproduce exactly those digests.

## 6. Genericity evidence (second target)

`test/FitAgent/tasks/test_target.rb` (2 tests / 15 assertions) with
`test/fixtures/dummy_target/`: a dummy second target (`name: dummy`,
`workflow_dir: ${FITAGENT_DUMMY_DIR}`, `tools: ['Dummy echo']`, catalogue
D01/D02) is created by the test, loads and materializes purely through the
target input, and flips the derived grammar to `'Dummy echo'`
(`Evolve.default_tool_example`, `DefaultProposer.repair_example_spec`) —
with **zero edits in lib/**. The target's default `message_rules` merging
into `define()` fallbacks is exercised on the way.

## 7. Live smoke (the one sanctioned session)

- Driver: `tmp/live_smoke_f01_driver.rb` — mirrors
  `test_e2e_smoke.rb#test_baseline_arm_scores_match_frozen_expectations`
  restricted to `ids: %w[F01]` (the shipped test materializes F01+E01+E06
  = 3 model calls, which would blow the one-live-session budget).
- Command: `BWRAP_PATH=false SCOUT_WORKFLOW_AUTOINSTALL=false
  FITAGENT_LIVE_MODEL=1 timeout 900 ruby -Ilib -I. tmp/live_smoke_f01_driver.rb`
- Result: exit 0, `SMOKE_VERDICT=PASS`; F01 verdict `PASS`, score `1.0`,
  functional_ok/message_ok true; a real `patch` tool call (exit_status 0,
  used_strip 1, applied true); work `notes.txt` byte-identical to
  `expected/notes.txt`.
- Chain proven: TargetSpec load → `Scenarios.load(target)` + materialize →
  `Runner.run_arm` staging → `LiveAgentChat` child (script at
  `var/fitagent_live_chat.rb`) requiring the target's `workflow.rb` →
  ComputerUse patch job → deterministic scoring.
- Canonical checkout untouched: `git -C ../ComputerUse status --short` empty
  before/during/after; HEAD `97e5f4a31628c3a9cc10abc01b9b080bcdcee52c`.
- **Evidence status (anomaly, see §10.4):** the evidence pack was written
  under `results/decoupling-live-smoke/` (EVIDENCE_INDEX.md, live
  stdout/stderr, pre/post snapshots, computeruse clean check, driver copy,
  `run_outputs/live-smoke/baseline/`), but that directory was later wiped
  by `test_fit_task.rb#teardown` (`FileUtils.rm_rf Dir.pwd/results`) when
  the deterministic suite re-ran after the smoke — the same trap note 10 §8
  recorded for the Unit A smoke. Salvaged copies now live in
  `tmp/decoupling-live-smoke/` (EVIDENCE_INDEX.md recovered verbatim from
  the session transcript, driver copy, RECOVERY_NOTE.md). The full
  transcript carrying the run's tool receipts is the Planned work job chat
  `~/.scout/var/jobs/Planned/work/Default_e3ffd29….chat.files/Manager.society/Worker/fitagent-cu-live/agent.chat`.

## 8. Suite totals (before/after)

- Before the round: 74 tests / 512 assertions / 0 failures / 0 errors /
  3 gated omissions.
- After the round, the post-smoke repair (`test_agent_chat.rb#test_live_model_f01`
  now passes `target: TARGET`, mirroring the e2e smoke), and this turn's
  pathname fix — full 13-file deterministic suite re-run fresh:
  **77 tests / 530 assertions / 0 failures / 0 errors / 3 omissions**
  (`tmp/pathname_fix_suite_v2.txt`).
- Delta +3 tests / +18 assertions = `test_target.rb` (2/15) +
  `test_target_digests.rb` (1/3).

## 9. Cleanup applied at record time (pathname self-containment)

`lib/FitAgent/target.rb` used `Pathname` (in `absolute?`, line 147) without
requiring it — it worked only through transitive requires (via
`scenarios.rb`'s load order). Fix: `require 'pathname'` at the top
(line 3). Validated:

- Negative control: a copy of target.rb without the require raises
  `uninitialized constant FitAgent::TargetSpec::Pathname (NameError)` in a
  fresh process.
- Self-contained probe (fresh this turn): `ruby -Ilib -e "require
  'FitAgent/target'; …"` resolves `workflow_dir!` → `…/AgentSuite/ComputerUse`
  and `catalogue_path` → `…/examples/computeruse-patch/catalogue.rb` with
  no other requires; `PROBE_OK`, exit 0 (`tmp/pathname_selfprobe.txt`).
- Full suite re-run: totals unchanged 77/530/0/0/3; lib/ gate still empty.

## 10. Open items

1. **C02 rubric needle fix** — the golden fixture
   `test/fixtures/golden/C02_rubric.yaml` is committed *as recorded*, while
   the catalogue's C02 has since gained the `'error status 1'` needle, so a
   fresh materialize would not reproduce the recorded golden (note 10 §9).
   Reconcile deliberately, not in passing.
2. **count_ok / message_ok reconciliation** — the legacy `score` task reads
   `r['message']['count_ok']` while Runner/Reporting emit the aggregate
   `message_ok` (note 10 §7.1). Changing it alters a task's output; do it
   as its own unit.
3. **Promote the target-swap recipe to `doc/`** —
   `examples/computeruse-patch/README.md` already documents how to point
   FitAgent at another workflow; there is no `doc/` yet. Promote once a
   second real target exists, so the recipe gets reviewed status.
4. **`results/` teardown trap** — `test_fit_task.rb#teardown` deletes
   `Dir.pwd/results`, which destroyed this round's sanctioned live-smoke
   evidence after the fact (§7). Scope the teardown to the test's own root
   (`@root`) or stage sanctioned evidence outside `results/`.
5. **Round uncommitted** — the whole round (`lib/FitAgent/target.rb`,
   `examples/computeruse-patch/`, new tests + fixtures, `research/11`,
   index row) is modified/untracked in git; committing is out of scope for
   this step.
6. **Cosmetic, no action** — `~/.scout/workflows` remains a dangling symlink
   (`→ /home/mvazque2/.rbbt/workflows`, target absent); recorded so nobody
   chases it again. `var/jobs/ComputerUse/**` runtime job trees remain
   deletable at any time.
