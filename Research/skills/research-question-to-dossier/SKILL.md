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
question is not required — create what the work needs. The only Research
dossier types are `question`, `claim` and `hypothesis`. A result described
as an observation is not another type and does not require an `OBS-###` ID.

## Procedure

1. Read the context you already have (study notes, method definitions, prior
   result tables) — in Workspace or attached evidence. **If a question
   dossier for this work already exists, re-read it instead of starting
   over** (see Keep context short below).
2. Name an answerable question: specify the units, intervention, endpoint
   and denominator where relevant, and make that question the dossier `title`.
   Do not title a new `Q-###` dossier "Observation OBS-###". If the result
   answers an existing question, update that dossier rather than allocating
   a new question per table or observation. A report or closure package belongs
   with the question it answers; it does not by itself need a new `Q-###`.
3. `dossier_create` (type `question`); keep the current answer in the README
   (the default document starts with the title alone).
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

Read the outline first and open the relevant scientific section. Keep settled
definitions, warrant, and scientific uncertainty in the current document.
Put a pending run, delegation, or next action in a working supplement such
as `supplements/continuation.md`. For example, response-selected membership
limits which population a claim covers. That limitation belongs beside the
claim. The instruction to rerun with an annotation-defined panel belongs in
the continuation supplement. A central unresolved mechanism can remain a
hypothesis. Create a claim when another investigation can use the result
as a premise.

For a GRN result, put its scientific contribution and shared-expression-input
limitation beside the claim it supports (`scientific`). Put the script command
in a reproduction supplement (`documentary`). A later heading-spacing repair
is also `documentary`; its reason fits in `change_note`.

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
  'mode' => 'add_section', 'section' => 'L1',
  'content' => "## Current answer\nPartial — see [C-001](../../claims/C-001/README.md).\n",
  'change_note' => 'link first claim')
# => revision 2
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
