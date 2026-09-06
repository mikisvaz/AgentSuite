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
    worker_agent = options[:Planned_worker_agent] || options[:worker_agent] || 'Manager'

    agent = self.agent worker_agent, chat: chat, tooling: self.tooling 

    agent.user <<-EOF
You have been asked to fulfill a user request. Proceed with the plan
    EOF

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

