# Semantics

Semantic access layer for Scout agents: discover the entity types
registered in the running process, list the properties registered on each,
and evaluate a property for a single entity or for a list of entities, with
a provenance receipt on every execution.

Semantics is deliberately thin. It does not define what a gene, a pathway
or any other scientific object is, and it does not implement scientific
computations of its own. Entity types and entity properties are authored
elsewhere (through ScoutCoder or by hand) into this checkout's `share/`
tree, live-loaded by Scout-gear's `LiveWorkflow` extension, and evaluated
through the existing Scout entity machinery. Semantics provides only the
discovery, dispatch and provenance plumbing that lets an agent ask "what
entities exist", "what can I ask of this entity" and "give me this
property for these entities" as ordinary workflow tasks.

## Overview

The core idea is to make it easy to:

- **Discover** which entity types are available and which properties are
  registered on each, without hardcoding any ontology.
- **Query** a property for one entity, passing property arguments through,
  and receive the result together with a provenance receipt.
- **Query a property over an entity list**, preserving the association
  between each entity and its result, so one failing entity never blocks
  or corrupts the others.

All tasks return JSON, and every result carries the job receipt naming
the producing workflow, task and job path, so numerical claims can cite
an execution instead of transcribing values.

The intended division of labor is a contract:

| Layer | Responsibility | Where it lives |
|---|---|---|
| ScoutCoder | Constructs and edits entity definitions and properties (authoring) | `AgentSuite/ScoutCoder` |
| Semantics | Discovers, validates and evaluates them for agents (access) | this workflow |
| Application workflows | Use the results in scientific investigations | e.g. BioModelAgent |

An entity definition describes the scientific object and its capabilities;
Semantics evaluates those capabilities; the application layer interprets
the results. Semantics does not duplicate entity-property execution logic,
and it must not grow its own ontology-definition mechanism.

## Prerequisites: defining entities

Semantics ships with no entity types of its own. Before any property can
be queried, entity drafts must exist in this checkout:

- `share/entities/<entity>.rb` — the entity module (one file per entity
  type), e.g. a `module ::Gene` extending `EntityWorkflow`.
- `share/entity_properties/<entity>/<property>.rb` — one property draft
  per file, each declaring `property :<name> => :<dispatch> do ... end`.

Entity files always load before their property files, so a property file
can rely on its entity module being registered. Both are live-loaded by
LiveWorkflow on every workflow (re)load: adding a draft file and reloading
the workflow registers it without any other edit, and it then appears in
the `list_entities` result immediately.

The normal way to create these drafts is ScoutCoder's `define_entity` /
`define_entity_property` generators with the `workflow:` input pointed at
this checkout (absolute path), which redirects the authoring writes into
`share/entities/` and `share/entity_properties/` here. Pair each draft
with a test under `share/test/` and run it with ScoutCoder's
`run_task_test`.

## Example usage

The examples below assume an example entity type `Gene` (identified by
gene symbol) with a property `pubmed_articles` returning publication
identifiers, has been defined as described above. Substitute whatever
entity types and properties your checkout actually carries.

```bash
scout workflow task workflow.rb list_entities

scout workflow task workflow.rb entity_property \
    --entity_type gene --entity TP53 --property pubmed_articles

scout workflow task workflow.rb entity_property \
    --entity_type gene --entity TP53 \
    --property pubmed_article_details --arguments '{"max": 3}'

scout workflow task workflow.rb entity_list_property \
    --entity_type gene --property pubmed_articles \
    --entities $'TP53\nKRAS\nZZZQQQNOTAGENE123'
```

From Ruby:

```ruby
require File.expand_path('workflow.rb', <semantics checkout>)

Semantics.job(:entity_property, entity_type: 'gene', entity: 'TP53',
                                property: 'pubmed_articles').run
```

In this environment bare workflow names may not resolve; address the
workflow by path (`workflow.rb`).

## Notes on outputs

- All tasks return **JSON** (Scout return type `:json`), so results can be
  directly consumed by other agent tools.
- Property tasks write their jobs under the standard Scout jobs tree
  (`var/jobs` / `~/.scout/var/jobs`); clean a job when freshness matters.
- When a dispatched property declares an `:output_dir` kwarg and the
  caller did not choose a location, `entity_property` routes it into the
  task's own job files dir (`<job>.files/property_output`), so bulk
  payloads (abstracts and similar) land on disk as one file per record
  while the in-memory result carries only compact pointers.

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

# Tasks

## list_entities
List registered entity types and their properties

Discovery task. It takes no inputs and returns one JSON record per entity
type registered in the running process, listing every property with its
effective dispatch, persistence flag and block parameter signature.

Discovery is REGISTRY-driven, mirroring ScoutCoder's
`EntityDefinitionSupport.entity_modules`: the runtime registry
(`Entity::MODULES`) is the authoritative list of every module that extended
`Entity`/`EntityWorkflow` in this process, deduplicated across reloads. It
is deliberately NOT layout-driven (no directory scan): a draft that fails
to load cannot be discovered by reading directories, while a registered
module whose file moved still can; drafts are discovered exactly when they
load successfully, and a failing draft is loud at load time rather than a
silent omission from the listing.

