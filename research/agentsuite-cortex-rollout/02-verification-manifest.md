# AgentSuite Cortex rollout - verification manifest (D4 closure)

Status: PASS
Date: 2026-09-05
Verifier: Critic agent, independent verification with its own cold-process
probes (fresh processes, no reliance on the implementer's runtime evidence
beyond cross-checking). All 12 checks A1-A7, B8-B10, C11-C12 returned PASS.

Scope verified: `./doctrine` (D1) plus the 13 `<Agent>/start_chat` files
(D2), against the Cortex spec artifact
`plans/agentsuite-rollout-spec.md` (sections 2 and 3) and the
`search/spec-reconciliation-brief.md` clauses, with the D2 packet as the
authoritative wording where it supersedes.

## 1. Check table

| Check | Result | Evidence |
|---|---|---|
| A1 exactly one bare `tool: Cortex`, only in Cortex/start_chat | PASS | tmp/critic_verify/critic_A1_A2.txt (hit: ./Cortex/start_chat:88); also tmp/d2_verify_out.txt |
| A2 granular line counts: doctrine 4, A agents 2 each, Worker 7, WorkflowCoder 11, none elsewhere | PASS | tmp/critic_verify/critic_A1_A2.txt (all 25 granular lines with file:line); tmp/start-chat-edits.diff |
| A3 exactly one `introduce: Cortex` (doctrine:278), none in any start_chat | PASS | tmp/critic_verify/critic_A3_A4.txt (real-files scan empty; doctrine count 1) |
| A4 doctrine headings 1-11 in order; trailing five lines exact; sections 1/3/10 identical to git HEAD | PASS | tmp/critic_verify/critic_A3_A4.txt (heading map + last-5-lines); section identity vs HEAD in tmp/critic_verify/current_doctrine_git.diff and tmp/doctrine-edit.diff |
| A5 zero non-ASCII added lines across the rollout diffs | PASS | tmp/critic_verify/critic_A5.txt (257 added lines scanned, 0 non-ASCII; pre-existing context chars in Critic 12 lines / Visualizer 2 lines untouched) |
| A6 saved diffs consistent with on-disk files | PASS | tmp/start-chat-edits.diff, tmp/doctrine-edit.diff vs disk; tmp/critic_verify/cur_*.diff |
| A7 rollout-touched set correct; unrelated pre-existing changes not attributed to rollout | PASS | tmp/critic_verify/critic_A7.txt (porcelain + submodule pointers; attribution note below) |
| B8 spec blocks 2.1-2.7 verbatim plus all six reconciliation clauses at specified locations; nothing dropped, weakened, or invented | PASS | tmp/critic_verify/b8_verbatim_check.txt and b8_verbatim_recheck.txt (2.1-2.7 verbatim True; six clauses flowing-verbatim True; the only 4 "missing source" lines are the pre-existing section 7 typos preserved by design); check script tmp/critic_verify/check_doctrine_clauses.rb |
| B9 all 13 start_chats match profiles, role sentences verbatim, removals complete, User and ComputerUse replacements exact | PASS | tmp/critic_verify/b9_startchat_detail.txt (per-file added-line dumps) |
| B10 capability-matrix rows verified for all 13 agents | PASS | tmp/critic_verify/critic_B10_anchors.txt (anchor spot checks: ChatAnalyst L27, ComputerUse L16, User L28, Cortex L84, ...) against research/agent-cortex-capabilities.md |
| C11 full 13-agent runtime effective-tool counts match profiles (4/6/11/15/21) | PASS | tmp/critic_verify/critic_probe_all_agents.rb -> tmp/critic_verify/critic_probe_out.txt (cold-process probe; corroborated by tmp/d2_probe_out.txt, tmp/d1_verify_out.txt) |
| C12 curator-only tools held only by the Cortex agent; no cortex_write on R agents | PASS | tmp/critic_verify/critic_probe_out.txt (C12 negatives section) |

B10 note: the Critic raised one wording nit - the ComputerUse row originally
conflated the strengthened sandbox_paths paragraph and the appended Cortex
paragraph (both texts do exist on disk; wording only). Resolved in this
closure step: the row now distinguishes the two edits explicitly.

## 2. Effective Cortex tool counts (all 13 agents, runtime)

