require 'scout-ai'

Misc.add_libdir if __FILE__ == $PROGRAM_NAME

#require 'scout/sources/Semantics'

module Semantics
  extend Workflow
  extend ::LiveWorkflow


end

require_relative 'lib/Semantics/tasks/entity_query'
require_relative 'lib/Semantics/tasks/entity_property'
require_relative 'lib/Semantics/tasks/entity_list_property'

#require 'scout/knowledge_base/Semantics'
#require 'scout/entity/Semantics'

