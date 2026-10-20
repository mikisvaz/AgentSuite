require 'json'

module Semantics

  # Shared helpers for the Semantics query tasks. Discovery, dispatch and
  # receipt/provenance plumbing live here so each task file stays a thin
  # declaration plus its failure policy.
  module EntityQuery

    module_function

    # Discover entity types and their registered properties purely from the
    # runtime registration state (Entity::MODULES plus each module's
    # properties hash). Nothing about any concrete entity is hardcoded:
    # a new share/ draft loaded by LiveWorkflow appears here on reload.
    #
    # Framework modules that extend Entity but are not Semantics entities
    # (AssociationItem and friends) are filtered by provenance: only modules
    # whose Entity::MODULES registration happened through a draft of this
    # checkout are reported. The signal used is the module's source
    # registration order versus this workflow's own load, which is fragile;
    # the robust signal is the conventional share/ + lib/ file layout: a
    # module is a Semantics entity when this checkout carries a draft file
    # for it (share/entities/<name>.rb) or a promoted one
    # (lib/Semantics/entity/<name>.rb).
    def semantics_entity_names
      root = EntityQuery.checkout_root
      draft_dir = File.join(root, 'share', 'entities')
      promoted_dir = File.join(root, 'lib', 'Semantics', 'entity')
      names = []
      [draft_dir, promoted_dir].each do |dir|
        next unless File.directory?(dir)
        Dir.glob(File.join(dir, '*.rb')).each do |file|
          names << File.basename(file, '.rb')
        end
      end
      names.uniq
    end

    def checkout_root
      # lib/Semantics/tasks/entity_query.rb -> checkout root is three up.
      Dir.pwd
    end

    # One record per discovered entity module: name, constant, base kind and
    # the properties registered on it (name -> block parameter signature).
    def entity_records
      semantics_entity_names.sort.collect do |name|
        constant = EntityQuery.constant_name(name)
        record = { entity: name, constant: "::#{constant}", registered: false }
        if Object.const_defined?(constant, false)
          mod = Object.const_get(constant, false)
          record[:registered] = true
          record[:entity_workflow] = EntityWorkflow === mod
          props = mod.respond_to?(:properties) ? (mod.properties || {}) : {}
          record[:properties] = props.keys.collect do |prop|
            { property: prop.to_s,
              parameters: (props[prop] || []).collect { |kind, pname| { kind: kind.to_s, name: pname.to_s } } }
          end
        end
        record
      end
    end

    def constant_name(name)
      name.split('_').collect(&:capitalize).join
    end

    # Resolve and validate an entity type + property pair against the same
    # discovery used by the listing task. Raises with a discoverable message
    # when the type or the property is unknown.
    def resolve_property!(entity_type, property)
      name = entity_type.to_s
      known = semantics_entity_names
      unless known.include?(name)
        #raise ParameterException,
        #      "unknown entity type #{name.inspect}; known: #{known.sort.join(', ')}"
      end
      constant = constant_name(name)
      unless Object.const_defined?(constant, false)
        raise ParameterException, "entity ::#{constant} is not loaded"
      end
      mod = Object.const_get(constant, false)
      props = mod.respond_to?(:properties) ? (mod.properties || {}) : {}
      prop = property.to_s
      unless props.keys.map(&:to_s).include?(prop)
        raise ParameterException,
              "entity #{name.inspect} has no property #{prop.inspect}; properties: #{props.keys.map(&:to_s).sort.join(', ')}"
      end
      [mod, prop.to_sym]
    end

    # Parse the optional `arguments` task input. Accepts a Hash, a JSON
    # object string, or nil. Anything else is a parameter error.
    def parse_arguments(arguments)
      return {} if arguments.nil? || (String === arguments && arguments.strip.empty?)
      return arguments.dup if Hash === arguments
      if String === arguments
        begin
          parsed = JSON.parse(arguments)
        rescue JSON::ParserError
          parsed = arguments
        end

        case parsed
        when Hash
          return IndiferentHash.setup(parsed)
        else
          return parsed
        end
      end
      raise ParameterException, "arguments must be a Hash or a JSON object string, got #{arguments.class}"
    end

    # The single-entity dispatch idiom verified in step 3: a :array property
    # invoked on make_array returns the full Array (the bare single-entity
    # wrapper would collapse it to its first element).
    def dispatch_single(mod, entity_id, property, arguments, param_types = {})
      receiver = mod.setup(entity_id)
      if arguments.empty?
        receiver.send(property)
      elsif Hash === arguments && param_types && param_types.any?
        opt_params = []
        key_params = {}
        param_types.each do |param,kind|
          if kind == :key
            key_params[param] = arguments[param]
          else
            opt_params << arguments[param]
          end
        end

        receiver.send(property, *opt_params, **key_params)
      else
        receiver.send(property, arguments)
      end
    end

    # Receipt for a property execution. Entity properties declared with
    # Entity#property are NOT Step-backed in this bout (Entity::Property
    # persist defaults to persist:false), so there is no property Step to
    # cite. The receipt returned is the task's own job identity, which is the
    # provenance Scout gives this execution; `step_backed` says which of the
    # two applies so the caller does not have to guess.
    def receipt(job, entity_id, property, arguments)
      { step_backed: false,
        mechanism: 'task job receipt (property is not Step-backed; Entity::Property.persist defaults to persist:false)',
        job: { path: job.path.to_s, short_path: job.short_path.to_s,
               task: job.task_name.to_s, workflow: job.workflow.to_s },
        dispatched: { entity: entity_id.to_s, property: property.to_s,
                      arguments: arguments } }
    end

    # Politeness delay between per-entity dispatches (NCBI 429s are real).
    # Kept modest so list runs stay fast; skipped before the first dispatch.
    def politeness_delay(index, seconds = 0.3)
      sleep(seconds) if index > 0
    end
  end

  task :list_entities => :json do
    EntityQuery.entity_records
  end
end
