# Research native dossier implementation report

Authority: this report closes the build (WO-8). Design authority:
`research/native-dossier-design-decisions.md` (sha256 85deee8c…45801).
Walkthrough: `doc/user/Walkthrough.md`; drift alarm:
`share/walkthrough/check_tasks_doc.rb`. All receipts cited below are
retained in this checkout.

## 1. Mission summary

Research gained a native dossier store: question, claim and hypothesis
records as ordinary files under a research root, mutated through nine
exported `exec` tasks with revisioned documents, optimistic concurrency,
per-dossier locks and batch-atomic evidence attachment (copy with digest,
reference with identity). The build replaced the earlier path-kind
observation registry wholesale (breaking change, WO-6): the `PATH_KINDS`
tree, path-kind code, the observation kind and their tests were deleted;
existing user record files were left untouched. Documentation was rebuilt
consumer-first (README, doc/user README + Tasks, doc/developer, start_chat,
three skills), and this dispatch added a runnable end-to-end walkthrough
verified verbatim, a Tasks.md drift alarm, and this report.

## 2. Native task inventory (cross-checked against workflow.rb)

All nine are `export_exec` tasks: every dispatch performs; there is no
persistent job tree (a `var/jobs` never appears under the research root —
verified by `ls` during the walkthrough probes). Common input:
`research_root` (string, overrides config/env/default; roots isolated,
IDs root-local). Rejections return exception objects through the agent
surface and never crash the host process (walkthrough step 6 shows the
real `StaleRevision`-class error text from `LLM.call_workflow`).

| Task | Contract |
|---|---|
| `dossier_create` | inputs `type` (question/claim/hypothesis), `title`, `content?`. Output: root-local id (Q/C/H-xxx), revision 1, directory, entry document README.md, Markdown link, record path + digest. Bounds: type validated; id minted per type under the root lock. |
| `dossier_list` | inputs `type?`, `query?`, `limit` (1..1000, default 100), `continuation?`. Output: paged id/title/type/revision/location. Query matches id, title, authored-document names, CURRENT authored contents only (never history snapshots, never attachment bytes); one document read per listed dossier — scan cost documented. Derived live; no index file. |
| `dossier_read` | inputs `id`, `document?` (README.md or supplements/<name>), `revision?`, `overview?`, `start_line?` (1-based), `max_lines?` (1..5000, default 500). Output: raw text separated from line-number metadata; overview = entry metadata + attachment inventory. Rejects evidence binaries. |
| `dossier_update` | inputs `id`, `expected_revision`, `document?`, `mode` (create_document/replace_document/replace_lines/delete_lines), `content?`, `replacement?`, `start_line?`, `end_line?` (half-open), `change_note?`. No-op edits create no revision; stale revision rejected under the per-dossier lock; external edits (drift) never adopted — rejected with guidance to `dossier_capture`. |
| `evidence_attach` | inputs `id`, `expected_revision`, `items` (JSON array; soft cap 100 items/call), `change_note?`. Item: source, slot, mode copy/reference, name/caption/script/parameters/inputs/receipt/replace?. Copy retains exact bytes; digest computed from retained bytes. Reference retains source identity + observed digest; references under ephemeral roots are rejected, durable-but-outside-job-tree sources attach with a warning. Batch-atomic: any item failure (directory source, stale revision, name collision) fails the whole batch. |
| `evidence_read` | inputs `id`, `attachment`, `revision?`, `start_line?`, `max_lines?`. Output: metadata, caption, source, retained address, observed integrity state (changed/unavailable reported, never current-bytes substitution); bounded text for text files, file/media info for binaries. |
| `dossier_check` | inputs `id?` (single) or `type?`/`limit?`/`continuation?` (bounded selection). Read-only mechanical integrity: missing/changed references, corrupted retained copies, broken local dossier links, external view drift, metadata inconsistencies. No scientific verdicts; `not_checked` lists out-of-scope items. |
| `dossier_history` | inputs `id`, `limit?` (1..1000, default 100), `continuation?`, `diff_document?`, `from_revision?`, `to_revision?`. Revision inventory (numbers, timestamps, change notes, document sets, attachment identities/digests) + optional line diff of ONE authored document; diff capped at 2000 lines. |
| `dossier_capture` | inputs `id`, `expected_revision`, `documents` (JSON array, or 'drifted'/'all'), `change_note?`. Captures externally edited authored documents as a new revision, guarded by expected_revision and observed digests; rejects when retained evidence corrupted or no drift. |

Cross-check: `Research.job(:dossier_list, workflow: 'Research')` task listing
plus `workflow.rb` `Research.task` blocks parsed by the drift alarm — all
nine names and every declared input (`research_root` shared, task blocks'
parameters) present in `doc/user/Tasks.md`.

