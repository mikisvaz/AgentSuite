# Return-path probes: four execution-layer facts for the citation contract

Bout: pre-implementation fact-finding for moving Research record sources from
AGS-style `entity_property` receipt paths to citing the persisted result of
any tool invocation (the return_path idea). Read-only plus `tmp/` scratch; no
changes to Semantics, Research, or AGS source. Every fact carries a receipt.

Method note: facts were gathered with `run_probe` children (unsandboxed, fresh
process, preloading the Research `workflow.rb`) because the Workspace `read`
allowlist does not cover `/bulk/.../Semantics` or the AGS sandbox, while the
probe kind reaches both (see Friction). Probe files under `share/probes/` were
removed after this report was written; the load-bearing probe bodies are
inlined below so the evidence stays reproducible.

---

## (a) Semantics entity_property export mode today

**FACT.** The Semantics checkout lives at `/bulk/mvazque2/git/AgentSuite/Semantics`
(readable; the `/home/mvazque2/AgentSuite/Semantics` spelling is a sandbox mount
alias). All three of its tasks — `entity_property`, `entity_list_property`,
`list_entities` — are declared with `export_exec`, i.e. exec mode, and nothing
else in AgentSuite source depends on that mode.

**EVIDENCE.**

Export mode, `grep -n "task :\|export"` (probe `final_consolidation_probe`,
exit 0):

```
lib/Semantics/tasks/entity_property.rb:20:  task :entity_property => :json do |entity_type, entity, property, arguments|
lib/Semantics/tasks/entity_property.rb:51:  export_exec :entity_property
lib/Semantics/tasks/entity_list_property.rb:35:  task :entity_list_property => :json do |entity_type, property, entities, arguments|
lib/Semantics/tasks/entity_list_property.rb:63:  export_exec :entity_list_property
lib/Semantics/tasks/entity_query.rb:281:  task :list_entities => :json do
lib/Semantics/tasks/entity_query.rb:285:  export_exec :list_entities
```

`workflow.rb` (24 lines, read in full by probe `semantics_probe`): no export
declarations of its own; lines 18-20 `require_relative` the three task files;
line 16 `Semantics.extend LiveWorkflow`; `share/` is EMPTY (probe
`semantics_entities_probe`: `find Semantics/share -type f` returns nothing) —
the checkout ships no entities, only the dispatch tasks.

Result JSON shape, `lib/Semantics/tasks/entity_property.rb:33-45` (read in full,
probe `semantics_probe`):

```ruby
result = EntityQuery.dispatch_single(mod, entity, prop, args, param_types)
record = { status: 'done',
           entity: entity.to_s,
           property: prop.to_s,
           result: result,
           receipt: EntityQuery.receipt(self, entity, prop, args) }
record[:payload_dir] = payload_dir if payload_dir
```
Error path (same file, rescue arm): `{status: 'error', entity:, property:,
error: {class:, message:}, receipt: ...}`.

The receipt block, `lib/Semantics/tasks/entity_query.rb:249-256`:

```ruby
def receipt(job, entity_id, property, arguments)
  { step_backed: false,
    mechanism: 'task job receipt (property is not Step-backed; Entity::Property.persist defaults to persist:false)',
    job: { path: job.path.to_s, short_path: job.short_path.to_s,
           task: job.task_name.to_s, workflow: job.workflow.to_s },
    dispatched: { entity: entity_id.to_s, property: property.to_s,
                  arguments: arguments } }
end
```

Bulk output location: `entity_query.rb:272-278` `route_payload_dir!` routes an
`:output_dir` property kwarg into `File.join(job.files_dir, 'property_output')`
— under exec mode that directory is not a persisted job tree (see fact (b)).

Dependencies on the current mode. `grep -rn entity_property
/bulk/mvazque2/git/AgentSuite` excluding `.git/tmp/var`: 451 source hits, of
which the non-Semantics, non-doc-test noise reduces to (probe
`final_consolidation_probe`):

