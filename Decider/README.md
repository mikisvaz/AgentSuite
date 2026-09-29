# Decider Agent

The `Decider` agent provides typed decision inference to other agents.

A Manager sends the Decider an ordinary natural-language prompt containing a single `<scout-decision>` block. The JSON block describes the questions to answer. Everything outside that block is treated as the decision state.

The Decider parses the request, runs the configured `Decision` model, records the decision in its `.files/decisions.json` sidecar, and returns the structured result as JSON.

## Request format

A request has two parts:

```text
Natural-language state and instructions.

<scout-decision>
{
  "questions": {
    ...
  }
}
</scout-decision>
```

The `<scout-decision>` block must contain a JSON object with a non-empty `questions` object.

There must be exactly one decision block.

Everything outside the block becomes the `state` passed to the decision model.

## Example Manager request

A Manager can ask:

```text
Review the evidence gathered so far and determine what to do next.

The investigation has already inspected the available workflows and consulted
two specialist agents. The latest evidence suggests that the candidate
workflow may already contain the required information, but this has not been
verified experimentally.

<scout-decision>
{
  "questions": {
    "action": {
      "type": "choice",
      "instructions": "What should the Manager do next?",
      "criteria": {
        "continue": "Continue investigating the current hypothesis.",
        "workflow": "Run a workflow to obtain additional evidence.",
        "specialist": "Ask a specialist agent for additional analysis.",
        "stop": "Stop because the available evidence is sufficient."
      }
    },
    "evidence_strength": {
      "type": "score",
      "instructions": "How strong is the evidence supporting the selected action?",
      "criteria": [
        "Very weak",
        "Weak",
        "Moderate",
        "Strong",
        "Very strong"
      ]
    }
  }
}
</scout-decision>
```

The Decider does not attempt to infer the question specification from the prose. The Manager explicitly defines the decision surface.

## Calling the Decider from a Manager

The Manager should delegate the request through its normal agent/tool mechanism.

Conceptually:

```ruby
manager.ask(
  "Review the evidence ...\n\n" \
  "<scout-decision>\n" \
  "#{JSON.generate(specification)}\n" \
  "</scout-decision>"
)
```

The exact mechanism for exposing the `Decider#ask` `chat_task` depends on how the Manager is configured to delegate agents.

The important contract is the request text.

## Decision questions

The question definitions use the native `Decision` specification.

For example, a yes/no question:

```json
{
  "supported": {
    "type": "noul",
    "instructions": "Does the evidence support the hypothesis?"
  }
}
```

A finite choice:

```json
{
  "action": {
    "type": "choice",
    "instructions": "What should happen next?",
    "criteria": {
      "continue": "Continue the investigation",
      "workflow": "Run a workflow",
      "specialist": "Ask a specialist",
      "stop": "Stop"
    }
  }
}
```

A scored judgment:

```json
{
  "evidence": {
    "type": "score",
    "instructions": "How strong is the evidence?",
    "criteria": [
      "Very weak",
      "Weak",
      "Moderate",
      "Strong",
      "Very strong"
    ]
  }
}
```

The Manager should keep questions atomic. Complicated decisions are better represented as several independent questions whose results the Manager can combine.

## Result

The Decider returns the structured model result as JSON.

For example:

```json
{
  "action": {
    "type": "choice",
    "choice": "workflow",
    "probabilities": {
      "continue": 0.12,
      "workflow": 0.71,
      "specialist": 0.11,
      "stop": 0.06
    },
    "confidence": 0.71
  }
}
```

The Manager should use the returned structure rather than asking the Decider for a prose explanation.

The probability distribution is retained because the Manager may want to apply its own thresholds or combine several questions.

## Persistent decision record

Every successful Decider request is recorded in:

```text
<job>.files/decisions.json
```

The file contains all decisions made by that Decider job:

```json
{
  "schema_version": 1,
  "decisions": [
    {
      "timestamp": "...",
      "questions": {...},
      "state": "...",
      "result": {...}
    }
  ]
}
```

This is an audit/reference artifact. The persisted Decider conversation and workflow provenance remain the authoritative record of the execution.

The decision file is useful when a Manager needs to inspect what decisions were requested and what the model returned without reading the entire conversation.

## Invalid requests

Malformed requests are rejected with a `ScoutException` subclass.

Examples:

* missing `<scout-decision>` block
* more than one decision block
* invalid JSON
* JSON that is not an object
* missing `questions`
* empty `questions`
* missing decision state
* malformed existing `decisions.json`

The Manager should treat these as protocol errors rather than trying to interpret the response as a normal decision.

## Recommended Manager pattern

A Manager should formulate:

1. the complete state needed by the decision;
2. one explicit `<scout-decision>` block;
3. atomic questions appropriate to the decision.

The Manager should not put important decision instructions only in the system prompt of the Decider. The request should be self-contained and reproducible.

For example:

```text
Here is the current investigation state:

...

Determine what I should do next.

<scout-decision>
{
  "questions": {
    "next_action": {
      "type": "choice",
      "instructions": "What should happen next?",
      "criteria": {
        "investigate": "Gather more evidence.",
        "execute": "Execute the relevant workflow.",
        "delegate": "Ask another agent.",
        "finish": "The investigation is sufficiently resolved."
      }
    }
  }
}
</scout-decision>
```

This gives the Manager control over **what decision is being asked**, while the Decider controls **how that decision is evaluated**.


