Semantics

Semantic access layer for Scout agents: discover the entity types
registered in the running process, list the properties registered on each,
and evaluate a property for a single entity or for a list of entities, with
a provenance receipt on every execution.

When loading the Semantics workflow it also automatically requires the
project workflow by loading the './workflow.rb' in the current working
directory, if present. This is to ensure that entities defined in the
project are also prepared.

Semantics is deliberately thin: it does not define what a gene, a pathway
or any other scientific object is, and it implements no scientific
computations of its own. Entity types and entity properties are authored
elsewhere (ScoutCoder's `entity`/`entity_property` path kinds, or by hand)
into a checkout's `share/` tree, live-loaded by Scout-gear's
`LiveWorkflow`, and evaluated through the existing Scout entity machinery.
Out of scope, deliberately: knowledge-base mutation, association
traversal, database writes, identifier translation, and any general query
language.

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

**Usage detail:** task choice, naming rules, addressing the workflow by
path, examples, output/receipt behavior and the failure policy are in
[doc/user/README.md](doc/user/README.md); authoring drafts, the
LiveWorkflow load order, layout and testing are in
[doc/developer/README.md](doc/developer/README.md).

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
    --entity_type Gene --entity TP53 --property pubmed_articles
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
    --entity_type Gene --property pubmed_articles \
    --entities $'TP53\nKRAS\nZZZQQQNOTAGENE123'
```

In this example, if `ZZZQQQNOTAGENE123` has no publications (or the
underlying service cannot resolve it), its record reports the failure
while TP53 and KRAS still return their results.