The listing therefore includes framework entities (e.g. `AssociationItem`)
and entities owned by other workflows that happen to be loaded, not just
this checkout's own drafts. Each record carries a `source` field with the
checkout-relative definition and property draft files when this checkout
owns the entity, and `null` otherwise, so the ownership boundary is always
visible.

Example:

```bash
scout workflow task workflow.rb list_entities
```

## entity_property
Evaluate one property for one entity and return the result with provenance

Single-entity query. It dispatches the named property for the named entity
and returns the result plus a provenance receipt.

Inputs:

- `entity_type` (string, required): entity type name, as listed by
  `list_entities`.
- `entity` (string, required): entity identifier (its convention depends
  on the entity type, e.g. a gene symbol).
- `property` (string, required): property name registered on the entity
  type.
- `arguments` (text, optional): property arguments as a JSON object
  string, e.g. `{"max": 2}`. Passed through to the property as keyword
  arguments.

Dispatch uses the single-entity idiom: the property is invoked on a
`make_array` receiver (`mod.setup(entity_id).make_array`), with property
arguments passed as keyword arguments. An `:array` property then returns
its full Array result rather than collapsing to a first element.

The result's receipt names the producing job (path, task, workflow) and
the dispatched entity/property/arguments, and states explicitly whether
the property execution was Step-backed; properties declared with plain
`Entity#property` are not, so the receipt cites the task's own job as the
provenance edge.

If the property execution itself raises, the result is an error envelope
(`status: 'error'`) carrying the exception class and message — the run
does not abort.

Example:

```bash
scout workflow task workflow.rb entity_property \
    --entity_type gene --entity TP53 --property pubmed_articles
```

## entity_list_property
Evaluate one property for each entity in a list, preserving per-entity results

Per-entity fan-out over one property. Two dispatch modes, chosen per
property from its declared type:

- **List mode** (default when the property registered a special accessor —
  `:single`, `:array`, `:multiple`): the property is called ONCE on the
  whole annotated entity list and Scout's framework fans out per element;
  per-entity records are aligned from that one result. This is the
  batch-friendly path — `:multiple` properties receive the whole list in
  their block, and `:single`/`:array` properties are collected
  element-wise without N separate dispatches.
- **Per-entity fallback** (for typeless `:both` properties, or when the
  list result cannot be aligned per entity, or an element failed inside
  the framework fan-out): each entity is dispatched individually using
  the single-entity idiom described under `entity_property`. The reported
  `dispatch_mode` says which path ran.

Inputs:

- `entity_type` (string, required): entity type name, as listed by
  `list_entities`.
- `property` (string, required): property name registered on the entity
  type.
- `entities` (text, required): entity identifiers, one per line.
- `arguments` (text, optional): property arguments as a JSON object
  string, passed through to every dispatch.

Every entity produces exactly one record, with `status` `done` or
`failed`; failures carry the exception class and message. A summary
(`count`, `done`, `failed`), the dispatch mode, and the same provenance
receipt as `entity_property` are included. One entity's failure never
blocks the rest of the list.

Properties that declare an `:output_dir` kwarg get the same task-output
routing as `entity_property` (`<job>.files/property_output`), reported as
`payload_dir` in the result. Per-entity fallback dispatches apply a
modest politeness delay between calls, since some properties call
rate-limited public services.

Example:

```bash
scout workflow task workflow.rb entity_list_property \
    --entity_type gene --property pubmed_articles \
    --entities $'TP53\nKRAS\nZZZQQQNOTAGENE123'
```

In this example, if `ZZZQQQNOTAGENE123` has no publications (or the
underlying service cannot resolve it), its record reports the failure
while TP53 and KRAS still return their results.

## Layout

- `workflow.rb` — entrypoint. Extends `Workflow` and `::LiveWorkflow`,
  then requires the task files.
- `lib/Semantics/tasks/` — the task implementations:
  `entity_query.rb`, `entity_property.rb`, `entity_list_property.rb`.
- `share/entities/` — entity module drafts, live-loaded by LiveWorkflow.
- `share/entity_properties/<entity>/<property>.rb` — property drafts,
  also live-loaded; entity files always load before their property files.
- `share/entity/` — identifier TSVs for entity translation (when
  registered).
- `share/test/` — paired tests for the drafts, run in fresh processes by
  ScoutCoder's `run_task_test`.
- `test/Semantics/` — unit tests for the tasks.
- `research/` — bout records and analyses (non-authoritative).
- `tmp/` — probes and captured demo outputs (disposable).

## Testing

```bash
ruby -Itest -Ilib test/Semantics/tasks/test_entity_query.rb
ruby -Itest -Ilib test/Semantics/tasks/test_entity_property.rb
ruby -Itest -Ilib test/Semantics/tasks/test_entity_list_property.rb
```

The task tests are structure-based: they register their own probe entity
modules in-process (the same registration a loaded draft performs) and run
the real task jobs, so they pass regardless of which entity drafts the
checkout carries, involve no network, and pin both the success and failure
contracts. Property tasks write their jobs under the standard Scout jobs
tree; the tests clean each job before running it.

## Scope and non-goals

Out of scope for the current bout, deliberately: knowledge-base mutation,
association traversal, database writes, identifier translation, and any
general query language. The bootstrap bout that established this design
is recorded in `research/`.
