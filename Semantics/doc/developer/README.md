# Semantics developer documentation

Implementation, authoring, layout and testing material for the Semantics
workflow. Agent-facing usage lives in `Semantics/README.md` and
[doc/user/README.md](../user/README.md); this file owns the developer view.

## Auto-require of the project workflow

`workflow.rb` (L7-9) requires the project workflow when Semantics itself is
loaded from its own checkout rather than as `./workflow.rb`:

```ruby
if File.expand_path(__FILE__) != File.expand_path('./workflow.rb')
  Workflow.require_workflow './workflow.rb', silent: true if File.exist?('./workflow.rb')
end
```

This loads `./workflow.rb` from the current working directory, if present,
so entities defined in the project are also prepared. It is silent: a
project without a local `workflow.rb` loads nothing.

## Authoring entity drafts (corrected claims)

Semantics ships with no entity types of its own; drafts are authored
elsewhere and live-loaded. The authoring surface, corrected against the
current ScoutCoder task list:

- There is **no `define_entity` / `define_entity_property` ScoutCoder
  task**. Authoring goes through ScoutCoder's `path_write` on the `entity`
  and `entity_property` path kinds:
  `path_write kind=entity path=<name>` writes `share/entities/<name>.rb`
  and `path_write kind=entity_property path=<entity>/<property>` writes
  `share/entity_properties/<entity>/<property>.rb` — with the `workflow:`
  input pointed at this checkout (absolute path) the authoring writes land
  in this checkout's `share/` tree. Drafts can also be written by hand;
  the validation rules for both shapes are in the ScoutCoder README,
  section "Authoring ScoutCoder entities" (CamelCase canonical, legacy
  snake accepted with a warning, extend line owned by the entity file).
- Scout-gear's `LiveWorkflow` loads `share/tasks`, `share/helpers`,
  `share/entities` and `share/entity_properties` under the workflow root on
  every workflow (re)load, in that order — entity files therefore always
  load before their property files. Adding a draft file and reloading the
  workflow registers it without any other edit, and it then appears in the
  `list_entities` result immediately. A draft that fails to load is loud at
  load time (a `ScoutException` naming the file), never a silent omission
  from the listing.
- **Current checkout state**: this checkout carries no `share/` tree at all
  (the Wave A audit dossier recorded it as empty; at execution it is
  absent). Older READMEs described the prerequisites as current state;
  they describe the intended state. Create `share/entities/` and
  `share/entity_properties/` when authoring drafts here.
- **Paired tests**: the `share/test/` tier does not exist in this checkout.
  Tests for drafts are authored through ScoutCoder `path_write` on the
  `test_file` kind (virtual paths such as `entity/DemoWidget`) and run with
  ScoutCoder's **`run_test`** task — the older name `run_task_test` is
  wrong; no such task exists.

## Layout

- `workflow.rb` — entrypoint. Extends `Workflow` and `::LiveWorkflow`,
  auto-requires the project workflow, then requires the task files.
- `lib/Semantics/tasks/` — the task implementations: `entity_query.rb`
  (`list_entities`), `entity_property.rb`, `entity_list_property.rb`.
- `share/entities/` — entity module drafts, live-loaded by LiveWorkflow
  (absent in this checkout today).
- `share/entity_properties/<entity>/<property>.rb` — property drafts, also
  live-loaded; entity files always load before their property files
  (absent in this checkout today).
- `share/entity/` — identifier TSVs for entity translation, when registered
  (absent in this checkout today).
- `test/Semantics/tasks/` — unit tests for the three tasks.
- `research/` — bout records and analyses (non-authoritative).
- `tmp/` — probes and captured demo outputs (disposable).
- `var/` — the job tree produced by task runs.

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

(The behavioral description above was marked unverified in the Wave A
audit dossier; it was verified against the test file headers during the
Wave A execution — the probe-module and no-network claims appear in the
test file comments and code.)
