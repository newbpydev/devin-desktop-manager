# Portable Make Commands - Issues Workorder

**Feature ID:** portable-make-commands  
**Status:** U8 implementation, test, and review findings resolved<br>
**Owner:** Implementation agent and repository maintainer  
**Linked plan:** `docs/plans/2026-07-27-001-fix-portable-make-commands-plan.md`  
**Workflow test:** `docs/user-workflows-test-plans/portable-make-commands-user-workflow-test.md`

## Purpose

This is the canonical issue ledger for plan review, implementation, testing, terminal workflow execution, and specialist review. Every defect must be logged here before it is fixed. An issue is `Fixed` only when its named retest evidence passes; unresolved work cannot be hidden in sign-off notes.

## Status Definitions

| Status | Meaning |
|---|---|
| Open | Reproduced or accepted finding; fix or retest incomplete. |
| Fixed | Fix is present and the required retest evidence has passed. |
| Accepted | Deliberately accepted by the user with rationale, owner, and follow-up. |

## Issue Register

| ID | Severity | Title | Owner / role | Status | Affected plan units | Required retest |
|---|---|---|---|---|---|---|
| PTU-001 | P1 | Generic output transaction framework exceeded product scope | Plan Architect / Scope Guardian | Fixed | U5-U7, removed U9 | PMC-U5-R01 through R04; PMC-U6-R03 through R04; PMC-U7-R01 through R04 |
| PTU-002 | P1 | First mixed-version manager publication could race the current manager | Reliability Specialist | Fixed | U4 | PMC-U4-R02, PMC-U4-R03, PMC-WF-011 |
| PTU-003 | P1 | Legacy `coverage/` and `dist/` had no adoption or cleanup path | Reliability Specialist | Fixed | U5-U7 | PMC-U5-R04, PMC-U6-R03, PMC-U7-R01 through R04 |
| PTU-004 | P1 | Extracted-source repackaging created an unnecessary release system | Scope Guardian / Security Specialist | Fixed | U6, U8 | PMC-U6-R01, PMC-U8-R06, PMC-WF-020 |
| PTU-005 | P1 | Public checkout-manager override made source identity ambiguous | Plan Architect / Code Quality Reviewer | Fixed | U1-U3 | PMC-U1-R02 through R04; PMC-U3-R01 |
| PTU-006 | P1 | Preflight records, lock transport, output APIs, and helper interfaces were underspecified | Plan Architect / Code Quality Reviewer | Fixed | U2-U7, U10 | PMC-U2-R04; PMC-U3-R01 through R07; PMC-U4-R03; helper/file contract review |
| PTU-007 | P0 | Units lacked independent red-first verification and stable scenario IDs | Test Strategist | Fixed | U1-U8, U10 | Per-unit filterable repository evidence; PMC-U8 R01-R07 |
| PTU-008 | P1 | Busy, partial-install, prompt, and cleanup-refusal outcomes lacked retry contracts | Interaction / Accessibility Specialists | Fixed | U3, U4, U7 | PMC-U3-R06; PMC-U4-R05, R07, R08; PMC-U7-R02; PMC-WF-012 through 015 |
| PTU-009 | P1 | Lock identity depended on mutable/cleanable namespaces and over-serialized unrelated checkouts | Plan Architect / Reliability / Security Specialists | Fixed | U4, U10 | PMC-U4-R02 through R03; PMC-U10-R01 through R03 |
| PTU-010 | P1 | Supported filesystem semantics were not defined | Reliability Specialist | Fixed | U5-U7, U10 | PMC-U10-R04 plus documented canonical filesystem floor |
| PTU-011 | P1 | Make values and startup hooks could alter recipe source or Bash behavior | Security Specialist | Fixed | U1, U3 | PMC-U1-R03 through R04; PMC-U3-R05; PMC-WF-003, 004, 008 |
| PTU-012 | P1 | Executable probe identity was not bound to execution identity or containment | Security Specialist / Test Strategist | Fixed | U2, U3 | PMC-U2-R02 through R04; PMC-U3-R02, R03, R07 |
| PTU-013 | P1 | Ambient curl policy could weaken runtime network behavior | Security Specialist | Fixed | U2 | PMC-U2-R05, PMC-WF-009, exact policy review |
| PTU-014 | P1 | Official release provenance and upload did not bind one immutable artifact set | Security / Reliability Specialists | Fixed | U6, U8 | PMC-U6-R02, R06; PMC-U8-R05; PMC-WF-021 |
| PTU-015 | P1 | Path corpus, diagnostic encoding/bounds, and same-UID threat boundary were ambiguous | Security / Accessibility Specialists | Fixed | U1-U3, U5-U8 | PMC-U1-R04; PMC-U2-R04/R06; PMC-U3-R06; PMC-U5-R05; canonical path matrix |
| PTU-016 | P1 | PTY, fault injection, package death, concurrency, and compatibility evidence were not executable | Test Strategist | Fixed | U3-U8, U10 | Named workflows plus PMC-U8-R01 through R04 and PMC-WF-025 |
| PTU-017 | P1 | Breaking Make entry changes lacked rollout and migration evidence | Scope Guardian / Documentation owner | Fixed | U1, U8 | PMC-U1-R03; PMC-U8-R01, R06; PMC-WF-026 |
| PTU-018 | P1 | Output sidecar names were not derived from canonical override roots | Plan Architect / Reliability Specialist | Fixed | U5-U7 | PMC-U5-R03; PMC-U6-R04; PMC-U7-R03/R04 |
| PTU-019 | P1 | Clean repaired one domain before validating both and lacked narrow owner APIs | Plan Architect / Reliability / Code Quality Reviewers | Fixed | U5-U7 | PMC-U7-R02/R04; coverage/package classify API review |
| PTU-020 | P2 | Make/direct status boundaries and repeated update/rollback oracles were incomplete | Interaction / Test Specialists | Fixed | U4 | PMC-U4-R05/R07/R08/R09; PMC-WF-011 through 015 and 027 |
| PTU-021 | P0 | Portability smoke filter and container command could false-green or remain unreproducible | Test Strategist / CI owner | Fixed | U8 | PMC-U8-R01 through R04; PMC-WF-025; all named portability jobs |
| PTU-022 | P1 | Paused shim timeout behavior was incomplete | Test Strategist | Fixed | U3-U7, U10 | PMC-U3-R08; PMC-WF-008 |
| PTU-023 | P1 | Implementation initially lacked U8 compatibility jobs, fixtures, and runner | CI owner / Plan Architect | Fixed | U8 | Red PMC-U8-R01 through R04, then green focused repository suite |
| PTU-024 | P1 | Test policy initially lacked release, documentation, and companion assertions | Test Strategist | Fixed | U8 | Red PMC-U8-R05 through R07, then green focused repository suite |
| PTU-025 | P1 | Review found runtime output transport and obsolete Fedora-base risks | Code Quality / Security / Reliability reviewers | Fixed | U8 | Step-output handoff, supported Fedora 43 digest, actionlint, and PMC-U8-R01 through R07 |

