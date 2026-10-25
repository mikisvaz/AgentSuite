# Path kinds for the scout-ai agent path engine (Research workflow).
#
# AGGREGATOR: defines Research::PATH_KINDS, the workflow-scoped constant
# the engine consumes on WHOLE-WORKFLOW incorporation
# (`tool: Research`; integrate_workflow_path_kinds in scout-ai
# lib/scout/llm/agent/path/workflow_kinds.rb).  Task-level imports
# register nothing.
#
# The three kind definitions (observation, claim, hypothesis) share one
# record engine implemented in lib/Research/path_kinds/records.rb; this
# file loads it and merges the definitions into one Hash keyed by kind
# name (the shape the engine normalizes; keys ARE the kind names, so a
# missing "name" key cannot silently mis-register).
#
# The constant is loaded from workflow.rb after the Research module is
# extended, mirroring the ScoutCoder precedent (its path_kinds.rb loads
# after `module ScoutCoder; extend Workflow; end`).

require_relative 'path_kinds/records'

module Research
  PATH_KINDS = Research::PathKinds.definitions.freeze
end
