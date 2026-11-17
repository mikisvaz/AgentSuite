# Testing Research

Ten test suites under `test/`, all run in fresh processes, all expected
green (logs under `tmp/`):

| Suite | Covers |
|---|---|
| `line_edit/test_line_edit.rb` | pure one-based half-open line editor |
| `store/test_ids.rb` | ID allocation, cwd-based root resolution |
| `store/test_store.rb` | S/J/M/V/C protocol, locking, drift, recovery |
| `tasks/test_registration.rb` | task discovery, exec exports, grep-clean |
| `tasks/test_dossier_tasks.rb` | create/list/read/update payloads and errors |
| `tasks/test_evidence_tasks.rb` | attach modes, sandbox edges, evidence_read |
| `tasks/test_check_history_capture_tasks.rb` | checker, history, capture |
| `tasks/test_job_level_semantics.rb` | dispatcher-level freshness/isolation |
| `tasks/test_legacy_store_compatibility.rb` | pre-refactor stores stay valid |
| `tasks/test_links_and_conciseness.rb` | link coverage model, payload conciseness |

Run one suite:

    ruby -Itest test/Research/tasks/test_dossier_tasks.rb

Harness discipline:

- **Every store-writing dispatch runs inside the temp-project harness**
  (`DossierFixtures.in_project` — `Dir.mktmpdir` + `Dir.chdir`). A test
  process's cwd is never the checkout, so a leaked write cannot reach a
  real store.
- `LLM.call_workflow` **returns** exception objects instead of raising
  (agent-tool contract). Rejection tests re-raise the returned exception
  or use `Research.job(...).exec`, which raises.
- Fresh processes matter: job-level semantics (memoization, cwd-derived
  roots) are asserted per process, not within one process's warm state.