## Issue Details

### PTU-001 - Generic Output Transaction Framework

**Expected:** Disposable coverage and package output should preserve prior accepted state through the smallest target-specific mechanism needed by the portability goal.  
**Actual finding:** The prior plan introduced global coordination, persisted write-ahead records, generic metadata, quarantine, and recovery states whose transition discriminator remained undefined.  
**Reproduction:** Review the previous R13-R14, KTD7-KTD8, and removed U9 design against current coverage/package/clean behavior.  
**Planned fix:** The revised plan uses one narrow checkout lock plus separate coverage and package stage/backup/final precedence; no generic metadata or transaction state remains.  
**Evidence required:** Specialist re-review plus PMC-U5/6/7 repair and cleanup scenarios.  
**Attachments:** Plan `Lock and Output Publication Contract`; Plan Architect and Scope Guardian findings.

### PTU-002 - Mixed-Version Publication Race

**Expected:** First upgrade from the current released manager cannot race an old uninstall and lose the canonical command.  
**Actual finding:** The proposed new publication lock was unknown to the current installed manager.  
**Reproduction:** Pause current-manager uninstall while it holds its existing lifecycle lock and start new publication.  
**Planned fix:** Acquire publication, current lifecycle, and shipped legacy locks in order and pass validated descriptors through composite install.  
**Evidence required:** Synchronized PMC-U4-R02/R03 and PMC-WF-011 traces.  
**Attachments:** Plan U4 and manager-publication sequence diagram.