```
Semantics/README.md:104            (usage example: Semantics.job(:entity_property, ...))
Semantics/README.md:286            (test invocation)
Semantics/workflow.rb:19           (require_relative)
Research/lib/Research/path_kinds/records.rb   (LOCAL_SOURCE_TYPES vocabulary; no exec-mode coupling)
ScoutCoder README/path_kinds/tests             (own path kind; mentions the Semantics task as a doc example of production dispatch)
Cortex/lib/Cortex/{entities,properties,properties_run,tasks/entity}.rb  (Cortex's own property machinery, not the Semantics task)
```
No code outside Semantics invokes the Semantics `entity_property` task; nothing
consumes or asserts its exec export. Changing the export mode has no in-suite
dependents today.

**STATUS.** validated (source read in full + live workflow load + scoped grep).

---

## (b) Durable vs temporary in practice

**FACT.** Verified live against the real Semantics task (inline entity defined
in the probe process, since the checkout ships none): in exec mode the result
JSON returns in memory with a receipt whose `job.path` does NOT exist and
nothing is persisted anywhere; in normal (non-exec) mode the same JSON returns
and the job result plus `.info` sidecar persist under
`~/.scout/var/jobs/Semantics/<task>/<name>...`. The tool-dispatch layer
(scout-ai) maps `return_path` to a `TmpFile.tmp_file` for exec-exported tasks
and to the persisted `job.path` for non-exec tasks.

**EVIDENCE.** Probe body (both probes ran `exit_class: completed`; the second
died only on a trailing read-past-EOF after printing everything needed):

```ruby
require '/bulk/.../Semantics/workflow.rb'   # loads Semantics
module ProbeWidget2 ; extend Entity ; property :label => :single do "widget2-#{self}" end ; end
job = Semantics.job(:entity_property, 'rp_probe_run',
                    entity_type: 'ProbeWidget2', entity: 'W9', property: 'label')
result = job.run        # probe 1 used job.exec instead
```

exec mode (probe `live_exec_probe`):

```
job.path BEFORE exec: /home/mvazque2/.scout/var/jobs/Semantics/entity_property/Default_182a0ff94a47701c888eb40184d79055.json
    File.exist?(job.path) AFTER exec = false
Semantics var/ files BEFORE: 24   AFTER: 24 (delta 0)
result JSON: { "status":"done", "entity":"W1", "property":"label", "result":"widget-W1",
  "receipt": { "step_backed": false, "mechanism": "task job receipt (property is not
  Step-backed; Entity::Property.persist defaults to persist:false)",
  "job": { "path": ".../Default_182a...json", "short_path": "Semantics/entity_property/Default_182a...json",
           "task": "entity_property", "workflow": "Semantics" },
  "dispatched": { "entity": "W1", "property": "label", "arguments": {} } } }
```

normal mode (probe `live_run_probe`):

```
job.path: /home/mvazque2/.scout/var/jobs/Semantics/entity_property/rp_probe_run_12c908504599acbbfb9ae02774b51b8d.json
== run result JSON ==  (identical shape: status/entity/property/result/receipt)
job.path exists now: true
~/.scout Semantics jobs BEFORE: 163  AFTER: 165 (new: 2)
  NEW: .../rp_probe_run_12c9....json
  NEW: .../rp_probe_run_12c9....json.info
```
Both artifacts were deleted afterwards (cleanup probe; `deleted: ...` lines).
Durable-after-process-end was not re-tested in a second process, but the two
files are ordinary on-disk job artifacts; the exec probe's absence of files is
the load-bearing observation.

return_path branch, scout-ai dispatch source
`/home/mvazque2/git/scout-ai/lib/scout/llm/tools/workflow.rb:135-172` (read
verbatim by probe `live_run_probe`):

