# Phase 6 — sparse FitAgent smoke tests of the redesigned configuration

Date: 2026-11-01 · Branch: `ags-redesign` · Author: Worker (Phase 6 execution)
Scope: provisioning and boundary mistakes only — no quality scoring, no
rubrics, no full evaluation (user constraint). One live run per scenario,
plus targeted re-runs only where a fix changed that role's surface.

## 0. Endpoints and pre-run blockers (resolved)

Two environment defects blocked all live runs at first; both were fixed
minimally and are recorded here because they are smoke findings in
themselves.

1. **Dead model in `FitAgent/etc/AI/qwen`** (`model: qwen3.6:35b` — the
   openwebui `/api/models` list has `Qwen3.8-27B`). Every use_case run
   died with `RestClient::BadRequest 400` / `"detail":"Model not found"`.
   Fix: `model: Qwen3.8-27B`.
2. **openwebui backend rejects Scout's tool schema.** The `openwebui`
   backend posts tools in `{"type":"function","name":…,"parameters":…}`
   form; the server requires `{"type":"function","function":{…}}` →
   `400 … ('body','tools',0,'function'), 'Field required'`. With a
   tools-bearing agent this makes every ask fail at turn 0. The `openai`
   backend (same URL, key, model) wraps definitions correctly and tool
   calling works (verified with a fake `demo_tool` probe: the model
   called it and received its output). Fix: `backend: openai` in
   `FitAgent/etc/AI/qwen`.
3. **Chat-breaking typo in `society` (line 162)**: the ScoutCoder entry
   read `specialist: owns workflows, …` — the `specialist:` marker
   leaks a role named `specialist` into every agent chat that imports
   `society` (Manager, Worker, …), and the openai backend rejects the
   unexpected message role (`"Unexpected message role."`, 400). Fix:
   `specialist who owns workflows, …` (3 bytes, verified in a fresh
   process: roles reduce to `system,introduce,tool,user`).

   *Note*: this typo was introduced by an uncommitted working-tree edit
   to `society` (not present at HEAD); the fix is a working-tree fix to
   that same edit. No committed content was touched.

All subsequent runs went through `FitAgent use_case` normally:
`--agents tmp/ags-smoke/agents --endpoint qwen --main_agent <role>`,
sandbox per job, endpoint staged into the sandbox, transcript in
`sandbox/main.chat`.

## 1. Scenarios and commands

Scenario dirs (authored, minimal): `tmp/ags-smoke/use_cases/`
(`s1-lead-outline`, `s2-manager-packets`, `s3-investigator-conclusion`,
`s4-research-curator`, `s6-worker-longoutput`); agents snapshot:
`tmp/ags-smoke/agents` (byte-identical copies of the repo roles at run
time, verified by md5). Command template (from `FitAgent/`):

```bash
scout workflow task FitAgent use_case \
  --agents ../tmp/ags-smoke/agents \
  --use_case ../tmp/ags-smoke/use_cases/s1-lead-outline \
  --endpoint qwen --main_agent ScientificLead
```

(`--main_agent` Manager / Investigator / Research / Worker as
appropriate; the first S6 attempt additionally passed `--repo ../`,
which was dropped in later runs — see S6 section.)

| # | Scenario | Role under test | Live runs | Verdict |
|---|---|---|---|---|
| S1 | Scientific outline from mission + evidence path | ScientificLead | 1 | **PASS** |
| S2 | Work order / Investigator packet translation | Manager | 1 | **PASS** |
| S3 | One-question packet → bounded conclusion citing artifact | Investigator | 1 | **PASS** |
| S4 | Verbatim registration via `cortex_write`, confirm path | Research | 1 | **PASS** |
| S5 | Context-delivery inspection (hermetic, no model turn) | all 5 changed roles | 1 (deterministic) | **PASS** (after bug fix) |
| S6 | Long-output discipline: write file, reference path | Worker | 3 (1 fixture-failure, 1 deliverable-only, 1 clean re-run) | **PASS** (both halves evidenced) |

## 2. Per-scenario detail

### S1 — ScientificLead outline (PASS)

- Setup: `main.chat` = mission statement + pointer to
  `evidence/summary.md` (7-line stub). Ask: outline with questions,
  hypotheses, discriminating evidence, go/no-go criteria; no tool calls,
  no domain-tool internals.
