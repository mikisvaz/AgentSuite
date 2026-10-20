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
  input :entity_type, :string, 'Entity type name (e.g. as listed by the list_entities task)', nil, required: true
  input :entity, :string, 'Entity identifier (e.g. a gene symbol)', nil, required: true
  input :property, :string, 'Property name registered on the entity type', nil, required: true
  input :arguments, :text, 'Optional property arguments as a JSON object string (e.g. {"max": 2})', nil
  task :entity_property => :json do |entity_type, entity, property, arguments|
    mod, prop = EntityQuery.resolve_property!(entity_type, property)
    args = EntityQuery.parse_arguments(arguments)

    # Task-output mechanism for full payloads: when the dispatched property
    # declares an :output_dir kwarg and the caller did not choose a location,
    # the task routes it into its own job files_dir (<job>.files/property_output).
    # Properties then write their bulk payloads (e.g. article abstracts) there
    # and return compact result entries with pointers, so the payloads are
    # readable from the job output tree instead of the in-memory result.
    payload_dir = nil
    param_types = {} 
    (mod.properties[prop] || []).collect { |kind, pname| param_types[pname] = kind}
    param_names = param_types.keys
    if param_names.include?(:output_dir) && Hash === args && args[:output_dir].nil?
      payload_dir = File.join(files_dir.to_s, 'property_output')
      args[:output_dir] = payload_dir
    end

    begin
      result = EntityQuery.dispatch_single(mod, entity, prop, args, param_types)
      record = { status: 'done',
                 entity: entity.to_s,
                 property: prop.to_s,
                 result: result,
                 receipt: EntityQuery.receipt(self, entity, prop, args) }
      record[:payload_dir] = payload_dir if payload_dir
      record
    rescue StandardError, SystemCallError => error
      { status: 'error',
        entity: entity.to_s,
        property: prop.to_s,
        error: { class: error.class.to_s, message: error.message },
        receipt: EntityQuery.receipt(self, entity, prop, args) }
    end
  end
end
