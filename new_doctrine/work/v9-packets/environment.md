# Delegation packet — environment / user-owned items (from doctrine-v9)

Recipient: environment owner / user. Source: doctrine-v9 evidence register
(dispositions: environment/user) and `new_doctrine/work/v9-baseline.md`
friction inventory. All evidence inlined.

## 1. searxng web-search service dead

- Evidence (inline): d8 F9 — 28 searxng mentions, **0 successful calls** in
  the final report chain; 5 search-stage queries returned empty/HTTP 500;
  Reader logged 7 `.info`-only failures. Consequence: literature tier was
  downgraded to "unverified/literature optional" at Gate-5; the KB/
  entity-property `literature_summary` surface was used instead; the final
  report discloses a thin literature layer. Searcher cost before discovery:
  117 messages / 30 calls / 26 inf / 1.53M pt.
- Disposition: environment (service availability), user decision.
- Action: restore searxng (it answers HTTP 500), or accept no web search and
  keep the d8 fallback documented. v9 launch checklist carries this as item
  (c).

## 2. ExTRI2 / SaezLab workflow dependency mounts

- Evidence (inline): d6 C05 — SaezLab/ExTRI2 mount absence, 71 load-failure
  mentions; d7 FR-05 — SaezLab symlink rediscovered by Worker, ≈2.5M tt.
- Disposition: environment (mounts) — these repos must be mounted/linked on
  any host where their workflows are expected to run.
- Action: confirm mounts at launch preflight; the v9 mission template now
  carries a preflight step so absence is detected before dispatch, not
  rediscovered mid-run.

## 3. workflows/ symlinks carry machine-absolute targets

- Evidence (inline, from v9-baseline.md §frictions): `git ls-files -s
  workflows/` → 5 tracked symlinks (mode 120000); `ls -la workflows/` shows
  the exact targets:
  - `Cortex -> /bulk/mvazque2/git/AgentSuite/Cortex`
  - `Reader -> /bulk/mvazque2/git/AgentSuite/Reader`
  - `ScoutCoder -> /bulk/mvazque2/git/AgentSuite/ScoutCoder`
  - `Semantics -> /bulk/mvazque2/git/AgentSuite/Semantics`
  - `Workspace -> /bulk/mvazque2/git/AgentSuite/Workspace`
  `git cat-file` confirms the absolute paths are stored in git (introduced by
  commit `6a3ec78`, "Wiring: Agent/ agent namespace, tool provisioning,
  workflows and etc symlinks (Phase 4)"). All five RESOLVE on this machine
  because `/bulk/mvazque2/git/AgentSuite` exists; `/home/mvazque2/git/
  AgentSuite` does NOT. **Any clone at another path breaks all five.**
- Disposition: delegate (ScoutCoder/Manager own tracked symlinks; relative
  targets like `../Cortex` would fix it). Not touched in v9 — no row
  authorized it.
- Action if launching from another host: re-point the five symlinks (v9
  launch checklist item (b)); a durable relative-target fix is a separate
  change request.

## 4. User-owned decision items (carried from v9 final report)

- Merge doctrine-v9 → main, or keep the branch (checklist item (a); rollback
  point 46433830).
- `Priest/` untracked directory appeared after the last v9 commit; no v9 row
  owns it — repo-hygiene decision (keep/discard/assign owner).
- ChatAnalyst gitlink sits ahead of its parent pin (parent 25f423a; submodule
  HEAD 2bbc1e9, clean descendant adding `import:
  Agent/doctrines/scientific_investigation`) — trivial future bump, outside
  v9 ownership.
