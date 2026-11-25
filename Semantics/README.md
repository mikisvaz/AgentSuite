# Semantics

Semantics gives Scout agents access to entities registered in the current Ruby process. ScoutCoder authors entity definitions and properties. Semantics evaluates those properties and produces a Scout job that downstream workflows can cite.

| Task | Use |
|---|---|
| `list_entities` | Discover loaded types, qualified names, property signatures and draft files. |
| `entity_property` | Evaluate one registered property for one identifier. |
| `entity_list_property` | Evaluate one property for an ordered list of identifiers and inspect individual outcomes. |

When loaded from a project directory containing another `workflow.rb`, Semantics loads the project workflow so its entities can register. Agent-facing examples and evidence handoff instructions are in [the user guide](doc/user/README.md). The [developer guide](doc/developer/README.md) covers authoring, loading and testing.

# Tasks

## list_entities
List loaded entity types and their registered properties

Use the qualified constant from discovery to identify an entity type across calls.

## entity_property
Evaluate a registered property for one entity identifier

The JSON result includes the entity type, identifier, property and producing job receipt. Use the ordinary exported task with `return_path: true` to capture the job in a dossier.

## entity_list_property
Evaluate one registered property for an ordered list of entity identifiers

The JSON result includes per-entity records, success and failure counts, dispatch mode and the producing job receipt. Check the selected record's status and identifier before citing its result.
