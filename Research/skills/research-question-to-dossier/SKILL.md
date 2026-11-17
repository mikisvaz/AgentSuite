---
name: research-question-to-dossier
description: >
  Frame or resume a scientific question as a Research dossier; organize a
  finding; draft a claim or hypothesis from evidence. Triggers: starting an
  investigation, resuming prior work, turning results into a claim,
  proposing an explanation, context growing long enough that settled
  definitions should be re-read instead of rediscovered.
---

# Question to dossier

## When

You are starting a scientific question, resuming one, or moving from results
to a bounded claim or a falsifiable hypothesis. One dossier per type per
question is not required — create what the work needs.

## Procedure

1. Read the context you already have (study notes, method definitions, prior
   result tables) — in Workspace or attached evidence. **If a question
   dossier for this work already exists, re-read it instead of starting
   over** (see Keep context short below).
2. Name the question so an answerable comparison is possible: units,
   intervention, endpoint, denominator. Write it as the dossier `title`.
3. `dossier_create` (type `question`); keep the current answer in the README
   (it starts as "no answer yet" — update it as evidence arrives).
4. When a result warrants a statement, draft a *claim* (bounded to what the
   attached evidence supports) or a *hypothesis* (falsifiable, with explicit
   predictions). Create a separate dossier and link them with the Markdown
   links the tasks return (absolute links come back in every create/update
   result).
5. Update the question's current answer with `dossier_update` citing the
   linked claim/hypothesis and its evidence.

Descriptive vs explanatory: "measured endpoint X differs between groups"
(evidence-attached claim) vs "the intervention changes X through mechanism P"
(hypothesis needing predictions and a falsifier). Keep the distinction in the
document text; the dossier types do not enforce it mechanically.

## Keep context short (workflow aid)

When definitions are repeatedly needed, or the conversation is getting long
enough that compaction or re-derivation is likely, do a maintenance edit
instead of carrying it in working memory: one `dossier_update` on the
question dossier (or one small working note it links) recording — the
settled definitions with their sources, the points still unresolved, and
the single next action. Then re-read that note at resume time. Do not
create a new checkpoint object per inference; this is an ordinary revision
of the working record, not a new process step.

## Example (generic longitudinal perturbation study)

Run from the working project (the store root is `<working
project>/research/`):

```ruby
LLM.call_workflow(Research, :dossier_create,
  'type' => 'question',
  'title' => 'Does the feed change alter the measured growth endpoint?')
# => {"id"=>"Q-001", "type"=>"question", "revision"=>1, "changed"=>true,
#     "entry_document"=>"README.md",
#     "link"=>"[Q-001](<project>/research/questions/Q-001/README.md)"}

# record an in-progress answer after first results
LLM.call_workflow(Research, :dossier_update,
  'id' => 'Q-001', 'expected_revision' => 1,
  'mode' => 'replace_lines', 'start_line' => 3, 'end_line' => 4,
  'replacement' => "Current answer: partial — see [C-001](../../claims/C-001/README.md).\n",
  'change_note' => 'link first claim')
# => {"id"=>"Q-001", "type"=>"question", "document"=>"README.md",
#     "mode"=>"replace_lines", "changed"=>true, "revision"=>2,
#     "previous_revision"=>1, "change_summary"=>"edited README.md (…)",
#     "change_note"=>"link first claim"}
```

## Details

- Task signatures and output shapes: `doc/user/Tasks.md`; working loop,
  relative sources, safe line editing, error recovery:
  `doc/user/Walkthrough.md`; when/how-to-use guidance per task:
  repository `README.md` (`# Tasks`).
- Evidence attachment (tables, figures, scripts) is its own skill:
  `research-evidence-from-results`.
- Narrowing a claim after contrary evidence: `research-revise-and-review`
  (edit the current document; history stays honest).
