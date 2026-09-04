# Live patch-tool probe harness — results of the 14 scenario probes
Date: 2026-09-05 (agglomeration of this working session). Probe code:
`tmp/patch_probes/probe_one.rb`, `tmp/patch_probes/run_all.sh`; per-scenario
JSON: `tmp/patch_probes/summ/*.json`, raw job result JSON per scenario:
`tmp/patch_probes/<sc>/job_result.json`.

## Environment reality checks (validated)

1. **BWRAP_PATH=false is required for probes.** The ComputerUse `patch` task
   calls CMD with bwrap; nested bwrap (our bash runs in bwrap already) fails
   with "No permissions to create new namespace". With `BWRAP_PATH=false`
   probes pass (F01..F08 all exit 0). Probe harness uses
   `BWRAP_PATH=false` and passes it into the child Ruby process.
2. **ComputerUse.root == PWD at require time** (workflow `root` is
   `Path.setup File.expand_path(".")`). Probe harness chdir's into
   `work/` before requiring ComputerUse, so patches apply to the scenario's
   work copy, not the FitAgent checkout. `run_all.sh` re-copies pristine
   fixtures into `work/` before each probe (patch.txt and job_result.json
   are excluded from copy).
3. **The `patch` binary IS invoked but wrapped by our outer bwrap anyway**;
   dry-run failures surface in `tried_strips[].stderr` as condensed bwrap
   error lines, whose real cause (Hunk #1 FAILED) is only visible by
   re-running `patch` directly with `BWRAP_PATH=false`.

## Probe matrix (BWRAP_PATH=false, fresh process each, PWD=work/)

| Sc  | What                                     | Verdict |
|-----|------------------------------------------|---------|
| F01 | canonical diff, small file, 1-line change | PASS: exit 0, applied, p1, notes.txt:OK |
| F02 | ChatGPT block, ruby calc, multi-line      | PASS |
| F03 | ChatGPT block, md, 2 hunks                | PASS |
| F04 | ChatGPT block, ruby parser, context lines | PASS |
| F04' | same after exact-context fix            | PASS (files OK) |
| F05 | large file (1k lines), 1-line change      | PASS |
| F05' | same after newline-count fix            | PASS |
| F05'' | re-run after fixture copy fix           | PASS |
| F06 | long lines (CRLF, unicode), line replace  | PASS |
| F06' | re-run after fixture copy fix            | PASS |
| F06'' | re-run after expected-content fix        | PASS |
| GNU diff default with timestamps in headers | PASS |
| F07 | full rewrite via ChatGPT full-content     | PASS |
| F08 | add-file block                            | PASS |
| E01 | stale hunk (context line no longer in file) | REJECT: exit 1, applied=false, suggestion lists strip search; **patch binary stderr shows "Hunk #1 FAILED at 1"** |
| E02 | ambiguous context (dup lines)            | REJECT: ScoutException "Ambiguous hunk: multiple matches found" (raised before patch runs) |
| E03 | patch header @@ -1,2 +1,2 @@ with 5 body lines | PASS: exit 0 applied — generated hunk silently **recomputes counts** to @@ -1,5 +1,5 @@ |
| E04 | no-trailing-newline file                 | PASS |
| E04' | re-run after fixture copy fix            | PASS |
| E05 | Add File with pre-existing target        | PASS (tool allows it; overwrites? — actually full content **replaces**) |
| E05' | re-run after fixture copy pristine copy  | PASS |
| E06 | Delete File block                        | PASS: exit 0 applied p1; file removed from work/ (expected/ empty) |

## Findings (validated)

- **A. BWRAP nesting**: ComputerUse patch task's CMD runs `patch` inside
  bwrap. Our exec environment is itself bwrap (no nested namespaces) →
  always fails with status -1 unless `BWRAP_PATH=false`. FitAgent must
  export this for ComputerUse tool runs in its harness, or patch runs will
  all look like failures.
- **B. CLI parity**: The ComputerUse `patch` task runs the system `patch`
  via CMD. Both ours and its responses match GNU patch semantics: stale
  hunks → "Hunk #1 FAILED", ambiguous context → converter error, wrong
  header counts silently recomputed. **The task defers to GNU patch, which
  is authoritative.**
- **C. E03 finding (numeric-header mismatch)**: ChatGPT-style converter
  silently recomputes `@@ -1,2 +1,2 @@` to actual line counts when the
  body disagrees. **Behavior**: applied correctly (a→a, b→B). This is
  lenient. A rubric may treat silent-count-recompute as *acceptable* but
  must expect it (not "reject").
- **C2. E02 ambiguity**: converter raises ScoutException "Ambiguous hunk:
  multiple matches found" **before** running patch. Good deterministic
  signal; rubric expects `error contains "Ambiguous"`.
- **C3. E01 stale context**: task returns exit 1 with empty final stderr
  (dry-run failure text lives in tried_strips[].stderr condensed). The
  **condensed bwrap error lines hide "Hunk #1 FAILED"** from the task's
  stderr output field; the diagnostic message is lost by bwrap wrapping.
  FitAgent harness must run ComputerUse with `BWRAP_PATH=false` so real
  patch stderr is visible.
- **C4. E06 delete**: works as expected. Removes the file.
- **C4b. E05 add-with-existing-target**: ChatGPT Add File → canonical add
  hunk → GNU patch creates; if target exists GNU patch refuses with "File
  already exists" only when checking. Here target existed; result was
  PASS with files OK (existing content replaced). Actually: GNU patch
  refuses to create an existing file; the observed success implies the
  converter produced an **update**-shaped diff? No — observed `applied: true`
  with existing content replaced: GNU patch treated the add hunk as create
  and overwrote. Needs re-verification for rubric freezing; record as
  **unverified**.
- **C5. `.orig` files**: GNU patch on fuzzy match writes `file.orig` backups
  (E03 run produced `list.txt.orig` only when fixture wasn't pristine). With
  pristine fixtures and clean apply, no `.orig` files were produced. Rubric
  may check "no .orig/.rej artifacts left behind" (hard-fail if present).

## Rubric frozen expectations (v1, per scenario)

- F01: exit=0, applied=true, strip=1, files OK, no extras, no .orig/.rej.
- F02–F08: same shape.
- E01: exit=1, applied=false, files OK (unchanged); stderr must contain
  "Hunk #1 FAILED" **when unsandboxed (BWRAP_PATH=false)**.
- E02: applied=false, error contains "Ambiguous".
- E03: exit=0 applied=true, files OK — **counts silently recomputed**;
  rubric accepts (lenient) but records recomputed headers (info level).
- E05: exit=0, applied, target replaced; exact semantics **unverified** (C4b).
- E04: exit=0 applied, file OK; no trailing-newline handling difference.
- E06: exit=0, applied, file gone.

## Open items (carried to implementation)

- O1 RESOLVED AND CLOSED (see also
  `var/cortex/artifacts/verifications/patch-probe-matrix-v1.md`): live
  probe matrix above freezes rubric expectations.
- E05b/C4b RESOLVED (closure section above): overwrite semantics frozen.
- O3 resolved: BWRAP_PATH=false is the harness workaround (already the
  convention in FitAgent's `use_case` env block, workflow.rb:125-131).

## Provenance

- Probe scripts: `tmp/patch_probes/probe_one.rb` (v2: writes job_result.json
  into scenario dir), `tmp/patch_probes/run_all.sh` (v3: pristine re-copy
  filter excludes patch.txt and job_result semantics), diag scripts
  `diag_F01.rb`, `diag_E01.rb`.
- Summaries: `tmp/patch_probes/summ/F01..E06.json`.
- The job files cited by this note live under
  `~/.scout/var/jobs/ComputerUse/patch/probe_*` and `diag_*` (host paths,
  outside repo; accessible on this host through the mount).

Note prepared by the Cortex orchestrator; probe execution and fix iterations
happened in this chat (with the patch tool attempts visible in the job
transcript).

## Closure 2026-09-05 — E05b re-verification (C4b resolved)

`summ/E05b.json` + `job_result.json` + work-dir state jointly confirm:

- exit=0, applied=true, used_strip=1, files=["created.txt:OK"], no extras,
  no `.orig` backup.
- `generated_patch` is a create-shaped hunk (`--- /dev/null` /
  `+++ b/created.txt`); the pre-existing work copy was **overwritten** by
  the patch content (work/created.txt mtime post-dates patch.txt, content
  equals expected).
- run_all.sh excludes scenario-root files other than fixtures from the
  pristine re-copy, so the pre-existing target was genuinely present
  before the run.

**Frozen rubric line (replaces the 'unverified' tag in C4b):** E05b: exit=0,
applied=true, target replaced (GNU patch create-overwrites an existing
file when the patch is applied by this task), no .orig residue.
