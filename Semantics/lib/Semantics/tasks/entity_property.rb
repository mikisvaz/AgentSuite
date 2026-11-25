require 'json'

module Semantics

  # Single-entity property query. Dispatches one property for one entity and
  # returns the result plus provenance.
  #
  # Failure policy (documented choice): parameter problems (unknown entity
  # type, unknown property, malformed arguments) abort with a Scout
  # ParameterException, which is the framework's conventional loud failure
  # for bad input. A failure of the property execution itself (network down
  # for a gene without fixture PMIDs, etc.) is returned as a structured
  # error envelope with :status => 'error' and the exception class/message,
  # so a single bad query is inspectable without losing the receipt. This is
  # an error envelope, not a silent success: the status field is explicit.
  input :entity_type, :string, 'Entity type name (e.g. as listed by the list_entities task)', nil, required: true, nofile: true
  input :entity, :string, 'Entity identifier (e.g. a gene symbol)', nil, required: true, nofile: true
  input :property, :string, 'Property name registered on the entity type', nil, required: true, nofile: true
  input :arguments, :text, 'Optional property arguments as a JSON object string (e.g. {"max": 2})', nil, nofile: true
  task :entity_property => :json do |entity_type, entity, property, arguments|
    mod, prop = EntityQuery.resolve_property!(entity_type, property)
    args = EntityQuery.parse_arguments(arguments)

    mode = EntityQuery.effective_dispatch(mod, prop)
    positional, keywords = EntityQuery.prepare_call(self, mod, prop, args)
    receipt = EntityQuery.receipt(self, mod, prop, args, entity: entity.to_s)
    payload_dir = keywords[:output_dir]

    begin
      result = EntityQuery.dispatch(mod, entity, prop, mode, positional, keywords)
      record = { status: 'done',
                 entity_type: mod.name, entity: entity.to_s,
                 property: prop.to_s,
                 result: result,
                 receipt: receipt }
      record[:payload_dir] = payload_dir if payload_dir
      record
    rescue StandardError, SystemCallError => error
      { status: 'error',
        entity_type: mod.name, entity: entity.to_s,
        property: prop.to_s,
        error: { class: error.class.to_s, message: error.message },
        receipt: receipt }
    end
  end

  export :entity_property
end
