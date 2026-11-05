# Delegation packet — epistemic-API schema work (from doctrine-v9)

Recipient: epistemic-record API owner (Semantics/record store). Source:
doctrine-v9 evidence register + d8 process x-ray; all d8 figures inlined
from `AGS.full.scout.science.v2.doctrine8_66c09b60223d3f876df84a64ab42584c/
AGS/process_xray/doctrine8_process_xray.md` §4/§8 (read-only export).

Value context (inline): the epistemic surface **paid** in d8 — 49/49 records
cited downstream, 11/11 corrections caught pre-consumption (each would have
corrupted a decision input), ≥4 adjudication outcomes changed by
pre-registered predictions and record evidence. The defects below did not
destroy that value, they limited it; the "preserve" verdict is now
conditional on this schema work (v9-evidence-register.md §3).

---

## 1. Missing `supported_qualified` enum value

- Evidence (inline): d8 F-E2 — missing enum value caused 5/10 decision records
  to split status vs assessment fields; all five user schema suspicions were
  VERIFIED against the store.
- Root cause: the status vocabulary lacks the value agents actually needed
  ("supported with qualifications"), so they encoded it in a free field.
- Requested change: add `supported_qualified` to the status enum; migration
  for the 5 split records.
- Acceptance test: a record can be registered `supported_qualified` and
  round-trips with status==assessment (no split).

## 2. Open `evidence_tier` vocabulary conflates measured and derived

- Evidence (inline): d8 F-E4 — a measured-in-this-experiment tier was applied
  to RNA-derived TF activity/onset quantities in 16/39 observations.
- Root cause: `evidence_tier` is free-text; no constraint distinguishes
  directly measured quantities from derived ones.
- Requested change: closed tier vocabulary + a measured/derived flag (or two
  fields); validate at registration.
- Acceptance test: registering a derived quantity with a
  measured-in-this-experiment tier is rejected or warned.

## 3. No delete/retire; disposable namespace

- Evidence (inline): d8 F-E5 — a disposable probe record could not be deleted
  and remained citable.
- Requested change: delete or retire lifecycle + a `disposable` namespace
  whose records are excluded from citation surfaces.
- Acceptance test: a record marked disposable does not appear in citation
  lookups; a retired record shows retired status to consumers.

## 4. Record title lifecycle

- Evidence (inline): d8 F-E3 / C-005 — the record title contradicted the
  Lead's own ruling (phospho ban) and could not be forced to match it.
- Root cause: titles are write-once; adjudication has no path to correct a
  title that the ruling supersedes.
- Requested change: title edit on adjudication, with provenance (old title
  retained in history).
- Acceptance test: after a Lead ruling, the record title can be updated and
  the history shows both titles with the ruling reference.

Register rows behind these items: d8 P1-3 (ledger-Y; the AgentSuite-side
half, CL-08 contract-input vocabulary before Gate-1, is already implemented
on doctrine-v9); schema enum work intentionally delegated here.
