# Refactor round record — FitAgent execution layer and library cleanup (2026-09-06)

Final, durable record of the refactor round's two units (A: execution-layer
unification; B: library/task cleanup). Companion documents: the pre-round
review `10-refactor-review.md` and the reference artifacts in Cortex
(`design/refactor-round-reference.md`, `design/refactor-reference-pack.md`).
Everything below cites only paths verified on disk or in Cortex this turn.

## 1. Purpose and scope

User request behind the round: clean up lib/ code that looked like scripts,
simplify the convoluted sandboxing workarounds, and reconsider whether things
should run differently (e.g. framework-native). The round was executed as two
units with suite-green gates:

- **Unit A — execution layer unification.** One adapter (`LiveAgentChat`)
  replaces the two diverging child-process paths; sandbox/endpoint staging
  hacks deleted; the scripted single-turn file deleted; scorer contract
  locked with a golden-transcript replay; one gated live smoke as proof.
- **Unit B — library/task cleanup.** Reporting split out of the runner;
  `Evolve` requires explicit `out_dir`; stale comment fixed; proposer
  verified untouched; legacy task quartet marked deprecated; scratch drivers
  under `tmp/` deleted.

Out of scope by instruction: scenario/rubric semantics (frozen), ComputerUse
sources (canonical, read-only), full live fit loops (one-session smoke only).

## 2. The two decisions

1. **Adapter strategy — Consultant Option B: keep the child-process adapter
   shape, simplify it, and log framework-native execution as a follow-up.**
   Rationale (one line): the child process is what gives us PWD=staged-work
   semantics and a clean per-session environment without coupling FitAgent to
   framework job placement, so unify around it now and leave the seam thin
   (the `LiveAgentChat` facade) rather than re-architecting in the same round.
2. **Endpoint switch — delete the temp-HOME + copied `etc/AI` staging and let
   the child resolve the configured default endpoint natively from the user
   store (default by omission).**
   Rationale (one line): a two-attempt probe showed sandboxed children can
   read `~/.scout/etc/AI` directly, so the staging was pure workaround with
   nothing left to protect. Accepted consequence: live sessions now ride the
   user-store default rather than the repo-staged set, so **cross-run model
   comparability with pre-refactor live evidence is NOT guaranteed** — a
   caveat to carry forward, not something to engineer around.

## 3. Element-by-element old → new

| Old | New | Reason |
|---|---|---|
| `lib/FitAgent/agent_turn.rb` (scripted single ComputerUse turn; duplicate `SESSION_SCRIPT` constant → runtime warning) | **deleted**; its gated e2e smoke now runs `LiveAgentChat` in `test/FitAgent/tasks/test_e2e_smoke.rb` | Legacy two-units-era path; the duplicate constant was its symptom; unification means one adapter, zero duplicate definitions |
| `agent_chat.rb` temp-HOME + copied `etc/AI` staging, `FITAGENT_AI_DIR` src-dir picking | **deleted**; child runs with the real HOME and resolves endpoints natively | Probe showed children can read `~/.scout/etc/AI`; staging was pure workaround (decision 2) |
| `agent_chat.rb` `CU_CHECKOUT`-style hardcoded checkout env | `CU_CHECKOUT = ENV['FITAGENT_COMPUTERUSE_DIR'] \|\| <canonical path>` | Keep a single, overridable ComputerUse source; ComputerUse itself is canonical and untouched |
| Two embedded `SESSION_SCRIPT` strings (agent_turn + agent_chat) | **one** `SESSION_SCRIPT` in `agent_chat.rb`, materialized/refreshed to `lib/FitAgent/fitagent_live_chat.rb` by `LiveAgentChat.session_script` | Executed child and inspectable repo file can never drift; duplicate-constant warning gone |
| (nothing) | `test/FitAgent/tasks/test_agent_chat.rb` | Adapter contract tests: no staging, PWD=work, BWRAP guard, single-source script, failure-chat fallback |
| (nothing) | `test/FitAgent/tasks/test_golden_replay.rb` + `test/fixtures/golden/` (`C02_live.chat`, `C02_work/`, `C02_rubric.yaml`) | Lock the transcript contract: same recorded live transcript must score identically across the refactor |
| `runner.rb` mixed policy + reporting (`scores_tsv` inline) | reporting extracted to `lib/FitAgent/reporting.rb` (`scores_tsv`, `write_arm_outputs`); runner keeps staging/turn/scoring policy | The message_ok-vs-count_ok column drift was born in this mix; separation makes the projection auditable. Byte-identical outputs proven by a three-arm replay diff |
| `evolve.rb` `out_dir \|\| Dir.pwd/results` silent default | **required**: `ArgumentError` when nil/empty; +1 test (`test_evolve_loop_requires_explicit_out_dir`) | Silent PWD-relative output wrote results where nobody looked; explicit is safer for a loop that writes trees |
| `scenarios.rb:16` stale E01 comment | corrected (E01 v1.1 nuance: exit code not observable through the nested CMD layer) | Comment said something the code did not do |
| `proposer.rb` | **unchanged**; grammar coverage re-verified intact | Validator is the load-bearing fix from patch-mini-1; nothing in the round touched it |
| legacy tasks `use_case` / `analyze` / `compare` (`workflow.rb`) | kept + `# DEPRECATED (fit-era)` notes pointing at successors | No external callers found; README-documented surface; interface-stability default this round |
| `tmp/` drivers (`run_fit*.rb`, `wart_repro.rb`, `add_wart_test.py`, `dedup_test.py`, `run_catalogue_pm2.rb`) | **deleted** | Scratch that duplicated task wiring; the `fit` task is the sanctioned entry |
| `test/test_helper.rb` duplicated requires | deduplicated; `agent_chat` + `proposer` added to the load list | Hygiene; new modules must be loadable by every test |

