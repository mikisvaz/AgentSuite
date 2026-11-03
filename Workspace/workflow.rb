require 'scout'
require 'scout-ai'

$LOAD_PATH.unshift(File.expand_path('lib', __dir__)) unless $LOAD_PATH.include?(File.expand_path('lib', __dir__))

module Workspace
  extend Workflow

  task current_time: :string do
    Time.now.to_s
  end

  export_exec :current_time
end

require_relative 'lib/Workspace/exceptions'
require_relative 'lib/Workspace/tasks/filesystem'
require_relative 'lib/Workspace/tasks/exec'
require_relative 'lib/Workspace/tasks/patch'
require_relative 'lib/Workspace/tasks/precise_edit'
require_relative 'lib/Workspace/tasks/tsv'
