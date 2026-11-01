# Phase 7 pilot report — bounded AGS route exercise (mission foxo-pi3k)

**Phase 7 of the AgentSuite redesign** (branch `ags-redesign`, drift baseline
`a552de1`). This report executes the redesign-ags-route.md pilot: one real
investigation through the new loop. It cites durable paths; bodies are not
pasted.

## Which mission ran

**Surrogate** (sanctioned by the route's fallback clause). Evidence for the
decision, recorded at intake and kept at `tmp/ags-pilot/AGS_REACHABILITY.txt`
and `ags/foxo-pi3k/mission.md`:

- `/bulk/mvazque2/git` contains only `AgentSuite`, `scout-ai`,
  `scout-essentials`, `scout-gear` — no AGS checkout anywhere (find over `/`
  maxdepth 5 for a `AGS` directory: zero hits outside proc).
- `cortex_path_map.yaml` declares maps pointing at `~/git/workflows/...`,
  which do not exist from this sandbox; there is no AGS map entry. Only the
  `:current` map is readable.
- This reproduces the Phase 6/audit §4 finding (AGS substrate unreachable),
  re-verified rather than assumed.

The surrogate mission is the bounded literature-reasoning variant of the same
FOXO/PI3K question: "does FOXO transcriptional activity increase when
PI3K/AKT signaling is inhibited, in the society's own documented knowledge?"
— answered over the society's own knowledge only, every conclusion labeled
prior-domain-knowledge.

## Loop execution (per route stages; owners as in §2 of the route doc)

| Stage | Owner | Conversation | Durable deliverable |
|---|---|---|---|
| 1 Intake | Manager | `ags-foxo-pi3k` | `ags/foxo-pi3k/mission.md` (written by Research from the Manager's Curator request) |
| 2+3 Recon + background | Searcher | `ags-foxo-pi3k` | `ags/foxo-pi3k/evidence/background-brief.md` (finding: no internal FOXO/PI3K material anywhere searched) |
| 4 Lead outline | ScientificLead | `ags-foxo-pi3k` (Lead turn) | `ags/foxo-pi3k/questions/lead-outline.md` (verbatim persist) |
| 5 Registration | Research | `ags-foxo-pi3k-record` | `ags/foxo-pi3k/questions/Q1.md`, `Q2.md`, `Q3.md` |
| 6 Investigation | Investigator ×3 | `ags-foxo-pi3k-q1`, `-q2`, `-q3` | `ags/foxo-pi3k/evidence/Q1-answer.md`, `Q2-answer.md`, `Q3-answer.md` |
| 7 Lead review | ScientificLead | `ags-foxo-pi3k-lead` | `ags/foxo-pi3k/reports/lead-review.md` (verbatim persist) |
| 8 Consolidation + Critic gate | Research, Critic | `ags-foxo-pi3k-record`, `ags-foxo-pi3k-critic` | closure edits on Q1-Q3 + mission status; `ags/foxo-pi3k/reports/critic-gate.md` (verbatim persist); `ags/foxo-pi3k/reports/final.md` |

All mission artifacts carry `.info` provenance sidecars and prior-version
history under `.files/history/` (see `cortex_list ags/foxo-pi3k/` — 19 entries
incl. sidecar history). Mission answer (two-part bounded conclusion): reading L
— no FOXO/PI3K material in the society's documented knowledge (verified absence
in searched locations, remainder unverified/low-prior); reading S — canonical
PI3K→AKT→FOXO logic predicts FOXO transcriptional activity **increases** under
PI3K/AKT inhibition (prior-domain-knowledge; directional only).

## First-turn probes (delivered-context verification)

Probes ran before any role work was dispatched (`ags-pilot-endpoint-probe*`
conversations; `tmp/ags-pilot/runlogs/ags-pilot-endpoint-probe-*.log`):

1. **Probe finding 1 (endpoint)** — direct `cortex_continue` calls from this
   harness hit `api.openai.com` with an invalid key (401; the FitAgent etc/AI
   qwen endpoint is not visible to this process). Root cause: agent
   `start_chat` had no `option endpoint` line, so no endpoint was resolved.
2. **Probe finding 2 (role context)** — with the endpoint fixed, the Lead
   probe still returned "NO ROLE CONTEXT": `LLM::Agent.load_agent` resolved
   `ScientificLead` via `Scout.Agent[...]`, which found the repo's
   `ScientificLead/` dir with only `start_chat` and no workflow — while the
   rewritten agent dirs (with role doctrine) live under `Agent/<Role>/`.
   Repair (staging, recorded as deviation 1 below): copy
   `Agent/<Role>/start_chat` to `<Role>/start_chat` with the endpoint option
   prepended. After staging, the Lead probe confirmed role context
   ("...you as the society's Lead", `ags-pilot-role-context` conversation).
3. Every staged conversation's first turn was then a role/context probe or an
   operational first turn whose reply was verified from the artifact/stdout
   before the next dispatch (Phase 6 carry-list practice), e.g. the Research
   Curator turn confirmed `mission.md` before the Searcher was dispatched.

## Lead review outcomes

Stage 7 verdict (conversation `ags-foxo-pi3k-lead`, persisted verbatim as
`ags/foxo-pi3k/reports/lead-review.md`): Q1 CLOSED (negative finding with
verified scope), Q2 CLOSED (direction INCREASE, 7-link PDK-labeled chain,
"what counts against H" adjudicated), Q3 CLOSED (scope + four caveats +
uncertainty + two-branch reopening condition). **Overall: SUFFICIENT** — all
three sufficiency-plan conditions of the outline hold.

## Critic verdict

Stage 8 gate (conversation `ags-foxo-pi3k-critic`, persisted verbatim as
`ags/foxo-pi3k/reports/critic-gate.md`): **PASS** on all four checks —
provenance chain (10 artifacts, sidecars, cited job receipts all resolve),
closure (Q1-Q3 closed citing evidence; mission `answered`), label integrity
(no prior-domain-knowledge content presented as measured data), sufficiency
logic (decision entailed by the closures; no scope drift). One optional
cosmetic repair performed (backfill `agent: Investigator` in the
`Q3-answer.md.info` sidecar only).

## Stop condition

**S1 — Lead sufficiency declaration** at stage 7, ratified by the Critic PASS
at stage 8 (S6 close-with-budget-remaining honored). Budget respected: 3
questions (cap 3), broad search 1/1 spent at stages 2+3, 0 branch switches
(cap 1), no over-budget repairs. Not budget-driven.

## Deviations from the route doc

1. **Agent staging (start_chat)** — role agents had no start_chat context
   until `Agent/<Role>/start_chat` copies (with `option endpoint qwen`
   prepended) were placed at `<Role>/start_chat`; root cause is the dual
   `Agent/<Role>` vs bare `<Role>` lookup path (see probes above). Affected
   dirs: Manager, ScientificLead, Investigator, Research, Searcher, Critic,
   Reader, User, Worker.
2. **Workflow symlinks** — `workflows/{Reader,Workspace,ScoutCoder,Semantics}`
   symlinks were created so `tool:` introduction lines resolving bare workflow
   names would load during role-agent construction (first Research dispatch
   failed with `RuntimeError: Workflow Workspace not found`, then Reader, then
   ScoutCoder).
3. **Conversation set** — the curation thread followed route 6.1's optional
   `ags-<slug>-record` name (`ags-foxo-pi3k-record`), but no fresh
   `ags-<slug>-report` conversation was staged: the route's stage-9 report step
   (fresh conversation synthesizing from cited paths) was executed inside
   stage-8 consolidation, with Research composing
   `ags/foxo-pi3k/reports/final.md` from cited paths.
4. **Probe conversations** — `ags-pilot-endpoint-probe*` and
   `ags-pilot-role-context` exist as operational probe conversations (this
   pilot's C10 right), outside the route's mission conversation set.
5. **Endpoint hygiene** — the live endpoint was selected via the staged
   `option endpoint qwen` lines; no key material was reproduced anywhere in
   outputs or artifacts (Phase 6 carry rule respected; the 401 probe output
   contains only the OpenAI error text).

## Drift check

- Baseline (bout start, recorded in `tmp/ags-pilot/DRIFT_START.txt`):
  `git diff 1116c9a --stat` → 15 files, +643 −365 (matches route §8 note).
- End (recorded in `tmp/ags-pilot/DRIFT_END.txt`): identical —
  15 files, +643 −365; untracked count still 27 (adds: `Agent/`, `workflows/`
  symlinks, `new_doctrine/work/redesign-pilot-report.md` and
  `redesign-pilot-resume-packet.md`, `tmp/ags-pilot/`).
- Conclusion: **no tracked-file drift beyond the pre-existing route delta**;
  all bout writes are untracked operational artifacts (mission artifacts live
  in Cortex under `var/cortex/` — also untracked, as designed for the pilot).

## Open issues (route-level, not mission-level)

1. `LLM::Agent.load_agent` resolving bare `ScientificLead/` (start_chat-only)
   over `Agent/ScientificLead/` is an environment/packaging gap for role
   agents in this checkout; the staging copies are the pilot's workaround.
2. Workflow tool-introduction requires the workflow to be resolvable at agent
   construction; `workflows/` symlinks are a checkout-shape workaround.
3. `Cortex` continuation claims from crashed/failed constructions are not
   auto-released (manual `.claims/<sha>.json` removal needed when a launch
   dies before the job registers); handled inside
   `tmp/ags-pilot/launch_role_turn.sh`.
4. Stage 9 (fresh `-report` conversation) was folded into stage 8 for this
   bounded pilot; a full-scale mission should exercise it as designed.

## Resume packet

`new_doctrine/work/redesign-pilot-resume-packet.md` — mission decision
evidence, stage map, remaining work, resume paths.
