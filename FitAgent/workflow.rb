require 'scout-ai'
require 'fileutils'

FITAGENT_ROOT = File.dirname(File.expand_path(__FILE__))

# Deterministic scenario catalogue + scorer (no inference anywhere in them)
$LOAD_PATH.unshift(File.join(FITAGENT_ROOT, 'lib'))
module FitAgent
  extend Workflow
  self.include_workflow AgentWorkflow
end

require_relative 'lib/FitAgent/tasks/use_case.rb'
