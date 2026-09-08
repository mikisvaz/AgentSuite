require 'scout-ai'

module Critic
  extend Workflow
  self.include_workflow AgentWorkflow

  chat_task :ask do
    agent = self.agent chat: chat

    agent.start_chat.user <<-EOF
Evaluate the previous work.
    EOF

    response = agent.chat return_messages: true
    begin
      set_info :json, Chat.parse_json(response.answer)
    rescue
    end

    agent
  end
end

