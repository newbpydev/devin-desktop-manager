# Legacy Installation Recovery - Issues Workorder

**Feature ID:** `legacy-installation-recovery`  
**Status:** Planning complete - implementation evidence pending  
**Evidence scope:** Planning findings only; no implementation test is recorded as run  
**Owner:** Implementation agent and repository maintainer  
**Linked plan:** `docs/plans/2026-08-09-001-fix-legacy-installation-recovery-plan.md`  
**Workflow test:** `docs/user-workflows-test-plans/legacy-installation-recovery-user-workflow-test.md`

## Purpose

This is the canonical ledger for plan-review findings and later implementation, verification, hosted, and manual defects. A planning decision is `Planned`, not `Fixed`: it becomes `Fixed` only after its named implementation and retest evidence passes. New defects must be logged before they are changed, and unresolved work cannot be hidden in review sign-offs.

## Status Definitions

| Status | Meaning |
|---|---|
| Open | The planning or implementation issue is unresolved and has an owner/next action. |
| Planned | The canonical planning pack contains the decided correction; implementation and retest remain pending. |
| In progress | Implementation or verification is actively addressing the issue. |
| Fixed | The correction exists and the named focused/aggregate evidence has passed. |
| Blocked | External evidence or authority is unavailable; owner, blocker, revisit condition, and acceptance are recorded. |
| Accepted | The user explicitly accepts the remaining risk with rationale and follow-up. |

## Issue Register

| ID | Source | Owner / lens | Severity | Status | Impact | Next action | Retest / evidence |
|---|---|---|---|---|---|---|---|
| LIR-ISS-001 | Reported host / U1-U2 | Plan architecture, correctness | P0 | Planned | Valid initial-manager users cannot update, reinstall, or uninstall. | Implement the exact `initial-complete` classifier and lifecycle branch. | LIR-U1-R01; LIR-U2-R01 through LIR-U2-R04; LIR-WF-002 through LIR-WF-005 |
| LIR-ISS-002 | Document review / U1 | Ownership security | P1 | Planned | A marker-only desktop proof could authorize deletion of a modified executable entry. | Implement the role-specific non-executing semantic parser and near-miss corpus. | LIR-U1-R04; LIR-WF-007 |
| LIR-ISS-003 | Document review / U1-U2 | Security, data integrity | P1 | Planned | Effective legacy IDs alone do not prove which user MIME file can be reversed; Added Associations could remain stale. | Implement the three-file provenance matrix, exact-ID cleanup, re-query, and transaction restore. | LIR-U1-R06; LIR-U2-R08; LIR-WF-006 |
| LIR-ISS-004 | Document review / U1-U3 | Plan architecture, maintainability | P1 | Planned | Separate predicates and prose diagnostics can accept one profile while explaining another. | Centralize fixed classifier globals/reason codes and one renderer. | LIR-U1-C01 and LIR-U1-R01 through LIR-U1-R06; LIR-U3-R01/R03 |
| LIR-ISS-005 | Code trace / U2 | Reliability, desktop lifecycle | P0 | Planned | Current post-link migration marks active releases before the app-stopped gate. | Gate every active recognized profile before marker/metadata mutation. | LIR-U2-R05; LIR-WF-008 |
| LIR-ISS-006 | Reported doctor output / U3 | CLI interaction, reliability | P1 | Planned | Doctor emits seven derivative failures, while its unlocked diagnosis must never become mutation authority. | Classify first, render one recovery result, and make lifecycle commands reclassify under lock without consuming doctor state. | LIR-U3-R01/R04/R06; LIR-WF-001/010/011 |
| LIR-ISS-007 | Ultrathink recovery audit / U2 | Reliability, data migration | P1 | Planned | Marker/metadata and transaction interruption windows need executable retry oracles. | Add exact-call failure hooks and same-command recovery tests at every named boundary. | LIR-U2-R06/R07; LIR-WF-009 |
| LIR-ISS-008 | Scope/test review / U4 | Portability, test strategy | P1 | Planned | A focused compatibility filter can false-green or a new workflow could duplicate suite ownership. | Extend the existing non-empty runner selection only; retain the four existing job owners. | LIR-U4-R01/R02; LIR-WF-013 |
| LIR-ISS-009 | Release audit / U4 | Documentation, release | P1 | Planned | Users with the broken `0.1.0` manager need fixed source before recovery; old `update` cannot update the manager itself. | Document verified `0.1.1` source/manager bootstrap and preserve manual publish authority. | LIR-U4-R03/R04/R06; LIR-WF-014 |
| LIR-ISS-010 | Review correction / U4 | Manual acceptance | P1 | Planned | A live rollback check could leave the affected machine on the old release and conflate local/hosted/manual evidence. | Run rollback twice, leave the new release current, and record evidence tiers separately. | LIR-U4-R05; LIR-WF-015/016 |
| LIR-ISS-011 | Coherence/scope review / U3-U4 | Scope guardian, maintainability | P2 | Planned | Shared documentation/workflow ownership could cause duplicate edits and unnecessary CI churn. | Keep all prose/version work in U4 and treat `.github/workflows/ci.yml` as inspection-only unless a red test proves otherwise. | File ownership review; LIR-U4-R03/R06 |

