# Using Semantics

Start in the project checkout that owns the entities. Load Semantics and call `list_entities` in the process that will evaluate the properties. A fresh consumer process must load the project workflow and its entity definitions. Use the reported `constant` as `entity_type` when passing a type between agents. A unique short CamelCase name or snake_case alias also works. An ambiguous alias produces an error listing the qualified alternatives.

Discovery reports property names, dispatch modes, persistence flags and Ruby parameter signatures. For entity definitions in the Scout draft or promoted layout, `source.definition` identifies the file where the constant was defined. A property's `source` points to a matching draft by filename under that checkout. It is a navigation hint. Inline properties can have a null source. Paths under the Semantics checkout are relative to that checkout. Foreign checkout paths are absolute.

## Evaluate a property

For example, if the project registers a type named Gene with a property named pubmed_articles, run the following commands from the project directory. Set SEMANTICS to the absolute path to the Semantics workflow.rb.

```bash
scout workflow task "$SEMANTICS" list_entities
scout workflow task "$SEMANTICS" entity_property \
  --entity_type Gene --entity TP53 --property pubmed_articles
scout workflow task "$SEMANTICS" entity_list_property \
  --entity_type Gene --entities $'TP53\nKRAS' --property pubmed_articles
```

For a property with arguments, supply a JSON object such as `--arguments '{"max":3}'`. Names are taken from the property signature. Supply positional parameters from left to right without gaps. Required keywords must be present. Extra keys require a property that accepts arbitrary keywords. An invalid call raises a parameter error before property execution. A declared output_dir keyword defaults to the job’s property_output directory.

## Interpret the result

A single evaluation returns `done` with a result or `error` with the exception details. Both carry the resolved entity type and a receipt for the Semantics job. List evaluations preserve input order and duplicates. The summary status is `done`, `partial`, or `failed`. Each record has its own `done` or `failed` status.

Scalar and typeless properties run once per input. Array and multiple properties use Scout’s batch accessor. If the batch raises or its result cannot be aligned, Semantics retries each identifier separately. In that case `dispatch_mode` is `per_entity` and `batch_error.stage` identifies `execution` or `alignment`. A missing key in a keyed result produces a failure for that identifier. Properties that call rate-limited services own their pacing.

## Cite a result in Research

1. Call the ordinary property tool with `return_path: true`. Use `refresh: "refresh"` to recompute a cached Semantics job, including when testing edited property code. Capture the completed job output before a later refresh.
2. Attach the job output by copy to the Research dossier and retain its returned digest. Select the value directly from that JSON. For a single result, check the status, entity type, identifier and property before resolving a selector such as `/result/n_active`.
3. For a list, check the selected record's identifier and status before using a selector such as `/records/2/result/n_active`. A successful result with `comparable: false` and a null fraction can support an observation about comparability. A failed record carries an execution error.
4. If the claim uses bytes from a bulk payload, capture the referenced payload file as well. Copying the JSON captures the pointer.

Receipts identify the Semantics job and its effective arguments. Cached jobs created with earlier workflow code retain the receipt and status fields written by that version.

## Troubleshooting for Agents

When the ScoutCoder agent develops new entities and entity properties, these are not automatically made available until a workflow reload is done with 'reload_workflow'. New tasks are not made available during a running inference bout even after a workflow reload, but it will make them available for new inferences, like a new delegation.