### PTU-003 - Legacy Generated Output

**Expected:** Normal pre-upgrade `coverage/` and `dist/` can be replaced or cleaned safely.  
**Actual finding:** Prior metadata ownership rules would classify existing unmarked output as foreign.  
**Reproduction:** Seed current SimpleCov output and package/checksum files, then run coverage/package/clean under the proposed contract.  
**Planned fix:** Characterize exact legacy coverage top-level entries and package-owned dist names; preserve unknown dist siblings and reject unknown coverage entries.  
**Evidence required:** PMC-U5-R04, PMC-U6-R03, and PMC-U7-R01 through R04.  
**Attachments:** Plan target-specific output contract.

### PTU-004 - Extracted-Source Repackaging

**Expected:** Release engineering solves the current Git-based release path without inventing unverifiable provenance.  
**Actual finding:** The prior plan added a custom embedded inventory and a second packaging mode for extracted releases.  
**Reproduction:** Compare release workflow inputs and install documentation with the former extracted-source package requirements.  
**Planned fix:** Require exact-root Git with HEAD for package/release-check; keep extracted sources supported for applicable help/install/lifecycle targets with an actionable package refusal.  
**Evidence required:** PMC-U6-R01 and documentation workflow PMC-WF-020/026.  
**Attachments:** Plan KTD10, U6, and deferred scope.

### PTU-005 - Manager Override Ambiguity

**Expected:** Checkout Make behavior always executes the source manager under review.  
**Actual finding:** `PROJECT_MANAGER` allowed an external implementation with unclear publication and private-protocol ownership.  
**Reproduction:** Trace the former override through manager-backed and installer-local target classes.  
**Planned fix:** Fix manager identity to the checkout executable and reject legacy `MANAGER` with migration guidance.  
**Evidence required:** PMC-U1-R02 through R04 and profile ownership review.  
**Attachments:** Plan KTD2 and Interface Contract.

### PTU-006 - Helper And Profile Ownership

**Expected:** Every target/helper references one capability owner and has an exact CLI/status/mutation contract.  
**Actual finding:** Profile names, private protocol, direct-helper behavior, and shared-file ownership required implementer invention.  
**Reproduction:** Trace every Make target and script to its prior capability list and first effect.  
**Planned fix:** Add command-level private profiles, exact bounded NUL record grammar/streams/statuses, fixed lock FDs 9/8/7 and output FD 6 transport, a sole repository registry, exact root defaults, target-specific output source APIs, and Helper/File Ownership matrices.  
**Evidence required:** PMC-U2-R04, PMC-U3-R01 through R07, and code-quality re-review.  
**Attachments:** Plan Interface, Policy Boundary, Helper Contract, and Target Contract matrices.

### PTU-007 - Independent Red-First Units

**Expected:** Each unit has stable red-first scenarios and a command executable after only declared dependencies.  
**Actual finding:** U1 depended on U2/U3 behavior, removed U9 was a horizontal platform, and test bullets lacked IDs/filter commands.  
**Reproduction:** Attempt to verify each prior unit independently using its stated files and dependencies.  
**Planned fix:** Remove U9, add narrow U10, reslice vertical units, assign `[PMC-U*-R*]`/`C*` IDs, and add one filterable command per unit.  
**Evidence required:** Test Strategist re-review and independent execution of all per-unit commands after implementation.  
**Attachments:** Plan sequencing diagram and implementation units.

