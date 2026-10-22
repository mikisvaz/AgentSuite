require 'json'

module Semantics

  # Shared helpers for the Semantics query tasks. Discovery, dispatch and
  # receipt/provenance plumbing live here so each task file stays a thin
  # declaration plus its failure policy.
  module EntityQuery

    module_function

    # Checkout root derived from this file (lib/Semantics/tasks/), NOT from
    # the process working directory: jobs and tests may run from anywhere.
    CHECKOUT_ROOT = File.expand_path('../../..', __dir__)

    # Registry-driven entity discovery, mirroring ScoutCoder's
    # EntityDefinitionSupport.entity_modules: Entity::MODULES is the
    # authoritative runtime registry of every module that extended Entity in
    # this process. Layout scanning (share/entities/*.rb) is deliberately
    # NOT used for discovery: a draft that fails to load, or a file without
    # a registered module, cannot be found by reading directories, and a
    # registered module whose file moved still can be. Entity::MODULES is
    # append-only: re-loading an entity file re-extends and re-appends the
    # same module object, so uniq keeps one row per module.
    def entity_modules
      return [] unless defined?(Entity)
      Entity::MODULES.uniq.select do |mod|
        mod.is_a?(Module) && Entity === mod && mod.respond_to?(:properties) && mod.name
      end
    end

    # snake_case entity name from the module's last constant segment
    # (SemanticsToy -> semantics_toy), the convention ScoutCoder uses.
    def entity_name(mod)
      mod.name.to_s.split('::').last
         .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
         .gsub(/([a-z0-9])([A-Z])/, '\1_\2')
         .downcase
    end

    def constant_name(name)
      name.to_s.split('_').collect(&:capitalize).join
    end

    # Effective dispatch of a property, probed from the accessor its
    # declaration registered (Entity::Property single/array/multi methods).
    # A typeless `property :plain do` registers no special accessor and
    # dispatches as 'both' (the block receives the receiver as-is).
    def effective_dispatch(mod, property)
      return 'single'   if mod.method_defined?(Entity::Property.single_method(property))
      return 'array'    if mod.method_defined?(Entity::Property.array_method(property))
      return 'multiple' if mod.method_defined?(Entity::Property.multi_method(property))
      'both'
    end

    # Checkout source metadata for one module: the definition draft and the
    # property draft files this checkout carries for it. nil when the module
    # is not defined by this checkout (framework entities such as
    # AssociationItem, or entities owned by other workflows); the registry
    # lists them all the same, source just reports the ownership boundary.
    def entity_source_metadata(mod)
      name = entity_name(mod)
      candidates = [File.join(CHECKOUT_ROOT, 'share', 'entities', "#{name}.rb"),
                    File.join(CHECKOUT_ROOT, 'lib', 'Semantics', 'entity', "#{name}.rb")]
      definition = candidates.find { |file| File.file?(file) }
      property_dir = File.join(CHECKOUT_ROOT, 'share', 'entity_properties', name)
      property_files = File.directory?(property_dir) ? Dir.glob(File.join(property_dir, '**', '*.rb')).sort : []
      return nil if definition.nil? && property_files.empty?
      { definition: definition && relative_to_checkout(definition),
        property_files: property_files.collect { |file| relative_to_checkout(file) } }
    end

    def relative_to_checkout(path)
      path = path.to_s
      path.start_with?(CHECKOUT_ROOT + File::SEPARATOR) ? path.delete_prefix(CHECKOUT_ROOT + File::SEPARATOR) : path
    end

    # One record per registered entity module: names, base kind, and every
    # property with its effective dispatch, persistence flag and block
    # parameter signature.
    def entity_records
      entity_modules.sort_by { |mod| entity_name(mod) }.collect do |mod|
        props = mod.properties || {}
        { entity: entity_name(mod),
          constant: mod.name.to_s,
          entity_workflow: (defined?(EntityWorkflow) && EntityWorkflow === mod),
          properties: props.keys.sort.collect do |prop|
            { property: prop.to_s,
              dispatch: effective_dispatch(mod, prop),
              persisted: !!(mod.respond_to?(:persisted?) && mod.persisted?(prop)),
              parameters: (props[prop] || []).collect { |kind, pname| { kind: kind.to_s, name: pname.to_s } } }
          end,
          source: entity_source_metadata(mod) }
      end
    end

    # Resolve and validate an entity type + property pair against the same
    # registry the listing task uses. Raises ParameterException naming the
    # known alternatives when the type or the property is unknown.
    def resolve_property!(entity_type, property)
      name = entity_type.to_s
      mod = entity_modules.find do |m|
        entity_name(m) == name || m.name.to_s == name || m.name.to_s.split('::').last == name
      end
      raise ParameterException,
            "unknown entity type #{name.inspect}; known: #{entity_modules.collect { |m| entity_name(m) }.sort.join(', ')}" unless mod

      props = mod.properties || {}
      prop = property.to_s
      unless props.keys.map(&:to_s).include?(prop)
        raise ParameterException,
              "entity #{entity_name(mod).inspect} has no property #{prop.inspect}; properties: #{props.keys.map(&:to_s).sort.join(', ')}"
      end
      [mod, prop.to_sym]
    end

    # Parse the optional `arguments` task input. Accepts nil/blank (meaning
    # no arguments), a Hash, or a JSON object string; anything else, and any
    # JSON string that does not encode an object, is a parameter error:
    # property arguments are name-based, so a non-object payload cannot be
    # forwarded meaningfully.
    def parse_arguments(arguments)
      return {} if arguments.nil? || (String === arguments && arguments.strip.empty?)
      return IndiferentHash.setup(arguments.dup) if Hash === arguments
      if String === arguments
        begin
          parsed = JSON.parse(arguments, symbolize_names: true)
        rescue JSON::ParserError
          raise ParameterException, "arguments must be a JSON object string, got unparseable: #{arguments.inspect}"
        end
        raise ParameterException, "arguments JSON must encode an object, got #{parsed.class}" unless Hash === parsed
        return IndiferentHash.setup(parsed)
      end
      raise ParameterException, "arguments must be a Hash or a JSON object string, got #{arguments.class}"
    end

    # Block parameter signature of one property as {param_name => kind},
    # kinds being Ruby parameter kinds (:req, :opt, :key, ...).
    def parameter_types(mod, property)
      ((mod.properties || {})[property] || []).each_with_object({}) do |(kind, pname), types|
        types[pname] = kind
      end
    end

    # ScoutCoder: property dispatch shapes (verified against scout-gear):
    # `property :x => :single` invoked through the bare accessor on a LIST
    # receiver returns one result per element; `:array` on a SINGLE receiver
    # collapses to the first element of its result unless the receiver is
    # make_array'd; `:multiple` runs its block once on the whole annotated
    # list; a typeless property (=> :both) receives the receiver as-is, so a
    # list receiver yields ONE whole-list value, not per-entity results.
    #
    # Dispatch one property for one entity id (or one list of ids), choosing
    # the receiver so the result keeps its natural shape: single/both on a
    # plain receiver; array/multiple on a make_array receiver for single
    # entity ids (preserves the full Array result) and on the list itself
    # for Arrays (the framework fans out per element).
    def dispatch_single(mod, entity_id, property, arguments, param_types = {})
      receiver = mod.setup(entity_id)
      unless Array === receiver
        receiver = receiver.make_array if %w(array multiple).include?(effective_dispatch(mod, property))
      end

      if arguments.nil? || arguments.empty?
        receiver.send(property)
      elsif Hash === arguments && param_types && param_types.any?
        opt_params, key_params = [], {}
        param_types.each do |param, kind|
          next unless arguments.key?(param)
          if kind == :key
            key_params[param] = arguments[param]
          else
            opt_params << arguments[param]
          end
        end
        if opt_params.empty? && key_params.empty?
          receiver.send(property)
        else
          receiver.send(property, *opt_params, **key_params)
        end
      else
        receiver.send(property, arguments)
      end
    end

    # Per-entity dispatch loop: one dispatch per entity, each individually
    # rescued, so one entity's failure becomes that record's error envelope
    # and never blocks the others. A politeness delay separates dispatches
    # (some properties call rate-limited public services).
    # ScoutCoder: do NOT use each_with_index (or other blockless enumerator
    # idioms) on an annotated entity list — scout-essentials
    # AnnotatedArray#each_with_index calls `block.call` unconditionally, so
    # enumerator mode raises NoMethodError for nil. Index loops are safe.
    def dispatch_each(mod, entities, property, arguments, param_types)
      entities.length.times.collect do |index|
        entity = entities[index]
        politeness_delay(index)
        begin
          { entity: entity, status: :done,
            result: dispatch_single(mod, entity, property, arguments, param_types) }
        rescue StandardError, SystemCallError => error
          { entity: entity, status: :failed,
            error: { class: error.class.to_s, message: error.message } }
        end
      end
    end

    # One-shot list dispatch: call the property once on the whole entity
    # list and align the result back to per-entity records. Works for every
    # dispatch type that registered a special accessor (single, array,
    # multiple); raises when the result cannot be aligned per entity, which
    # the caller treats as the signal to fall back to dispatch_each.
    def records_from_list_dispatch(mod, entities, property, arguments, param_types)
      res = dispatch_single(mod, entities, property, arguments, param_types)
      case res
      when Array
        unless res.length == entities.length
          raise ArgumentError,
                "list dispatch returned #{res.length} results for #{entities.length} entities"
        end
        entities.length.times.collect do |index|
          { entity: entities[index], status: :done, result: res[index] }
        end
      when Hash
        entities.collect do |entity|
          if res.key?(entity)
            { entity: entity, status: :done, result: res[entity] }
          else
            { entity: entity, status: :failed,
              error: { class: 'KeyError', message: "no result for entity #{entity.inspect}" } }
          end
        end
      else
        raise ArgumentError,
              "list dispatch returned a single #{res.class}; cannot align per-entity records"
      end
    rescue StandardError, SystemCallError => error
      # A failing element inside the framework fan-out (or any unalignable
      # result) fails the whole one-shot dispatch. Convert it to the
      # ArgumentError signal the caller understands as "fall back to
      # per-entity": only the offending entities become error envelopes
      # there, while here the whole run would be one undifferentiated
      # failure.
      raise ArgumentError, "list dispatch failed: #{error.class} #{error.message}"
    end

    # Receipt for a property execution. Entity properties declared with
    # Entity#property are NOT Step-backed here (Entity::Property.persist
    # defaults to persist:false), so there is no property Step to cite. The
    # receipt returned is the task's own job identity, which is the
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

    # Task-output mechanism for full payloads: when the dispatched property
    # declares an :output_dir kwarg and the caller did not choose a location,
    # route it into the given task job's files_dir
    # (<job>.files/property_output). Properties then write their bulk
    # payloads (e.g. article abstracts) there and return compact result
    # entries with pointers, so the payloads are readable from the job
    # output tree instead of the in-memory result. Returns the payload dir
    # (nil when the property takes no :output_dir).
    def route_payload_dir!(job, param_types, args)
      return nil unless param_types.key?(:output_dir)
      return nil if args[:output_dir]
      payload_dir = File.join(job.files_dir.to_s, 'property_output')
      args[:output_dir] = payload_dir
      payload_dir
    end
  end

  task :list_entities => :json do
    EntityQuery.entity_records
  end

  export_exec :list_entities
end
