require 'json'

module Semantics

  # Per-entity fan-out of one property over a list of entity ids.
  #
  # The property is called ONCE PER entity using the single-entity dispatch
  # idiom verified in step 3 (make_array receiver, full Array result). The
  # documented array-receiver first-gene behavior of the property body is
  # explicitly NOT relied on here.
  #
  # Failure policy: one entity's failure never affects the others. Each
  # entity gets its own record {entity, status (:done/:failed), result or
  # error}; a failed dispatch records the exception class and message in an
  # error envelope and the run continues. Parameter problems (unknown type
  # or property, malformed arguments) abort the whole run with
  # ParameterException, since they make every per-entity record invalid.
  # A modest politeness delay separates dispatches (NCBI 429s are real).
  input :entity_type, :string, 'Entity type name (e.g. as listed by the list_entities task)', nil, required: true
  input :property, :string, 'Property name registered on the entity type', nil, required: true
  input :entities, :array, 'Entity identifiers', nil, required: true
  input :arguments, :text, 'Optional property arguments as a JSON object string (e.g. {"max": 2})', nil
  task :entity_list_property => :json do |entity_type, property, entities, arguments|
    mod, prop = EntityQuery.resolve_property!(entity_type, property)
    args = EntityQuery.parse_arguments(arguments)

    mod.setup(entities)
    raise ParameterException, 'entities is empty' if entities.empty?

    param_types = {} 
    (mod.properties[prop] || []).collect { |kind, pname| param_types[pname] = kind}
    param_names = param_types.keys

    records = []
    res = EntityQuery.dispatch_single(mod, entities, prop, args, param_types)
    if Array === res
      res.each_with_index do |result,i|
        entity_id = entities[i]
        records << { entity: entity_id, status: :done, result: result }
      end
    elsif Hash === res
      entities.each do |entity|
        if res[entity]
          records << { entity: entity, status: :done, result: result }
        else
          records << { entity: entity, status: :failed }
        end
      end
    end

    { status: 'done',
      entity_type: entity_type.to_s,
      property: prop.to_s,
      count: records.length,
      done: records.count { |record| record[:status] == :done },
      failed: records.count { |record| record[:status] == :failed },
      receipt: EntityQuery.receipt(self, nil, prop, args),
      records: records }
  end
end