## Issue Details

### LIR-ISS-001 - Complete Initial-Manager Profile Is Deadlocked

- **Phase found:** Reported behavior and planning investigation.
- **Affected:** R1-R11; U1-U2; LIR-WF-002-005.
- **Evidence:** The affected host passes release/root/cache/state/link/integration predicates and fails only because `legacy_post_link_defaults_are_unclaimed` rejects the legacy IDs written by the initial manager.
- **Expected:** A provably manager-created complete legacy layout self-heals through normal lifecycle commands.
- **Planning correction:** Add `initial-complete` without weakening existing state-less modern-default rejection.
- **Closure evidence:** Focused classifier and every public lifecycle flow green; aggregate ownership/transaction suite green.

### LIR-ISS-002 - Desktop Marker Is Insufficient Deletion Authority

- **Phase found:** Security document review.
- **Affected:** R2/R4; U1; LIR-WF-007.
- **Evidence:** Current `legacy_desktop_owned` checks only regular-file type and one marker line; command, role, icon, MIME, duplicates, and extra executable sections are not proven.
- **Expected:** Only the shipped initial-manager semantic role can authorize adoption/removal.
- **Planning correction:** Parse but never execute content; require the exact main/URL semantic table and reject every executable ambiguity.
- **Closure evidence:** LIR-U1-R04 near-miss matrix plus security review of the parser.

### LIR-ISS-003 - Legacy Default Provenance And Cleanup Are Incomplete

- **Phase found:** Security, feasibility, and data-integrity review.
- **Affected:** R2-R4/R9-R11; U1-U2; LIR-WF-006.
- **Evidence:** `query_default` returns only the effective desktop ID, while current transaction/remove helpers own three generic user MIME files and rewrite only Default Applications. The affected host also contains Added Associations.
- **Expected:** Adoption proves a reversible manager write and leaves no stale manager association in owned files while preserving unrelated order/content.
- **Planning correction:** Require traceability to the three transaction-owned files, reject desktop-specific manager IDs, clean exact legacy IDs from Default/Added, re-query, and restore on mismatch.
- **Closure evidence:** LIR-U1-R06 and LIR-U2-R08 with byte-identical failure snapshots.

### LIR-ISS-004 - Classification And Explanation Can Drift

- **Phase found:** Coherence and maintainability review.
- **Affected:** R5/R12-R14; U1/U3.
- **Evidence:** Existing migration combines several boolean helpers into generic branch errors; doctor independently validates modern paths and state.
- **Expected:** One complete predicate determines both authorization and bounded explanation.
- **Planning correction:** Fixed classifier globals, stable reason codes, one renderer, no duplicated doctor ownership rules.
- **Closure evidence:** Identical fixtures map to consistent lifecycle/doctor reasons in LIR-U1 and LIR-U3.