```ruby
jobname, return_path, exec_type, ... = IndiferentHash.process_options parameters, :jobname, :return_path, :exec_type, ...
if workflow.exec_exports.include?(task_name.to_sym) || exec_type.to_s == 'exec'
  if return_path
    result = job.exec
    file = TmpFile.tmp_file          # line 145: TEMPORARY file
    ... Open.write(file, result.to_s)
    file
  else
    job.exec
  end
else
  ...
  if return_path
    job.run(true)
    Chat.allow_read_job job
    job.path                          # line 172: durable job path
```

So with today's `export_exec`, a `return_path` call of the Semantics
`entity_property` tool answers the model with a temp file path; without the
parameter it answers with the value only. Dropping `export_exec` switches the
same call to the `else` branch: `job.run` + durable `job.path`, which is
exactly the path already embedded in the in-result receipt — the receipt
becomes resolvable instead of dangling.

Placement note (observed, not designed): the Semantics job lands under the
user-global root `~/.scout/var/jobs/Semantics/...`, not the checkout's
`var/jobs` (Scout `Path#find` first-existing-wins; Semantics does not pin its
module directory the way Cortex does).

**STATUS.** validated (live probe, fresh process, explicit inputs; dispatch
branch confirmed against scout-ai source).

---

## (c) persist_entity_receipt call sites in the AGS sandbox

**FACT.** Exactly one definition and no other callers: `AGS.persist_entity_receipt`
and its key helper live in `share/helpers/entity_data.rb:439-446` of the AGS
sandbox; the only other references are one integration test (key-stability
assertions) and documentation. 417 receipt files exist on disk under the
sandbox's `var/entity_property/`. No runtime code reads receipts back
programmatically; they are consumed by citation (markdown ledgers/reports) and
by the Persist replay semantics of the helper itself.

**EVIDENCE.** Scoped grep of the sandbox source dirs (lib, share, workflow.rb,
workflows, research, doc, test, examples, etc) — probe `ags_probe2`, exit 0
(a first unscoped recursive grep of the whole sandbox timed out at 300 s on the
multi-MB chat transcripts under `var/jobs/...`; see Friction):

```
$ grep -rn persist_entity_receipt <sandbox>/lib <sandbox>/share <sandbox>/workflow.rb ...
share/helpers/entity_data.rb:443:  def self.persist_entity_receipt(entity_module_name, prop, entity, args = [], &block)
--hit-count=1

$ grep -rn entity_receipt_key <same scope>
share/test/integration/ags_scheme_trajectory.rb:44-51   (asserts default == [nil]-compacted key; :fc0 differs)
share/helpers/entity_data.rb:439,445                    (definition + internal use)
research/ags_entity_layer.md:281 ; doc/user/ags-entity-layer.md:293   (docs)
--hit-count=10
```

Definition, `share/helpers/entity_data.rb:433-446` (read verbatim):

```ruby
# Canonical receipt convention for the entity layer: key
# [prop, "entity:<id>", args.compact.join(',')] persisted as :marshal
# under var/entity_property/<Entity>/<prop>/. compact means a nil
# scheme appends NOTHING, so a no-scheme dispatch reuses the pre-scheme
# receipt path (receipt-key stability across the scheme extension).
def self.entity_receipt_key(prop, entity, args = [])
  [prop, "entity:#{entity}", args.compact.join(',')].inspect
end

def self.persist_entity_receipt(entity_module_name, prop, entity, args = [], &block)
  dir = libdir[File.join('var/entity_property', entity_module_name.to_s, prop.to_s)].find.to_s
  Persist.persist(entity_receipt_key(prop, entity, args), :marshal, dir: dir, &block)
end
```

