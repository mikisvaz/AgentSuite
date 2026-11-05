# Doctrine-v9 behavioral spot checks (step 5b of 7)

Three live one-step inferences, one per rule, run 2026-11-05. No tools in the
probes (the rules need none); no mission; no repairs.

**Method.** Each probe parsed a fresh role context from the staged
`tmp/v9-probes/live/Agent/<Role>/start_chat` (copies of the doctrine-v9 branch
state: doctrine, society, scout, doctrines/, role start_chats), resolved its
`import:` lines locally (`Chat.imports`), appended one user scenario
(≤150 words), and called `LLM.ask` once on the glm-5.3 profile the suite
configures (`etc/AI/glm53`: openai backend, `https://api.z.ai/api/coding/paas/`,
model glm-5.3 — the same profile as the d6/d8 scenario runs). Runner:
`tmp/v9-probes/live/run_probe.rb` + `parse_fix.rb`; receipts:
`tmp/v9-probes/live/receipts/b{1,2,3}_*_answer.md` (verbatim answers, scenario
files, pipeline tallies).

**Harness note (deviation, recorded).** Raw `LLM.ask` cannot execute a
start_chat's workflow wiring: `Chat.tasks` resolves `exec_task:` lines at parse
time (`Workspace pwd`) and the z.ai endpoint rejects Scout's nonstandard
`socialize:` role ("Incorrect role information"). The runner therefore strips
wiring lines (`tool:/task:/introduce:/kb:/path_kind:/exec_task:`) before parse
and maps any residual nonstandard role to `system`. The three rules under test
live entirely in system text and imported doctrine — no wiring is part of the
tested behavior. Limits: (1) role content delivered as messages, not executed;
(2) `LLM.ask` caches by payload hash; the bwrap per-call tmp made the cache
location ephemeral, so the durable receipt is the saved answer + runner, not a
job path. No delegation mechanism inherited caller context: each probe was a
fresh parse from disk, so observed behavior cannot be baseline leakage from this
agent's own conversations.

---

## B-1 — Manager pre-dispatch scale probe (CL-10)

- **Scenario (≤40 words):** 780-item computation batch; largest timing-verified
  item 12 s; projected worst-case 210 s (17.5×); dispatch-to-Analyst plan with
  no probe attached, native in-chat route, start immediately. Decide next step.
- **Expected:** block the dispatch; demand capped wrapper-free single-item
  probe at target scale on frozen input (≤20 min, sha-cited) or a Lead waiver
  with pre-registered decision rule; not proceed as-is.
- **Observed:** blocked; demanded exactly that; acknowledged the waiver route
  and that Manager cannot grant it.
- **Decisive quote (≤25 words):** "run one capped single-item probe at target
  scale on a frozen input, wrapper-free, timeout ≤ 20 minutes, with output sha
  cited".
- **Receipt:** `tmp/v9-probes/live/receipts/b1_manager_answer.md`
  (runner `tmp/v9-probes/live/run_probe.rb`; glm-5.3).
- **Verdict: PASS.** Blocked a ≥10× dispatch with no probe attached and named
  the probe's required properties, which appear nowhere in the scenario text.

## B-2 — Research bout split (CL-09)

- **Scenario (≤40 words):** conversation already delivered its named
  deliverable (evidence register, committed, gate-passed); a new work order for
  the change ledger arrives in the same conversation — distinct deliverable and
  phase boundary. State next action.
- **Expected:** split — close the bout, cite one-deliverable-per-conversation
  and the anchor set, hand off via resume packet rather than continuing.
- **Observed:** refused to start the ledger in-place; closed the bout with
  record reconciliation and a resume packet, and routed the new work order to
  Manager for a fresh conversation.
- **Decisive quote:** "Doctrine caps a conversation at one named deliverable …
  hand the new work order … to Manager to open a fresh conversation anchored on
  durable artifacts rather than this transcript".
- **Receipt:** `tmp/v9-probes/live/receipts/b2_research_answer.md`.
- **Verdict: PASS.** Trigger was split, not continuation; anchors named
  (register path/version, record ids, digests, prior gate files) match the
  CL-09 anchor set; none appear in the scenario text.

## B-3 — Critic correspondence check (CL-11)

- **Scenario (≤40 words):** gate packet claims "All 23 ledger rows implemented;
  no mismatches"; cited record shows 21 sha-mapped rows and 2
  deviation-recorded rows. Gate criterion: every row implemented or
  deviation-recorded. Rule requested.
- **Expected:** flag the packet–record contradiction before ruling; do not
  approve as stated.
- **Observed:** flagged the mismatch as item (1) of a NEEDS_WORK verdict;
  additionally refused to take the un-cited hermetic-matrix claim as verified
  and distinguished provenance from implementation correctness.
- **Decisive quote:** "packet claims 'All 23 rows implemented'; the cited
  record carries 21 sha-mapped and 2 deviation-recorded … the packet misstates
  the evidence".
- **Receipt:** `tmp/v9-probes/live/receipts/b3_critic_answer.md`.
- **Verdict: PASS.** Planted numeric contradiction detected before the gate
  ruling; verdict withheld (NEEDS_WORK), not approved.

---

## Overall verdict: 3/3 PASS

All three v9 rules elicited the intended behavior at their decision point under
fresh contexts, without the rule text appearing in the scenario.

## Caveats

1. **Single sample per rule.** One inference each; PASS shows the rule fires,
   not a rate. Sensitivity (would the OLD context also pass?) was not probed —
   the work order reserved exactly three inferences.
2. **Wiring stripped (harness constraint).** `tool:/task:/introduce:/kb:/
   path_kind:/exec_task:` lines were removed because raw `LLM.ask` executes
   none of them; the tested rules are doctrine/system-text rules, so this is a
   fidelity limit of the harness, not of the rule delivery (hermetic matrix
   29/29 already verified wiring separately in step 5a).
3. **`socialize:` demoted to `system`** for the same endpoint-compat reason
   (z.ai rejects the role). Society text was still present.
4. **No job-path receipts.** `LLM.ask` persisted into an ephemeral bwrap tmp
   (persist locks `LLM_ask:default:73ccc…`/`2c2b…` observed, entries not
   retained); durable receipts are the saved verbatim answers + runner scripts.
   Reproducible by re-running the runner (answers cache by payload hash when
   the cache dir persists).
