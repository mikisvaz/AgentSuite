require 'scout-ai'

Misc.add_libdir if __FILE__ == $PROGRAM_NAME

#require 'scout/sources/Semantics'


module Semantics
  extend Workflow


end
Semantics.extend LiveWorkflow

if File.expand_path(__FILE__) != File.expand_path('./workflow.rb')
  Workflow.require_workflow './workflow.rb', silent: true if File.exist?('./workflow.rb') 
end

require_relative 'lib/Semantics/tasks/entity_query'
require_relative 'lib/Semantics/tasks/entity_property'
require_relative 'lib/Semantics/tasks/entity_list_property'

#require 'scout/knowledge_base/Semantics'
#require 'scout/entity/Semantics'

