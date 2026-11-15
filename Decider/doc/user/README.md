# Decider user guide

How to send the Decider typed decision requests. The workflow
introduction and the `ask` entry live in `Decider/README.md`; the
decisions sidecar and model configuration are in
[doc/developer/README.md](../developer/README.md).

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

- The `<scout-decision>` block must contain a JSON object with a
  non-empty `questions` object.
- There must be exactly one decision block.
- Everything outside the block becomes the `state` passed to the decision
  model (compacted to the newest tool call — see the developer doc).

## Example Manager request

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

The Decider does not attempt to infer the question specification from the
prose. The Manager explicitly defines the decision surface.

## Calling the Decider from a Manager

The Manager should delegate the request through its normal agent/tool
mechanism. Conceptually:

```ruby
manager.ask(
  "Review the evidence ...\n\n" \
  "<scout-decision>\n" \
  "#{JSON.generate(specification)}\n" \
  "</scout-decision>"
)
```

Concretely: Decider declares no task exports, so a whole-workflow agent
line (`tool: Decider`) exposes `ask` through the all-tasks fallback, and
a Manager carrying that line can call it as a tool directly. The same
`chat_task` is also reachable programmatically
(`Decider.job(:ask, chat: chat).run` — the route Priest uses) and from
the scout CLI. The important contract is the request text.

## Decision questions

The question definitions use the native `Decision` specification.

A yes/no question:

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

Keep questions atomic. Complicated decisions are better represented as
several independent questions whose results the Manager can combine.

## Result

The Decider returns the structured model result as JSON. For example:

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

Use the returned structure rather than asking the Decider for a prose
explanation. The probability distribution is retained so the Manager can
apply its own thresholds or combine several questions.

## Invalid requests

Malformed requests are rejected with a `ScoutException` subclass
(`Decider::RequestError`). Examples:

- missing `<scout-decision>` block
- more than one decision block
- invalid JSON
- JSON that is not an object
- missing `questions`
- empty `questions`
- missing decision state
- malformed existing `decisions.json`

Treat these as protocol errors rather than trying to interpret the
response as a normal decision.

## Recommended Manager pattern

A Manager should formulate:

1. the complete state needed by the decision;
2. one explicit `<scout-decision>` block;
3. atomic questions appropriate to the decision.

Do not put important decision instructions only in the Decider's system
prompt; the request should be self-contained and reproducible. This gives
the Manager control over **what decision is being asked**, while the
Decider controls **how that decision is evaluated**.
