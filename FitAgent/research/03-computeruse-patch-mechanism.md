# ComputerUse `patch`: source-verified mechanism and failure modes (research note 03)

**Scope**: exact behavior of the patch tool the agent-under-test will be
provisioned with. **Evidence**: full read of
`/bulk/mvazque2/git/AgentSuite/ComputerUse/lib/ComputerUse/tasks/patch.rb`
(453 lines) plus `test/ComputerUse/tasks/test_patch.rb` and the tool docs
attached to this session. Cortex receipt:
`findings/agentsuite-components-available.md` (v1); catalogue impact
recorded in `design/patch-scenario-catalogue-v1.md` (v2).

## 1. Two-layer pipeline

`task :patch` never applies user text directly. It first tries
`convert_chatgpt_patch(patch)`:

1. **`normalize_unified_diff`** — repairs stale `@@ -a,b +c,d @@` counts by
   recomputing them, tolerating `@@` without counts. This is why slightly
   wrong hunk numbers still apply.
2. **ChatGPT block conversion** — `*** Begin Patch`, `*** Update/Add/Delete
   File: <path>` markers are converted into a canonical unified diff
   (synthesized `--- a/` `+++ b/` headers, synthesized `@@` headers when
   missing, forced trailing newline).
3. **Bare-`@@` contextual hunks** (no context in the hunk body) are located
   by exact line-sequence matching against the target file; ambiguity or
   no-match raises `ScoutException` (the test file exercises exactly this
   path).

Path sanity: `..` rejected; absolute paths relativized to the workflow
root.

## 2. Apply loop and diagnostics

- Candidate strip order `[1, 0, 2, 3, 4]`, each tried with `patch
  --dry-run` first; real apply only after a successful dry run.
- `malformed` detection short-circuits the whole loop (no strip retry
  past a malformed verdict).
- `p0 → p1` preference: when the diff body carries `+++ b/` prefixes, `p1`
  wins if it dry-runs clean.
- **`apply_direct` fallback**: when diffing fails and the block looks like a
  full-content replacement, files are written directly from the plain body
  (atomic tmp+rename, `.bak.<timestamp>` backups). The tool docs warn:
  prefer `patch` for updates, `apply_direct` is last-resort.
- Return: JSON with `stdout, stderr, exit_status, generated_patch,
  used_strip, tried_strips, applied, applied_directly, suggestion`.

## 3. Failure modes the rubric must cover (source-anchored)

| Mode | Source behavior |
| --- | --- |
| patch text contains markdown code fences | fences stripped only during ChatGPT-mode parsing; canonical diffs with fences are malformed → dry-run fails → (maybe) apply_direct |
| missing diff headers | ChatGPT `*** Update File` block or canonical diff required; bare content fails |
| paths with leading `./` or absolute | normalized when possible; `..` rejected |
| no trailing newline in patch | synthesized |
| wrong `@@` counts | repaired by `normalize_unified_diff` |
| bare `@@` hunk not found in file | raises "Could not locate hunk context" |
| ambiguous context (matches multiple places) | raises |
| adding/deleting files via patch | docs say use write/delete tasks instead — expected behavior is failure or fallback |
| large near-total rewrites | dry-run may fail → `apply_direct` full-content write (with backups) |

## 4. Scenario-catalogue consequences

The Dimension B/C expectations in Cortex
`design/patch-scenario-catalogue-v1.md` are now mechanism-anchored. Open
byte-level question for live probing (agenda O1): for each scenario, does
the observed `used_strip`/`applied_directly`/exit status match the
prediction table? That probing session turns this note into ground truth
for rubric expected-values.

## 5. Test template

`test/ComputerUse/tasks/test_patch.rb` (50 lines) is the pattern for any
new deterministic test: `require` the helper, `Workflow.require_workflow
'ComputerUse'`, build a patch/file/target triple in heredocs, run under
`TmpFile.with_file` + `Misc.in_dir`, assert equality. FitAgent's rubric
runner can reuse exactly this shape at larger scale (expected after-state
files instead of expected diff text).
