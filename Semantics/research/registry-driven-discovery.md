# Registry-driven entity discovery in Semantics

Date: 2026-10-22
Status: verified (probes + task tests, fresh processes)
Scope: `lib/Semantics/tasks/entity_query.rb` and dependents

## Context

The bootstrap implementation of Semantics `list_entities` discovered entity
types by scanning the checkout layout (`share/entities/*.rb` and
`lib/Semantics/entity/*.rb`). The user pointed at ScoutCoder's earlier,
more reliable approach (`AgentSuite/ScoutCoder/lib/ScoutCoder/tasks/entity_tools.rb`,
`EntityDefinitionSupport.entity_modules`) and asked to study it and improve
`entity_list_property` / discovery accordingly.

## What was studied

`entity_modules(scope = nil)` in ScoutCoder relies on the runtime registry
`Entity::MODULES` (scout-gear `lib/scout/entity.rb`):

```ruby
def entity_modules(scope = nil)
  return [] unless defined?(Entity)
  scoped_entities = scope.constants(false).sort_by(&:to_s).filter_map do |constant|
    next if scope.autoload?(constant)
    entity = scope.const_get(constant, false)
    entity if entity.is_a?(Module) && Entity === entity && entity.respond_to?(:properties)
  end if scope
  return scoped_entities if scope
  Entity::MODULES.uniq
end
```

Key facts established by probes (`tmp/probe_property_types.rb` — deleted
after verification, its findings summarized below — and
`tmp/probe_registry_list.rb`, in fresh processes):

- `Entity::MODULES` is append-only; re-loading an entity file re-extends
  and re-appends the SAME module object, so `.uniq` keeps one row.
- The registry contains framework entities too (`AssociationItem`), not
  only checkout-owned ones — the scoped branch in ScoutCoder exists to
  enumerate one module's own entity constants, which Semantics does not
  need.
- `Module#name` is the reliable display key; anonymous modules are
  filtered out (`mod.name` non-nil guard), which the layout scan cannot
  even represent.

## Changes

`lib/Semantics/tasks/entity_query.rb`:

- `EntityQuery.entity_modules` now mirrors ScoutCoder's unscoped
  `Entity::MODULES.uniq` (plus `Entity === mod`, `respond_to?(:properties)`
  and named-module guards). Layout scanning is REMOVED from discovery.
- `entity_source_metadata` stays, but only as optional per-module source
  annotation (`source: null` for framework/foreign modules); it no longer
  gates what is listed.
- `resolve_property!` resolves against the same registry, accepting
  snake_case, full constant, and last-segment spellings; unknowns raise
  `ParameterException` naming the known alternatives.
- `parse_arguments` JSON path now symbolizes keys
  (`JSON.parse(arguments, symbolize_names: true)`), matching the kwargs
  forwarder.

## Additional findings while investigating

1. **AnnotatedArray#each_with_index enumerator bug (scout-essentials).**
   `AnnotatedArray#each_with_index` calls `block.call` unconditionally;
   blockless enumerator use (`entities.each_with_index.collect` on an
   annotated list) raises `NoMethodError: undefined method 'call' for nil`.
   Reproduction shape (probe deleted after verification): take a
   `make_array` receiver and call `each_with_index` on it blockless as an
   enumerator
   (`list.each_with_index.collect { ... }`). ScoutCoder: this is why index
   loops replace `each_with_index` in Semantics code.
   Replaced both `each_with_index` uses in Semantics with index loops.
   A `ScoutCoder:` comment records it at the call site.

2. **Property dispatch shapes (verified by the deleted probe
   `tmp/probe_property_types.rb`; kept probes: `tmp/probe_registry_list.rb`,
   `tmp/probe_modes.rb`).**
   Through the bare accessor on a list receiver: `:single` fans out per
   element; `:array` and `:multiple` also yield per-element results;
   typeless (`:both`) returns ONE whole-list value — which motivated the
   per-entity fallback for `:both` properties in `entity_list_property`.

3. **One-shot list dispatch can fail mid-fan-out.** When an element raises
   inside the framework's `collect`, the whole dispatch raises (no partial
   results). `records_from_list_dispatch` now converts any such failure
   into the `ArgumentError` "fall back to per-entity" signal, so only the
   offending entities become error envelopes (verified:
   `test_one_failure_never_blocks_the_rest`).

4. **`entity_list_property` lacked the payload_dir routing** that
   `entity_property` had for `:output_dir`-declaring properties. Both now
   call the shared `EntityQuery.route_payload_dir!`, and the result
   carries `payload_dir`.

5. **Replayed JSON jobs return string-keyed hashes.** A replayed
   `entity_list_property` job's `records` came back with string keys
   (`IndiferentHash` covers top level only in the probe's access
   pattern). Clean the job when key shape matters in a probe; task code
   itself always returns symbol keys on clean runs. Not a task defect.

## Verification

- Task suites (fresh processes, all green):
  - `test_entity_query.rb` — 8 tests, 29 assertions (registry discovery,
    probe module + AssociationItem, dispatch/parameters, source boundary,
    resolve errors, parse_arguments)
  - `test_entity_property.rb` — 8 tests, 24 assertions (result+receipt,
    positional and kwarg argument forwarding, payload_dir routing,
    error envelope, three loud aborts)
  - `test_entity_list_property.rb` — 10 tests, 31 assertions (all four
    dispatch modes, arguments in list mode, one-failure isolation,
    receipt, three loud aborts)
- Probes: `tmp/probe_registry_list.rb` (all modes through real tasks,
  cleaned jobs), `tmp/probe_modes.rb` (fallback + arguments).
- README `# Tasks` section updated to describe registry-driven discovery
  and the two dispatch modes; Testing section updated to the probe-module
  test design.

## Open items

- The AnnotatedArray enumerator bug belongs upstream (scout-essentials);
  Semantics works around it with index loops and documents it.
- The share/entity drafts that the bootstrap demo used (Gene +
  pubmed_articles) are no longer present in this checkout; that is
  expected (drafts are per-application), and the task tests now define
  probe modules so the suite does not depend on any draft existing.
