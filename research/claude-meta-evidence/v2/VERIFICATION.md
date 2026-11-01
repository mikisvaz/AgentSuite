# Revised Claude per-message metas — live verification (v2, 2026-10-30)

Two live runs of the revised `Claude/workflow.rb` (`ask`, 657 lines), claude CLI
2.1.306, model glm-5.2 (`ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic/`),
AgentSuite checkout under `/bulk/mvazque2/git/AgentSuite`. Evidence copied
verbatim from the job dir immediately after each run (`-cl` reruns overwrite the
digest job dir in place).

Runs:
- `multi-turn` — two-sequential-tool-call probe chat (`input-main.chat`, from
  `tmp/claude-meta-probe/main.chat`). Job `Claude/ask/Default_098ce77d256140f4c341f20c06464cbf.chat`.
- `read_file` — the user's reference scenario
  (`~/git/sandbox/Scenarios/scenarios/read_file/main.chat`, `file.txt` 4 lines).
  Job `Claude/ask/Default_08fa9dec7b4433768124597f1113bd7c.chat`.

Manifests verified with `sha256sum -c` (all OK):
- `v2/multi-turn/MANIFEST.sha256` — 6 files
- `v2/read_file/MANIFEST.sha256` — 7 files

## Run 1: multi-turn (3 API turns)

Result event (events.jsonl:184): `num_turns=3 usage_in=520 out=290
cache_read=3392 cache_creation=0 cost=0.011546`; debug.log:210
`[engine] turn 1 end (turns=3 usage in=520 out=290 cost=$0.0115 ... resultLen=94)`;
3 `[API REQUEST]` lines. Turn estimates from events.jsonl segmentation:
turn 1 lines 3–158 est→243 (sum deltas 243); turn 2 lines 162–179 est→24 (sum
deltas 24); turn 3 no thinking events (result `thinking_tokens=0`).

First accounted meta (chat line 3, verbatim, before the first function_call):
```
meta: rt_s=243 rt_c=243 rt=243 cwt_s=0 cwt_c=0 cwt=0 cct_s=0 cct_c=0 cct=0 tt_s=0 tt_c=0 tt=0 ct_s=0 ct_c=0 ct=0 pt_s=0 pt_c=0 pt=0 model=glm-5.2 timestamp=2026-10-30T11:33:53.931Z inference_id=23ed7ac5-585d-4145-874e-75af4394adb0
```
Final accounted meta (chat line 9, verbatim, before the assistant message):
```
meta: rt_s=267 rt_c=267 rt=0 cwt_s=0 cwt_c=0 cwt=0 cct_s=3392 cct_c=3392 cct=3392 tt_s=810 tt_c=810 tt=810 ct_s=290 ct_c=290 ct=290 pt_s=520 pt_c=520 pt=520 model=glm-5.2 timestamp=2026-10-30T11:33:56.667Z inference_id=db7c4985-432e-471e-9de1-6ec46debda2f
```

## Run 2: read_file (2 API turns)

Result event (events.jsonl:25): `num_turns=2 usage_in=87 out=108 cache_read=2048
cache_creation=0 cost=0.004159`; debug.log:192 `[engine] turn 1 end (turns=2
usage in=87 out=108 ... resultLen=230)`; 2 `[API REQUEST]` lines. Turn
estimates: turn 1 lines 3–20 est→22 (sum deltas 22); turn 2 none.

First accounted meta (chat line 3, verbatim):
```
meta: rt_s=22 rt_c=22 rt=22 cwt_s=0 cwt_c=0 cwt=0 cct_s=0 cct_c=0 cct=0 tt_s=0 tt_c=0 tt=0 ct_s=0 ct_c=0 ct=0 pt_s=0 pt_c=0 pt=0 model=glm-5.2 timestamp=2026-10-30T11:35:04.798Z inference_id=c1870f6e-88a0-4cbe-978a-fc7671935939
```
Final accounted meta (chat line 7, verbatim):
```
meta: rt_s=22 rt_c=22 rt=0 cwt_s=0 cwt_c=0 cwt=0 cct_s=2048 cct_c=2048 cct=2048 tt_s=195 tt_c=195 tt=195 ct_s=108 ct_c=108 ct=108 pt_s=87 pt_c=87 pt=87 model=glm-5.2 timestamp=2026-10-30T11:35:06.918Z inference_id=aeb48225-ab75-4272-a7a7-5cab763854e9
```

## Check results

### 1. Layout — PASS (both runs)
Block sequences (job .chat):
- multi-turn: `meta(job) meta fc fco meta fc fco meta assistant`
- read_file: `meta(job) meta fc fco meta assistant`
Every `function_call:` / `assistant:` block is immediately preceded by exactly
one accounted `meta:` line; the `job=` meta is first; the chat ends on the
assistant message — no trailing meta (last byte of both saved .chat files is
`.`, the sentence terminator, not a meta line). No degenerate-run fallback
needed.