### PTU-008 - Public Retry And Interaction Outcomes

**Expected:** Users can distinguish success, decline, usage, busy, partial install, unsafe clean, and retry actions from streams/status/text.  
**Actual finding:** The prior plan left contention, partial install, cleanup refusal, and direct Bash behavior partly undefined.  
**Reproduction:** Review non-TTY, PTY decline/EOF, busy lock, post-publication failure, and unsafe clean flows.  
**Planned fix:** Add the Public Terminal Contract, exact prompt grammar, same-command retry, partial-state message, and all-candidate cleanup refusal.  
**Evidence required:** PMC-U3-R06; PMC-U4-R05/R07/R08; PMC-U7-R02.  
**Attachments:** Workflow PMC-WF-012 through PMC-WF-015 and PMC-WF-023.

### PTU-009 - Lock Namespace And Serialization

**Expected:** All participants in one resource converge on one lock without blocking unrelated checkouts.  
**Actual finding:** XDG-dependent identities could diverge, while one per-user output coordinator serialized independent project roots.  
**Reproduction:** Use different XDG roots for one canonical manager and separate checkouts with independent local outputs.  
**Planned fix:** Keep the manager lock beside the canonical command outside every removable state root with normative parent/inode checks; use one project-local output lock and prohibit output escape/cross-checkout sharing.  
**Evidence required:** PMC-U4-R02/R03 and PMC-U10-R01 through R03.  
**Attachments:** Plan lock contracts and U10.

### PTU-010 - Filesystem Support Boundary

**Expected:** Atomic rename, advisory lock, identity, and staging assumptions are explicit and testable.  
**Actual finding:** The prior plan did not define which filesystem semantics were supported.  
**Reproduction:** Place stage/final paths on different devices or provide unsupported lock/rename behavior.  
**Planned fix:** Scope to validated local same-device filesystems and fail pre-publication when required behavior cannot be proven.  
**Evidence required:** PMC-U10-R04 and canonical native-lane output workflows.  
**Attachments:** Plan R9 and Environment/Threat Boundary.

### PTU-011 - Recipe Injection And Startup Ingress

**Expected:** Caller-controlled values remain data and Make-invoked probes/payloads do not inherit project-neutralizable startup hooks.  
**Actual finding:** Make-expanded quoted values could break recipe syntax; `BASH_ENV` executes before Bash script code; hostile Make ingress was overclaimed.  
**Reproduction:** Use quotes, backticks, `$()`, separators, exported functions, `BASH_ENV`, `MAKEFILES`, and tool config sentinels.  
**Planned fix:** Export values, pin `/bin/sh` and flags, resolve exact Bash, sanitize controllable ingress, and document caller-trusted Make/same-UID boundaries.  
**Evidence required:** PMC-U1-R03/R04 and PMC-U3-R05.  
**Attachments:** Plan KTD1 and Environment/Threat Boundary.

### PTU-012 - Executable Identity And Probe Containment

**Expected:** The exact absolute executable probed is the executable run, and probes cannot hang, consume stdin, reach the network, or flood output.  
**Actual finding:** Bare command names, mutable PATH, and unspecified behavioral probes could change identity or side effects.  
**Reproduction:** Use relative/empty PATH entries, functions, aliases, symlinks, PATH swaps, hanging shims, and verbose shims.  
**Planned fix:** Exclude non-filesystem command forms, bind absolute identity, use pre-resolved harness tools, and contain probes.  
**Evidence required:** PMC-U2-R02 through R04 and PMC-U3-R02/R03/R07.  
**Attachments:** Plan Interface Contract and Verification Contract.

### PTU-013 - Ambient Curl Policy

