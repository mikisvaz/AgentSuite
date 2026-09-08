require 'yaml'
require 'fileutils'
require 'pathname'  # self-contained: absolute? uses Pathname; only transitively available otherwise

module FitAgent
  # A fitness TARGET: everything the generic harness core needs to know about
  # the workflow an agent under test operates on. The core (Runner, Evolve,
  # Scoring, Scenarios DSL, LiveAgentChat) never names a concrete target
  # workflow; a target is DATA, loaded from a config file.
  #
  # Config file (YAML by convention, `.yaml`/`.yml`):
  #
  #   name:          computeruse-patch          # required, short label
  #   workflow_dir:  ../<target>                # required, path to the target
  #                                              # workflow CHECKOUT (the dir
  #                                              # holding its workflow.rb).
  #                                              # Relative paths resolve
  #                                              # against the config file.
  #   agent:         FitMain                    # optional, agent under test
  #                                              # (Runner default), may be
  #                                              # overridden per call
  #   tools:                                      # optional, default tool
  #     - <Workflow> task                          # spec lines handed to the
  #                                              # proposer/stub as examples
  #   message_rules:                              # optional, default success
  #     tool: patch                               # message rules used by the
  #     min_calls: 1                              # Scenarios `define` DSL when
  #     max_calls: 2                              # a definition omits them
  #     expect:                                    # (replaces the old frozen
  #       applied: true                            # SUCCESS_MESSAGE_RULES
  #       exit_status: 0                           # constant)
  #       used_strip: 1
  #   catalogue:     catalogue.rb                # optional, path to a Ruby
  #                                              # scenario catalogue; relative
  #                                              # paths resolve against the
  #                                              # config file. The file is
  #                                              # `instance_eval`ed against
  #                                              # FitAgent::Scenarios, so it
  #                                              # is simply a list of
  #                                              # define(...) / f01 / e01 /
  #                                              # c01 style calls.
  #
  # String values support generic ${VAR} environment expansion; the expansion
  # is target-agnostic (any var name may appear in any config). Unknown vars
  # expand to the empty string.
  #
  # No endpoint and no model keys are ever read or accepted here: targets are
  # inference-blind by construction.
  class TargetSpec
    FIELDS = %w[name workflow_dir agent tools message_rules catalogue].freeze
    REQUIRED = %w[name workflow_dir].freeze

    attr_reader :name, :workflow_dir, :agent, :tools, :message_rules, :catalogue

    def initialize(name:, workflow_dir:, agent: nil, tools: [],
                   message_rules: {}, catalogue: nil, config_path: nil)
      raise ArgumentError, 'name must be a non-empty string' if name.to_s.strip.empty?
      raise ArgumentError, 'workflow_dir must be a non-empty string' if workflow_dir.to_s.strip.empty?

      @name = name.to_s
      @workflow_dir = workflow_dir.to_s
      @agent = agent.to_s unless agent.to_s.strip.empty?
      @agent = nil if agent.to_s.strip.empty?
      @tools = Array(tools).map(&:to_s).reject(&:empty?).freeze
      @message_rules = normalize_message_rules(message_rules)
      @catalogue = catalogue.to_s unless catalogue.to_s.strip.empty?
      @catalogue = nil if catalogue.to_s.strip.empty?
      @config_path = config_path && File.expand_path(config_path.to_s)
      freeze
    end

    # Convenience: the first tool spec line (the canonical "example" tool of
    # the target), or nil when the target declares none.
    def primary_tool
      @tools.first
    end

    # The resolved, absolute catalogue path (nil when no catalogue is
    # declared). Relative catalogue paths resolve against the config file.
    def catalogue_path
      return nil if @catalogue.nil?
      return @catalogue if absolute?(@catalogue)
      base = @config_path ? File.dirname(@config_path) : Dir.pwd
      File.expand_path(@catalogue, base)
    end

    # Resolved, absolute workflow checkout dir.
    def workflow_dir!
      return @workflow_dir if absolute?(@workflow_dir)
      base = @config_path ? File.dirname(@config_path) : Dir.pwd
      File.expand_path(@workflow_dir, base)
    end

    def to_h
      { 'name' => @name, 'workflow_dir' => @workflow_dir, 'agent' => @agent,
        'tools' => @tools.dup, 'message_rules' => deep_dup(@message_rules),
        'catalogue' => @catalogue }
    end

    # -- loading -----------------------------------------------------------

    class << self
      # Load a target config (YAML). `path` may be a directory holding
      # target.yaml / target.yml, or the config file itself.
      def load(path)
        path = path.to_s
        file = if File.directory?(path)
                 %w[target.yaml target.yml].map { |n| File.join(path, n) }
                                        .find { |p| File.file?(p) }
               else
                 File.file?(path) ? path : nil
               end
        raise ArgumentError, "no target config at #{path} (looked for target.yaml/target.yml)" if file.nil?

        raw = YAML.safe_load(File.read(file), permitted_classes: [], aliases: false)
        raise ArgumentError, "target config #{file} is empty or malformed" unless Hash === raw

        expanded = deep_expand_env(raw)
        missing = REQUIRED.map(&:to_s) - expanded.keys.map(&:to_s)
        raise ArgumentError, "target config #{file} is missing #{missing.inspect}" unless missing.empty?

        new(name: expanded['name'],
            workflow_dir: expanded['workflow_dir'],
            agent: expanded['agent'],
            tools: expanded['tools'],
            message_rules: expanded['message_rules'],
            catalogue: expanded['catalogue'],
            config_path: file)
      end

      private

      # Generic ${VAR} expansion over every String leaf of the config.
      def deep_expand_env(obj)
        case obj
        when String then obj.gsub(/\$\{([^}]+)\}/) { ENV[Regexp.last_match(1)].to_s }
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k] = deep_expand_env(v) }
        when Array then obj.map { |v| deep_expand_env(v) }
        else obj
        end
      end
    end

    private

    def absolute?(path)
      Pathname.new(path).absolute?
    end

    # Stringify keys of the message_rules so a config may use either
    # `tool:` or `'tool':` spelling and the Scenarios DSL sees plain
    # string keys (the shape rubrics materialize with).
    def normalize_message_rules(rules)
      case rules
      when Hash
        rules.each_with_object({}) do |(k, v), h|
          h[k.to_s] = v.is_a?(Hash) ? v.each_with_object({}) { |(k2, v2), h2| h2[k2.to_s] = v2 } : v
        end
      else {}
      end
    end

    def deep_dup(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array then obj.map { |v| deep_dup(v) }
      else obj
      end
    end
  end
end