Note on the round's *reach*: `scenarios.rb` and `scoring.rb` also carry the
C-series additions from the previous bout (contrived scenarios C01/C02 and
the message_ok aggregate). Those predate this round and are **not** part of
the refactor's changes; the refactor's obligation there was only to leave
the rule grammar untouched — verified by the golden replay.

## 4. Unit B verdicts, as applied (six)

1. Reporting split out of `runner.rb` → `reporting.rb`; three-arm replay
   diff proved byte-identical outputs.
2. `Evolve` requires explicit `out_dir` (ArgumentError; test added).
3. `scenarios.rb:16` stale comment fixed.
4. `proposer.rb` verified unchanged; tools-grammar coverage intact.
5. Deprecation notes on `use_case`/`analyze`/`compare` in `workflow.rb`.
6. `tmp/` scratch drivers deleted; library code takes no `tmp/` dependency.

## 5. Suite progression

| Point | tests | assertions | omissions |
|---|---|---|---|
| pre-Unit-A baseline | 69 | 499 | 1 |
| after Unit A | 73 | 507 | 3 |
| after Unit B (final, this turn re-run) | 74 | 512 | 3 |

Deltas: Unit A +4 tests (adapter contract + golden replay) and the rerouted
smoke; Unit B +1 test (evolve out_dir). Omissions are gated live tests
(`FITAGENT_LIVE_MODEL=1`); 3 at the end (2 in the e2e smoke file, 1 live
gated elsewhere). Zero Ruby warnings on the final run — the duplicate
`SESSION_SCRIPT` constant warning is gone (grep for `warning:` /
`already initialized` over the full suite output: none).

## 6. Verification summary

- **Golden replay (Unit A).** A recorded live transcript (the C02 baseline
  session, see §8 provenance) was scored with the pre-refactor code and the
  full verdict JSON saved to `tmp/contrived/unitA_golden_before.json`. The
  committed fixture `test/fixtures/golden/C02_live.chat` (+ `C02_work/`,
  `C02_rubric.yaml`) is replayed through the new code with
  field-by-field assertions plus full-JSON equality when the golden file is
  present. Result: identical (C02 FAIL / 0.0, message rules equal) — the
  transcript contract survived the refactor.
- **Byte-identical replay diff (Unit B).** The reporting split was verified
  by re-running three arms and diffing outputs against pre-split bytes:
  identical.
- **Gated live smoke (Unit A, one session).** F01 through the new adapter:
  real model session, one `patch` call applied (`applied: true`,
  `exit_status 0`), transcript parsed by `Chat.tool_calls`, score row
  `F01 PASS 1.0 message_ok=true` (`total_calls 2`: patch 1, read 1). Two
  documented repairs, then success: (1) relative-path ENOENT — child chdirs
  into the work tree before reading scenario inputs; fix: expand paths
  before spawn. (2) `Errno::EROFS` on the LLM ask cache — from a foreign
  PWD, `Scout.var.cache.ask` resolves through the read-only user store; fix:
  `persist: false` (ask caching is wrong for a fit session anyway — fresh
  turns are the point).
- **Warnings audit.** Final suite run greps clean (no `warning:`, no
  `already initialized`).

## 7. DEFERRED (recorded, deliberately not fixed)

1. **Legacy `score` task divergent semantics** (`workflow.rb`, the inline
   tsv read near l.517–526): it reads `r['message']['count_ok']` while
   Runner/Reporting emit the aggregate `message_ok`. Changing it would alter
   a core task's output; deferred under this round's interface-stability
   default. Anyone consuming `score`'s tsv should read
   `count_ok` semantics there deliberately.
2. **Framework-native execution follow-up.** The open question stands, logged
   in `agent_chat.rb`'s header: can a framework chat job run with
   PWD = the staged work dir and produce scorer-parseable transcripts? If
   yes, `LiveAgentChat` (the swap seam) collapses onto it.
