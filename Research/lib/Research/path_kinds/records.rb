# Scientific-record Path kinds for the scout-ai agent path engine: the
# shared record engine (schemas, validation, register/edit/list/validate).
#
# Step 3 of the planned build; the authoritative contract is
# research/path-kinds-spec.md (verbatim specification + step-1 decisions +
# step-2 verdicts).  This module implements it for the three kinds
# `observation`, `claim` and `hypothesis`; lib/Research/path_kinds.rb
# aggregates the kind definitions into Research::PATH_KINDS, which the
# engine consumes on whole-workflow incorporation (`tool: Research`).
#
# Storage layout (one authoritative root per kind, no promote, no second
# location):
#
#   <base>/var/records/<kind>/<ID>.yaml          record body (YAML)
#   <base>/var/records/<kind>/<ID>.info.json     sidecar (JSON: version,
#                                                created_at, updated_at, job)
#   <base>/var/records/<kind>/history/<ID>.v<N>.yaml   prior bodies
#   <base>/var/records/<kind>/counter            ID counter (plain integer)
#   <base>/var/records/<kind>/register.lock      counter allocation lock
#   <base>/var/records/<kind>/edit-<ID>.lock     per-record edit lock
#
# Identifiers: OBS-NNN / C-NNN / H-NNN, zero-padded to width 3 (growing
# naturally past 999), allocated inside Open.lock by the shared `register`
# custom operation.  Agents never allocate IDs; the `path` argument of the
# register tool is required by the engine but ignored by the operation.
#
# Concurrency/history: Open.sensible_write + Open.lock (step-2 verdict d);
# the .info sidecar + history/ snapshots + the version line in the record
# body implement optimistic concurrency (step-2 verdict e: no generic
# helper exists, this is the justified in-kind addition).  The expected
# version is carried by the `version:` line of the record body the caller
# must have read: a whole-file edit whose body declares a version older
# than the sidecar fails cleanly as stale.

require 'scout'
require 'yaml'
require 'json'
require 'time'
require 'fileutils'