**Expected:** Runtime network behavior retains TLS verification and explicit bounded policy regardless of user curl config.  
**Actual finding:** Existing curl calls can read `.curlrc` and ambient proxy/credential options.  
**Reproduction:** Supply hostile `.curlrc`, proxy/CA/credential variables, redirects, large responses, and timeout endpoints.  
**Planned fix:** Put `--disable` first; define exact TLS, two-host manual redirect allowlist, proxy/CA allowlist and cleared variables, no credential/config inputs, 1 MiB/2 GiB size caps, 60/7200-second limits, and retry/connect bounds.  
**Evidence required:** PMC-U2-R05 and PMC-WF-009.  
**Attachments:** Plan KTD5 and U2.

### PTU-014 - Official Artifact Binding

**Expected:** Official release mode attests/uploads exactly one artifact pair produced from the clean workflow/tag commit.  
**Actual finding:** Dirty tracked bytes, extra archives, separate checksum handling, and mutable handoff were not fully constrained.  
**Reproduction:** Modify tracked content, mismatch tag/commit, add extra archive, or change checksum between package and upload.  
**Planned fix:** Split local/official modes, require clean exact commit/tag in official mode, verify one archive and one-record checksum immediately before handoff, and reject extras/changes.  
**Evidence required:** PMC-U6-R02/R06, PMC-U8-R05, and PMC-WF-021.  
**Attachments:** Plan KTD10, U6, U8.

### PTU-015 - Path, Diagnostic, And Threat Grammar

**Expected:** Supported path bytes and trust limits are unambiguous; diagnostics cannot forge lines or disclose secrets.  
**Actual finding:** Tabs were both supported and treated as controls; record/path/version limits and the same-UID boundary were incomplete.  
**Reproduction:** Inject tabs, newlines, ESC, ANSI, GitHub annotation text, long versions, and credential-shaped values.  
**Planned fix:** Add one exact path corpus/interface matrix; use byte-defined ASCII/backslash/`\xhh` escaping, 512-byte fields, 2048-byte lines, 64 records, 32768-byte aggregate, explicit truncation/overflow output, credential redaction, and global UID trust.  
**Evidence required:** PMC-U1-R04, PMC-U2-R06, PMC-U3-R06, PMC-U5-R05.  
**Attachments:** Plan R11, Public Terminal Contract, Environment/Threat Boundary.

### PTU-016 - Executable Stress Harness

**Expected:** PTY, process death, move failure, contention, and cross-userland scenarios have deterministic drivers and oracles.  
**Actual finding:** Prior scenarios named timing windows without a PTY driver, failure hooks, readiness barriers, state snapshots, manager-focused compatibility coverage, or exact offline mechanism.  
**Reproduction:** Attempt to execute the prior U4-U8 scenarios without inventing test-only behavior.  
**Planned fix:** Own byte-exact fixture APIs/statuses in `tests/helpers/portable.bash`, select util-linux `script` with explicit VEOF/SIGINT/transcript handling, use exact-call barriers/snapshots including package death, and run the exact filtered `tests/run-portability-smoke --assert-offline` under named network-isolated canonical/Debian/Fedora/minimum jobs.  
**Evidence required:** PMC-U4-R05, PMC-U10-R02/R03, all required workflow scenarios and CI jobs.  
**Attachments:** Plan Verification Contract and workflow test plan.

### PTU-017 - Rollout And Migration

**Expected:** Enforcement of a breaking Make invocation contract is documented before users encounter it.  
**Actual finding:** Legacy `MANAGER` rejection and output-root narrowing lacked a release/documentation migration contract.  
**Reproduction:** Follow existing documentation or automation using `MANAGER=...` or absolute output roots.  
**Planned fix:** Add changelog, README/install/contributing/releasing/security guidance, parse-time migration text, and repository policy checks.  
**Evidence required:** PMC-U1-R03, PMC-U8-R01/R06, and PMC-WF-026.  
**Attachments:** Plan R20 and U8.

