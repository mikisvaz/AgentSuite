# Phase 7 resume packet — AGS route pilot (mission foxo-pi3k)

Written at close of the Phase 7 bout. Everything needed to continue lives at
durable paths; this packet only points at them.

## Mission decision
SURROGATE (sanctioned). Evidence: `tmp/ags-pilot/AGS_REACHABILITY.txt` —
`/bulk/mvazque2/git` holds only AgentSuite, scout-ai, scout-essentials,
scout-gear; no AGS checkout; `cortex_path_map.yaml` has no AGS entry and its
declared maps (`~/git/workflows/...`) do not exist from this sandbox.
Recorded by Research in `ags/foxo-pi3k/mission.md` (mode: sanctioned surrogate).

## Completed (all stages 1-8 + gate + final report)
- Stage map with conversation and artifact paths: Cortex artifact
  `ags/foxo-pi3k/reports/final.md` (sections "Stages completed", "Lead review
  outcome", "Critic verdict", "Stop condition", "Deviations").
- Mission record set: 12 mission artifacts under `ags/foxo-pi3k/` (mission,
  questions/, evidence/, reports/), all with `.info` provenance sidecars.
- Conversations: `ags-foxo-pi3k`, `ags-foxo-pi3k-record`, `ags-foxo-pi3k-lead`,
  `ags-foxo-pi3k-q1|q2|q3`, `ags-foxo-pi3k-critic`.
- Launch logs (stdout per turn): `tmp/ags-pilot/runlogs/` (`ags-foxo-pi3k*.log`).

## Remaining
- None for the mission itself (S1 sufficiency declared, Critic PASS, status
  `answered`).
- Open for the pilot (route-level, not mission-level): see the pilot report
  `new_doctrine/work/redesign-pilot-report.md` § Open issues.

## Resume paths
- Facts scratch (pinned, cite sources not the scratch): `tmp/ags-pilot/FACTS.md`.
- Verbatim Lead outline / review / Critic verdict copies used for verification:
  `tmp/ags-pilot/lead_outline_reply.md`, `tmp/ags-pilot/lead_review_reply.md`,
  `tmp/ags-pilot/critic_reply.md`.
- Launch helper (stale-claim clearing + env): `tmp/ags-pilot/launch_role_turn.sh`.
- Drift baselines: `tmp/ags-pilot/DRIFT_START.txt`, `tmp/ags-pilot/DRIFT_END.txt`.
