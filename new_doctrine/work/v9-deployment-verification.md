# Doctrine v9 deployment verification (step 5a, hermetic)

Bout: delivery verification only — fresh-context parses, no agent inferences,
no doctrine/start_chat edits. Head at verification time: a286826 (16 commits
after rollback point 46433830). Probe scripts: `tmp/v9-probes/parse_probe.rb`
(fresh-context surface matrix), `tmp/v9-probes/import_match.rb` (import
resolution), outputs `tmp/v9-probes/parse_probe_output.{txt,json}`,
`tmp/v9-probes/import_match.json`.

Method. For each role the probe copies the current start_chat into a scratch
chat dir (`tmp/v9-probes/chats/<Role>`) alongside `Agent/{doctrine,society,
scout,doctrines/*}`, then runs `Chat.parse` + `Chat.imports` on it and records
the resulting messages — actual post-resolution provisioning, not declarations.
Import resolution compares every parsed message body against every candidate
source file normalized the same way `Chat.parse` normalizes (leading
`system:` header stripped; leading `\` before a `word:` directive start
un-escaped; whitespace collapsed) — `doctrine` contains an intentionally
escaped `\risk:` at line 213, which the parser un-escapes, so both sides
apply the transform. Verification of that equivalence: normalized parsed
doctrine message == normalized `doctrine` file, byte-identical after
normalization (14339 chars both sides). `scout` resolves to a `user` message
(file begins `# Scout Vocabulary`, no role header), so import matching cannot
be role-restricted; `import_match.rb` matches on body across all roles —
finding documented, not a defect (see M-1).

## Matrix: role × surface (all rows parsed fresh)

| Role | Surface | Intended (from branch start_chat + ledger) | Actual (parsed) | Verdict |
|---|---|---|---|---|
| Manager | tools | Cortex cortex_continue, cortex_brief; Workspace read | identical (3) | PASS |
| Manager | kb/mcp | none | none | PASS |
| Manager | introduce | none | none | PASS |
| Manager | imports | doctrine, society, doctrines/{collaboration,handoff,scientific_investigation} | 5/5 resolved, 0 leftover, 0 unknown | PASS |
| Manager | path_kind/socialize | none / true | none / true | PASS |
| Research | tools | Semantics; Workspace; Cortex ×9 (list,search,read,write,edit,continue,brief,rename,move,remove); Research | identical (13) | PASS |
| Research | kb/mcp | none | none | PASS |
| Research | introduce | Semantics, Workspace, Research | identical (3) | PASS |
| Research | imports | doctrine, society, doctrines/{scientific_investigation,discipline,handoff,catalogue} | 6/6 resolved, 0 leftover | PASS |
| Research | path_kind/socialize/exec_task | Research / true / Workspace pwd | identical | PASS |
| Analyst | tools | Workspace {bash,python,ruby,r,read,write,list_directory,file_stats} | identical (8) | PASS |
| Analyst | kb/mcp/introduce | none / none / Workspace | identical | PASS |
| Analyst | imports | doctrine, society, doctrines/{collaboration,scientific_investigation,handoff} | 5/5 resolved | PASS |
| Analyst | path_kind/socialize | none / none | none / none | PASS |
| ScientificLead | tools | none (tool-less per D1/advisory rec 1) | 0 tools | PASS |
| ScientificLead | kb/mcp/introduce | none | none | PASS |
| ScientificLead | imports | doctrine, society, doctrines/{collaboration,scientific_investigation,discipline,handoff} | 6/6 resolved | PASS |
| Critic | tools | Workspace {read,list_directory,file_stats,search,sandbox_paths,pwd,bash} | identical (7) | PASS |
| Critic | kb/mcp | none | none | PASS |
| Critic | introduce | Workspace | identical | PASS |
| Critic | imports | doctrine, doctrines/{scientific_investigation,collaboration,discipline} | 4/4 resolved | PASS |
| Worker | tools | Workspace; Cortex | identical (2) | PASS |
| Worker | kb/mcp | none | none | PASS |
| Worker | introduce | Workspace, Cortex | identical (2) | PASS |
| Worker | imports | doctrine, doctrines/{collaboration,handoff} | 3/3 resolved | PASS |
| ScoutCoder | tools | Cortex cortex_write, cortex_edit; Workspace; ScoutCoder | identical (4) | PASS |
| ScoutCoder | kb/mcp | none | none | PASS |
| ScoutCoder | introduce | Workspace, ScoutCoder | identical (2) | PASS |
| ScoutCoder | imports | doctrine, scout, doctrines/scientific_investigation | 3/3 resolved (scout as user-role message, see M-1) | PASS |
| ScoutCoder | path_kind/exec_task | ScoutCoder / Workspace pwd | identical | PASS |

Totals: 29/29 rows PASS; 0 mismatches; 0 leftover `import` messages; 0
unknown roles; 0 wiring-directive leaks inside system bodies (leak scan from
the v8 probe pattern, re-run and clean).

## Per-role one-line verdicts (imports called out per task 3)

- **Manager** — PASS: 5/5 imports resolve (incl. doctrine, society), 3 tools, socialize on.
- **Research** — PASS: 6/6 imports resolve, 13 tools across Semantics/Workspace/Cortex/Research, path_kind Research.
- **Analyst** — PASS: 5/5 imports resolve, 8 Workspace exec tools, no Cortex.
- **ScientificLead** — PASS: tool-less as intended, 6/6 imports resolve.
- **Critic** — PASS: 4/4 imports resolve, 7 Workspace verification tools.
- **Worker** — PASS: 3/3 imports resolve, Workspace+Cortex only.
- **ScoutCoder** — PASS: 3/3 imports resolve (doctrine + scout + sci-inv; submodule @ 7da7ab8 contains both the 667d1e2 v7 stance edit and the 7da7ab8 v9 pin-first edit), path_kind ScoutCoder.

## Delivery-path verification (task 2, re-run now)

- `bash bin/bundle_doctrine.sh` → **exit 0**, empty stderr. `diff -q` clean
  for all 3 top-level files, all 8 `doctrines/*`, all 11 role start_chats
  present in the bundle (incl. Reader/ChatAnalyst/Basic/Clean). PASS.
- ScoutCoder gitlink: `git ls-tree HEAD ScoutCoder` → `160000 7da7ab8`;
  `git submodule status` shows `7da7ab8` with no `+`; `git -C ScoutCoder
  merge-base --is-ancestor 667d1e2 HEAD` → true (the v8-era start_chat
  edit lineage is present); `ScoutCoder/start_chat` line 25 carries the v9
  pin-first text. PASS.
- ChatAnalyst gitlink: `git ls-tree HEAD ChatAnalyst` → `160000 25f423a`,
  submodule HEAD 25f423a, equal → unchanged as recorded in the migration
  note (its in-submodule uncommitted start_chat edit predates v9 and is not
  owned by any v9 row). PASS (unchanged as intended).

## Not testable hermetically (task 4)

- **Mission-template instantiation** (`doctrines/mission_template`): the
  template is a tracked doctrine file, not an import of any role start_chat;
  its consumption happens at mission-creation time by an operator/Manager
  copy step. Hermetic parse cannot exercise that path. Bundled copy is
  diff-clean (so delivery-by-bundle holds); instantiation is a runtime act.
- **Planned workflow runtime** (`Planned/workflow.rb` work-stage prompt,
  CL-18): `ruby -c` passed in step 4, but actually running a mission through
  `request → plan → work → ask` requires a live chat/LLM run — out of scope
  for a hermetic bout. Also the row's disable-branch remains unimplemented
  (step-4 deviation).
- **Society instantiation at launch** (roster read, F7 standing constraint
  consumption): society resolves as an import for the roles that declare it
  (verified in the matrix), but whether a launcher/Manager session actually
  reads the roster to decide recipients is runtime behavior.
- **Domain-tool provisioning** (Boolean/Gene, per F7/CL-19): provisioned at
  launch by tool wiring outside the repo; only the *constraint note* in
  `society` (line 184) is verifiable here, and it is present.
- **Delegated items** (delegate-disposition register rows): exec-failure
  surfacing, .info job birth, cortex_brief tool attachment, char pagination,
  path_write compaction guard, per-call token metering, staged Agent/
  namespace root fix, searxng, ExTRI2/SaezLab mounts — all live in scout-ai
  or the environment, outside this repo; nothing to verify here beyond their
  being absent from v9's fix-here scope (confirmed).

## Findings requiring no repair (mechanism notes)

- **M-1**: `scout` imports resolve as `user`-role messages because the file
  has no role header; `Chat.imports` accepts any role. Not a v9 regression
  (pre-existing shape), and ScoutCoder's import is confirmed present by body
  match. Probe adjusted to match across roles rather than system-only;
  documented here so the next verifier does not mistake it for a failure.
- **M-2**: The normalized-comparison method (whitespace collapse) is
  byte-exact for every matched import (checked by comparing normalized
  lengths: every pair equal); normalization exists only to absorb the
  parser's `\risk:` un-escape and header strip, both deterministic.
