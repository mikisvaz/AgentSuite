require 'scout-ai'

module Direct
  extend Workflow
  self.include_workflow AgentWorkflow

  chat_task :ask do
    self.agent chat: chat
  end
end