### 2. Telescoping — PASS (both runs)
Parsed from the saved .chat files:

| check | multi-turn | read_file |
|---|---|---|
| first accounted meta tt_c == tt | 0 == 0 ✓ | 0 == 0 ✓ |
| sum of metas' deltas == final *_c | pt 520, ct 290, tt 0+0+810=810, cct 3392, cwt 0, rt 243+24=267 == final `pt_c=520 ct_c=290 tt_c=810 cct_c=3392 cwt_c=0 rt_c=267` ✓ | pt 87, ct 108, tt 0+195=195, cct 2048, cwt 0, rt 22 == final `pt_c=87 ct_c=108 tt_c=195 cct_c=2048 cwt_c=0 rt_c=22` ✓ |
| final tt_c == result pt+ct | 810 == 520+290 ✓ | 195 == 87+108 ✓ |
| cct_c/cwt_c == result cache | 3392/0 == cache_read 3392 / cache_creation 0 ✓ | 2048/0 == 2048/0 ✓ |
| rt_c == sum of turn estimates | 267 == 243+24 (turn 3 has no thinking) ✓ | 22 == 22 ✓ |
| *_s == *_c | equal in both runs (single ask job per session) ✓ | ✓ |
| all six base keys + *_c + *_s present | 18/18 keys in every accounted meta, no extras ✓ | ✓ |

rt is per-turn estimate totals and is NOT additive into tt (rt ⊂ ct): the final
multi-turn meta carries rt=0 yet ct=290 includes the session's 267 reasoning
tokens — as designed.

### 3. Counting (`scout-ai llm prov -e <saved .chat>`) — PASS (both runs)
multi-turn:
```
root deduplicated_total=810 (3 events) prompt=520 cache=3.4K@652.3% fresh=-2.9K cont=290 reason=267
23ed7ac5-... total=0 reason=243   ... counted once
f8b7eabf-... total=0 reason=24    ... counted once
db7c4985-... total=810 prompt=520 cont=290 cache=3392 ... counted once
```
read_file:
```
root deduplicated_total=195 (2 events) prompt=87 cache=2K@2354.0% fresh=-2K cont=108 reason=22
c1870f6e-... total=0 reason=22  ... counted once
aeb48225-... total=195 prompt=87 cont=108 cache=2048 ... counted once
```
Totals equal the result-event usage exactly (input→pt, output→ct,
cache_read→cct, cache_creation→cwt, reason = sum of turn rt estimates), and
each of the 3/2 API turns is counted exactly once (dedup by inference_id).

### 4. Non-regression — PASS (both runs)
Job `.info` still merges `"model":"glm-5.2"`, the full usage hash
(`input_tokens 520 / 87`, `cache_read_input_tokens 3392 / 2048`,
`output_tokens 290 / 108`), `total_cost_usd 0.011546 / 0.004159`,
`session_id e7f6d0c6-6893-4e85-8eb5-91750094df89 /
3a50baf1-7dd5-432d-97df-ea1ce808a928`. keep_reas default still strips `reas`
from the projection: `grep -c 'reas='` over the saved job .chat files = 0 for
both runs, while the raw `agent.chat` retains them (multi-turn 2, read_file 1,
e.g. `reas=The user wants to count lines in ./file.txt. I'll use wc -l.`).

## Nuances / notes
- No surprises. Both runs produced clean layouts on first execution; no
  fallback meta was emitted.
- Prefix caching: the multi-turn chat was run before (v2-probe, 11:03) and
  again here (12:33) with essentially identical numbers (pt 520 both times,
  cct 3392 both times, ct 274 vs 290 — answer text differs slightly). No
  cross-run cache discount was observed; each run is a fresh claude session
  (`session_id` differs).
- Reasoning-token coverage differs between runs: multi-turn turn 3 emitted no
  thinking events at all (rt=0 for that turn), read_file turn 2 likewise; the
  metas correctly show rt=0 for those turns while rt_c keeps the session sum.
- Probe note: `Chat.token_totals`/`Chat.project` could not be driven directly
  from a one-liner in this environment (wrong argument arity for the 2.1.0
  internal API); the CLI `scout-ai llm prov -e` is the acceptance instrument
  used, as specified in the task.

## Reproduction
```
cd /bulk/mvazque2/git/AgentSuite/tmp/claude-meta-probe && \
PATH=/home/mvazque2/tmp/claude-cli/bin:/home/mvazque2/.local/share/pi-node/node-v22.22.3-linux-x64/bin:$PATH \
BWRAP_PATH=false scout-ai workflow task Claude ask --chat <ABSOLUTE_CHAT_PATH> -cl
BWRAP_PATH=false scout-ai llm prov -e <saved job .chat>
```
The local `workflows/Claude` symlink points at the AgentSuite checkout, so the
runs above exercised the revised code live.
