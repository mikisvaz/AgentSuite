require 'scout-ai'

module Planned
  extend Workflow
  self.include_workflow AgentWorkflow

  chat_task :request do
    agent = self.agent :User, chat: chat

    agent.user <<-EOF
Restate the request from the user as self contained instructions for the agents.
    EOF

    agent
  end

  dep :request
  chat_task :search do
    chat = self.chat
    chat.follow step(:request).load
    agent = self.agent :Searcher, chat: chat, tooling: self.tooling_intro

    agent.user <<-EOF
Prepare a report that can be used as reference to help fulfill the user request
    EOF

    agent
  end

  dep :search do |jobname,options|
    options = LLM.options LLM.chat(options[:chat].dup)
    if options[:use_search].to_s != 'false'
      {inputs: options, jobname: jobname}
    else
      {task: :request, inputs: options, jobname: jobname}
    end
  end
  chat_task :plan do
    chat = self.chat
    chat.follow step(:request).load.last

    if step(:search)
      chat.follow step(:search).load.last
    end

    chat.message :clear_tools, true
    agent = self.agent :Planner, chat: chat, tooling: self.tooling_intro 

    agent.user <<-EOF
You have been asked to fulfill a user request. Elaborate a plan
    EOF

    agent
  end

  dep :plan
  chat_task :work do
    options = self.options
    chat = Chat.setup([])
    chat.follow step(:request).load.last
    chat.follow step(:search).load.last if step(:search)
    chat.follow step(:plan).load.last
    worker_agent = config :worker_agent, default: (options[:Planned_worker_agent] || options[:worker_agent] || 'Manager')

    agent = self.agent worker_agent, chat: chat, tooling: self.tooling 

    if Open.exists?(agent.save_file + '.error')
      old_chat = Chat.parse(Open.read(agent.save_file + '.error'))
      agent.current_chat = old_chat

      agent.user <<-EOF
Your work seems to have been interrupted. Please continue
      EOF
    else
      agent.user <<-EOF
You have been asked to fulfill a user request. A plan is attached above from the plan stage. Follow the plan for all consequential steps and cite the plan step you are executing in the work order; when you deviate from the plan, log the deviation and its reason in your report rather than silently departing from it.
      EOF

    end

    agent
  end

  dep :work
  chat_task :ask do
    chat = self.chat
    chat.follow step(:request).load
    chat.follow step(:plan).load
    chat.follow step(:work).load
    chat.message :clear_tools, true

    agent = self.agent :User, tooling: false, chat: chat

    agent.user <<-EOF
Please elaborate a final report for the User.
    EOF

    agent
  end
end