### PTU-018 - Canonical Sidecar Naming

**Expected:** Every supported project-relative output override derives a collision-free, deterministic set of stage/backup names consumed identically by publisher and clean.  
**Actual finding:** The revised plan initially hardcoded default coverage names and left package sidecars unnamed.  
**Reproduction:** Set non-default nested-but-valid leaf names for coverage/dist and trace stage, backup, stale-candidate enumeration, and cleanup.  
**Planned fix:** Coverage uses parent-relative dot-prefixed leaf sidecars; package uses fixed dist-internal sidecars; both use exclusive mode-0700 creation, one stale stage/backup limits, and exact clean recognition.  
**Evidence required:** PMC-U5-R03, PMC-U6-R04, PMC-U7-R03/R04.  
**Attachments:** Plan Lock and Output Publication Contract.

### PTU-019 - Clean Classification Boundary

**Expected:** An unsafe candidate in either domain leaves coverage and dist byte-identical before any repair or deletion.  
**Actual finding:** The initial revised U7 repaired coverage/package before validating both, contradicting AE7.  
**Reproduction:** Seed repairable coverage plus unsafe package state and invoke clean.  
**Planned fix:** U5/U6 own pure classify plus separate repair/removal source-library APIs; U7 classifies both, aborts if either unsafe, then repairs, reclassifies, validates both removal sets, and deletes.  
**Evidence required:** PMC-U7-R02/R04 plus file-ownership review.  
**Attachments:** Plan Helper Contract, File Ownership Contract, and U7.

### PTU-020 - Status Boundary And Repeat Oracles

**Expected:** Tests assert exact direct-helper statuses but only zero/nonzero at GNU Make boundaries, and all meaningful repeat semantics have executable scenarios.  
**Actual finding:** Some workflow rows expected exact Make status 1/130, and repeated update/rollback behavior was only prose.  
**Reproduction:** Compare R19 with prior PMC-WF-012/014/015 and the target matrix update/rollback repeat rows.  
**Planned fix:** Separate direct and Make status oracles, define PTY process-group delivery, and add PMC-U4-R09/PMC-WF-027 for update idempotency and rollback toggling.  
**Evidence required:** PMC-U4-R05/R07/R08/R09 and PMC-WF-011 through 015/027.  
**Attachments:** Plan Public Terminal Contract and workflow matrix.

### PTU-021 - Portability Runner False-Green And Isolation

**Expected:** Focused compatibility jobs select the intended tagged tests, fail when none are selected, and run through one independently reproducible immutable image/network-isolation command.  
**Actual finding:** The first regex ended in `-` instead of the closing `]`, and container commands omitted image/build/mount/workdir/final-run details.  
**Reproduction:** Apply the former filter to `[PMC-U1-R01]` and attempt to run the former Docker fragment from a clean runner.  
**Planned fix:** End the exact filter in `\]`, fail zero selection, build reviewed digest/checksummed Dockerfiles, resolve immutable image ID, and run the exact read-only non-root `--network none` command.  
**Evidence required:** PMC-U8-R01 through R04, PMC-WF-025, and all four named CI jobs.  
**Attachments:** Plan U8 Execution Note and Verification Contract.

### PTU-022 - Paused Shim Timeout

**Expected:** A missing continue barrier cannot hang or unexpectedly invoke the real command.  
**Actual finding:** The initial harness API did not define timeout status, delegation, diagnostic, evidence retention, or default wait timeout.  
**Reproduction:** Create a `pause:1:READY:CONTINUE` shim and never create CONTINUE.  
**Planned fix:** Timeout after `PORTABLE_TEST_TIMEOUT`, retain barrier evidence, skip REAL, emit one stderr line, and return 124; omitted `wait_for_ready` seconds use the same default.  
**Evidence required:** PMC-U3-R08, PMC-WF-008, and every failure-injection consumer's bounded supervisor test.  
**Attachments:** Plan Test Harness Contract.