From tmp/critic_verify/critic_probe_out.txt (cold-process agent-load probe,
no model turns). Counts by profile: R=4, A=6, E=11, P=15, C=21.

| Agent | Profile | Count | Effective Cortex tools |
|---|---|---|---|
| ChatAnalyst | A | 6 | cortex_activity, cortex_edit, cortex_list, cortex_read, cortex_search, cortex_write |
| ComputerUse | R | 4 | cortex_activity, cortex_list, cortex_read, cortex_search |
| Consultant | R | 4 | cortex_activity, cortex_list, cortex_read, cortex_search |
| Cortex | C | 21 | cortex_activity, cortex_brief, cortex_continue, cortex_edit, cortex_entity_property, cortex_list, cortex_move, cortex_property_define, cortex_property_history, cortex_property_list, cortex_property_read, cortex_property_remove, cortex_property_update, cortex_property_validate, cortex_read, cortex_read_list, cortex_remove, cortex_rename, cortex_search, cortex_write, cortex_write_list |
| Critic | R | 4 | cortex_activity, cortex_list, cortex_read, cortex_search |
| Manager | R | 4 | cortex_activity, cortex_list, cortex_read, cortex_search |
| Planner | R | 4 | cortex_activity, cortex_list, cortex_read, cortex_search |
| ScoutCoder | A | 6 | cortex_activity, cortex_edit, cortex_list, cortex_read, cortex_search, cortex_write |
| Searcher | A | 6 | cortex_activity, cortex_edit, cortex_list, cortex_read, cortex_search, cortex_write |
| User | R | 4 | cortex_activity, cortex_list, cortex_read, cortex_search |
| Visualizer | A | 6 | cortex_activity, cortex_edit, cortex_list, cortex_read, cortex_search, cortex_write |
| Worker | E | 11 | cortex_activity, cortex_edit, cortex_entity_property, cortex_list, cortex_property_list, cortex_property_read, cortex_read, cortex_read_list, cortex_search, cortex_write, cortex_write_list |
| WorkflowCoder | P | 15 | cortex_activity, cortex_edit, cortex_entity_property, cortex_list, cortex_property_define, cortex_property_history, cortex_property_list, cortex_property_read, cortex_property_update, cortex_property_validate, cortex_read, cortex_read_list, cortex_search, cortex_write, cortex_write_list |

## 3. Curator-only negatives (C12)

All six curator-only tools resolve for exactly one agent, the Cortex agent,
and for no other: cortex_continue, cortex_brief, cortex_rename, cortex_move,
cortex_remove, cortex_property_remove - each `holders=["Cortex"] OK` in
tmp/critic_verify/critic_probe_out.txt. Additionally, cortex_write is absent
from every R agent (ComputerUse, Consultant, Critic, Manager, Planner,
User), confirming that no read-only agent gained write capability.

## 4. Caveats - known limitations (verbatim)

- ask delegation defaults to inherit=tools, so a delegated agent receives
  the caller's full tool surface (a superset of its profile)
- cortex_continue attaches the full Cortex tooling to contributing agents
  regardless of profile
- start_chat edits do not invalidate cached agent jobs; clean or vary inputs
  when testing an edited agent

## 5. Remaining uncertainties

- Visualizer has no git baseline (its directory is untracked in the
  superproject and it has no own repo HEAD for start_chat); diff fidelity
  rests on the saved diff section in tmp/start-chat-edits.diff plus the
  current on-disk file and the runtime probe.
- Attribution note (A7): the submodule working trees and the superproject
  carry unrelated pre-existing uncommitted changes - e.g.
  Cortex/lib/Cortex/tasks/conversation.rb, the WorkflowCoder lib diff, and
  the root .gitignore/.vimproject/Planned/workflow.rb edits plus the stray
  `]` file - that are NOT part of this rollout and must not be attributed to
  it.
- Wording nit on the capability matrix ComputerUse row: resolved in this
  step (see B10 note above).

## 6. Conclusion

The rollout met its acceptance criteria: doctrine-carries-recall-tools
mechanism implemented and verified, per-agent profiles match the spec and
the D2 packet exactly (mechanical, content, and runtime evidence all PASS),
curator exclusivity holds, and the reference artifact is accurate. Related
artifacts: research/agentsuite-cortex-rollout/01-preflight-report.md,
research/agent-cortex-capabilities.md.
