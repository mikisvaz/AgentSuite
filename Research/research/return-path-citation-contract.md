# Research citation contract: what a source ref promises

Status: authoritative contract for Research record sources. This document
supersedes nothing in the schemas; it defines the semantics the schema layer
(lib/Research/path_kinds/records.rb, next bout) must enforce. Fact base:
research/return-path-probes.md (facts (a)-(d), all validated). Intent
authority: the user's design conversation quoted in that file's appendix.

Terminology:
- **execution layer** — the tool-dispatch machinery (scout-ai
  `lib/scout/llm/tools/workflow.rb`) plus the Scout job system it drives.
- **result ref** — the `ref` string of a Research source entry, plus its
  optional `locator` and `digest`.
- **job tree** — a persisted Scout job directory: a result file
  (`<job>.json`, `<job>.yaml`, `<job>.tsv`, ...) with an adjacent `<result>.info`
  and optional `<result>.files/` sidecar, rooted at `var/jobs/<Workflow>/<task>/`
  of some Scout root (checkout or user-global `~/.scout/var/jobs`).
- **durability** — resolvability and readability of the cited artifact after
  the producing process has ended.

Every rule carries its enforcement locus:
- **registration-time hard error** — `register`/`edit` reject the record;
- **registration-time warning** — recorded in the returned `warnings`; the
  record is created;
- **migration-time** — applies only while translating pre-contract records;
- **deferred** — a promise we do not yet make; listed with the reason.

---

## 1. The five citation properties (rules C1-C5)

Each property from the design conversation becomes one testable rule about a
registered source ref.

**C1 — Identity.** A result ref identifies one particular result, not a tool
name, task name, or property name.
- Promise: the ref, after resolution, names one concrete artifact (a job
  result file, a file inside its `.files/` tree, or a named durable file).
  Two different executions never resolve through the same durable ref.
- Test: ref resolves to an existing file (R7); a ref naming a directory or a
  bare tool/task name fails resolution; a resolvable-but-scratch path fails
  the durability arm (R10) and the lifetime promise (C2).
- Locus: registration-time hard error (unresolvable ref), registration-time
  warning (resolvable but no digest — see C4).

**C2 — Lifetime.** A registered record does not silently lose its source when
the execution that produced it ends.
- Promise: the cited artifact is on persistent storage at registration and
  carries no promise of later cleanup by the execution layer; nothing in the
  citation workflow may delete it.
- Test: at registration the ref resolves (existence check, R7); refs that
  resolve only inside the producing process (in-memory results, `TmpFile`
  scratch) are classified temporary and hit the promote-or-reject rule (R10).
- Locus: registration-time hard error (ephemeral ref, after the
  promote-or-reject remedy fails or is declined).

**C3 — Inspection.** A downstream agent can retrieve the cited result through
ordinary tools (Workspace read, tsv_* tasks, chat job read) given only the
record.
- Promise: `ref` (+ `locator` when present) is sufficient for an agent with
  ordinary read access to the host tree to recover the bytes; the record never
  requires the producing process, a special API, or the original chat.
- Test: resolvability by plain filesystem resolution (R7); jobs are readable
  from a fresh process (proven by probe (b): the non-exec run's `.json` +
  `.json.info` persisted and are ordinary files).
- Locus: registration-time hard error (unresolvable), registration-time
  warning (resolvable but outside every whitelisted read root — recorded so a
  later tool failure is explainable).

**C4 — Integrity.** The system can detect whether the referenced result
changed, when the backend exposes a content digest.
- Promise: if `digest` is recorded, it is a hex digest of the cited FILE's
  bytes at registration; verification is byte-identity of that file.
  What a digest proves and does not prove is fixed by R12.
- Test: digest present ⇒ recomputing the file digest at validation matches;
  mismatch is a hard error at `edit`/`validate` time (the record cites
  content that no longer exists as cited).
- Locus: registration-time warning (no digest recorded); registration-time
  hard error on `edit`/`validate` when a recorded digest mismatches (R12).

**C5 — Backend independence.** The ref need not be a filesystem path tied to
one engine; the persistence backend may use another locator.
- Promise: the contract is stated over "resolvable locators". Today the only
  concrete form is a filesystem path (the general case the execution layer
  already returns). No rule in this contract forbids a future
  `backend: '<engine>:<key>'` form, and no Research rule may assume the ref
  is digest-addressable storage owned by Research.
- Test: all rules below are stated on "resolve(ref) → file or locator"; only
  R7 (anchoring/existence) touches concrete path grammar.
- Locus: deferred (the `backend:` locator form is not implemented; the
  execution layer returns filesystem paths today, per probe (b)).

---

## 2. Ref grammar for `tool_result` (rules R6-R9)

**R6 — Source type `tool_result` is added, general, and preferred.**
`tool_result` cites "the persisted result of any tool invocation". It is the
default type for new evidence refs. It carries no domain semantics: no entity
names, no property vocabulary, no AGS-specific anything.
- Locus: schema change next bout (`LOCAL_SOURCE_TYPES` gains `tool_result`;
  see R14 for compatibility).

