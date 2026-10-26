require 'scout'
require 'scout-ai'

Workflow.require_workflow 'Workspace'
module Reader
  extend Workflow
end

Reader.helpers.merge!(Workspace.helpers)

require_relative 'lib/Reader/tasks/documents'
require_relative 'lib/Reader/tasks/web'
