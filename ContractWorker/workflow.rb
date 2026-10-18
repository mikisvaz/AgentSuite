require 'scout'

Misc.add_libdir if __FILE__ == $PROGRAM_NAME

#require 'rbbt/sources/ContractWorker'

module ContractWorker
  extend Workflow

  extend Workflow
  self.include_workflow AgentWorkflow

  chat_task :contract do
    agent = self.agent 'ScoutCoder'

    agent.user <<-EOF

Prepare a reference report mapping the development tasks an agent needs to
perform when implementing Scout functionality through ScoutCoder, and identify
the skills needed to carry out that work reliably. **Start by examining the
existing Cortex `skills/` artifacts.** Determine what is already covered and
usable, and work incrementally only on genuine gaps. If the existing skills are
sufficient, report the mapping and move on; do not manufacture additional work.

Think from the perspective of the next worker waking up to perform an
implementation. The skills may already cover most of the work, in which case
the worker should be able to proceed immediately. Alternatively, the
implementation may require several distinct bouts of work, each addressing a
different contract. The documentation should make both situations
straightforward to navigate.

Organise skills around **reusable workflows of development steps**, not
individual concepts, tools, or isolated operations. A skill should explain how
to complete a coherent piece of work, including its internal sequence,
contracts, tests, and relevant documentation. Provide simple connections
between skills so an agent can move naturally from one workflow to the next
without having to understand a complicated global process. Keep the complexity
inside each skill and the transitions between skills few and explicit. Ground
the mapping in Scout's actual conceptual model and the contracts exposed
through ScoutCoder.

Probe the tools only as needed to resolve uncertainties about existing coverage
or actual contracts. Clean up all temporary files, test artifacts, jobs, and
other state created by those probes. **Leave no implementation work completed,
no persistent probe traces, and no changes beyond the documentation genuinely
missing from the existing Cortex skills.** The deliverable is a concise task
map, an assessment of existing skill coverage, and only the incremental skill
documentation required to make the next worker effective. 

Respond with a report advicing agents on what Cortex skills to follow, and
other useful tips.
    EOF

    agent
  end

  dep :contract
  chat_task :work do
    options = self.options
    chat.follow step(:contract).load.last
    worker_agent = config :worker_agent, default: (options[:Contract_worker_agent] || options[:worker_agent] || 'ScoutCoder')

    agent = self.agent worker_agent, chat: chat, tooling: self.tooling 

    agent.user <<-EOF
You have been asked to fulfill a user request. You should find relevant skills as Cortex artifacts
    EOF

    agent
  end

  dep :work
  chat_task :ask do
    chat = self.chat
    chat.follow step(:work).load
    chat.message :clear_tools, true

    agent = self.agent :User, tooling: false, chat: chat

    agent.user <<-EOF
Please elaborate a final report for the User.
    EOF

    agent
  end

end

#require 'ContractWorker/tasks/basic.rb'

#require 'rbbt/knowledge_base/ContractWorker'
#require 'rbbt/entity/ContractWorker'

