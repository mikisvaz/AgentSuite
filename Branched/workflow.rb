require 'scout-ai'

Workflow.require_workflow Scout.chats.Agent.Planned['workflow.rb'].find

module Branched
  extend Workflow
  self.include_workflow AgentWorkflow

  task_alias :plan, Planned, :plan

  dep :plan
  chat_task :work do
    worker_agent = options[:Branched_worker_agent] || options[:worker_agent] || 'Worker'

    plan = step(:plan).load
    search = step(:search).load if step(:search)

    chat = self.chat
    chat.follow search if search
    chat.follow plan

    chat.message :clear_tools, true

    spliter = self.agent nil, chat: chat

    spliter.user <<-EOF
Divide the job into parallel branched out sub-tasks, were each
implements the same work but on a different subject.

Return them as JSON object with names and instructions, like in this example:

{
  "file1": "Process file1 in this way..."
}

A different worker will recieve the instructions for each sub-task,
along with the entire plan for reference. Execution may proceed
in parallel, so consider race conditions.
    EOF

    tooling = self.tooling

    reports = {}
    spliter.iterate_dictionary nil, cpus: 8, bar: self.progress_bar('Branches'), into: reports do |name, instructions|
      log name, "Start #{name}"
      agent_chat = Chat.setup([])
      agent_chat.follow search
      agent_chat.follow plan
      worker = self.agent worker_agent, chat: agent_chat, tooling: tooling 
      worker.user <<-EOF
You have been asked to produce one sub-task (#{name}):

#{instructions}
      EOF

      reports[name] = worker.chat
      log_agent worker, "worker-#{name}"
      log name, "Done #{name}"
      [name, worker.chat]
    end

    log_agent spliter, 'spliter'

    critic = self.agent :Critic, chat: chat, tooling: self.tooling 
    critic.user <<-EOF
The work has been complete in different subtasks. Here are the reports
    EOF

    reports.each do |name, report|
      critic.user <<-EOF
Report for sub-task #{name}:

#{report}
      EOF
    end

    critic
  end

  dep :work
  chat_task :ask do
    chat = self.chat
    chat.follow step(:request).load
    chat.follow step(:plan).load
    chat.message :clear_tools, true
    agent = self.agent :User, tooling: false, chat: chat

    agent.user <<-EOF
The work proceeded reports and their review are here

#{step(:work).load.answer}
    EOF

    agent.user <<-EOF
Please elaborate a final report for the User.
    EOF

    agent
  end
end

