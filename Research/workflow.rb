require 'scout'
require 'scout-ai'

Workflow.require_workflow 'Workspace'
module Research
  extend Workflow
end

Research.helpers.merge!(Workspace.helpers)

require_relative 'lib/Research/tasks/documents'
require_relative 'lib/Research/tasks/web'