## 3. Changed/added/deleted files

Added this dispatch (WO-8):
- `doc/user/Walkthrough.md` — runnable end-to-end scenario with real outputs.
- `share/walkthrough/run_walkthrough.rb` — runs the scenario (`run`) and
  verifies every documented JSON block against a fresh run (`verify`).
- `share/walkthrough/check_tasks_doc.rb` — Tasks.md drift alarm (see §7).
- `results/walkthrough-output/` — 21 step-tagged output JSONs, verify log,
  receipt (working artifacts retained as receipts; `results/` is gitignored).
- `results/w08-input.tsv`, `results/w08-extract.py` — synthetic staged
  extraction files used by the walkthrough (gitignored scratch).
- `research/native-dossier-implementation-report.md` — this report.
- README.md: walkthrough + drift-alarm pointer lines (edit, not add).

Earlier build waves (as dispatched, WO-2..WO-7; full detail in the
respective WO completions — summarized here as inventory):
- `workflow.rb` — rewritten: nine task declarations, `export_exec`, no
  path-kind registration, no `jobname`.
- `lib/Research/` — `store.rb`, `ids.rb`, `line_edit.rb`, `common.rb`,
  `tasks/{dossier_create,dossier_list,dossier_read,dossier_update,evidence,
  evidence_attach,evidence_read,dossier_check,dossier_history,dossier_capture}.rb`.
- `test/Research/` — store/ids, line_edit, task suites (8 files),
  registration test.
- `doc/user/README.md`, `doc/user/Tasks.md`, `doc/developer/README.md`,
  `start_chat`, `skills/` (three), `README.md` rewritten.
- Deleted (WO-6, breaking): `lib/Research/path_kinds/` tree, the observation
  Path kind and its registration, `test/…/test_path_kinds*.rb` and the eight
  retired-API tests, `research/design_evidence.rb`.
- Existing user record files: untouched (WO-6 verification receipt cited in
  §4).

## 4. Retired components and the breaking change

Retired wholesale: `PATH_KINDS` registration and the whole path-kind code
path (the Research `Path` kinds from the earlier design), the observation
kind, and the API tests that exercised them (eight test files). This is
breaking for anything that called the retired surfaces. No migration was
performed and no replacement observation registry was created — records
live as dossiers with ordinary-document semantics; historical notes in
user-visible docs are marked as historical where relevant.

