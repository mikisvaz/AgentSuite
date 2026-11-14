# Using Semantics tasks (user guide)

Agent-facing usage of the Semantics workflow's three tasks —
`list_entities`, `entity_property`, `entity_list_property`. The workflow
introduction and task entries live in `Semantics/README.md`; developer
material (authoring drafts, layout, testing) in
[doc/developer/README.md](../developer/README.md).

## Picking the task

| Need | Task |
|---|---|
| What entity types and properties exist in this process? | `list_entities` |
| One property for one entity | `entity_property` |
| One property for many entities at once | `entity_list_property` |

`list_entities` is the discovery entry point: run it before assuming an
entity type or property exists. It reports every entity type registered in
the running process — including framework entities and entities owned by
other loaded workflows — each with its properties, and a `source` field
naming the checkout-relative draft files when this checkout owns the
entity (`null` otherwise).

## Naming rules (aligned with ScoutCoder)

Entity-TYPE names are CamelCase, matching `[A-Z][A-Za-z0-9]*` (e.g. `Gene`,
`DemoWidget`, or the all-caps acronym `TF`); property names are snake_case
(`[a-z][a-z0-9_]*`). A legacy snake_case entity name still validates, with
a warning that names both spellings; the two collision cases (a snake name
whose camelized constant collides with a coexisting CamelCase draft, and
two snake names whose constants collide) are hard errors. The full rule,
with examples, is in the ScoutCoder README, section "Authoring ScoutCoder
entities".

## Addressing the workflow

In this environment bare workflow names may not resolve; address the
workflow by path (`workflow.rb`):

```bash
scout workflow task workflow.rb list_entities
```

## Examples

The examples assume an example entity type `Gene` (identified by gene
symbol) with a property `pubmed_articles` returning publication
identifiers. Substitute whatever entity types and properties your checkout
actually carries.

```bash
scout workflow task workflow.rb list_entities

scout workflow task workflow.rb entity_property \
    --entity_type Gene --entity TP53 --property pubmed_articles

scout workflow task workflow.rb entity_property \
    --entity_type Gene --entity TP53 \
    --property pubmed_article_details --arguments '{"max": 3}'

scout workflow task workflow.rb entity_list_property \
    --entity_type Gene --property pubmed_articles \
    --entities $'TP53\nKRAS\nZZZQQQNOTAGENE123'
```

From Ruby:

```ruby
require File.expand_path('workflow.rb', <semantics checkout>)

Semantics.job(:entity_property, entity_type: 'Gene', entity: 'TP53',
                                property: 'pubmed_articles').run
```

## Outputs and receipts

- All tasks return **JSON** (Scout return type `:json`), so results can be
  directly consumed by other agent tools.
- Export mode: `entity_property` and `entity_list_property` are exported as
  ordinary (non-exec) tasks, so one dispatched call runs as a persisted job
  and returns value and durable job path together. Through the agent tool
  layer, `return_path: true` answers with the persisted job path (durable,
  readable by ordinary tools after the producing process ends) rather than a
  temporary file; `list_entities` stays exec-exported (pure discovery, no
  result to cite).
- Property tasks write their jobs under the standard Scout jobs tree
  (`var/jobs` / `~/.scout/var/jobs`); clean a job when freshness matters.
- When a dispatched property declares an `:output_dir` kwarg and the
  caller did not choose a location, `entity_property` routes it into the
  task's own job files dir (`<job>.files/property_output`), so bulk
  payloads (abstracts and similar) land on disk as one file per record
  while the returned JSON record carries only compact pointers (the record
  itself is persisted as the job result). `entity_list_property` reports
  the same routing as `payload_dir`.

## Failure policy

A consistent two-level policy, shared by the property-evaluating tasks:

- **Parameter problems** — unknown entity type, unknown property,
  malformed `arguments` JSON, empty entity list — abort the run with a
  Scout `ParameterException`. These make every downstream record invalid,
  so they fail loud and early.
- **Execution problems** — a property that raises for one particular
  entity (network down for a gene without offline fallbacks, a bad
  identifier, etc.) — are captured per entity as a structured error
  envelope carrying the exception class and message. One entity's failure
  never blocks or corrupts another's record.

List runs also apply a modest politeness delay between dispatches, since
some properties call rate-limited public services.
