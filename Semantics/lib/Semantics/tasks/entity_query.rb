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

    # Canonical public name; the qualified constant disambiguates namespaces.
    def entity_name(mod)
      Misc.camel_case(mod.name.to_s.split('::').last)
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

    # Anchor draft lookup at the registered constant's definition. A matching
    # draft is a navigation hint; Scout's registry only retains block parameters.
    def entity_source_metadata(mod)
      file, = Object.const_source_location(mod.name)
      return unless file && File.file?(file)
      definition = File.expand_path(file)
      match = definition.match(%r{\A(.+)/(?:share/entities|lib/[^/]+/entity)/([^/]+)\.rb\z})
      return unless match
      root, basename = match.captures
      property_dir = File.join(root, 'share', 'entity_properties', basename)
      drafts = Dir.glob(File.join(property_dir, '**', '*.rb')).sort
      { definition: relative_to_checkout(definition),
        property_files: drafts.map { |draft| relative_to_checkout(draft) } }
    end

    def relative_to_checkout(path)
      path = path.to_s
      path.start_with?(CHECKOUT_ROOT + File::SEPARATOR) ? path.delete_prefix(CHECKOUT_ROOT + File::SEPARATOR) : path
    end

    # One record per registered entity module: names, base kind, and every
    # property with its effective dispatch, persistence flag and block
    # parameter signature.
    def entity_records
      entity_modules.sort_by { |mod| [entity_name(mod), mod.name] }.collect do |mod|
        props = mod.properties || {}
        source = entity_source_metadata(mod)
        { entity: entity_name(mod), constant: mod.name,
          entity_workflow: (defined?(EntityWorkflow) && EntityWorkflow === mod),
          properties: props.keys.sort_by{|k| k.to_s }.collect do |prop|
            { property: prop.to_s,
              source: source && source[:property_files].find { |file| File.basename(file, '.rb') == prop.to_s },
              dispatch: effective_dispatch(mod, prop),
              persisted: !!(mod.respond_to?(:persisted?) && mod.persisted?(prop)),
              parameters: (props[prop] || []).collect { |kind, pname| { kind: kind.to_s, name: pname.to_s } } }
          end,
          source: source }
      end
    end

    # Resolve and validate an entity type + property pair against the same
    # registry the listing task uses. Raises ParameterException naming the
    # known alternatives when the type or the property is unknown.
    def resolve_property!(entity_type, property)
      name = entity_type.to_s
      modules = entity_modules
      mod = modules.find { |candidate| candidate.name == name }
      unless mod
        matches = modules.select do |candidate|
          short = entity_name(candidate)
          short == name || Misc.snake_case(short) == name
        end
        if matches.size > 1
          raise ParameterException, "ambiguous entity type #{name.inspect}: #{matches.map(&:name).sort.join(', ')}"
        end
        mod = matches.first
      end
      raise ParameterException, "unknown entity type #{name.inspect}; known: #{modules.map(&:name).sort.join(', ')}" unless mod

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
          raise ParameterException, "arguments must be a JSON object string, invalid JSON"
        end
        raise ParameterException, "arguments JSON must encode an object, got #{parsed.class}" unless Hash === parsed
        return IndiferentHash.setup(parsed)
      end
      raise ParameterException, "arguments must be a Hash or a JSON object string, got #{arguments.class}"
    end

    # Bind once before execution so bad inputs cannot produce success receipts.
    def prepare_call(job, mod, property, args)
      signature = begin
                    mod.properties.fetch(property)
                  rescue KeyError
                    raise ParameterException, "Property not found #{property}"
                  end
      if signature.any? { |kind, name| name == :output_dir && [:key, :keyreq].include?(kind) }
        args[:output_dir] ||= File.join(job.files_dir.to_s, 'property_output')
      end
      remaining = args.transform_keys(&:to_sym)
      positional = []
      keywords = {}
      gap = nil
      accepts_keywords = false
      signature.each do |kind, name|
        case kind
        when :req, :opt
          raise ParameterException, "unnamed positional parameter on #{property}" unless name
          if remaining.key?(name)
            raise ParameterException, "supply #{gap} before #{name}" if gap
            positional << remaining.delete(name)
          elsif kind == :req
            raise ParameterException, "missing argument #{name}"
          else
            gap ||= name
          end
        when :keyreq, :key
          raise ParameterException, "missing keyword #{name}" if kind == :keyreq && !remaining.key?(name)
          keywords[name] = remaining.delete(name) if remaining.key?(name)
        when :keyrest
          accepts_keywords = true
        when :block, :nokey
          # JSON callers do not supply Ruby blocks.
        else
          raise ParameterException, "unsupported parameter #{kind} on #{property}"
        end
      end
      if accepts_keywords
        keywords.merge!(remaining)
      elsif !remaining.empty?
        raise ParameterException, "unknown arguments for #{property}: #{remaining.keys.join(', ')}"
      end
      [positional, keywords]
    end

    def dispatch(mod, id, property, mode, positional, keywords)
      receiver = mod.setup(id)
      receiver = receiver.make_array if !receiver.is_a?(Array) && %w[array multiple].include?(mode)
      receiver.public_send(property, *positional, **keywords)
    end

    def dispatch_each(mod, entities, property, mode, positional, keywords)
      entities.map do |entity|
        begin
          value = dispatch(mod, entity, property, mode, positional, keywords)
          { entity: entity, status: :done, result: value }
        rescue StandardError => error
          { entity: entity, status: :failed, error: { class: error.class.to_s, message: error.message } }
        end
      end
    end

    class AlignmentError < StandardError; end

    def align_records(entities, res)
      case res
      when Array
        unless res.length == entities.length
          raise AlignmentError,
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
        raise AlignmentError,
              "list dispatch returned a single #{res.class}; cannot align per-entity records"
      end
    end

    def receipt(job, mod, property, arguments, **selection)
      { mechanism: 'Semantics task job',
        job: { path: job.path.to_s, short_path: job.short_path.to_s,
               task: job.task_name.to_s, workflow: job.workflow.to_s },
        dispatched: { entity_type: mod.name, property: property.to_s,
                      arguments: arguments }.merge(selection) }
    end
  end

  task :list_entities => :json do
    EntityQuery.entity_records
  end

  export_exec :list_entities
end