### LIR-ISS-005 - Active-App Gate Runs Too Late

- **Phase found:** Live code sequencing trace.
- **Affected:** R7-R8; U2; LIR-WF-008.
- **Evidence:** Current post-link/no-state handling sets `pre_activation=true`, so `require_app_stopped` is skipped inside migration until after metadata/marker work.
- **Expected:** An active linked legacy release is stopped before any adoption mutation.
- **Planning correction:** Return `LEGACY_REQUIRES_APP_STOP=true` for every active profile and enforce it immediately after locked classification.
- **Closure evidence:** LIR-U2-R05 snapshot covers marker, metadata, journal, state, defaults, and integration.

### LIR-ISS-006 - Doctor Hides Root Cause And Is Advisory

- **Phase found:** Reported output and design/reliability review.
- **Affected:** R12-R14; U3; LIR-WF-001/010.
- **Evidence:** Doctor checks only manager-specific integration/state and reports seven symptoms for the valid legacy shape; it runs without lifecycle mutation locks.
- **Expected:** One recoverable diagnosis that never becomes mutation authority.
- **Planning correction:** Shared classifier first, direct command guidance, no persisted doctor token, and locked lifecycle revalidation. A full fingerprint subsystem was rejected as unnecessary because doctor does not mutate.
- **Closure evidence:** LIR-U3-R01/R04/R06 and no-mutation snapshots.

### LIR-ISS-007 - Recovery Windows Need Deterministic Oracles

- **Phase found:** Ultrathink failure-path audit.
- **Affected:** R8/R11/R15-R16; U2; LIR-WF-009.
- **Evidence:** The plan names marker, metadata, transaction, association, state, activation, prune, and uninstall cleanup boundaries; unsynchronized process timing would not prove them.
- **Expected:** Each boundary has a deterministic fail-on-call or readiness barrier and same-command retry oracle.
- **Planning correction:** Reuse existing failure hooks/barriers and snapshot every durable publication state.
- **Closure evidence:** LIR-U2-R06/R07 selects and passes without sleeps as correctness oracles.

### LIR-ISS-008 - Portability Must Not False-Green Or Duplicate CI

- **Phase found:** Scope and test-strategy review.
- **Affected:** R15-R16; U4; LIR-WF-013.
- **Evidence:** The existing runner has a fixed regex plus explicit zero-selection failure, and every existing job already calls it.
- **Expected:** New recovery tests participate in all focused lanes without another workflow/full-suite owner.
- **Planning correction:** Extend the runner filter and repository assertions; change CI YAML only if a red test establishes necessity.
- **Closure evidence:** LIR-U4-R01/R02, runner non-empty output, and the four hosted jobs at one SHA.

### LIR-ISS-009 - Broken Manager Cannot Bootstrap Its Own Fix

- **Phase found:** Release/documentation audit.
- **Affected:** R17-R19; U4; LIR-WF-014.
- **Evidence:** `update` updates Devin Desktop, not the manager binary; the reported `0.1.0` binary contains the refusal.
- **Expected:** Affected users first execute verified fixed source or install the fixed manager, then run lifecycle recovery.
- **Planning correction:** Versioned `0.1.1` install/upgrade/support/release guidance with unchanged schemas and manual publish authorization.
- **Closure evidence:** LIR-U4-R03/R04/R06 and documentation journey.

### LIR-ISS-010 - Live Acceptance Needs A Safe Final State

- **Phase found:** Coherence and manual-evidence review.
- **Affected:** R19; U4; LIR-WF-015/016.
- **Evidence:** A single rollback after successful update would intentionally leave the affected host on the previous release.
- **Expected:** Rollback is proven without undoing the user's final upgrade, and destructive uninstall is isolated elsewhere.
- **Planning correction:** Roll back twice on the affected host; run uninstall only in the disposable environment; keep local/hosted/manual records distinct.
- **Closure evidence:** Recorded current/previous labels before update, after update, after each rollback, and final healthy doctor.

### LIR-ISS-011 - Unit And Workflow Ownership Must Stay Narrow