3. **Pre-refactor evidence caveat.** contrived-fit-1 per-arm scores are
   Worker-reported only — the outputs were deleted post-turn in an earlier
   round (see `verifications/contrived-fit-1-verdict.md`). Process rule
   since adopted: sanctioned live outputs survive the turn. This round's
   smoke outputs are preserved (§8).

## 8. Evidence pointers (real paths, verified this turn)

- **Unit A live smoke, durable copy: `tmp/contrived/unitA-smoke-outputs/`**
  — `SMOKE.md` (command + repair write-up), `receipt.json`,
  `baseline/{scores.json,scores.tsv,arms.json,sandbox/main.chat,
  session.stdout,session.stderr,scenarios/F01/...}`.
  `main.chat` md5 `cb30d20026728a2fa8a7e70d623095c5`.
- **`results/unitA-smoke/` does NOT exist in this checkout.** It was
  materialized during the Unit A turn and wiped afterwards by the suite's
  teardown (`test/FitAgent/tasks/test_fit_task.rb` deletes
  `Dir.pwd/results` in `teardown`); only `results/exp3/` remains there. The
  record therefore cites `tmp/contrived/unitA-smoke-outputs/` as the
  authoritative smoke evidence. (Note: `SMOKE.md`'s own title still says
  "results/unitA-smoke" — stale label, content correct.)
- Golden fixture: `test/fixtures/golden/` (committed, hermetic); golden
  verdict JSON: `tmp/contrived/unitA_golden_before.json`.
- Source session of the golden fixture (the recorded live C02 baseline):
  `tmp/contrived/live-record/contrived-baseline/baseline/sandbox/scenarios/C02/`
  with the staged set at `tmp/contrived/live-record/cset/`.
- Pre-existing staged evidence (read-only for this round, intact):
  `tmp/contrived/arms-fit/candidates/**`, `tmp/contrived/scenarios-fit/**`.
- Reference artifacts (Cortex): `design/refactor-round-reference.md`,
  `design/refactor-reference-pack.md`,
  `verifications/contrived-fit-1-verdict.md`,
  `verifications/contrived-c-series-baseline-v1.md`,
  `status/2026-09-05-two-units-closure.md`; companion Cortex record of this
  round: `design/refactor-round-record.md`.

## 9. Golden-fixture provenance (captured from the deleted one-off
`tmp/contrived/c02_new.rb`)

The C02 scenario — the recorded live session whose transcript is the golden
fixture — was designed as a draft in the one-off scratch file
`tmp/contrived/c02_new.rb` (created 2026-09-05 in the
`fitagent-contrived-design` working conversation). Its content, verbatim,
now lives as `lib/FitAgent/scenarios.rb#def c02`. The load-bearing comment
from that draft (kept verbatim in the catalogue):

> Plausible hunk: counts and start are self-consistent, but one MIDDLE
> context line is misspelled (`epsiln`) → GNU patch refuses at every `-p`
> level (Hunk #1 FAILED; too many context lines differ for fuzz), and the
> tree must stay pristine. NB a wrong line at the EDGE of the hunk
> (`theta` vs `zeta`) IS fuzz-tolerated and applies — live-verified in
> results/contrived-baseline; do not reintroduce.

Plus the rubric reachability nuance added after the first live fit
(also in the catalogue): under bwrap the sandboxed patch run loses GNU
patch's own message, so `output_contains` needs `['FAILED', 'error status
1']`-style needles — 'Hunk #1 FAILED' covers the un-sandboxed wording.
That is why the golden fixture commits `C02_rubric.yaml` **as recorded**
rather than re-materializing a fresh rubric (the catalogue's C02 has since
gained a needle; a fresh materialize would not reproduce the recorded
golden).

The file `tmp/contrived/c02_new.rb` no longer exists on disk — it was
already removed by the Unit B `tmp/` driver cleanup, and this record now
carries the note, so the delete step is a confirmed no-op.

## 10. Standing constraints reaffirmed after the round

- No endpoint/model/inference-point name in any code on the new path
  (`agent_chat.rb`, `fitagent_live_chat.rb`, runner, reporting, evolve,
  proposer, catalogue/override/score/run_arms/fit tasks): default by
  omission holds (grep-clean).
- The five `endpoint`/`endpoints` occurrences that remain in `workflow.rb`
  (l.21 `use_case`, l.176 `analyze`, l.256 `compare`, l.341+345 `evolve`)
  are **user-settable task inputs with defaults** on the deprecated legacy
  quartet — knobs, not hardcoded run-path endpoint selection. They were
  deliberately left untouched (deprecate-not-remove decision); the
  no-endpoint-in-code constraint governs the new path and was not violated
  by new code.
- Live tests stay gated behind `FITAGENT_LIVE_MODEL=1`; canonical agents
  untouched; overrides only under caller-staged dirs.
