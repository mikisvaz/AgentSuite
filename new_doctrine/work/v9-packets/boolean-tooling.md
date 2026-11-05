# Delegation packet — Boolean tooling (from doctrine-v9)

Recipient: Boolean/Gene workflow owner. Source: doctrine-v9 evidence register
+ d7/d8 x-ray; figures inlined from
`AGS.full.scout.science.v2.doctrine8_66c09b60223d3f876df84a64ab42584c/AGS/
process_xray/` (H-004 branch analysis, friction register F1–F3) and the d7
friction register. d8 run context: MCF7 drug-combination mission; H-004 was
closed indeterminate-capability-blocked after its native Boolean route failed
at scale.

## 1. Timeout as a first-class input

- Evidence (inline): H-004 — 8 SIGTERM kills at ~3600 s each, ≈7 h wall
  consumed on the branch, 8.3–9.3M tt avoidable (d8 h004_branch_analysis.md
  §3–4; P0-1 evidence). Kills were engine-side; success of the route would
  not have averted them.
- Root cause: the tool's timeout is not an input agents can set to match the
  workload; the effective ceiling came from an unmanaged external limit.
- Requested change: explicit `timeout` input on Boolean tasks, validated and
  honored, with the effective timeout echoed in job `.info`.
- Acceptance test: a Boolean task dispatched with timeout=600 finishes or
  fails by 600 s with the timeout recorded in `.info`.

## 2. Kill attribution in `.info`

- Evidence (inline): d8 F1 — the SIGTERM sender was never identified: no
  workflow timeout was configured, no framework reaper claimed it, no cgroup
  evidence available; attribution is still open.
- Requested change: record kill metadata (signal, sender or "unknown",
  timestamp) in the job's `.info` at kill time.
- Acceptance test: a killed Boolean job's `.info` names the signal and either
  the sender or an explicit unknown marker.

## 3. MaBoSS cfg dialect mismatches

- Evidence (inline): d7 RM-14/FR-06 — two MaBoSS cfg dialect failures before
  convergence, plus a dangling symlink blocking re-run; d8 F2/F3 — task
  defects surfaced the same evening via OBS-014/D6.
- Root cause: the accepted cfg dialect is undocumented; error messages do
  not name the offending construct.
- Requested change: document the dialect in the task docstring; reject
  invalid dialect with a line-numbered error.
- Acceptance test: a cfg in the wrong dialect fails immediately with a
  message naming the line; a documented example runs.

## 4. Unmeasured external 3600 s job killer — investigation request

- Evidence (inline): 8 kills clustered at ~3600 s across H-004; no component
  in the stack has been shown to own a 3600 s limit (no workflow timeout, no
  framework reaper, no cgroup evidence found by the x-ray).
- Requested: harness/host instrumentation to identify the killer (cgroup
  `memory/events`, systemd slice limits, batch scheduler). This is an open
  investigation, not a code change; its result decides whether item 1's
  timeout input can even be honored above 3600 s.
- Acceptance test: a documented identification of the sender with evidence
  (which component, which config), or a verified absence at a named layer.

Register rows: d8 P0-1 (AgentSuite half — pre-dispatch scale-probe rule —
implemented on doctrine-v9 as CL-10; the timeout-input half is this packet),
F1–F3, d7 RM-14/FR-06, RM-15/FR-07 (Gene stack, quarantined by instruction).
