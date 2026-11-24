---
name: research-evidence-from-results
description: >
  Attach computational outputs as evidence: tables, figures, entity subsets,
  scripts. Triggers: retaining a result table, citing a figure, keeping an
  extraction script, deciding copy vs reference, recording how a result was
  produced, preparing to tell someone how to reproduce an artifact.
---

# Evidence from results

## When

A computation produced outputs (table, figure, selected entity subset) that a
claim or question dossier should be able to cite, and you want the exact
bytes plus the producing method retained and checkable.

## Procedure

1. Inspect what the result actually is: schema of the table (read its header
   and a few rows in Workspace) and the method definition (script or task
   inputs). Do not attach blind — the caption and declared provenance must
   match reality.
2. Choose mode per item:
   - `copy` — bytes enter the dossier (`evidence/<slot>/<name>`), digest from
     retained bytes. Default for tables, figures, scripts.
   - `reference` — durable external artifact (job-tree result): identity +
     observed digest recorded, no bytes. Ephemeral `/tmp` sources are
     rejected.
3. Sources may be absolute or **relative to the working project** (there is
   no `base_path`; relative sources resolve against the process cwd and are
   still sandbox-checked).
4. Attach script and outputs **together in one batch** with declared
   `script`, `parameters`, `inputs` — the batch is atomic, so either the
   complete evidence set lands or nothing does.
5. Keep the distinctions honest: `verified.digest/basis` is what the store
   checked; `declared_script/parameters/inputs` are the caller's assertion.
   Attach contrary results too — a dossier that only keeps supporting
   evidence is not an evidence record.
6. Link the attachment from the claim's document with the returned
   Markdown `link`. Pass the item’s `evidence_read` arguments to Research to revisit the same revision.

## Reconcile before you tell someone how to reproduce (workflow aid)

Before presenting reproduction instructions, reconcile what you retained
with what actually produced it: re-check each retained artifact against the
script or command that generated it (several scripts each producing part of
a result is fine). An artifact's declared provenance must name a producer
that really emits it — never describe one script as regenerating artifacts
it does not produce. If the producer is several steps, say so in the
caption/`parameters` rather than compressing it into one false command.

## Example (generic annotation-enrichment result)

Run from the working project; relative `source` paths resolve against it:

```ruby
items = [
  { 'source' => 'results/enrichment.tsv', 'slot' => 'tables',
    'name' => 'enrichment.tsv', 'mode' => 'copy',
    'caption' => 'Term enrichment over the changed-gene set (synthetic)',
    'script' => 'scripts/run_enrichment.rb',
    'parameters' => 'ruby run_enrichment.rb gene_list.tsv',
    'inputs' => ['results/gene_list.tsv'] },
  { 'source' => 'scripts/run_enrichment.rb', 'slot' => 'scripts',
    'mode' => 'copy' }
]
LLM.call_workflow(Research, :evidence_attach,
  'id' => 'Q-002', 'expected_revision' => 2,
  'items' => JSON.generate(items),
  'change_note' => 'attach enrichment table + script')
# => {"revision"=>3, "items"=>[
#      {"attachment"=>"tables/enrichment.tsv", "mode"=>"copy",
#       "sha256"=>"5064fba5…", "verified"=>{"digest"=>"5064fba5…", "basis"=>"retained bytes"},
#       "retained_location"=>"<project>/research/questions/Q-002/store/objects/<sha256>", …},
```

## Details

- Copy vs reference semantics, ephemeral-reference rejection, source
  authorization: `doc/user/Walkthrough.md`; full input schema and output
  fields: `doc/user/Tasks.md`; when/how-to-use guidance per task:
  repository `README.md` (`# Tasks`).
