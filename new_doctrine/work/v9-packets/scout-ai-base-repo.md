# Delegation packet — scout-ai base-repo fixes (from doctrine-v9)

Recipient: scout-ai base-repo maintainer. Source: doctrine-v9 evidence
register (`new_doctrine/work/v9-evidence-register.md` on branch doctrine-v9
of AgentSuite; run trees cited per item are read-only x-ray exports — the
essential figures are inlined below so this packet is self-contained).
Evidence from three instrumented multi-agent runs (d6 = glm5/doctrine6,
d7 = glm5/doctrine7, d8 = science.v2/doctrine8).

---

## 1. Exec-task failure surfacing: bwrap wrapper hides inner exit status

- Evidence (inlined): d6 — 62 raw bwrap exit −1 launch failures, cause-blind
  (friction C01/RB-5). d7 — 107 raw / 26 deduplicated −1 wrapper failures,
  ≈4.2M tt wasted retrying (FR-03/RM-03). d8 — 70 `.info`-only jobs (no
  `.error`, no stdout); kills reached the Lead 7.5 h after they happened
  (P0-2, findings C-4/F1/F5/F6).
- Root cause: when a sandboxed exec task dies (kill/timeout/launch failure),
  the wrapper reports bwrap's own −1 exit and discards or never captures the
  inner process's exit status and stderr; the job directory is born with only
  a `.info` file and the late-written `.error` is rejected (item 2).
- Requested change: propagate the inner exit code and the tail of stderr
  through the wrapper; when capture is impossible, write an explicit
  "inner status unknown" marker instead of −1.
- Acceptance test: a deliberately killed exec task (e.g. `sleep 300` under
  `timeout 5`) produces a job dir with the real inner exit status (124) or the
  explicit unknown-marker — never bare −1 with no diagnostic.

## 2. Job birth visible only as .info; late .error write rejected

- Evidence (inlined): d8 — H-004 branch: Manager sat idle-blocked ≈6 h waiting
  on a job that had already died; 70 jobs had `.info` only. F6: when `.error`
  was written late it was not accepted into the job record.
- Root cause: jobs materialize `.info` at birth; failure artifacts are written
  at a stage that has already been torn down or already validated its file
  set, so the failure never lands where polling agents look.
- Requested change: write a tombstone (`.error` or status field) atomically
  with/inside the failing operation; allow `.error` to attach to an existing
  `.info`-only job.
- Acceptance test: kill a running job mid-execution; a polling `job.info`
  read within one poll interval must show a failed/present-error status.

## 3. cortex_brief tool attachment fails at spawn

- Evidence (inlined): d8 F8/P1-4 — the brief existed on disk, the Worker spawn
  did not attach it; ≈33k tt spent before the run discovered the brief's tools
  were empty. Verified harness defect (not agent error).
- Root cause: brief tool blocks are persisted in the brief body but the spawn
  path does not reliably attach them to the child agent's chat.
- Requested change: attach brief tooling at spawn; record a **tools-attached
  receipt** in the spawned job's `.info` (list of attached tool specs).
- Acceptance test: `cortex_continue --agent Agent/<brief>` on a brief with
  `tools:` entries produces a job `.info` whose receipt lists those tools, and
  the child's first context contains the tool definitions.

## 4. Char-based pagination for single-line large outputs

- Evidence (inlined): d6 C11 — `read`/`list` 100k-char cap refusals; d6 C17 —
  single-line large outputs resist line pagination (linked RB-5(d)). Every
  occurrence was absorbed by agents adapting in one call — the cost is real
  but bounded; still a harness gap.
- Requested change: add char-offset pagination (start/chars) to line-based
  read surfaces.
- Acceptance test: a 1 MB single-line file can be read in 100k-char windows
  without refusal.

## 5. path_write compaction-guard false positive

- Evidence (inlined): d6 C13 — the compaction-tag guard rejects legitimate
  quoted content in ScoutCoder path_write drafts.
- Requested change: scope the guard to actual compaction markers, not any
  quoted occurrence.
- Acceptance test: a draft legitimately containing the phrase "compaction" in
  quotes writes successfully; a real compaction marker is still rejected.

## 6. Mirror-chat confusion

- Evidence (inlined): d6 C18 — result-mirror chats carry 0 canonical
  inferences; naive token sums over them mislead accounting.
- Requested change: label mirror chats distinctly (metadata flag) so
  accounting can exclude them.
- Acceptance test: a mirror chat reports a canonical-inference count of 0 and
  a flag that lets a sum script exclude it.

## 7. Per-call token metering absence

- Evidence (inlined): audit gap across d6–d8 — resource accounting is
  reconstructed post-hoc from x-ray exports, not metered per call.
- Requested change: per-call pt/tt metering available from job artifacts.
- Acceptance test: any inference's pt/tt readable from its own job record
  without run-wide reconciliation.

## 8. Staged Agent/ namespace requirement — root fix

- Evidence (inlined): every agent parse/deploy must stage an `Agent/` namespace
  (probe scripts, `.save/Agent/`, run trees all carry copies); AgentSuite's
  own `bin/bundle_doctrine.sh` exists solely to produce this staging set —
  and it must be re-run by hand after every doctrine/start_chat edit, a
  recurring friction (d7 FR-04 family; v9-baseline.md friction inventory).
- Requested change: make role resolution read the repository's role files
  directly (or auto-stage on change) so a hand-run bundling step is not
  required for correctness.
- Acceptance test: editing a role start_chat and immediately launching an
  agent reflects the edit with no intermediate bundling step.

## 9. socialize capability fails on z.ai (error 1214)

- Evidence (inlined): v9 5b probe — `LLM.ask` with a `socialize:`-capability
  role returned z.ai error 1214; stripping the capability made the same call
  succeed (tmp/v9-probes/live receipts; v9-behavioral-results.md caveat).
- Requested change: either drop the unhandled capability from the default
  payload or translate it for the openai-compatible endpoint.
- Acceptance test: a `socialize:` role answers through the openai backend
  without a 1214.

Priority order: 1, 2, 3 (causal chains that idled agents for hours), then
8, 9, then 4–7. Register rows behind each item: d6 RB-5/C01/C11/C13/C17/C18,
d7 RM-03/FR-03/FR-04, d8 P0-2/P1-4, plus v9-baseline BF rows.