### PTU-023 - Missing U8 Compatibility Implementation

**Expected:** Four named jobs enforce one canonical suite owner and the exact
isolated focused smoke contract from immutable inputs.

**Actual finding:** The red PMC-U8-R01 through R04 tests found only the legacy
single verification job and no runner or fixture files.

**Reproduction:** Run the exact PMC-U8 repository filter before implementation.

**Fix:** Added the canonical, Debian-family, Fedora, and minimum-toolchain jobs,
the externally isolated runner, and digest/checksum-pinned fixtures.

**Evidence required:** Green PMC-U8-R01 through R04 and hosted execution of all
four jobs; hosted execution remains an explicit environment blocker locally.

### PTU-024 - Missing U8 Policy Tests And Guidance

**Expected:** Release handoff, documentation, workflow-plan, issue, and sign-off
contracts fail closed under repository tests.

**Actual finding:** Red PMC-U8-R05 through R07 found globbed release upload,
incomplete migration/recovery guidance, and planning-only companion state.

**Reproduction:** Run the exact PMC-U8 repository filter before implementation.

**Fix:** Added exact-pair release assertions, cross-document policy checks,
workflow evidence, implementation/test/review issue records, and specialist
sign-offs.

**Evidence required:** Green PMC-U8-R05 through R07 and zero open issue-register
rows.

### PTU-025 - Workflow Review Risks

**Expected:** A validated archive name reaches later action inputs reliably, and
the Fedora digest refers to a supported userspace with available repositories.

**Actual finding:** The initial implementation used a runtime environment value
inside an action expression and selected obsolete Fedora 42.

**Reproduction:** Review GitHub step data flow and Fedora lifecycle/package
availability after the first green repository-policy run.

**Fix:** Publish the archive as `steps.handoff.outputs.archive`, consume that
output in attestation and upload, and pin the reviewed Fedora 43 amd64 manifest.

**Evidence required:** Clean actionlint, PMC-U8-R01 through R07, and manual
release/data-flow review.

## Planning Specialist Sign-Offs

| Specialist | Status | Evidence checked | Required before sign-off |
|---|---|---|---|
| Plan Architect | Signed off | Exact protocol/lock transports, target APIs/sidecars, classify-before-repair, ownership, and acyclic units | Reopen if implementation changes an architecture contract. |
| Product and Scope Guardian | Signed off | 22/22 target contracts, bounded helper/test additions, explicit deferrals and migrations | Reopen if deferred scope is pulled into implementation. |
| Frontend Interaction Specialist | Signed off | Direct/Make statuses, PTY/non-TTY, busy/partial/cleanup retry, update/rollback repeat | Reopen if observable terminal outcomes change. |
| UI and Visual Design Specialist | Signed off | No graphical/browser UI; visual/responsive/theme/touch concerns are N/A with terminal owners | Reopen only if implementation adds graphical output. |
| Accessibility Specialist | Signed off | Byte-exact protocol, escaped/bounded text, stream/color semantics, exact VEOF/SIGINT transcript | Reopen if diagnostic or prompt grammar changes. |
| Reliability and Data Integrity Specialist | Signed off | Non-cleanable manager lock, U10, target precedence, legacy adoption, package death, all-candidate clean | Reopen if persistence/repair semantics change. |
| Privacy and Security Specialist | Signed off | Recipe/startup boundary, flock-bound FDs, CA snapshot, curl policy, encoding, path corpus, provenance | Reopen if trust/network/path contracts change. |
| Test Strategist | Signed off | Stable filters, exact harness APIs, timeout, PTY, package death, smoke runner, immutable offline jobs | Reopen if scenario IDs/runner/isolation change. |
| Code Quality Reviewer | Signed off | Root contracts, file owners, narrow U10, target libraries, fixture compatibility, test allocation | Reopen if helper boundaries/new files change. |