Existing user record files were not touched: WO-6 verified this and the
receipt is the WO-6 completion report (no record-tree writes during
retirement; retirement only deleted Research's own code). I did not
re-verify WO-6's file-level guarantee this dispatch; it is cited, not
re-executed.

## 5. Storage guarantees and limitations

Guarantees: revision coherence (monotonic per-dossier revision numbers,
atomic record + view writes under the per-dossier lock); optimistic
concurrency via `expected_revision` (stale rejection under the lock, shown
in walkthrough step 6); interruption/recovery — no partially-visible
mutations (atomic view/record swap; recovery is "re-read and decide", the
documented at-least-once stance); copy retention of exact bytes with digest
computed from retained bytes; reference identity = source path + observed
digest at attach time; capture semantics — external edits only enter
history through `dossier_capture`, guarded and digest-verified.

Known limitations (each also in user docs):
- Reference portability across mounts: references store absolute source
  paths; cross-mount moves invalidate them (`dossier_check` then reports
  unavailable/changed; re-attach is the remedy).
- No explicit check ID list input on `dossier_check` (selection is single
  id or bounded type/limit/continuation pages).
- History diff capped at 2000 lines.
- `delete_lines` is a fourth update mode beyond the mission's three
  (justified: without it, agents could not delete lines at all — see §9).
- Supplements nest at any depth under `supplements/` (not constrained to
  one level).
- `dossier_list` query scans id + title + authored-document names + CURRENT
  authored contents; cost is one read per document per listed dossier.
- Dispatch is at-least-once (exec tasks always perform); idempotence is the
  caller's re-read-and-decide (documented; walkthrough shows it), no
  exactly-once guarantee.

## 6. Test results (fresh run this dispatch)

Per file (fresh processes, `ruby <file>`, this dispatch):

| File | Tests | Assertions |
|---|---|---|
| test/Research/tasks/test_check_history_capture_tasks.rb | 16 | 76 |
| test/Research/tasks/test_dossier_tasks.rb | 25 | 170 |
| test/Research/tasks/test_evidence_tasks.rb | 19 | 84 |
| test/Research/tasks/test_job_level_semantics.rb | 7 | 44 |
| test/Research/tasks/test_registration.rb | 4 | 15 |
| test/Research/store/test_ids.rb | 8 | 21 |
| test/Research/store/test_store.rb | 31 | 107 |
| test/Research/line_edit/test_line_edit.rb | 31 | 62 |
| **Total** | **141** | **579** |

All green (zero failures, zero errors; each per-file run ended with the
standard summary, e.g. `... 31 tests, 62 assertions` — full transcripts not
retained; the counts above are from this dispatch's fresh runs). The
job-level receipts summary (WO-5): job-level semantics covered by
`test_job_level_semantics.rb` (dispatch performs, no persistent job tree,
per-dispatch job-id mechanism — see §9 deviations).

Sandbox status: all runs this dispatch (tests, walkthrough, drift alarm)
were unsandboxed. The sandboxed `run_test` harness path remains
**unverified** — no sandboxed suite run was executed this dispatch; stated
as-is, it is a remaining item (§8).

## 7. Walkthrough

Reproduce: `ruby share/walkthrough/run_walkthrough.rb run` (scenario,
outputs saved under `results/walkthrough-output/`), then
`ruby share/walkthrough/run_walkthrough.rb verify` (fresh root, every
documented JSON block compared against fresh output; exit 0 = 0 failing
blocks). Document: `doc/user/Walkthrough.md`. Verbatim-run receipt:
`results/walkthrough-output/RECEIPT.md` + `verify-receipt.log` (43 lines,
18 PASS block-lines, `ALL: verify 0 failing block(s)`).

Defects found by the walkthrough itself (all doc-side; code was right, all
fixed and re-verified to 0 failing blocks):
- copy-mode digest in step 4: doc carried a digest computed from the staged
  script bytes instead of the retained bytes;
- step 8 `dossier_check` report ordering and step 11 `dossier_list` ordering
  did not match actual output order;
- heredoc quoting in the doc's inline script (Ruby interpolation mangled
  Python escapes; fixed with a single-quoted heredoc `<<~'PY'`).

Harness fixes found by re-running the gate (code-side, harness only — no
workflow code touched): the runner initially wiped the whole output
directory on re-run (deleting receipts beside it) and `verify` parsed every
`.json`-suffixed file there; both now select only the harness's own
`NN-NNN-*.json` step outputs, so receipts persist beside re-runs.

## 8. Concrete remaining issues / extension points

- `dossier_check`: add explicit check ID-list input (bounded) — currently
  single id or paged selection only.
- History diff paging beyond the 2000-line cap (paged diff API).
- Reference portability across mounts (canonical/relative source identity
  or explicit remap operation).
- Replace the bespoke `line_edit` implementation with a shared
  edit-library if one is adopted project-wide.
- Sandboxed-suite verification (run the suite through the sandboxed
  `run_test` harness once; §6).
- start_chat tool-grant confirmation by the launcher (WO-7 OQ3): the
  rewritten start_chat requests specific Research tools; the launcher's
  actual grant behavior is unconfirmed.
- `dossier_list` query: consider a title-only fast path or index if scan
  cost ever matters at real scale.

## 9. Deviations from the mission request and plan

- `delete_lines` fourth mode (update): beyond the mission's three modes;
  without it line deletion is unreachable by agents (dispatch coercion made
  empty-replacement unreachable). Kept, documented in Tasks.md.
- Per-dispatch job-id mechanism: exec dispatches have no persistent job
  tree; identity comes from a per-dispatch job id in results where useful.
  Documented in doc/developer.
- Supplements nested at any depth (not one level): simpler and matches
  document semantics; documented.
- List query scope (title+names+current contents): documented scan cost.
- This dispatch (WO-8) deviations: the walkthrough scenarios were first
  played through `run_probe` children (unsandboxed Ruby that loads the
  checkout) to pin real output shapes; the committed harness now executes
  the documented sequence directly (`bash` + local Ruby, unsandboxed) via
  the same naive-consumer dispatch surface (`LLM.call_workflow`) the doc
  documents; outputs archived. The per-step agent-tool `run_task` surface
  was used where available (Workspace `python` for the extraction); it is
  not available for Research tasks from this ScoutCoder context, so the
  doc's `LLM.call_workflow` examples are the modeled agent surface. Tasks.md drift
  protection implemented as a script (not a test) — smaller, runnable
  anywhere, exit-code contract; negative control run (removing an input
  line makes it fail, restoring makes it pass). Workspace extraction step:
  the script was developed and first executed through the Workspace `python`
  task via `run_task` (sandboxed bwrap-executed; receipt in the walkthrough
  step 3 output block), while the reproducible harness replays it with a
  local `python3` invocation of the same staged script — the run/verify
  contract is exact-bytes reproduction, not a Workspace re-dispatch; the
  attached evidence bytes are identical either way.