- **Phase found:** Coherence and scope review.
- **Affected:** U3-U4 and file ownership contract.
- **Evidence:** The first draft assigned `SUPPORT.md` to both diagnostics and release units and listed CI YAML despite the existing runner handoff.
- **Expected:** One prose owner and the minimum changed file set.
- **Planning correction:** U4 solely owns docs/versioning; existing workflow calls are inspection-only.
- **Closure evidence:** Final diff/file-ownership review and LIR-U4 repository-policy scenarios.

## Planning Review-Lens Sign-Offs

These sign-offs mean the planning pack was reviewed for decision completeness. They do not mean code, tests, CI, manual acceptance, or release work is complete.

| Lens | Planning status | Evidence checked | Findings / reopen condition |
|---|---|---|---|
| Plan architecture and sequencing | Reviewed | Classifier interface, lock/app-stop/migration/transaction order, file ownership | LIR-ISS-001/004/005/011; reopen if lock or schema boundaries change. |
| Product and scope | Reviewed | Universal exact-profile recovery, explicit exclusions, no force repair/CI expansion | LIR-ISS-008/011; reopen if broader adoption or platforms enter scope. |
| Correctness and reliability | Reviewed | Nil/absent/empty/error paths, retry, interruption, doctor race, idempotency | LIR-ISS-001/005-007/010. |
| Test strategy and evidence | Reviewed | Stable scenario IDs, red-first commands, snapshots, focused-to-aggregate tiers | LIR-ISS-007/008; implementation evidence pending. |
| Ownership security and privacy | Reviewed | Desktop semantic proof, MIME provenance, bounded diagnostics, no content leakage | LIR-ISS-002/003. |
| Data integrity and migration | Reviewed | Default normalization, exact cleanup, transaction restore, schema compatibility | LIR-ISS-003/005/007. |
| CLI interaction and accessibility | Reviewed | Direct/Make statuses, streams, actionable recovery, plain-text bounded output | LIR-ISS-004/006. |
| Desktop lifecycle and portability | Reviewed | App-running gate, XDG roles, native/container evidence boundary, four existing lanes | LIR-ISS-005/008/010. |
| Documentation and release | Reviewed | Fixed-source bootstrap, `0.1.1`, schema stability, separate publish authority | LIR-ISS-009/010. |
| Simplicity and maintainability | Reviewed | One in-file classifier, one renderer, no repair command/framework/new CI owner | LIR-ISS-004/011. |

## Execution Log

| Date | Phase | Command / workflow | Result | Issues | Evidence |
|---|---|---|---|---|---|
| 2026-08-09 | Planning investigation | Read-only affected-host fingerprint and live code/test trace | Root cause identified; no product mutation | LIR-ISS-001/003/005/006 | Current planning session and linked plan sources |
| 2026-08-09 | Headless document review | Coherence, feasibility, design, security, scope, adversarial lenses run sequentially | Three certain plan corrections applied; deep findings recorded | LIR-ISS-002-004/010/011 | Canonical plan diff and issue details |
| 2026-08-09 | Plan Ultrathink | CLI, migration, operations, desktop, docs, and mixed-system deepening | Planning decisions and companion artifacts complete; implementation pending | LIR-ISS-001-011 | Linked plan and workflow test plan |

## Implementation And Release Gate

Leave every item unchecked during planning.

- [ ] Planned units implemented red-first in dependency order.
- [ ] Every named focused test passes for the intended reason.
- [ ] Aggregate `make verify` and locked coverage pass.
- [ ] Portability selection is non-empty and all existing hosted lanes pass at one head.
- [ ] `0.1.1` release-check and deterministic package pass with unchanged schema constants.
- [ ] Affected-host and disposable-environment workflows are manually accepted and separately evidenced.
- [ ] Every Planned issue is Fixed by its named evidence, or an explicit user-accepted blocker is recorded.
- [ ] Remaining unaccepted Open/Blocked P0/P1 issues: 0.
- [ ] No tag, push, merge, draft release, or publish occurs without separate authorization.