Planning sign-off approves decision completeness only. Implementation sign-off remains mandatory after the named automated and terminal evidence exists.

## Implementation Specialist Sign-Offs

| Specialist domain | Status | Evidence checked |
|---|---|---|
| Plan Architect | Signed off | U8 file graph, immutable inputs, exact runner command, and no plan-body mutation; PMC-U8-R01/R07. |
| Product and Scope Guardian | Signed off | Native Linux target classes, extracted-source boundary, migrations, and no package-manager expansion; PMC-U8-R06. |
| Frontend Interaction Specialist | Signed off | Terminal statuses, usage/isolation failures, retry guidance, and no graphical scope; PMC-U8-R04/R06. |
| UI and Visual Design Specialist | Signed off (N/A) | Browser, responsive, theme, touch, and screenshot dimensions are explicitly N/A; PMC-U8-R07. |
| Accessibility Specialist | Signed off | Plain-text status/remediation and terminal-equivalent workflow disposition; PMC-U8-R06/R07. |
| Reliability and Data Integrity Specialist | Signed off | Read-only fixture run, one-pair revalidation, exact-root and same-device boundaries; PMC-U8-R01/R05/R06. |
| Privacy and Security Specialist | Signed off | Non-root/offline isolation, digest/checksum pins, sole live canary, exact artifact handoff; PMC-U8-R01/R03-R05. |
| Test Strategist | Signed off | Proof-first R01-R07, exact filter, zero-selection failure, and focused/full-suite ownership; PMC-U8-R01-R07. |
| Code Quality Reviewer | Signed off | Workflow policy, shell/YAML syntax, documentation consistency, and final diff scope; PMC-U8-R01-R07. |

## Execution Log

| Date | Phase | Command / workflow | Result | Issues | Evidence |
|---|---|---|---|---|---|
| 2026-07-27 | Initial plan review | Seven-lens headless plan review | Findings recorded | PTU-001 through PTU-017 | Current session review outputs |
| 2026-07-27 | Ultrathink specialist review | Architecture, scope, interaction, visual, accessibility, reliability, security, test, and code-quality review | Plan changes required | PTU-001 through PTU-017 | Specialist task outputs in current session |
| 2026-07-27 | Plan revision | Canonical plan plus CLI workflow artifact | Awaiting specialist re-review | All Open | Linked plan and workflow file |
| 2026-07-27 | Ultrathink specialist re-review | Revised plan/workflow/workorder | Additional interface precision required | PTU-006, 008, 009, 013, 015, 016, 018-020 | Specialist task outputs in current session |
| 2026-07-27 | Final ultrathink sign-off | Decision-complete plan/workflow/workorder | All planning specialists signed off | PTU-001 through PTU-022 planning-resolved; implementation retests pending | Specialist task outputs and linked artifacts |
| 2026-07-27 | Implementation | U8 proof-first compatibility, release, and documentation work | Complete | PTU-023 | Red then green PMC-U8-R01 through R07 |
| 2026-07-27 | Test | Exact PMC-U8 repository filter plus runner eligibility and static workflow policy | Complete with hosted-CI environment blocker recorded | PTU-024 | Focused command transcript and diff evidence |
| 2026-07-27 | Review | Scope, security, reliability, interaction/N/A, test, and code-quality review | Complete | PTU-025 | Evidence-backed implementation sign-offs above |

## Final Completion Gate

- [x] Every Open issue is Fixed with retest evidence or Accepted by the user with rationale.
- [x] Every U8 implementation specialist domain is Signed off with named evidence.
- [ ] Every unit-specific red-first and regression command passes.
- [ ] PMC-WF-001 through PMC-WF-027 pass on required environments.
- [ ] Canonical and focused compatibility CI gates pass (hosted-only environment blocker; static policy is complete).
- [x] No unresolved P0/P1 issue remains.
- [x] Final U8 diff contains no obsolete helper, duplicate suite owner, live-test path, or undocumented public behavior.
