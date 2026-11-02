# v7 role-to-context and role-to-tool matrix

Built from actual probe output, not declarations. Evidence:
script `tmp/v7-edit-bout/matrix_probe.rb` (hermetic: scratch-copy of the
edited `doctrine`/`doctrines`/`society`/`scout`, workflow preloads, then
production `Chat.parse -> Chat.imports -> Chat.tools`; zero model turns),
raw output `tmp/v7-edit-bout/matrix-probe.out`, machine-readable
`tmp/v7-edit-bout/matrix-probe.json`. Run date: 2026-11-03, branch
doctrine-v7.

Verdict line from the probe: `SUMMARY: 14 roles probed; doctrine
resolution failures: NONE` — every role's `Agent/doctrine` and
`doctrines/*` imports resolve to the edited tree with zero leftover
import messages, and the v7 `<!-- v7: -->` markers flow into the
effective system text everywhere.

## Role-to-context matrix

| Role | Imports resolved | Introductions | Anomalies |
|------|-----------------|---------------|-----------|
| Manager | doctrine, society, collaboration, handoff — all resolve | none | none |
| ScientificLead | doctrine, society, collaboration, investigation, discipline, handoff — all resolve | none | none |
| Research | doctrine, society, investigation, discipline, handoff, catalogue — all resolve | Semantics, Workspace | none |
| ScoutCoder | doctrine, scout — resolve | Workspace, ScoutCoder | none |
| Critic | doctrine, investigation, collaboration, discipline — all resolve | Workspace | none |
| Investigator | doctrine, society, collaboration, investigation, handoff — all resolve | Workspace | none |
| Worker | collaboration, handoff, doctrine — all resolve | Workspace, Cortex | none |
| Reader | investigation, catalogue, doctrine — all resolve | Reader, Workspace, Cortex | none |
| ChatAnalyst | doctrine — resolves | Workspace, ChatAnalyst | none |
| Analyst (new) | doctrine, society, collaboration, investigation, handoff — all resolve | Workspace | none |
| Planner (control) | doctrine, collaboration, handoff, society — all resolve | ScoutCoder | none |
| Searcher (control) | investigation, doctrine — resolve | Workspace, Reader, ScoutCoder | none |
| User (control) | doctrine, collaboration, handoff, society — all resolve | none | none |
| Consultant (control) | catalogue, doctrine — resolve | none | none |

## Role-to-tool matrix (effective tools by origin)

Footer grant = the three read-only Cortex tools every `Agent/doctrine`
importer inherits (decision b): `cortex_list`, `cortex_read`,
`cortex_search`. Role block = the role's own `tool:` lines.

| Role | Tool total | Cortex surface | Beyond footer (role block) | Workflow tools (non-Cortex) |
|------|-----------|----------------|---------------------------|------------------------------|
| Manager | 5 | 5 (brief, continue + footer 3) | cortex_brief, cortex_continue | none (delegation only) |
| ScientificLead | 3 | 3 (footer only) | — | none (tool-less by design) |
| Research | 36 | 10 (full curator set + footer) | cortex_write, cortex_edit, cortex_continue, cortex_brief, cortex_rename, cortex_move, cortex_remove | Semantics + Workspace (full) |
| ScoutCoder | 45 | 5 (write, edit + footer 3) | cortex_write, cortex_edit | ScoutCoder (full incl. help tools) + Workspace |
| Critic | 10 | 3 (footer only) | — | Workspace read-only subset + bash |
| Investigator | 28 | 5 (write, edit + footer 3) | cortex_write, cortex_edit | Workspace (full) |
| Worker | 33 | 10 (full + footer) | cortex_write, cortex_edit, cortex_continue, cortex_brief, cortex_rename, cortex_move, cortex_remove | Workspace (full) |
| Reader | 37 | 10 (full + footer) | cortex_write, cortex_edit, cortex_continue, cortex_brief, cortex_rename, cortex_move, cortex_remove | Reader + Workspace |
| ChatAnalyst | 44 | 5 (write, edit + footer 3) | cortex_write, cortex_edit | ChatAnalyst + Workspace |
| Analyst (new) | 11 | 3 (footer only) | — | Workspace exec/file subset only: bash, python, ruby, r, read, write, list_directory, file_stats |
| Planner (control) | 8 | 3 (footer only) | — | ScoutCoder help tools |
| Searcher (control) | 15 | 5 (write, edit + footer 3) | cortex_write, cortex_edit | Workspace read subset, Reader (searxng, html2md), ScoutCoder help |
| User (control) | 3 | 3 (footer only) | — | none |
| Consultant (control) | 3 | 3 (footer only) | — | none |

Tool-total note: totals are distinct effective tool names; where a role
declares `tool: Workspace` (whole-workflow), every exported task counts.

## Observations against the ledger

- Analyst's Cortex surface is exactly the footer grant — its own block
  carries no Cortex line, matching ROLE-1 (general-purpose compute only).
  <!-- v7: ROLE-1 -->
- Critic, ScientificLead, Planner, User, Consultant are footer-only —
  read-only recall, no write side: the decision-b encoding in practice.
- The four control rows (Planner, Searcher, User, Consultant) resolve the
  edited doctrine unchanged and inherit only the footer — the edit set
  did not leak tool lines into unedited roles.
