# return_path migration (R13) — inventory, actions, verification

Migration bout for the citation contract's rule R13
(`research/return-path-citation-contract.md`; fact base
`research/return-path-probes.md`). Scope: migrate incumbent Research
records whose only defect is AGS-style relative receipt anchoring to
absolute sandbox paths, original key preserved in the migration note;
leave everything else untouched; verify the sandbox stayed pristine.

## Inventory (the migration baseline)

Full enumeration of `var/records/<kind>/*.yaml` for all three kinds
(observation, claim, hypothesis) through the real `validate_path`, plus a
checkout-wide search for record bodies and AGS-citing refs outside the
record store. Quoted outcomes:

- `find var/records -name "*.yaml"` → **no output**; `ls var/records/` →
  **empty** (the directory does not even exist yet — `var/` holds only
  `cortex/` and `jobs/`).
- Inventory run through `Research::PathKinds.validate_path` over all
  three kind roots: **`records=0 sources=0`**.
- Checkout-wide searches, all empty:
  `find . -name "OBS-*.yaml" -o -name "C-*.yaml" -o -name "H-*.yaml"`
  (no record bodies outside `var/records`), `grep -rl "var/entity_property"`
  over yaml/json/md (no AGS-citing refs anywhere in the checkout outside
  this research/ documentation), `grep -rl "OBS-10[0-9]"` (no OBS-010,
  OBS-105/106/107 mentions anywhere).

**Inventory conclusion: the Research record store holds zero incumbent
records. There is nothing to migrate.**

### The design-conversation examples have no live counterpart

The user's authoritative design conversation
(`/home/mvazque2/.inbox/Roma/Analysis commentary2.md`, quoted in the probe
appendix) cites an OBS-010-style record with
`ref: var/entity_property/Timepoint/active_tfs/[...]` and three
observations-ledger.md lines OBS-105/106/107. Searches for their live
counterparts:

- **OBS-010 record**: absent. No `OBS-010` (or any `OBS-*.yaml`) exists
  anywhere in the Research checkout or its `var/records` (evidence above).
- **observations-ledger.md**: absent.
  `sandbox/artifacts/ags/observations-ledger.md` does not exist
  (`File.file?` → false; the probe bout had already recorded this, and the
  recheck confirms it).
- **AGS-style relative refs**: absent from every record (there are no
  records) and from every non-research file in the checkout.

These examples were verbatim migration *illustrations* in the design
conversation, not existing records; the migration contract (R13) was
written against a store that turns out to be empty today.

## Migrations applied

**None.** R13's anchoring arm has no target: broken-by-anchoring refs
found = 0, already-valid records = 0, other-broken refs = 0. No CAS edit
was made, so no edit receipts exist.

## Verification

- **Record validation**: vacuously green — zero records, zero sources;
  `validate_path` has nothing to report on.
- **Fresh-process reads of cited absolute paths**: vacuous — no record
  cites any path.
- **Sandbox integrity**: receipt-leaf count under
  `sandbox/var/entity_property/` = **417**, exactly the probe baseline
  (the probe counted "receipt files": 417 leaf entries; 411 extensionless
  Marshal payloads plus 6 `".5h\"]"`-suffixed variants — same population,
  same count). Newest mtime under that tree is 2026-10-24 20:12:23 +0200,
  predating every bout of this implementation (first probe bout ran
  2026-10-25), so nothing this line of work wrote there. The `.files`
  sidecar and job tree are otherwise untouched. One incidental finding,
  recorded not acted on: the sandbox is *writable* by the running user
  (a write probe succeeded and was immediately deleted); the read-only
  posture is a discipline, not a filesystem fact. Nothing in this bout
  wrote to it.
- **Layer self-check**: because there are no incumbent records to migrate,
  the migration-specific behavior (AGS receipt tree recognized as a
  durable named store, absolute AGS paths validate warning-only) is
  exercised only by the unit suite, not by live migrated records. The
  next record registered against an AGS receipt will be the first real
  instance.

## Unresolvable items

None, in the sense of R13: nothing was found that *should* have been
migrated but could not be. The genuinely open items are the absences
documented above (no ledger file, no OBS-010, no incumbent records), which
are facts about the environment, not defects in the layer or the contract.

## What this means for the citation rollout

The contract lands on an empty store: every future record is born under
the new rules, and R13's absolute-migration arm becomes a contingency for
records that may be created *elsewhere* (e.g. AGS-side records that later
move into Research) rather than a repair of present data. The migration
mechanism (cite absolute, preserve the original key in the migration note)
remains specified and implemented-ready; it simply has no live call yet.
