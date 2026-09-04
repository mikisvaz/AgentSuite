require 'scout-ai'
require 'fileutils'
require 'json'

module FitAgent
  # Deterministic scorer for FitAgent scenario runs (research/04, research/08;
  # rubric expectations frozen in verifications/patch-probe-matrix-v1.md).
  #
  # Pure Ruby over recorded evidence only:
  #   - the run transcript (sandbox/main.chat) parsed with Chat.tool_calls /
  #     Chat.tool_call_status, and the tool-call JSON payload itself for the
  #     exit_status / applied / used_strip / error fields;
  #   - the work tree the agent actually produced;
  #   - the expected/ fixtures of the scenario.
  #
  # No model calls anywhere.
  module Scoring
    RESIDUE_GLOBS = ['*.orig', '*.rej'].freeze

    class << self
      # Score one scenario run.
      #
      #   work_dir   directory the agent patched (scenario <id>/work)
      #   rubric     parsed rubric.yaml of the scenario
      #   chat_file  path to the run transcript (sandbox/main.chat)
      #   evidence   optional extra evidence hash (e.g. { 'use_case_job' => ... })
      #
      # Returns a hash: scenario, verdict (PASS/FAIL), score (0.0 or 1.0),
      # functional:{...}, message:{...}, failures:[...], evidence:{...}.
      def score_scenario(work_dir, rubric, chat_file, evidence = {})
        work_dir = work_dir.to_s
        chat_file = chat_file.to_s
        failures = []

        functional = score_functional(work_dir, rubric['functional'] || {}, failures)
        message = score_message(chat_file, rubric['message_rules'] || {}, failures)

        {
          'scenario' => rubric['scenario'],
          'verdict' => failures.empty? ? 'PASS' : 'FAIL',
          'score' => failures.empty? ? 1.0 : 0.0,
          'functional' => functional,
          'message' => message,
          'failures' => failures,
          'evidence' => { 'chat' => chat_file, 'work_dir' => work_dir }.merge(evidence || {})
        }
      end

      # -- functional tier ---------------------------------------------------

      def score_functional(work_dir, func, failures)
        expect_files = func['expect_files'] || {}
        file_results = {}
        expect_files.each do |rel, mode|
          path = File.join(work_dir, rel)
          mode = mode.to_s
          case mode
          when 'match'
            ok = File.file?(path) && File.binread(path) == expected_bytes(work_dir, rel)
            file_results[rel] = { 'mode' => mode, 'ok' => ok }
          when 'absent'
            ok = !File.exist?(path)
            file_results[rel] = { 'mode' => mode, 'ok' => ok }
          else
            file_results[rel] = { 'mode' => mode, 'ok' => false }
          end
          failures << "functional:#{rel}:#{mode}:mismatch" unless ok
        end

        residue = []
        if func['reject_residue']
          residue = collect_residue(work_dir)
          residue.each { |r| failures << "functional:residue:#{r}" }
        end

        { 'files' => file_results, 'residue' => residue }
      end

      # expected/ sits as a sibling of work/ in the canonical scenario layout
      def expected_bytes(work_dir, rel)
        cand = File.join(work_dir.sub(%r{/work/?$}, ''), 'expected', rel)
        File.binread(cand)
      end

      def collect_residue(work_dir)
        out = []
        RESIDUE_GLOBS.each do |glob|
          Dir.glob(File.join(work_dir, '**', glob)).each do |f|
            out << f.sub(%r{^#{Regexp.escape(work_dir)}/?}, '')
          end
        end
        out.sort
      end

      # -- message tier ------------------------------------------------------

      # Extract tool calls with their parsed payloads from a transcript.
      def tool_calls(chat_file)
        return [] unless File.file?(chat_file.to_s)
        chat = Chat.load(chat_file)
        Chat.tool_calls(chat).collect do |call|
          info = IndiferentHash.setup(call.dup)
          payload = parse_payload(info[:output])
          { 'tool' => info[:name].to_s,
            'arguments' => info[:arguments],
            'status' => symbolized(info[:status]) || payload_status(payload),
            'payload' => payload }
        end
      end

      def parse_payload(output)
        return IndiferentHash.setup({}) unless String === output
        begin
          parsed = JSON.parse(output)
          return IndiferentHash.setup({}) unless Hash === parsed
          IndiferentHash.setup(parsed)
        rescue JSON::ParserError
          IndiferentHash.setup('content' => output)
        end
      end

      def payload_status(payload)
        return {} unless payload.respond_to?(:[])
        return { 'success' => false } if payload[:exception]
        return {} unless payload.key?(:exit_status)
        { 'success' => payload[:exit_status].to_i == 0 }
      end

      def symbolized(status)
        return unless status.respond_to?(:[])
        { 'success' => !!status[:success], 'exit_status' => status[:exit_status]&.to_i }.compact
      end

      def score_message(chat_file, rules, failures)
        calls = tool_calls(chat_file)
        tool = rules['tool'].to_s
        mine = calls.select { |c| c['tool'] == tool }

        by_tool = Hash.new(0)
        calls.each { |c| by_tool[c['tool']] += 1 }

        min_calls = rules['min_calls'].to_i
        max_calls = rules['max_calls'].to_i
        count_ok = mine.length >= min_calls && mine.length <= max_calls
        failures << "message:#{tool}:count:#{mine.length}:#{min_calls}..#{max_calls}" unless count_ok

        text_ok = nil
        needles = nil
        if (rules['expect'] || {}).key?('output_contains')
          needles = Array(rules['expect']['output_contains'])
          text_ok = check_output_contains(mine, needles)
          failures << "message:#{tool}:output_contains:missing" unless text_ok
        end

        expect_results = {}
        (rules['expect'] || {}).each do |key, want|
          next if key.to_s == 'output_contains'
          got = extract_expectation(mine, key)
          expect_results[key] = { 'want' => want, 'got' => got,
                                  'ok' => expectation_ok?(want, got) }
          failures << "message:#{tool}:#{key}:want=#{want}:got=#{got.inspect}" unless expect_results[key]['ok']
        end

        { 'total_calls' => calls.length, 'by_tool' => by_tool,
          'tool' => tool, 'count' => mine.length, 'count_ok' => count_ok,
          'output_contains' => text_ok, 'output_contains_needles' => needles,
          'expect' => expect_results }
      end

      def extract_expectation(calls, key)
        case key.to_s
        when 'exit_status'
          calls.map { |c| c['payload']['exit_status'].nil? ? nil : c['payload']['exit_status'].to_i }.compact.first
        when 'applied'
          calls.map { |c| c['payload']['applied'] }.compact.first
        when 'used_strip'
          calls.map { |c| c['payload']['used_strip'] }.compact.first
        end
      end

      def expectation_ok?(want, got)
        want.to_s == got.to_s
      end

      # Full evaluation of output_contains over concatenated payloads.
      def check_output_contains(calls, needles)
        text = calls.map { |c| c['payload'].to_s }.join("\n")
        Array(needles).all? { |n| text.include?(n.to_s) }
      end
    end
  end
end