- Job: `FitAgent/var/jobs/FitAgent/use_case/Default_cf383b587a698356964a6fc301b59c77`
- Outcome: `status: done`; single assistant turn, **0 tool calls**; 1343
  words; explicit "Outline complete; I stop here."
- Checks: Q1/Q2/Q3 questions ✔; hypotheses (H1/H2/H3) ✔; per-question
  "Discriminating experiment" sections ✔ (3×); GO/NO-GO criteria ✔;
  `evidence/summary.md` cited ✔. No Workspace/Cortex invocation
  attempted ✔.
- Evidence: `tmp/ags-smoke/runs/s1.out`, `tmp/ags-smoke/runs/s1.main.chat`,
  `tmp/ags-smoke/runs/s1.err`.

### S2 — Manager packet translation (PASS)

- Setup: `main.chat` = Lead outline (canonical, hypothesis wording
  marked as such) + instruction to compose one Investigator packet
  (Q01) translating not rewriting; science verbatim, logistics
  translated.
- Job: `Default_a9e8547f614034d42c5e9ef9ff7adae6`
- Outcome: `status: done`; 0 tool calls (fine — Manager's surface is
  delegation only); 463 words; packet with objective/current
  state/design/task/output-required; explicit ownership note
  ("Logistics … are Manager translations; everything under the Design
  science section is the Lead's text as written").
- Checks: hypothesis line `Hypothesis: no wording is lost; packets carry
  the hypothesis` present **byte-identical** in output ✔; "verbatim"
  marking ×6 ✔; no scientific substitution ✔; no `cortex_continue`
  call attempted in a single-turn smoke (boundary respected) ✔.
- Evidence: `tmp/ags-smoke/runs/s2.out`, `s2.main.chat`, `s2.err`.

### S3 — Investigator bounded conclusion (PASS)

- Setup: `main.chat` = one-question packet (Q01 byte-match question);
  `evidence/finding.md` = outline block + packet block (identical
  wording by construction). Ask: bounded conclusion citing the artifact
  path.
- Job: `Default_3878e1f630046763a8cfb8fc9687f284`
- Outcome: `status: done`; 9 tool calls, **all within provisioned
  surface**: `read`, `bash` ×2 (awk split + trivial probe),
  `python` (trivial), `file_stats`, `search` ×2, `read` ×2. Final
  answer 657 words in Worker report format; conclusion **GO** ("sampled
  packet hypothesis matches the outline byte-for-byte"), artifact path
  `evidence/finding.md` cited ✔.
- Boundary checks: no Cortex task invoked ✔ (explicitly noted "No
  Cortex tasks were needed or used (no rename/move/remove, no
  Semantics)" — the only textual mention of those words); no Semantics
  ✔; no attempt outside its 5-Cortex-task + Workspace surface ✔.
- Caveat (observed, not scored): it used 9 calls incl. `python` and a
  `file_stats`/`search` sequence where one `read` + one `bash` diff
  would have sufficed; also first `bash` attempted `mkdir -p tmp` +
  awk split. Under the phase constraint this is recorded, not graded.
- Evidence: `s3.out`, `s3.main.chat`, `s3.err`.

### S4 — Research curator registration (PASS)

- Setup: `main.chat` = registration request with exact record text
  `GO: sampled packet hypothesis matches the outline byte-for-byte.` and
  target path `ags/smoke/questions/Q01.md`; instruction to write
  verbatim, confirm path, no editorializing.
- Job: `Default_b362143303bee82325947d06001050bd`
- Outcome: `status: done`; 2 tool calls: `cortex_write` (path/content/
  mode=replace/agent=Research, **content byte-identical to request,
  incl. trailing newline**) then `cortex_read` for read-back
  confirmation. Final answer 53 words: path confirmed, "No editorial
  changes made", provenance noted.
- Verified side effects: artifact exists in the job sandbox at
  `var/cortex/artifacts/ags/smoke/questions/Q01.md` with adjacent
  `.info` recording `job: Cortex/cortex_write/Default_aade3db5…`,
  `agent: Research`, `mode: replace`, `size: 65`. ✔
- Evidence: `s4.out`, `s4.main.chat`, `s4.err`; sandbox artifact path
  above.

### S5 — Context-delivery inspection (PASS after bug fix)

Hermetic, zero inference: load each changed role's start_chat in a fresh
process exactly as the framework does and inspect the effective message
list, then compare against `new_doctrine/work/redesign-matrix-final.md`
(the capability truth). Script:
`tmp/ags-smoke/redesign_phase6_hermetic_s5.rb`; result JSON:
`tmp/ags-smoke/s5-hermetic/s5_hermetic_result.json`.

| Check | Meaning | Result |
|---|---|---|
| S5a | all 5 roles' imports (`import:` files) resolve | true |
| S5b | total effective tool counts match matrix (Lead 3, Manager 5, Investigator 28, Research 36, Worker 36) | true |
| S5c | Cortex counts match (3 / 2 / 5 / 10 / 10) | true |
| S5d | Investigator has Workspace provisioned | true |
| S5e | Investigator has **no** Semantics | true |
| S5f | Investigator lacks rename/move/remove triple | true |
| S5g | ScientificLead carries tools only (no exec/internals) | true |
| S5h | Manager's only tools are cortex_continue/cortex_brief | true |

Two script-side expectation bugs were fixed during authoring (counting
`cortex_list`/`cortex_read`/`cortex_search` duplicates from multi-map
loads, and wrong expected cortex counts for Manager/Worker copied from
an earlier draft); the final table is the corrected one. One real
finding surfaced here and is fixed (the `society` `specialist:` typo,
§0.3) — after the fix ALL_PASS: true.

### S6 — Worker long-output discipline (PASS, reply discipline verified on the clean re-run)

- Setup: `main.chat` = write `smoke-report.md` ≥200 lines (header +
  one line per Workspace task + filler), **do not paste the body**,
  reply by referencing the durable path.
- Run 1 (job `Default_bf07db75f9c4125d4ababea1095eebef`, 17:54): exit
  255 — HTTP 400, `status: error`. **Root cause not fully attributed at
  the time**; it is now characterized (see re-run below): the fixture
  itself contained the line `tasks: bash, copy, …` inside the `user:`
  body, which Scout parses as a chat directive and materializes as an
  extra `tasks`/`user` message pair (roles in the saved chat:
  `… tool, user, tasks, user`), and the openai-backed server rejects
  that unexpected role (`"Unexpected message role."`, 400 — reproduced
  deterministically in `s6-rerun-rootcause.txt`). This was a fixture
  authoring defect, not a role or provisioning defect. The earlier
  attribution "this run found the society bug" was wrong on the
  timeline: the society fix (17:38:55) predates this failure
  (17:54:30–32), and S1–S4 had already run post-fix.
- Run 2 (same job dir, 18:00–18:07, via `LLM::Agent` in the staged
  sandbox): produced `smoke-report.md` (205 lines) — **deliverable half
  verified**: the file exists in the job sandbox, md5-identical to the
  evidence copy, with real Workspace `write`/`bash` job records under
  the sandbox's `var/jobs/Workspace/`. The **reply half was not durably
  captured**: the run's stdout (`s6.out`) is 0 bytes, the job log and
  sandbox transcript hold only the failed first run, and no assistant
  turn survived — the path-referencing reply from that attempt was
  narrated only and is no longer claimed as evidence.
- Run 3 (clean re-run, 18:33, job
  `Default_a45fc904e1d337466b5b9391f2acd281`, after a one-line fixture
  fix renaming the stray `tasks:` line to plain text so the chat parses
  as a single `user` role): `status: done`, exit 0. Worker made exactly
  3 tool calls — `write smoke-report.md`, `pwd`, `file_stats` — wrote
  **208 lines / 18,056 bytes**, and its 235-word reply references
  `smoke-report.md` with its full sandbox path, reports the line count
  from `file_stats`, and does **not** paste the 200-line body. Both
  halves of the behavior (durable deliverable + path-referencing
  reply) are now evidence-backed.
- Evidence: `s6-rerun.out` (final answer text, 1.7 kB),
  `s6-rerun.err` (run log tail, `done` at 00:03:31),
  `s6-rerun.main.chat` (transcript: 3 function calls + assistant
  turn), `s6-rerun.smoke-report.md` (208-line artifact),
  `s6-rerun-rootcause.txt` (run-1 root-cause reproduction),
  `s6-rerun-roles.chat` (saved chat showing the stray `tasks` role),
  `s6-failed.info` / `s6-failed-log.txt` (run-1 job status + log),
  plus the earlier deliverable-half evidence `s6.smoke-report.md`.
  Superseded/empty: `s6.out` (0 bytes), `s6.err`, `s6.main.chat`.

## 3. Summary table

| # | Scenario | Role | Verdict | Key evidence |
|---|---|---|---|---|
| S1 | Lead outline | ScientificLead | PASS | 0 tool calls; outline complete w/ all 4 required elements; `s1.main.chat` |
| S2 | Packet translation | Manager | PASS | hypothesis byte-identical; science/logistics split explicit; `s2.main.chat` |
| S3 | Bounded conclusion | Investigator | PASS | GO verdict citing `evidence/finding.md`; only Workspace surface; `s3.main.chat` |
| S4 | Verbatim registration | Research | PASS | `cortex_write` byte-identical + `.info` provenance; `s4.main.chat` + sandbox artifact |
| S5 | Context inspection | (deterministic) | PASS | 8/8 checks; `redesign_phase6_s5.json` |
| S6 | Long-output discipline | Worker | PASS | 208-line file + 235-word path-referencing reply, 3 tool calls; `s6-rerun.main.chat`, `s6-rerun.out` |

All FAILs resolved: the only failures found were environment/
infrastructure (dead model name, tool-schema-incompatible backend,
society typo), each fixed minimally and followed by a targeted re-run of
only the affected scenario. No open role-level failures.

## 4. Fixes applied and re-runs

1. `FitAgent/etc/AI/qwen`: `qwen3.6:35b` → `Qwen3.8-27B`; then backend
   `openwebui` → `openai` (server rejects the openwebui tool schema).
   Re-ran S1 (first scenario) to confirm live runs work: PASS.
2. `society` line 162: `specialist:` → `specialist who`. (S5 re-run
   re-verified all-pass.) Note the fix was verified on the S1–S4 live
   runs, which postdate it; the "found by the S6 run" attribution was
   corrected in the S6 section.
3. S6 fixture (Phase-6 repair): the `user:` body contained a literal
   `tasks:` line that Scout parses as a chat directive, producing an
   unexpected `tasks` role the server rejects. Fixed to plain prose
   ("Workspace tasks (bash, copy, …)"); S6 re-run then passed cleanly.
4. S5 script expectation bugs (duplicate cortex task counting; wrong
   expected counts for Manager/Worker): fixed in
   `tmp/ags-smoke/redesign_phase6_hermetic_s5.rb`; no agent files
   touched.

## 5. Open observations (recorded, not blocking)

- Investigator S3 used 9 tool calls where ~2 would do (efficiency
  observation only; provisioning boundaries were respected).
- S6 run 2's assistant turn was never durably captured (stdout 0
  bytes; job log/sandbox transcript held only the failed run 1). The
  reply-discipline behavior is evidenced only by run 3. Authoring
  lesson recorded for the pilot: any literal `<role>:` line inside a
  `user:` chat body is parsed as a chat directive — fixture authors
  must avoid `tasks:`/`tool:`/`user:` colons in prose.
- `redesign-audit-c-matrix.md` §3 caveats re-confirmed by execution:
  workflows named in `tool:`/`introduce:` must be discoverable (they
  were: MiniTools, Workspace, Cortex, Semantics all symlinked into each
  sandbox); `endpoint_analyst` forwarding not exercised (analysis runs
  were not needed for PASS verdicts; smoke verdicts came from direct
  transcript inspection).

## 6. Drift check

- `tmp/ags-smoke/agents` snapshot vs repo at run time: byte-identical
  (md5) for all five roles' `start_chat`, `society`, `doctrine`,
  `doctrines/*`.
- Repo drift caused by this phase: `FitAgent/etc/AI/qwen` (endpoint
  fix), `society` (typo fix — working tree, matching the working-tree
  nature of the introduced edit). `git status` otherwise unchanged from
  the phase start (the other 20 modified/untracked entries predate this
  phase and were not touched).
- No agent/shared-doc edits beyond the two minimal fixes above; no
  evaluation rubrics or scores produced anywhere.