**R7 — Ref grammar and anchoring.** A `tool_result` `ref` MUST be one of:
1. an absolute path to a file that exists (e.g.
   `/home/mvazque2/.scout/var/jobs/Semantics/entity_property/Default_<md5>.json`),
   or
2. a relative path, anchored (as today) at the Research checkout root
   (`PATH_KIND_ROOT`), resolving to an existing file.
The ref points at the durable result the execution layer returned — the
receipt's `job.path` (`.json`/`.yaml`/`.tsv` result file) or a file it
designates inside its `.files/` tree (e.g. `.../Default_x.json.files/property_output/abstracts.tsv`).
A ref naming a directory is not a result ref; it must name a file.
- Locus: registration-time hard error for anything that does not resolve to an
  existing file (today's `broken reference` error, unchanged shape).

**R8 — Locator: exactly one minimal form.** `locator` for a `tool_result` is
optional and, when present, is a single string of one form:
`kind:value` where kind ∈ {`row`, `range`, `line`, `section`}.
- `row:<key>` — one keyed row of a tabular result;
- `range:<a>-<b>` — an inclusive span (rows, lines, or elements);
- `line:<n>` — one line of a text result;
- `section:<name>` — one named section of a structured result.
Anything else (JSON selectors, XPath, page numbers) is out of scope; an
unparseable locator is a hard error, an unused-but-well-formed locator is not
checked against the content (that is assessment, not integrity).
- Locus: registration-time hard error on malformed shape; content-level
  correctness of the locator deferred (the validator does not parse result
  contents).

**R9 — One execution, one receipt.** The cited path must be the path returned
by the execution that produced the value the record relies on. Citing a
result obtained by a second, parallel invocation is a scientific misattribution
the schema cannot detect; the contract makes it operationally unnecessary:
non-exec dispatch returns value AND receipt in one call (probe (b):
`job.run` returned the JSON with `receipt.job.path` that exists on disk), and
the tool layer's `return_path` on a non-exec task returns that same
`job.path` (scout-ai `tools/workflow.rb:163-172`). The mechanism is the
non-exec export; exec-exported tasks answer `return_path` with a
`TmpFile.tmp_file` and must not be cited through it (R10 classifies it
temporary).
- Locus: contract-level (no validator can test which execution produced a
  path); the operational rule for tools is "cite the receipt path of the call
  you actually made". Enforced socially/by tool docs, not at registration.

---

## 3. Durability classification (rule R10)

**R10 — Three classes, promote-or-reject for temporary.**

Classification of a `tool_result` ref, by concrete path conditions from the
probes:

| class | concrete condition | treatment |
|---|---|---|
| **durable (job tree)** | resolves to a file, and its path is inside a persisted job tree: a `var/jobs/<Workflow>/<task>/<name>` directory where the job result (`<name>` with the result extension) and/or `<name>.info` exist on disk | accepted; digest warning per R12 |
| **durable (named store)** | resolves to a file inside an explicitly named durable store declared by Research (initially `var/records-attachments/` under the Research root, the promote target of R11) | accepted; digest warning per R12 |
| **temporary / ephemeral** | anything else that "works now": a `TmpFile` scratch path (`/tmp/...` from exec-mode `return_path`), an exec-mode in-memory result (no path at all), a file under an unpromoted `files_dir` scratch of a running process, or a file under a temp root (`/tmp`, `TmpFile.tmp_file` output) | **promote-or-reject**: the register/edit call must either (i) promote — see R11 — or (ii) be rejected with the actionable message of R11. Never silently accepted. |

- Locus: registration-time hard error when an ephemeral ref is submitted
  without promotion (the validator rejects, message per R11).

**R11 — The promote remedy.** Promotion means: copy the bytes of the
temporary artifact into the Research-side durable store
`<Research root>/var/records-attachments/<record-destination>/`, and cite
that copy as the ref (optionally recording the original scratch path in
`locator`-free provenance notes — the migration note mechanism of R13 is the
model; the record schema itself stays path-only). The copy is made by an
explicit, named promote operation on the `tool_result` source type (next
bout: a `promote` step inside register/edit, or a dedicated operation — the
contract requires only that it exists, is explicit, and copies bytes).
Rejection message, rendered verbatim as the contract specifies it:

```
sources[0]: ephemeral reference: "…/tmp/20261025-…/entity_property" is a
temporary artifact (class: temporary — resolves under a temp root or is an
exec-mode TmpFile result; it does not survive the producing process). Remedy:
promote the artifact into the durable store and cite the promoted path
(var/records-attachments/<…>), or re-run the tool in non-exec mode and cite
the returned job path (receipt.job.path). Ephemeral refs are never registered
silently.
```

- Locus: registration-time hard error with the message above when promotion
  is neither performed nor possible; the promote operation itself is
  implementation (next bout).

---

## 4. Anchoring and migration of legacy refs (rule R13)

**R13 — Anchoring is unchanged; migration cites legacy receipts absolute.**
Relative refs anchor to the Research checkout root (`PATH_KIND_ROOT`) exactly
as today (records.rb:934-939); absolute refs resolve as-is. Cross-checkout
case, stated explicitly: incumbent AGS receipt refs
(`var/entity_property/<Type>/<prop>/["…key…"]`) do NOT resolve against the
Research root (probe (d): `File.exist?(expand_path(ref, Research root)) ==
false`, `resolves as absolute AGS path: true`). Migration therefore:
1. cites the legacy receipt ABSOLUTE (the full AGS sandbox path), under
   `type: entity_property` (unchanged type, R14) or the new `tool_result`;
2. preserves the original relative key in the migration note attached to the
   record (the `.info` sidecar's migration field or the migration report
   file), NOT in the record schema — no new schema key is introduced for it;
3. introduces no AGS-specific rule into Research: the mechanism is the
   existing absolute-path arm of R7 plus the migration note. Any workflow's
   out-of-tree receipts migrate the same way.
- Locus: migration-time. Post-migration records are ordinary absolute refs
  under the standing rules.

---

## 5. Digest semantics (rule R12)

**R12 — What a digest proves.** A recorded `digest` is the hex content digest
of the cited FILE's bytes at the moment of registration. It proves: the bytes
cited then are the bytes seen now (byte-identity check at validation). It
does NOT prove: property-definition identity, execution identity, or input
identity — Scout `Persist` caches are keyed by identifier, not by code
(scout-gear CachingData.md, "Two things that are *not* part of cache
identity: code changes... two calls with the same identifier and completely
different blocks resolve to the same path"); a receipt file surviving with
identical bytes says nothing about whether the code that would regenerate it
changed. When to record: whenever the cited ref is a file the backend
produced (which is every `tool_result` and every local ref) — recommended,
and warned about when absent. Absence: warning, never an error (matches the
existing `mutable source has no recorded digest` warning). Mismatch at
`edit`/`validate`: hard error — the record cites content that changed.
- Locus: registration-time warning (absent); registration-time hard error
  (recorded digest mismatches at edit/validate — new check, next bout).

---

## 6. Validation vocabulary mapping (with rule R14)

Three states, aligned with the existing errors-vs-warnings discipline:

| state | concrete path condition (from the probes) | existing behavior | contract behavior |
|---|---|---|---|
| **broken reference** (hard error) | ref does not resolve to an existing file: relative foreign `var/jobs/...` against Research root (probe (d) case 1); absolute path to a deleted job; directory-only ref | today's `broken reference: "..." does not exist` error | unchanged, now also the arm that rejects non-`tool_result` local types that fail resolution |
| **unverifiable-but-durable** (warning) | ref resolves to a durable file but: no digest recorded; no locator for a `task`/`entity_property` source (existing `derivation may not be re-executable` warning); source type unknown-but-well-formed (opaque, not existence-checked) | warnings today | unchanged set + one new warning: digest missing on `tool_result` (R12) |
| **ephemeral reference** (promote-or-reject) | ref resolves NOW but is in a temp root (`/tmp`, TmpFile), or is an exec-mode in-memory result with no durable path, or sits under an unpromoted scratch `files_dir` | NOT detected today (a `/tmp` path would pass the existence check) | new classification arm of R10; hard error with the R11 remedy message unless promoted |

Plus the standing compatibility rule:

**R14 — Compatibility.** `entity_property`, `task`, `workflow`, `file`,
`external` keep their exact semantics; `tool_result` is ADDED to
`LOCAL_SOURCE_TYPES` semantics (existence-checked, digest-warned). Unknown
well-formed types remain warning-opaque. Existing records must keep
validating: no rule above re-classifies an existing registered source
retroactively (digest-mismatch at edit/validate is the only new hard error,
and it fires only on records that recorded a digest).
- Locus: schema/validator change next bout; this contract fixes the target
  behavior.

---

## What this contract deliberately does not promise

- A universal provenance registry (no global map of every execution; the job
  tree plus the receipt inside the result is the provenance).
- Invocation manifests (no stored argument sets beyond what the cited result
  already carries in its `.info`/receipt; the design conversation's
  "keep the source reference minimal" rule).
- Per-tool persistence policies (no contract obligation on tool authors;
  the three-state classification covers whatever a tool returns).
- Backend-specific locators (C5 deferred: filesystem paths only today).
- Locator-content verification (R8: shape-checked, not content-checked).
- Re-executability guarantees (R12: a digest pins bytes, not the code that
  produced them).

## Worked example

A `tool_result` source citing a Semantics `entity_property` job (non-exec;
probe (b) ran exactly this shape):

```yaml
sources:
- type: tool_result
  ref: /home/mvazque2/.scout/var/jobs/Semantics/entity_property/rp_probe_run_12c908504599acbbfb9ae02774b51b8d.json
  locator: row:W9
  digest: 6f1a…c93
```

Why each field passes: `ref` is absolute and resolves (R7); its directory is
a persisted job tree (`…rp_probe_run_….json` + `.json.info` both on disk —
probe (b) "NEW:" lines) so it classifies durable (R10 row 1); `locator` is
one well-formed `row:<key>` (R8); `digest` recorded (R12). The same record
with `ref: /tmp/20261025-…/exec_out` classifies ephemeral and is rejected
with the R11 message verbatim.
