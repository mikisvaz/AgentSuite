require 'json'

module Semantics

  # Per-entity fan-out of one property over a list of entity ids.
  #
  # Two dispatch modes, chosen per property:
  #
  # - One-shot list dispatch (the default when the property registered a
  #   special accessor): the property is called ONCE on the whole annotated
  #   entity list and the framework fans out per element; per-entity records
  #   are aligned from the result. This is the batch-friendly path: :multiple
  #   properties get the whole list in their block, and :single/:array
  #   properties are collected element-wise without N dispatches.
  # - Per-entity fallback: when the list result cannot be aligned per entity
  #   (wrong arity or a non-alignable single value), each entity is
  #   dispatched individually through the single-entity idiom, each failure
  #   becoming that record's error envelope; nothing blocks the others.
  #
  # Properties that declare an :output_dir kwarg get the same task-output
  # routing as entity_property: the bulk payloads land under the task job's
  # <job>.files/property_output, and per-entity result entries carry
  # pointers. In list mode one payload dir serves the whole run; in
  # per-entity fallback mode the routing happens inside dispatch_single via
  # the args hash either way.
  #
  # Failure policy: one entity's failure never affects the others. Parameter
  # problems (unknown type or property, malformed arguments, empty list)
  # abort the whole run with ParameterException, since they make every
  # per-entity record invalid.
  input :entity_type, :string, 'Entity type name (e.g. as listed by the list_entities task)', nil, required: true
  input :property, :string, 'Property name registered on the entity type', nil, required: true
  input :entities, :array, 'Entity identifiers', nil, required: true
  input :arguments, :text, 'Optional property arguments as a JSON object string (e.g. {"max": 2})', nil
  task :entity_list_property => :json do |entity_type, property, entities, arguments|
    mod, prop = EntityQuery.resolve_property!(entity_type, property)
    args = EntityQuery.parse_arguments(arguments)
    raise ParameterException, 'entities is empty' if entities.empty?

    param_types = EntityQuery.parameter_types(mod, prop)
    payload_dir = EntityQuery.route_payload_dir!(self, param_types, args)

    mode = :list
    records = begin
      EntityQuery.records_from_list_dispatch(mod, entities, prop, args, param_types)
    rescue ArgumentError
      mode = :per_entity
      EntityQuery.dispatch_each(mod, entities, prop, args, param_types)
    end

    { status: 'done',
      entity_type: entity_type.to_s,
      property: prop.to_s,
      dispatch_mode: mode.to_s,
      payload_dir: payload_dir,
      count: records.length,
      done: records.count { |record| record[:status] == :done },
      failed: records.count { |record| record[:status] == :failed },
      receipt: EntityQuery.receipt(self, nil, prop, args),
      records: records }
  end

  export :entity_list_property
end
