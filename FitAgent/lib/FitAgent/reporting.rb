require 'scout-ai'
require 'fileutils'
require 'json'

module FitAgent
  # Reporting half of the multi-arm runner (Unit B verdict-1 split).
  #
  # Runner keeps the POLICY: arm staging, override resolution, agent-turn
  # invocation and scoring. This module keeps the REPORTING: the projection
  # of score_scenario results into the per-arm output files
  #
  #   results/<experiment>/<arm>/scores.tsv   one row per scenario
  #   results/<experiment>/<arm>/scores.json  detailed per-scenario breakdown
  #   results/<experiment>/<arm>/arms.json    arm manifest (staged override,
  #                                           chat + work paths, scenario ids)
  #
  # The split exists because the message_ok-column bug lived exactly in the
  # projection below: it read a single message-tier subflag (count_ok) while
  # ignoring the aggregate. Keeping the projection next to nothing else — and
  # independently testable against a plain results hash — is the point.
  module Reporting

    class << self
      # Column projection: results hash (Scoring.score_scenario output) ->
      # scores.tsv body. One row per scenario:
      #   verdict, score, functional_ok, message_ok, failures, chat
      # message_ok is the AGGREGATE flag (count_ok && total_cap_ok && no
      # forbidden rescue): count_ok alone hid C-series cap violations.
      def scores_tsv(results)
        tsv = TSV.setup({}, key: 'scenario', type: :list)
        tsv.fields = %w[verdict score functional_ok message_ok failures chat]
        results.keys.sort.each do |id|
          r = results[id]
          tsv[id] = [r['verdict'], r['score'].to_s,
                     r['functional']['files'].values.all? { |v| v['ok'] } ? 'true' : 'false',
                     # aggregate (count_ok && total_cap_ok && no forbidden
                     # rescue): count_ok alone hid C-series cap violations
                     r['message']['message_ok'].to_s,
                     r['failures'].join(';'),
                     r['evidence']['chat']]
        end
        tsv.to_s
      end

      # Persist one finished arm run: scores.json, arms.json and scores.tsv
      # under arm_out. Pure function of the run artifacts — given the same
      # (experiment, arm, agent, override, results, runs) the written bytes
      # are identical (Unit B no-behavior-change proof replayed this through
      # before/after snapshots).
      #
      #   arm_out   per-arm output dir (results/<experiment>/<arm>)
      #   override  staged override dir for this arm, or nil for baseline
      #   results   per-scenario results hash from Scoring.score_scenario
      #   runs      per-scenario { 'chat' =>, 'work' => } evidence paths
      #
      # Returns the scores.tsv body (also embedded by callers in run records).
      def write_arm_outputs(arm_out, experiment:, arm:, agent:, override:,
                            results:, runs:)
        FileUtils.mkdir_p arm_out
        Open.write(File.join(arm_out, 'scores.json'), JSON.pretty_generate(results) + "\n")
        Open.write(File.join(arm_out, 'arms.json'),
                   JSON.pretty_generate('experiment' => experiment, 'arm' => arm,
                                         'agent' => agent,
                                         'override' => override,
                                         'scenarios' => results.keys.sort,
                                         'runs' => runs) + "\n")
        tsv = scores_tsv(results)
        Open.write(File.join(arm_out, 'scores.tsv'), tsv)
        tsv
      end
    end
  end
end
