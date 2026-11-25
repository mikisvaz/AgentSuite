require 'json'

module Semantics

  input :entity_type, :string, 'Entity type name (e.g. as listed by the list_entities task)', nil, required: true, nofile: true
  input :property, :string, 'Property name registered on the entity type', nil, required: true, nofile: true
  input :entities, :array, 'Entity identifiers', nil, required: true
  input :arguments, :text, 'Optional property arguments as a JSON object string (e.g. {"max": 2})', nil, nofile: true
  task :entity_list_property => :json do |entity_type, property, entities, arguments|
    mod, prop = EntityQuery.resolve_property!(entity_type, property)
    args = EntityQuery.parse_arguments(arguments)
    raise ParameterException, 'entities is empty' if entities.empty?

    mode = EntityQuery.effective_dispatch(mod, prop)
    positional, keywords = EntityQuery.prepare_call(self, mod, prop, args)
    dispatch_mode = 'per_entity'
    batch_error = nil
    if %w[array multiple].include?(mode)
      begin
        stage = 'execution'
        result = EntityQuery.dispatch(mod, entities.dup, prop, mode, positional, keywords)
        stage = 'alignment'
        records = EntityQuery.align_records(entities, result)
        dispatch_mode = 'list'
      rescue StandardError => error
        batch_error = { stage: stage, class: error.class.to_s, message: error.message }
      end
    end
    records ||= EntityQuery.dispatch_each(mod, entities, prop, mode, positional, keywords)
    done = records.count { |record| record[:status] == :done }
    status = if done == records.size
               'done'
             elsif done.zero?
               'failed'
             else
               'partial'
             end
    response = { status: status, entity_type: entity_type.to_s, constant: mod.name,
                 property: prop.to_s, dispatch_mode: dispatch_mode,
                 payload_dir: keywords[:output_dir], count: records.size,
                 done: done, failed: records.size - done, records: records,
                 receipt: EntityQuery.receipt(self, mod, prop, args, entities: entities) }
    response[:batch_error] = batch_error if batch_error
    response
  end

  export :entity_list_property
end
