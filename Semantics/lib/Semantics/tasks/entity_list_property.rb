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
  input :entities, :text, 'Entity identifiers, one per line', nil, required: true
  input :arguments, :text, 'Optional property arguments as a JSON object string (e.g. {"max": 2})', nil
  task :entity_list_property => :json do |entity_type, property, entities, arguments|
    mod, prop = EntityQuery.resolve_property!(entity_type, property)
    args = EntityQuery.parse_arguments(arguments)

    ids = entities.to_s.split("\n").collect { |line| line.strip }.reject { |line| line.empty? }
    raise ParameterException, 'entities is empty' if ids.empty?

    records = ids.each_with_index.collect do |entity_id, index|
      EntityQuery.politeness_delay(index)
      begin
        result = EntityQuery.dispatch_single(mod, entity_id, prop, args)
        { entity: entity_id, status: :done, result: result }
      rescue StandardError, SystemCallError => error
        { entity: entity_id, status: :failed,
          error: { class: error.class.to_s, message: error.message } }
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
