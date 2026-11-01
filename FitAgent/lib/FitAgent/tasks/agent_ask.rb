module FitAgent
  input :agent, :string, "Agent name or 'none'", nil
  input :doctrine, :text, "Additional doctrine, incorporated as a system role message", nil
  chat_task :agent_ask do 
    agent_name, doctrine = self.recursive_inputs.values_at :agent, :doctrine
    agent = nil if agent_name == 'none'
    agent = self.agent agent_name, return_tool_calls: true
    agent.start_chat.follow({role: :system, content: doctrine}) if doctrine
    agent.follow self.chat.reject{|m| %w(agent system tool).include? m[:role].to_s }
    agent
  end

  dep :agent_ask
  input :rubric, :text, 'File path to the rubric', nil, required: true
  chat_task :evaluate_agent do
    agent = self.agent 'FitAgent'
    agent.workflow = nil
    agent.user <<-EOF
Evaluate the scenario proposed in the following messages
    EOF
    agent.follow self.chat
    agent.user <<-EOF
The rubric we want to evaluate is below
    EOF
    agent.file inputs[:rubric]
    agent.user <<-EOF
Below is the agents response
    EOF
    agent.follow step(:agent_ask).load

    agent.user <<-EOF
Please return your evaluation based on the agent response above.
    EOF

    agent
  end

  export :agent_ask, :evaluate_agent
end
