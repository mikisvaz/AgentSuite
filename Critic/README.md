Critic: independent verifier persona

An agent persona that independently evaluates previous work: its `ask`
chat task starts the Critic agent (whose `start_chat` carries the
verifier persona), appends "Evaluate the previous work.", and lets the
agent reason over the chat. If the agent's answer parses as JSON, the
verdict is also recorded as structured job info (`set_info :json`); an
unparseable answer leaves no info and the agent chat itself is the
result.

# Tasks

## ask

Evaluate the previous work. Starts the Critic agent on the task chat with
the prompt "Evaluate the previous work.", runs the agent, and records a
parsed JSON verdict in the job info when the answer parses as JSON (a
bare rescue swallows parse failures silently). Returns the agent.
Hand-written entry — `ask` declares no `desc` (flagged per the
minimal-entry policy).
