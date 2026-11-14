Direct: single-stage agent pipeline

A minimal single-stage agent pipeline: the `ask` chat task runs the
chat's own agent with no staged decomposition, planning, or extra tool
setup — the whole request goes to the agent exactly as supplied.

# Tasks

## ask

Run the chat's agent on the supplied chat, once, with the agent's normal
configuration. Hand-written entry — `ask` declares no `desc` (flagged per
the minimal-entry policy).