`var/entity_property` string hits are otherwise documentation/citations only:
`research/ags_entity_layer.md` (receipt inventory, lines 11, 85-128, 226-237,
280-304), `doc/user/ags-entity-layer.md` (same content, lines 23-316),
`research/ags_cycle_summary.md:28` ("Observations: 107 rows ... every value
receipt-cited; receipts under `var/entity_property/<Type>/<property>/<canonical
key>`"), `research/ags_avenues.md:5` ("Observations cite receipts (job path /
var/entity_property receipt dir)").

On-disk inventory (probe `final_consolidation_probe`):
`find <sandbox>/var/entity_property -type f | wc -l` → **417**, names of the
canonical form `["active_tfs",_"entity:PI-8h",_""]` (verified present for
`Timepoint/active_tfs`, incl. `["active_tfs",_"entity:INT_PD_PI-2h"]`).

Actively consumed today: (1) the helper itself as producer (its
`Persist.persist` replay is the only machine consumer); (2) the integration
test pinning key form; (3) markdown citations by agents. The ledger the
design conversation quotes — `./artifacts/ags/observations-ledger.md` with
rows OBS-105/106/107 — does NOT exist in this sandbox (probe
`cleanup_verify_probe`: `exists=false`); it belongs to the older analysis and
survives only as quoted lines (see the design-conversation receipts below).

**STATUS.** validated (scoped full grep + verbatim source read + disk inventory).

---

## (d) Research registration treatment of job-path refs today

**FACT.** Today a source `ref` pointing at a `var/jobs/...` path is accepted
only when it resolves absolutely (or relative to the Research checkout); a
relative `var/jobs/...` ref from another tree is a hard error. Unknown source
types are warnings-only and never existence-checked. The natural home for an
anchoring/durability rule is `validate_sources` / `resolve_local_ref` in
`lib/Research/path_kinds/records.rb`.

**EVIDENCE.** Source anchors (probe `roma_and_anchors_probe`, confirmed by
reading the file):

```
records.rb:45    PATH_KIND_ROOT = Scout.root.find(:current)
records.rb:138   LOCAL_SOURCE_TYPES = %w[entity_property task workflow file].freeze
records.rb:704   def validate_sources(kind, record, errors, warnings)
records.rb:737     when 'external'            → warning only (reachability not verified)
records.rb:740     when *LOCAL_SOURCE_TYPES   → resolve_local_ref; nil ⇒ ERROR
records.rb:758-762 else                       → WARNING "source type ... treated as opaque and not existence-checked"
records.rb:934   def resolve_local_ref(ref)
records.rb:935     expanded = File.expand_path(ref)              # absolute / cwd-relative
records.rb:937     anchored = File.expand_path(ref, PATH_KIND_ROOT)  # Research checkout
```

Write-free dry-run through the real `validate_record` (no files written; probe
`final_consolidation_probe`, fresh process):

```
-- relative var/jobs ref, type task
   errors:   ["sources[0]: broken reference: \"var/jobs/Semantics/entity_property/Default_abc.json\"
              does not exist (local artifact references resolve against the Research checkout
              /bulk/mvazque2/git/AgentSuite/Research/)"]
   warnings: []

-- absolute real job path, type task            (the job file created by probe (b))
   errors:   []
   warnings: ["mutable source has no recorded digest; content identity not pinned",
              "task source has no locator or digest; the derivation may not be re-executable"]

-- absolute real job path, type entity_property
   errors:   []     warnings: [same two]

-- unknown type tool_result, ref var/jobs/Whatever/xyz
   errors:   []
   warnings: ["source type \"tool_result\" is not in the built-in vocabulary
              (entity_property, task, workflow, file, external); treated as opaque
              and not existence-checked"]

-- relative Research-local existing file, type file   (workflow.rb)
   errors:   []     warnings: ["mutable source has no recorded digest; ..."]
```

Cross-check against the incumbent AGS evidence style: the OBS-010-style ref
`var/entity_property/Timepoint/active_tfs/["active_tfs",_"entity:INT_PD_PI-2h"]`
exists in the AGS sandbox (`resolves as absolute AGS path: true`) but
`File.exist?(File.expand_path(ref, '/bulk/mvazque2/git/AgentSuite/Research'))`
is **false** — i.e. the AGS-style relative receipt refs do not resolve against
the Research root and would be registration errors there unless given
absolute.

Where a rule would live: the type dispatch inside `validate_sources`
(records.rb:736-763) plus `resolve_local_ref` (records.rb:934-939). A
durability/anchoring rule for job-path refs (e.g. "ref must be absolute, must
exist, must carry a digest; reject refs under tmp/") slots into the
`when *LOCAL_SOURCE_TYPES` arm without touching register/edit plumbing, which
already threads `errors`/`warnings` through unchanged.

**STATUS.** validated (source anchors + write-free execution of the real
validator on five representative source entries).

---

## Implications for the citation contract

1. Semantics' three tasks are exec-exported today; under exec, `return_path`
   answers with a `TmpFile` and the in-result receipt's `job.path` dangles —
   the exact hazard the user's conversation flags. Nothing in AgentSuite
   depends on the exec mode, so dropping `export_exec` (or switching the
   export) is unconstrained by current callers.
2. Non-exec + `return_path` is the durable variant the conversation
   recommends: `job.run` then `job.path` (scout-ai workflow.rb:163-172), the
   same path already inside the result JSON's receipt block — one execution,
   one value, one resolvable reference.
3. Semantics jobs persist under the user-global `~/.scout/var/jobs/Semantics`
   root, not the checkout; the citation contract should say which roots are
   citable (or pin the module directory).
4. Research today accepts absolute job paths as `task`/`entity_property`
   sources (warning-only) and errors on foreign relative `var/jobs` refs; a
   `tool_result`-style general type is already tolerated as unknown-but-warned.
   The anchoring/durability rule belongs in `validate_sources`/`resolve_local_ref`.
5. AGS `var/entity_property` receipts remain the incumbent evidence store
   (417 files, one helper, citation-only consumers); migration should keep
   them readable, as the design conversation's step 5 asks.

## Friction encountered

- Workspace `read`/`search` cannot see `/bulk/.../Semantics` or the AGS sandbox
  (allowlist); the `/home/mvazque2/AgentSuite/...` spellings are read-only
  thread mounts with `realpath: null`. All reads went through `run_probe`
  children instead — expected two-layer behavior (doctrine §3), worked cleanly.
- Unscoped `grep -rn persist_entity_receipt <sandbox>` timed out at 300 s
  (huge agent-chat transcripts under the sandbox's own `var/jobs/`); a
  transcript from the sandbox quoted the helper name many times, inflating
  apparent hits. Fixed by scoping the grep to source dirs; report uses that.
- `scout workflow task AGS entity_property ...` via the CLI printed help/task
  listing and exited 255: `entity_property` is not an AGS task (the AGS entity
  layer is dispatched through probes), and `--rp`/`--exec_type` are chat
  tool-call parameters, not CLI inputs. Pivoted to direct `job.exec`/`job.run`
  probes of the real Semantics task — the same entry points the dispatch layer
  calls, verified against scout-ai source.
- Two probes hit their timeouts on self-inflicted loop bugs (a depth-counting
  loop re-printing a file forever; the recursive grep above) after emitting
  complete output; one probe ended `exit_class: raised` on a read-past-EOF
  after printing everything needed. No findings affected.
- The live normal-mode probe created 2 files under `~/.scout/var/jobs/Semantics`;
  both were deleted in the cleanup probe (receipts quoted in fact (b)). The
  exec probe created nothing. Probe files under `share/probes/` and the empty
  `tmp/return-path-probes` scratch were removed after this report was written.

## Appendix: design-conversation receipts (verbatim quotes)

`/home/mvazque2/.inbox/Roma/Analysis commentary2.md` (757 lines; read lines
560-757 and grepped), the user's authoritative design conversation:

- Line 563: "Proceed with the non-`exec` `entity_property` task, provided it
  produces a stable Path result under the intended lifecycle. Use `return_path`
  or its underlying mechanism to expose that result ... have Semantics return
  or register the **complete invocation receipt**, not just the path."
- Line 575: "Would it not be even simpler to have the Research engine cite the
  return_path."
- Lines 578-590: the OBS-010-style record quoted with
  `ref: var/entity_property/Timepoint/active_tfs/["active_tfs",_"entity:INT_PD_PI-2h"]`,
  `type: entity_property`, `digest: 1d7b...`.
- Lines 594-596: the three ledger lines OBS-105 (`Experiment.tf_overlap` :fc0
  T24), OBS-106 (:fc0 T1), OBS-107 (`TranscriptionFactor.onset` :diff) — each
  citing a `var/entity_property/...` canonical receipt key.
- Line 592: "The ref could instead be just the return_path of the
  entity_property call."
- Line 600: "using return_path as the general way to cite things in
  observations makes it so that not just entities, but also any type of tool
  calling ... can be used."
- Lines 650-676: the durability contract table (Identity / Lifetime /
  Inspection / Integrity / Backend independence) and "If the task returns a
  temporary path, Research should either promote or materialize the result
  into durable storage, or decline to treat that path as a durable citation."
- Line 741: "The path should be returned by the same execution that produced
  the result."
- Line 749-753: implementation order — establish `return_path` semantics,
  expose through normal tooling in non-exec mode, generalize Research source
  references, test the full lifecycle (including a non-entity tool and a
  temporary-result case), migrate existing observations.

## Semantics export change (bout 3)

What changed: `lib/Semantics/tasks/entity_property.rb:51` and
`lib/Semantics/tasks/entity_list_property.rb:63` flipped from `export_exec`
to `export` (the `export_asynchronous` alias, scout-gear
`lib/scout/workflow/export.rb:75`). `list_entities` stays `export_exec`:
pure discovery with no citable result; a non-exec flip would persist tiny
listings on every call (measured 2.0 KiB, 0.01s) while gaining nothing
citable. Deliberate scope boundary. README gained the export-mode note
("Notes on outputs", README.md:113-119) and the "in-memory result" phrase
at :121 was corrected to the persisted-record phrasing.

Why: contract rules C1/C2/C3/R9 (return-path-citation-contract.md). One
dispatched call now runs as a persisted job and returns value and durable
path together; `return_path` on the non-exec task returns the persisted
`job.path` under `~/.scout/var/jobs/Semantics/...` (scout-ai
`tools/workflow.rb:138-172`: exec branch answers TmpFile, non-exec branch
answers `job.run` + `Chat.allow_read_job` + `job.path`).

Tests (full suite, fresh process per file, `ruby -Itest -Ilib`):
test_entity_property `8 tests, 3 assertions, 0 failures, 5 errors`;
test_entity_list_property `10 tests, 3 assertions, 0 failures, 7 errors`;
test_entity_query `8 tests, 15 assertions, 2 failures, 3 errors`.
Identical counts at HEAD (verified by `git stash push` + rerun +
`git stash pop`; edits restored). The failures are a pre-existing test-data
defect, not the flip: tests register CamelCase probe modules
(`ProbePropertyWidget`) but pass snake_case `entity_type`
(`probe_property_widget`), aborting with `ParameterException: unknown
entity type "probe_property_widget"; known: AssociationItem,
ProbePropertyWidget`. Not chased.

Live proof (real dispatch surface `LLM.call_workflow`, entity_property,
`return_path: true`, jobname rp_flip_proof): answer =
`/home/mvazque2/.scout/var/jobs/Semantics/entity_property/rp_flip_proof_f3b0cfa5b2f5aa30c711866055c2f5c9.json`;
persisted record: `{status: "done", result: "demo-x3", receipt.job:
{path: ...same.json, task: entity_property, workflow: Semantics}}` — value
and durable path from one execution. Second process confirmed
`result file: exists=true`, `result .info: exists=true`, parsed the record
fresh: C2 (survives process) and C3 (ordinary tools) hold.

Cleanup: proof job `.json`+`.json.info` and `list_entities/Default.json`
deleted; scratch pointers/logs removed; all bout probes deleted from
`share/probes/`. Pre-existing `.info`-only remnants left untouched.

## Recovery bout (Critic-gate follow-up)

The Critic gate found the sibling checkouts vanished from
/bulk/mvazque2/git/AgentSuite at ~Oct 25 21:03. Bounded recovery search
(one pass, roots and obvious backups only): NOT LOST — the whole AgentSuite
is present again at /bulk/mvazque2/git/AgentSuite (all 21 agent suites plus
chats/doctrine/var; the /home spelling mirrors it; no backup archives or
Trash entries involved). The vanishing was a transient view, not a deletion.

Flip status: SURVIVED, verified in place — Semantics
lib/Semantics/tasks/entity_property.rb:51 `export :entity_property`,
entity_list_property.rb:63 `export :entity_list_property`, README bullets
intact (lines 116-120); list_entities stays exec as decided. No re-apply
needed.

Re-verification, all fresh processes:
- One-execution proof through the real dispatch surface
  (LLM.call_workflow, return_path: true): answer =
  ~/.scout/var/jobs/Semantics/entity_property/rp_recovery_proof_11bd29dafffb97eb46129a74aba0518f.json;
  second fresh process: result file exists=true, .info exists=true,
  status=done, result=14, receipt.job.path identical (543 bytes). Scratch
  job deleted after.
- test_path_kinds_engine: 9 tests, 81 assertions, 0 failures, 0 errors.
- test_integration_walkthrough: 1 tests, 67 assertions, 0 failures, 0 errors.
- test_h011_lines_edit: 3 tests, 5 assertions, 0 failures, 0 errors.
- test_h011_regression_matrix: 34 tests, 136 assertions, 0 failures, 0 errors.
- test_return_path_citation after the demo.json teardown fix: 20 tests, 40
  assertions, 0 failures, 0 errors; var/records-attachments empty after run.
- test_return_path_lifecycle: 3 tests, 18 assertions, 0 failures, 0 errors
  (one earlier run showed 1 environment error that did not reproduce on the
  immediate rerun; the second run is quoted above).

Minor fix in passing: the named-store test's teardown now removes
var/records-attachments/citation/demo.json and its empty parent (Critic's
known-defect note). Verdict: RECOVERED.

## Recovery addendum (final round)

Commit: Semantics flip landed as 980d809b43e01b58868afced5cba1f49f07bb226
("Semantics: export entity_property/entity_list_property non-exec for the
return_path citation contract"; 3 files changed, 11 insertions, 3 deletions;
only our three files added — the repo carries unrelated uncommitted
sibling state, untouched).

A1 durable proof job, KEPT:
~/.scout/var/jobs/Semantics/entity_property/rp_a1_durable_proof_401cef0564c8084a5af90bd0ffc16f98.json
(+ .info). Fresh-process check: exists=true/true; record {status: done,
result: 42, job.path: <same path>, job.task: entity_property}, 549 bytes.
Not deleted — this is the A1 receipt.

Lifecycle determinism fix: test_tool_result_generality_cross_session now
omits with reason 'ScoutCoder checkout not present' via scoutcoder_present?
(same guard shape as semantics_present?), so an invisible sibling yields an
omission, never a RuntimeError. Fresh runs x4 in my environment: 3 tests,
18 assertions, 0 failures, 0 errors, 0 omissions (all cases run; the
omission path is only exercised when siblings are absent).

Sibling-dependent test records, headers carry command + UTC date + pwd:
- research/test-logs/test_path_kinds_engine.log (9 tests, 81 assertions)
- research/test-logs/test_integration_walkthrough.log (1 tests, 67 assertions)
- research/test-logs/test_h011_lines_edit.log (3 tests, 5 assertions)
- research/test-logs/test_h011_regression_matrix.log (34 tests, 136 assertions)