module Research
  module PathKinds
    # Checkout root anchored structurally: this file lives at
    # <checkout>/lib/Research/path_kinds/records.rb.
    PATH_KIND_ROOT = Scout.root.find(:current)

    VERSION_WIDTH = 3

    # Per-kind schema: ID prefix, initial (system-set) status, allowed
    # top-level fields (strict; anything else is an unknown-key error),
    # status vocabulary and the status-transition graph (same-status edits
    # are always allowed; missing from the graph means terminal).
    KIND_SPECS = {
      'observation' => {
        'prefix' => 'OBS',
        'initial' => 'current',
        'fields' => %w[version statement title scope status sources value
                       links limitations],
        'statuses' => %w[current invalidated superseded],
        'transitions' => {
          'current' => %w[invalidated superseded],
          'invalidated' => [],
          'superseded' => []
        }
      },
      'claim' => {
        'prefix' => 'C',
        'initial' => 'proposed',
        'fields' => %w[version statement title scope status links
                       limitations assessment],
        'statuses' => %w[proposed supported qualified weakened rejected
                         superseded],
        'transitions' => {
          'proposed' => %w[supported qualified weakened rejected superseded],
          'supported' => %w[qualified weakened rejected superseded],
          'qualified' => %w[supported weakened rejected superseded],
          'weakened' => %w[supported qualified rejected superseded],
          'rejected' => %w[superseded],
          'superseded' => []
        }
      },
      'hypothesis' => {
        'prefix' => 'H',
        'initial' => 'proposed',
        'fields' => %w[version statement title scope status links
                       limitations assessment predictions test_ideas],
        'statuses' => %w[proposed under_test consistent_with_evidence
                         weakened rejected unresolved superseded],
        'transitions' => {
          'proposed' => %w[under_test consistent_with_evidence weakened
                           rejected unresolved superseded],
          'under_test' => %w[consistent_with_evidence weakened rejected
                             unresolved superseded],
          'consistent_with_evidence' => %w[weakened rejected unresolved
                                           superseded],
          'weakened' => %w[rejected unresolved superseded],
          'unresolved' => %w[under_test rejected superseded],
          'rejected' => %w[superseded],
          'superseded' => []
        }
      }
    }.freeze

    # Controlled relationship vocabulary with allowed source -> target
    # kinds, exactly as the spec tabulates for Claim (section 4) and
    # Hypothesis (section 5).  The spec gives no table for Observation;
    # the symmetric minimal set chosen for it is reported as a decision.
    RELATIONSHIPS = {
      'observation' => {
        'supported_by' => %w[observation],
        'contradicted_by' => %w[observation],
        'qualified_by' => %w[observation],
        'supersedes' => %w[observation],
        'related_to' => %w[observation claim hypothesis]
      },
      'claim' => {
        'supported_by' => %w[observation claim],
        'contradicted_by' => %w[observation claim],
        'qualified_by' => %w[observation claim],
        'supersedes' => %w[claim],
        'related_to' => %w[claim]
      },
      'hypothesis' => {
        'motivated_by' => %w[observation claim],
        'explains' => %w[observation claim],
        'supported_by' => %w[observation claim],
        'contradicted_by' => %w[observation claim],
        'supersedes' => %w[hypothesis],
        'related_to' => %w[observation claim hypothesis]
      }
    }.freeze

    ID_PATTERN = /\A(OBS|C|H)-\d{3,}\z/
    PREFIX_KINDS = { 'OBS' => 'observation', 'C' => 'claim',
                     'H' => 'hypothesis' }.freeze
    SOURCE_KEYS = %w[type ref locator digest].freeze
    LINK_KEYS = %w[type target note].freeze
    LOCAL_SOURCE_TYPES = %w[entity_property task workflow file].freeze
    EVIDENCE_RELATIONSHIPS = %w[supported_by qualified_by motivated_by
                                explains].freeze
    STALE_STATUSES = {
      'observation' => %w[invalidated superseded],
      'claim' => %w[superseded],
      'hypothesis' => %w[superseded]
    }.freeze
    FIELD_ORDER = %w[version statement title scope status sources value
                     links limitations assessment predictions test_ideas].freeze
    REGISTER_INPUT_FIELDS = %w[statement title scope sources links value
                               limitations predictions test_ideas
                               assessment].freeze

    # One shared parameter contract and one shared description for the
    # `register` operation on all three kinds (step-2 verdict c: identical
    # parameter schemas install ONE tool; the description must also be
    # identical because the last registration wins for the tool text).
    REGISTER_PARAMETERS = {
      'type' => 'object',
      'properties' => {
        'statement' => {
          'type' => 'string',
          'description' => 'Required: concise statement of the finding, '\
                           'proposition, or hypothesis.'
        },
        'title' => {
          'type' => 'string',
          'description' => 'Optional human-readable title.'
        },
        'scope' => {
          'type' => 'object',
          'description' => 'Optional conditions the statement applies to; '\
                           'free keys, scalar or list-of-scalar values.',
          'additionalProperties' => true
        },
        'sources' => {
          'type' => 'array',
          'description' => 'Evidence references (required for observation).',
          'items' => {
            'type' => 'object',
            'properties' => {
              'type' => {
                'type' => 'string',
                'description' => 'Source kind: entity_property, task, '\
                                 'workflow, file, external (vocabulary is '\
                                 'extensible).'
              },
              'ref' => {
                'type' => 'string',
                'description' => 'Canonical reference to the evidence '\
                                 'artifact or execution record.'
              },
              'locator' => {
                'type' => 'string',
                'description' => 'Optional: the relevant part of the artifact.'
              },
              'digest' => {
                'type' => 'string',
                'description' => 'Optional: content identity digest.'
              }
            },
            'required' => %w[type ref],
            'additionalProperties' => false
          }
        },
        'links' => {
          'type' => 'array',
          'description' => 'Typed relationships to other records.',
          'items' => {
            'type' => 'object',
            'properties' => {
              'type' => {
                'type' => 'string',
                'description' => 'Relationship: supported_by, '\
                                 'contradicted_by, qualified_by, '\
                                 'motivated_by, explains, supersedes, '\
                                 'related_to (validity depends on the '\
                                 'source and target kinds).'
              },
              'target' => {
                'type' => 'string',
                'description' => 'Target record id (OBS-NNN, C-NNN, H-NNN).'
              },
              'note' => {
                'type' => 'string',
                'description' => 'Optional clarification.'
              }
            },
            'required' => %w[type target],
            'additionalProperties' => false
          }
        },
        'value' => {
          'type' => 'object',
          'description' => 'Optional compact machine-readable value '\
                           '(observation only).',
          'additionalProperties' => true
        },
        'limitations' => {
          'type' => 'array',
          'items' => { 'type' => 'string' },
          'description' => 'Optional relevant qualifications.'
        },
        'predictions' => {
          'type' => 'array',
          'items' => { 'type' => 'string' },
          'description' => 'Optional expected findings (hypothesis only).'
        },
        'test_ideas' => {
          'type' => 'array',
          'items' => { 'type' => 'string' },
          'description' => 'Optional proposed tests (hypothesis only).'
        },
        'assessment' => {
          'type' => 'string',
          'description' => 'Optional evidential assessment (claim and '\
                           'hypothesis only).'
        }
      },
      'required' => %w[statement],
      'additionalProperties' => false
    }.freeze

    REGISTER_DESCRIPTION =
      'Register a new scientific record of the selected kind and allocate '\
      'its system identifier atomically (observation -> OBS-NNN, claim -> '\
      'C-NNN, hypothesis -> H-NNN); identifiers are never allocated '\
      'manually. The path argument is required by the tool interface but '\
      'is IGNORED by register (pass "."). status is system-set to the '\
      "kind's initial state (observation: current, claim: proposed, "\
      'hypothesis: proposed) and cannot be supplied. The complete record '\
      'is validated before it is written: fields the kind does not define '\
      '(for example value on a claim, or predictions on an observation) '\
      'are rejected as unknown keys, links must use a relationship valid '\
      'for the source and target kinds and must resolve to existing '\
      'records, and local artifact references must exist. Non-blocking '\
      'warnings are returned in the result.'

    class << self
      # --------------------------------------------------------------
      # Definition assembly
      # --------------------------------------------------------------

      def kind_roots(base_dir)
        KIND_SPECS.keys.each_with_object({}) do |kind, hash|
          hash[kind] = File.join(base_dir.to_s, 'var', 'records', kind)
        end
      end

      def definitions(base_dir: PATH_KIND_ROOT)
        roots = kind_roots(base_dir)
        KIND_SPECS.keys.each_with_object({}) do |kind, hash|
          hash[kind] = definition(kind, roots)
        end
      end

      def definition(kind, roots)
        spec = KIND_SPECS.fetch(kind)
        root = roots.fetch(kind)

        {
          'description' =>
            "Scientific #{kind} records: #{kind_description(kind)}. " \
            "Versioned YAML bodies under #{root} with system identifiers " \
            "#{spec['prefix']}-NNN allocated by the register operation. " \
            'Records are created only through register and modified only ' \
            'through edit (a whole-record rewrite whose body carries the ' \
            'current version line); prior versions are snapshotted under ' \
            'history/. read/list/validate are always available; manual ' \
            'write/move/rename/delete are disabled so the record identity ' \
            'and history stay reliable.',

          'extension' => 'yaml',
          'locations' => ['project'],
          'default_location' => 'project',
          'roots' => { 'project' => root },

          # Step-2 verdict b: records are born only through register and
          # mutate only through edit, so write/move/rename/delete are OFF
          # and read/edit/list/validate are ON.
          'capabilities' => {
            'read' => true, 'write' => false, 'edit' => true,
            'list' => true, 'move' => false, 'rename' => false,
            'delete' => false, 'validate' => true
          },

          'validate' => lambda do |agent, path, location, args|
            Research::PathKinds.validate_path(kind, roots, path)
          end,

          'list' => lambda do |agent, prefix, _location|
            Research::PathKinds.list_records(kind, roots, prefix.to_s)
          end,

          'operations' => {
            'register' => {
              'description' => REGISTER_DESCRIPTION,
              'parameters' => REGISTER_PARAMETERS,
              'implementation' => lambda do |agent, _target, args|
                Research::PathKinds.register_record(kind, roots, args)
              end,
              'authorization' => :write,
              'type' => :full
            }
          },

          'overrides' => {
            'edit' => {
              'type' => :full,
              'implementation' => lambda do |agent, target, args|
                Research::PathKinds.edit_record(kind, roots, target, args,
                                                agent)
              end
            }
          }
        }
      end

      def kind_description(kind)
        case kind
        when 'observation'
          'specific findings derived from identifiable sources'
        when 'claim'
          'propositions assessed against evidence'
        when 'hypothesis'
          'proposed explanations retaining predictions and evidential status'
        else
          kind
        end
      end

      # --------------------------------------------------------------
      # register
      # --------------------------------------------------------------

      def register_record(kind, roots, args, agent: nil)
        spec = KIND_SPECS.fetch(kind)
        root = roots.fetch(kind)

        # The engine hands the implementation the whole dispatch args hash,
        # so kind/path/location ride along; unwrap a nested payload if the
        # caller used one, then reject unknown INPUT fields with an
        # actionable message (system-managed fields included).
        args = args['args'] if args.key?('args') && Hash === args['args']
        supplied = args.keys.map(&:to_s) - %w[kind path location]
        reserved = supplied - REGISTER_INPUT_FIELDS
        unless reserved.empty?
          raise ParameterException,
                "register rejected for #{kind}: unknown input field(s) " \
                "#{reserved.sort.join(', ')}; accepted fields are " \
                "#{REGISTER_INPUT_FIELDS.join(', ')}; version and status " \
                'are system-managed and cannot be supplied'
        end

        record = { 'version' => 1, 'status' => spec['initial'] }
        REGISTER_INPUT_FIELDS.each do |field|
          record[field] = args[field] unless args[field].nil?
        end

        errors, warnings = validate_record(kind, record, roots: roots)
        unless errors.empty?
          raise ParameterException,
                "register rejected for #{kind}: #{errors.join('; ')}"
        end

        FileUtils.mkdir_p(root)
        FileUtils.mkdir_p(File.join(root, 'history'))

        id = file = nil
        Open.lock(File.join(root, 'register.lock')) do
          counter = File.join(root, 'counter')
          next_number = (File.file?(counter) ? File.read(counter).strip.to_i : 0) + 1
          id = "#{spec['prefix']}-#{format("%0#{VERSION_WIDTH}d", next_number)}"
          file = File.join(root, "#{id}.yaml")
          if File.exist?(file)
            raise ParameterException,
                  "duplicate identifier #{id}: a record already exists at #{file}"
          end
          Open.sensible_write(counter, next_number.to_s, force: true)
          # No :force here: sensible_write refuses to clobber, and the
          # existence check above already ran under the allocation lock.
          Open.sensible_write(file, serialize(kind, record))
        end

        write_sidecar(root, id, version: 1, job: ENV['SCOUT_JOB'])

        { 'kind' => kind, 'id' => id, 'path' => id, 'version' => 1,
          'status' => record['status'], 'file' => file,
          'warnings' => warnings }
      end

      # --------------------------------------------------------------
      # edit (the :full override of the built-in edit)
      # --------------------------------------------------------------

      def edit_record(kind, roots, target, args, agent)
        spec = KIND_SPECS.fetch(kind)
        root = roots.fetch(kind)
        file = target.to_s
        id = File.basename(file, '.yaml')

        unless File.file?(file)
          raise ParameterException, "record not found for edit: #{file}"
        end
        unless agent.respond_to?(:path_apply_selector)
          raise ParameterException,
                'edit requires the engine selector implementation'
        end

        Open.lock(File.join(root, "edit-#{id}.lock")) do
          current_text = File.read(file)
          current = parse_record(current_text)
          sidecar = load_sidecar(root, id) || {}
          current_version = current['version']
          sidecar_version = sidecar['version']

          unless Integer === current_version && current_version == sidecar_version
            raise ParameterException,
                  "record #{id} is inconsistent: body version " \
                  "#{current_version.inspect} vs sidecar version " \
                  "#{sidecar_version.inspect}; re-read the record and " \
                  'repair it with a whole-file edit'
          end

          candidate_text = agent.path_apply_selector(current_text,
                                                     args['selector'],
                                                     args['replacement'])
          candidate = parse_record(candidate_text)
          declared = candidate['version']
          unless Integer === declared
            raise ParameterException,
                  "edited record #{id} is missing the system 'version' " \
                  "field: include the current version line " \
                  "(version: #{current_version}) from the record you read"
          end
          unless declared == current_version
            raise ParameterException,
                  "stale edit of #{id}: the record is at version " \
                  "#{current_version} but the edited body declares version " \
                  "#{declared}; re-read the current record and re-apply " \
                  'your changes against it'
          end

          from_status = current['status']
          to_status = candidate['status']
          if to_status != from_status
            allowed = spec['transitions'].fetch(from_status, [])
            unless allowed.include?(to_status)
              raise ParameterException,
                    "invalid status transition for #{kind} #{id}: " \
                    "#{from_status.inspect} -> #{to_status.inspect} " \
                    "(allowed from #{from_status.inspect}: " \
                    "#{allowed.join(', ')}; same-status edits are always allowed)"
            end
          end

          errors, warnings = validate_record(kind, candidate, roots: roots)
          unless errors.empty?
            raise ParameterException,
                  "edit rejected for #{id}: #{errors.join('; ')}"
          end

          if candidate_text == current_text
            return { 'id' => id, 'version' => current_version,
                     'status' => from_status, 'changed' => false,
                     'warnings' => warnings }
          end

          snapshot = File.join(root, 'history',
                               "#{id}.v#{current_version}.yaml")
          FileUtils.mkdir_p(File.dirname(snapshot))
          Open.sensible_write(snapshot, current_text)

          candidate['version'] = current_version + 1
          Open.sensible_write(file, serialize(kind, candidate), force: true)
          write_sidecar(root, id, version: current_version + 1,
                                     created_at: sidecar['created_at'],
                                     job: ENV['SCOUT_JOB'])

          { 'id' => id, 'previous_version' => current_version,
            'version' => current_version + 1,
            'status' => candidate['status'], 'snapshot' => snapshot,
            'changed' => true, 'warnings' => warnings }
        end
      end

      # --------------------------------------------------------------
      # validate hook
      # --------------------------------------------------------------

      def validate_path(kind, roots, path)
        spec = KIND_SPECS.fetch(kind)
        root = roots.fetch(kind)
        id = path.to_s
        result = { 'kind' => kind, 'path' => id, 'op' => 'validate' }

        unless id =~ /\A#{spec['prefix']}-\d{3,}\z/
          return result.merge('ok' => false,
                              'reasons' => [
                                "#{id.inspect} is not a valid #{kind} " \
                                "identifier (expected #{spec['prefix']}-NNN)"
                              ])
        end

        file = File.join(root, "#{id}.yaml")
        unless File.file?(file)
          return result.merge('ok' => false,
                              'reasons' => [
                                "no such #{kind} record: #{id} " \
                                "(#{file} not found)"
                              ])
        end

        begin
          record = parse_record(File.read(file))
        rescue ParameterException => e
          return result.merge('ok' => false, 'reasons' => [e.message])
        end

        errors, warnings = validate_record(kind, record, roots: roots)
        sidecar = load_sidecar(root, id) || {}
        if Integer === record['version'] && record['version'] != sidecar['version']
          errors << "body version #{record['version'].inspect} does not " \
                    "match sidecar version #{sidecar['version'].inspect}"
        end

        result.merge('ok' => errors.empty?, 'id' => id,
                     'version' => record['version'],
                     'status' => record['status'],
                     'reasons' => errors, 'warnings' => warnings,
                     'links' => resolved_links(record, roots),
                     'backlinks' => backlinks(id, roots))
      end

      # --------------------------------------------------------------
      # list hook
      # --------------------------------------------------------------

      def list_records(kind, roots, prefix = '')
        spec = KIND_SPECS.fetch(kind)
        root = roots.fetch(kind)
        pattern = /\A#{spec['prefix']}-\d{3,}\z/

        ids = Dir.glob(File.join(root, '*.yaml'))
                 .map { |file| File.basename(file, '.yaml') }
                 .select { |id| id =~ pattern && id.start_with?(prefix.to_s) }
                 .sort

        records = ids.map do |id|
          begin
            record = parse_record(File.read(File.join(root, "#{id}.yaml")))
            sidecar = load_sidecar(root, id) || {}
            { 'id' => id, 'status' => record['status'],
              'version' => record['version'], 'title' => record['title'],
              'statement' => record['statement'].to_s[0, 120],
              'updated_at' => sidecar['updated_at'] }
          rescue ParameterException => e
            { 'id' => id, 'error' => e.message }
          end
        end

        { 'kind' => kind, 'count' => records.length, 'records' => records }
      end

      # --------------------------------------------------------------
      # Record validation (spec section 7)
      # --------------------------------------------------------------

      def validate_record(kind, record, roots:)
        spec = KIND_SPECS.fetch(kind)
        errors = []
        warnings = []

        allowed = spec['fields']
        unknown = record.keys - allowed
        unless unknown.empty?
          errors << "unknown top-level field(s): #{unknown.sort.join(', ')} " \
                    "(allowed for #{kind}: #{allowed.join(', ')})"
        end

        unless Integer === record['version']
          errors << "field 'version' must be the Integer system field " \
                    "(got #{record['version'].inspect})"
        end

        statement = record['statement']
        if statement.nil?
          errors << "missing required field 'statement'"
        elsif !(String === statement) || statement.strip.empty?
          errors << "field 'statement' must be a non-empty String"
        end

        if record.key?('title') && !(String === record['title'])
          errors << "field 'title' must be a String"
        end

        if record.key?('scope')
          scope = record['scope']
          if !(Hash === scope)
            errors << "field 'scope' must be a mapping of keys to scalars " \
                      'or lists of scalars'
          else
            scope.each do |key, value|
              unless scalar?(value) ||
                     (Array === value && value.all? { |v| scalar?(v) })
                errors << "scope[#{key.inspect}] must be a scalar or a " \
                          "list of scalars (got #{value.class})"
              end
            end
          end
        end

        status = record['status']
        unless spec['statuses'].include?(status)
          errors << "invalid status #{status.inspect} for #{kind} " \
                    "(allowed: #{spec['statuses'].join(', ')})"
        end

        validate_sources(kind, record, errors, warnings)
        validate_links(kind, record, roots, errors, warnings)

        %w[limitations predictions test_ideas].each do |field|
          next unless record.key?(field)
          value = record[field]
          if !(Array === value) || value.any? { |item| !(String === item) || item.strip.empty? }
            errors << "field '#{field}' must be a list of non-empty Strings"
          elsif field == 'predictions' && value.empty?
            warnings << 'exploratory hypothesis: no predictions recorded yet'
          end
        end
        if kind == 'hypothesis' && !record.key?('predictions')
          warnings << 'exploratory hypothesis: no predictions recorded yet'
        end

        if record.key?('assessment') && !(String === record['assessment'])
          errors << "field 'assessment' must be a String"
        end
        if record.key?('value') && !(Hash === record['value'])
          errors << "field 'value' must be a mapping (compact structured value)"
        end

        if kind == 'observation' && status == 'current'
          sources = record['sources']
          if !(Array === sources) || sources.empty?
            errors << "observation cannot be 'current' without at least " \
                      'one source (unreferenced exploratory findings ' \
                      'belong in working notes, not in the record store)'
          end
        end

        if kind == 'claim'
          links = record['links'] || []
          challenged = links.any? do |link|
            Hash === link && %w[contradicted_by qualified_by].include?(link['type'])
          end
          unless challenged
            warnings << "claim has not considered counterevidence (no " \
                        "contradicted_by or qualified_by links; status " \
                        "#{status.inspect})"
          end
        end

        [errors, warnings]
      end

      def validate_sources(kind, record, errors, warnings)
        return unless record.key?('sources')
        sources = record['sources']
        return errors << "field 'sources' must be a list of source entries" unless Array === sources

        sources.each_with_index do |source, index|
          label = "sources[#{index}]"
          unless Hash === source
            errors << "#{label} must be a mapping"
            next
          end
          extra = source.keys - SOURCE_KEYS
          unless extra.empty?
            errors << "#{label}: unknown key(s) #{extra.join(', ')} " \
                      "(allowed: #{SOURCE_KEYS.join(', ')})"
          end
          %w[type ref].each do |required|
            value = source[required]
            errors << "#{label}: missing required key '#{required}'" unless source.key?(required)
            if source.key?(required) && (!(String === value) || value.strip.empty?)
              errors << "#{label}: '#{required}' must be a non-empty String"
            end
          end
          %w[locator digest].each do |optional|
            if source.key?(optional) && !(String === source[optional])
              errors << "#{label}: '#{optional}' must be a String"
            end
          end

          next unless String === source['type'] &&
                      String === source['ref'] && !source['ref'].strip.empty?

          case source['type']
          when 'external'
            warnings << "#{label}: external source reachability not verified " \
                        '(no network check performed)'
          when *LOCAL_SOURCE_TYPES
            resolved = resolve_local_ref(source['ref'])
            if resolved.nil?
              errors << "#{label}: broken reference: #{source['ref'].inspect} " \
                        'does not exist (local artifact references resolve ' \
                        "against the Research checkout #{PATH_KIND_ROOT})"
            else
              if source['digest'].nil? || source['digest'].to_s.strip.empty?
                warnings << "#{label}: mutable source has no recorded digest; " \
                            'content identity not pinned'
              end
              if %w[task workflow entity_property].include?(source['type']) &&
                 source['digest'].nil? && source['locator'].nil?
                warnings << "#{label}: #{source['type']} source has no locator " \
                            'or digest; the derivation may not be ' \
                            're-executable from this reference'
              end
            end
          else
            warnings << "#{label}: source type #{source['type'].inspect} is " \
                        'not in the built-in vocabulary ' \
                        "(#{(LOCAL_SOURCE_TYPES + ['external']).join(', ')}); " \
                        'treated as opaque and not existence-checked'
          end
        end
      end

      def validate_links(kind, record, roots, errors, warnings)
        return unless record.key?('links')
        links = record['links']
        return errors << "field 'links' must be a list of link entries" unless Array === links

        relationships = RELATIONSHIPS.fetch(kind)
        seen = {}
        links.each_with_index do |link, index|
          label = "links[#{index}]"
          unless Hash === link
            errors << "#{label} must be a mapping"
            next
          end
          extra = link.keys - LINK_KEYS
          unless extra.empty?
            errors << "#{label}: unknown key(s) #{extra.join(', ')} " \
                      "(allowed: #{LINK_KEYS.join(', ')})"
          end
          relationship = link['type']
          unless relationships.key?(relationship)
            errors << "#{label}: relationship #{relationship.inspect} is not " \
                      "valid from a #{kind} (valid: " \
                      "#{relationships.keys.join(', ')})"
            next
          end
          target = link['target']
          match = String === target ? ID_PATTERN.match(target) : nil
          unless match
            errors << "#{label}: target #{target.inspect} is not a record " \
                      'identifier (expected OBS-NNN, C-NNN or H-NNN)'
            next
          end
          target_kind = PREFIX_KINDS.fetch(match[1])
          unless relationships[relationship].include?(target_kind)
            errors << "#{label}: relationship #{relationship.inspect} from " \
                      "a #{kind} cannot target a #{target_kind} (allowed " \
                      "target kinds: #{relationships[relationship].join(', ')})"
            next
          end
          key = [relationship, target]
          if seen.key?(key)
            errors << "#{label}: duplicate link entry #{relationship} -> " \
                      "#{target} (already at links[#{seen[key]}])"
          else
            seen[key] = index
          end
          if link.key?('note') && !(String === link['note'])
            errors << "#{label}: 'note' must be a String"
          end

          target_record, target_error = load_target_record(roots, target_kind, target)
          if target_record.nil?
            if target_error
              errors << "#{label}: broken reference: target #{target} exists " \
                        "but is unparseable (#{target_error})"
            else
              errors << "#{label}: broken reference: target record #{target} " \
                        "does not exist under the #{target_kind} kind"
            end
          elsif EVIDENCE_RELATIONSHIPS.include?(relationship) &&
                STALE_STATUSES.fetch(target_kind, []).include?(target_record['status'])
            warnings << "#{label}: evidence #{target} is " \
                        "#{target_record['status']}"
          end
        end
      end

      # --------------------------------------------------------------
      # Derived reference information (never stored)
      # --------------------------------------------------------------

      def resolved_links(record, roots)
        links = record['links']
        return [] unless Array === links
        links.map do |link|
          next nil unless Hash === link
          target = link['target']
          match = String === target ? ID_PATTERN.match(target) : nil
          target_kind = match && PREFIX_KINDS[match[1]]
          target_record = target_kind &&
                          load_target_record(roots, target_kind, target).first
          { 'type' => link['type'], 'target' => target,
            'target_kind' => target_kind,
            'resolved' => !target_record.nil?,
            'target_status' => target_record && target_record['status'] }
        end.compact
      end

      def backlinks(id, roots)
        found = []
        roots.each_pair do |source_kind, root|
          Dir.glob(File.join(root.to_s, '*.yaml')).each do |file|
            source_id = File.basename(file, '.yaml')
            begin
              record = parse_record(File.read(file))
            rescue ParameterException
              next
            end
            Array(record['links']).each do |link|
              next unless Hash === link && link['target'] == id
              found << { 'source' => source_id, 'source_kind' => source_kind,
                         'type' => link['type'] }
            end
          end
        end
        found
      end

      # --------------------------------------------------------------
      # Serialization and sidecars
      # --------------------------------------------------------------

      def serialize(kind, record)
        spec = KIND_SPECS.fetch(kind)
        ordered = {}
        (FIELD_ORDER & spec['fields']).each do |field|
          ordered[field] = record[field] if record.key?(field)
        end
        (record.keys - ordered.keys).each do |field|
          ordered[field] = record[field]
        end
        YAML.dump(ordered)
      end

      def parse_record(text)
        parsed =
          begin
            YAML.safe_load(text, permitted_classes: [], aliases: false)
          rescue Psych::SyntaxError => e
            raise ParameterException, "record is not valid YAML: #{e.message}"
          end
        raise ParameterException, 'record must be a YAML mapping' unless Hash === parsed
        parsed
      end

      def sidecar_path(root, id)
        File.join(root.to_s, "#{id}.info.json")
      end

      def load_sidecar(root, id)
        path = sidecar_path(root, id)
        return nil unless File.file?(path)
        JSON.parse(File.read(path))
      end

      def write_sidecar(root, id, version:, created_at: nil, job: nil)
        now = Time.now.utc.iso8601
        data = { 'version' => version, 'created_at' => created_at || now,
                 'updated_at' => now }
        data['job'] = job if job && !job.to_s.empty?
        Open.sensible_write(sidecar_path(root, id),
                            JSON.pretty_generate(data), force: true)
        data
      end

      # --------------------------------------------------------------
      # Helpers
      # --------------------------------------------------------------

      def load_target_record(roots, target_kind, target)
        file = File.join(roots.fetch(target_kind), "#{target}.yaml")
        return [nil, nil] unless File.file?(file)
        [parse_record(File.read(file)), nil]
      rescue ParameterException => e
        [nil, e.message]
      end

      def resolve_local_ref(ref)
        expanded = File.expand_path(ref)
        return expanded if File.exist?(expanded)
        anchored = File.expand_path(ref, PATH_KIND_ROOT)
        return anchored if File.exist?(anchored)
        nil
      end

      def scalar?(value)
        String === value || Integer === value || Float === value ||
          value == true || value == false
      end
    end
  end
end
