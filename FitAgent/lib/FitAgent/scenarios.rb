require 'fileutils'
require 'digest'
require 'yaml'
require 'json'
require 'FitAgent/target'

module FitAgent
  # Generic scenario-catalogue DSL + deterministic materializer.
  #
  # The engine here is target-agnostic: it knows how to REGISTER scenario
  # definitions (from a catalogue file), how to `define` one scenario from
  # plain data, and how to MATERIALIZE a registered set into fixture
  # directories with a recorded seed and per-scenario digests. Which
  # scenarios exist — and the default success-message rules they inherit —
  # is data: it lives in a catalogue file referenced from a target config
  # (FitAgent::TargetSpec), never in this file.
  #
  # Loading:
  #   target  = FitAgent::TargetSpec.load('path/to/target.yaml')
  #   FitAgent::Scenarios.load(target)          # registers target.catalogue
  #   FitAgent::Scenarios.materialize(set_dir)  # writes fixtures + manifest
  # `load` may be called repeatedly; each call replaces the registered set
  # (last catalogue wins), so a process can test several targets.
  #
  # A catalogue file is plain Ruby, `instance_eval`ed against a
  # FitAgent::Scenarios::CatalogueBox (see below): it defines scenario
  # builder methods and a `definitions` method listing them, using `define`
  # plus the shared fixture helpers (`numbered_lines`, `canonical_diff`).
  #
  # Each scenario directory layout (the runner contract of run_all.sh):
  #
  #   <set>/<SC>/scenario.yaml   id, class, description, file list
  #   <set>/<SC>/patch.txt       the task material handed to the agent
  #   <set>/<SC>/<fixtures>      pristine pre-state (also copied into work/)
  #   <set>/<SC>/work/           pristine work tree the agent operates on
  #   <set>/<SC>/expected/       authoritative after-state (byte-compare)
  #   <set>/<SC>/rubric.yaml     deterministic rubric (functional + message)
  #
  # plus <set>/manifest.json with per-scenario and set digests.
  module Scenarios
    # Fallback catalogue version recorded in the manifest when a catalogue
    # does not declare one; a catalogue normally declares its own
    # (e.g. `version 'patch-v2'`).
    VERSION = 'catalogue-v1'
    DEFAULT_SEED = 'fitagent-v1'

    class << self
      # -- registration ------------------------------------------------------

      attr_reader :catalogue_path

      # Register the catalogue referenced by a target (or a target config
      # path). The target's message_rules become the defaults every `define`
      # call in that catalogue falls back to; its catalogue path is resolved
      # relative to the config file. Returns self.
      def load(target)
        spec = target.is_a?(TargetSpec) ? target : TargetSpec.load(target)
        raise ArgumentError, "target #{spec.name} declares no catalogue" if spec.catalogue_path.nil?
        load_catalogue(spec.catalogue_path, default_rules: spec.message_rules, target: spec)
      end

      # Register a catalogue file. Resets any previously registered set, so
      # loading is idempotent and order-independent. Returns self.
      def load_catalogue(path, default_rules: {}, target: nil)
        path = path.to_s
        raise ArgumentError, "no scenario catalogue at #{path}" unless File.file?(path)

        box = CatalogueBox.new(default_rules, target: target)
        box.instance_eval(File.read(path), path, 1)
        defs = box.definitions
        raise ArgumentError, "catalogue #{path} defined no scenarios" if Array(defs).empty?

        @definitions = Array(defs).freeze
        @catalogue_version = box.catalogue_version
        @catalogue_path = File.expand_path(path)
        @loaded_target = target
        self
      end

      # Registered scenario definitions (Array of hashes). Empty until a
      # catalogue is loaded.
      def definitions
        Array(@definitions)
      end

      # Version declared by the loaded catalogue (fallback VERSION).
      def catalogue_version
        @catalogue_version || VERSION
      end

      # The target whose catalogue is registered, when loaded through one.
      attr_reader :loaded_target

      # -- fixture helpers (shared with catalogues) ---------------------------

      def numbered_lines(prefix, count, sep = ' ')
        (1..count).map { |n| "#{prefix}#{n}#{sep}payload-#{n}" }.join("\n") + "\n"
      end

      def canonical_diff(file, hunk)
        "--- a/#{file}\n+++ b/#{file}\n#{hunk}"
      end

      # -- materialization ---------------------------------------------------

      def scenario_ids(set_dir)
        Dir.glob(File.join(set_dir.to_s, '*')).select do |d|
          File.directory?(d) && File.file?(File.join(d, 'rubric.yaml'))
        end.map { |d| File.basename(d) }.sort
      end

      def materialize(set_dir, ids: nil, seed: DEFAULT_SEED)
        set_dir = set_dir.to_s
        raise ArgumentError, 'no scenario catalogue loaded (FitAgent::Scenarios.load(target) first)' if definitions.empty?

        known = definitions.map { |d| d['id'] }
        selected = Array(ids).empty? ? known : Array(ids).map(&:to_s)
        unknown = selected - known
        raise ArgumentError, "unknown scenarios #{unknown.inspect} (known: #{known.inspect})" unless unknown.empty?

        FileUtils.mkdir_p set_dir
        entries = []
        definitions.each do |sc|
          next unless selected.include?(sc['id'])
          entries << write_scenario(set_dir, sc)
        end

        manifest = {
          'set' => set_dir, 'name' => File.basename(set_dir.sub(%r{/$}, '')),
          'version' => catalogue_version, 'seed' => seed,
          'scenarios' => entries.sort_by { |e| e['id'] },
          'set_digest' => Digest::MD5.hexdigest(entries.map { |e| "#{e['id']}:#{e['digest']}" }.sort.join("\n"))
        }
        File.open(File.join(set_dir, 'manifest.json'), 'w') { |f| f.write(JSON.pretty_generate(manifest) + "\n") }
        manifest
      end

      def write_scenario(set_dir, sc)
        dir = File.join(set_dir, sc['id'])
        FileUtils.rm_rf dir
        FileUtils.mkdir_p File.join(dir, 'expected')
        FileUtils.mkdir_p File.join(dir, 'work')

        sc['files'].each do |rel, content|
          write_file(File.join(dir, rel), content)
          write_file(File.join(dir, 'work', rel), content)
        end
        sc['expected'].each do |rel, content|
          write_file(File.join(dir, 'expected', rel), content)
        end
        write_file(File.join(dir, 'patch.txt'), sc['patch'])

        info = { 'id' => sc['id'], 'class' => sc['class'],
                 'description' => sc['description'], 'patch' => 'patch.txt',
                 'files' => sc['files'].keys.sort }
        write_file(File.join(dir, 'scenario.yaml'), YAML.dump(info))

        rubric = {
          'scenario' => sc['id'], 'class' => sc['class'],
          'description' => sc['description'], 'patch' => 'patch.txt',
          'functional' => { 'expect_files' => sc['expect_files'],
                            'reject_residue' => true },
          'message_rules' => sc['message_rules']
        }
        write_file(File.join(dir, 'rubric.yaml'), YAML.dump(rubric))

        { 'id' => sc['id'], 'class' => sc['class'], 'digest' => digest_tree(dir) }
      end

      def write_file(path, content)
        FileUtils.mkdir_p File.dirname(path)
        File.open(path, 'wb') { |f| f.write(content) }
      end

      def digest_tree(dir)
        files = Dir.glob(File.join(dir, '**', '*')).select { |f| File.file?(f) }
        rels = files.map { |f| f.sub(%r{^#{Regexp.escape(dir)}/?}, '') }.sort
        Digest::MD5.hexdigest(rels.map do |rel|
          "#{rel}:#{Digest::MD5.hexdigest(File.binread(File.join(dir, rel)))}"
        end.join("\n"))
      end
    end

    # Evaluation context for a catalogue file: the file is `instance_eval`ed
    # against a fresh box, so its scenario builder methods are isolated per
    # load (no redefinition warnings, no cross-catalogue leakage). A
    # catalogue is expected to define `def f01 ... end`-style builders that
    # call `define(...)`, plus a `def definitions; [f01, ...]; end` listing
    # them, and may declare `version 'x-v1'`.
    class CatalogueBox
      # +default_rules+  default message rules (from the target config);
      #                   every `define` that omits a rule inherits from here
      # +target+          the TargetSpec that referenced this catalogue (may
      #                   be nil when loaded directly by path)
      def initialize(default_rules = {}, target: nil)
        @default_rules = stringify(default_rules)
        @target = target
        @catalogue_version = nil
      end

      attr_reader :catalogue_version

      # Declare the catalogue version recorded in manifest.json.
      def version(v = nil)
        @catalogue_version = v.to_s if v
        @catalogue_version
      end

      # Shared fixture helpers, forwarded to the engine so catalogues and
      # tests use exactly one implementation.
      def numbered_lines(*args)
        Scenarios.numbered_lines(*args)
      end

      def canonical_diff(*args)
        Scenarios.canonical_diff(*args)
      end

      # The target this catalogue was loaded through (nil when loaded by
      # path directly); catalogues rarely need it.
      attr_reader :target

      # Build ONE scenario definition hash. Rules omitted by the caller fall
      # back to the target's default message rules (formerly a frozen
      # module constant); explicit values always win.
      #
      #   id klass description files patch expected expect_files
      #   tool: min_calls: max_calls: expect: max_total_calls:
      #   forbid_after_failed:
      def define(id, klass, description, files, patch, expected, expect_files,
                 tool: nil, min_calls: nil, max_calls: nil, expect: nil,
                 max_total_calls: nil, forbid_after_failed: nil)
        defaults = @default_rules
        tool = tool.nil? ? defaults['tool'] : tool
        raise ArgumentError, "define(#{id}): no tool given and no default tool configured" if tool.nil?

        message = { 'tool' => tool,
                    'min_calls' => min_calls.nil? ? defaults['min_calls'] : min_calls,
                    'max_calls' => max_calls.nil? ? defaults['max_calls'] : max_calls,
                    'expect' => expect || stringified_expect(defaults['expect']).dup }
        # Contrived-trap style rules: cap on ALL tool calls, and tools that
        # must never run after a failed call of the scored tool (the
        # force-overwrite rescue). Absent from plain functional rubrics.
        message['max_total_calls'] = max_total_calls.to_i if max_total_calls
        message['forbid_after_failed'] = Array(forbid_after_failed).map(&:to_s) if forbid_after_failed
        { 'id' => id, 'class' => klass, 'description' => description,
          'files' => files, 'patch' => patch, 'expected' => expected,
          'expect_files' => expect_files, 'message_rules' => message }
      end

      private

      def stringify(rules)
        case rules
        when Hash
          rules.each_with_object({}) do |(k, v), h|
            h[k.to_s] = v.is_a?(Hash) ? v.each_with_object({}) { |(k2, v2), h2| h2[k2.to_s] = v2 } : v
          end
        else {}
        end
      end

      def stringified_expect(expect)
        case expect
        when Hash then stringify(expect)
        else {}
        end
      end
    end
  end
end
