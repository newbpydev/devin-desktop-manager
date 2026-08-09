# Legacy Installation Recovery - User Workflow Test Plan

**Feature ID:** `legacy-installation-recovery`  
**Status:** Local automation complete - hosted and manual acceptance pending
**Evidence scope:** Local focused, aggregate, coverage, and isolated portability evidence; no hosted or native desktop claim
**Owner:** Implementation agent and repository maintainer  
**Linked plan:** `docs/plans/2026-08-09-001-fix-legacy-installation-recovery-plan.md`  
**Issue workorder:** `docs/workorders/legacy-installation-recovery-issues-workorder.md`

## Purpose

Prove that a complete Legacy Installation created by the initial manager can recover through supported commands on every supported Linux userland while near-miss and foreign layouts remain untouched. The workflow covers terminal behavior, ownership classification, persisted migration, desktop integration, default associations, interruption/retry, portability, documentation, and patch-release readiness.

No browser UI is in scope. Terminal status/streams, filesystem state, XDG associations, launcher/deep-link behavior, app lifecycle, and native desktop evidence are the relevant interaction surfaces.

## Verification Contract

- **Behavior under test:** Read-only recognition, transactional ownership migration, update/install/rollback/uninstall, doctor diagnosis, default preservation/cleanup, retry, and release guidance.
- **Public contracts:** Existing Make targets and direct manager commands; status `0/1/2` boundaries; ownership/state/release schema `1`; offline test policy; current supported Linux/XDG environment.
- **Supported environments:** glibc Linux x86_64, Bash 4.4+, GNU Make 4.3 behavior, non-root user, local same-device filesystem, XDG-compatible desktop, current capability preflight.
- **Selected profiles:** CLI, data/persistence migration, infrastructure/operations, desktop lifecycle, documentation/release process, and mixed-system handoff.
- **Local evidence:** Focused Bats, aggregate Bats, lint, coverage, repository policy, portability selection, deterministic package and release-check.
- **Hosted evidence:** Existing canonical Ubuntu, Debian-family, Fedora, and minimum-toolchain jobs at the same head.
- **Manual evidence:** One preserved affected-host upgrade and one disposable clean supported desktop environment.
- **Explicit non-goals:** Browser testing, ARM64/macOS/Windows/musl/system-wide packaging, forced repair, guessed historical defaults, schema changes, tag/push/publish, and destructive testing against an unpreserved real home.

## Evidence Rules

1. Leave every checkbox unchecked until its exact scenario runs after implementation.
2. Record date, commit SHA, manager version/hash, environment, command, direct versus Make status, stdout/stderr, and evidence location.
3. Capture before/after path type, link target, mode, and SHA-256 snapshots for every refusal and failure-injection scenario.
4. Keep fixtures offline and synthetic. Never copy a real Devin package, workspace, credential, or unredacted user configuration into the repository.
5. Treat hosted and native desktop evidence as pending until it runs; container success does not prove launcher caches, user namespaces, or GUI integration.
6. Log every mismatch in the linked workorder before fixing it.

## Requirement Coverage

| Requirement | Unit | Scenario IDs | Evidence tier |
|---|---|---|---|
| R1 | U1 | LIR-U1-R01/R02/R05; LIR-WF-001/007 | Focused, aggregate |
| R2 | U1 | LIR-U1-R03/R04/R06; LIR-WF-006/007 | Focused, security review |
| R3 | U1-U2 | LIR-U1-R02/R06; LIR-U2-R01/R08; LIR-WF-002/006 | Focused, aggregate |
| R4 | U1 | LIR-U1-C01, LIR-U1-R03 through LIR-U1-R06; LIR-WF-007/012 | Focused, non-regression |
| R5 | U1/U3 | LIR-U1-R01 through LIR-U1-R06; LIR-U3-R01/R03/R06; LIR-WF-001/010 | Focused, review |
| R6 | U2 | LIR-U2-R01 through LIR-U2-R04, LIR-U2-R07; LIR-WF-002 through LIR-WF-005 | Focused, aggregate |
| R7 | U2 | LIR-U2-R05; LIR-WF-008 | Focused, manual app lifecycle |
| R8 | U2 | LIR-U2-R06/R07; LIR-WF-009 | Focused recovery |
| R9 | U2 | LIR-U2-R01/R03/R08; LIR-WF-002/004/006 | Focused, native desktop |
| R10 | U2 | LIR-U2-R04/R08; LIR-WF-005/006 | Focused, disposable manual |
| R11 | U2 | LIR-U2-R06/R07; LIR-WF-009 | Focused recovery |
| R12 | U3 | LIR-U3-R01/R02/R06; LIR-WF-001/010 | Focused terminal |
| R13 | U1/U3 | LIR-U1-R03 through LIR-U1-R06; LIR-U3-R03/R05; LIR-WF-007 | Focused terminal/security |
| R14 | U1/U3 | LIR-U3-R04/R06; LIR-WF-010/011 | Focused no-mutation |
| R15 | U1-U4 | LIR-U1-C01; LIR-U4-R01/R02; LIR-WF-012/013 | Aggregate, hosted |
| R16 | U4 | LIR-U4-R01/R02; LIR-WF-013 | Focused runner, hosted |
| R17 | U4 | LIR-U4-R03/R06; LIR-WF-014 | Repository policy, documentation review |
| R18 | U4 | LIR-U4-R03/R04/R06; LIR-WF-014 | Release-check, maintainer review |
| R19 | U4 | LIR-U4-R05; LIR-WF-015/016 | Manual, separately recorded |

## Workflow Scenarios

### Recognition and terminal diagnosis

- [x] **LIR-WF-001 - Affected profile diagnosis:** Seed the exact active markerless layout, run direct and Make doctor, and verify exit `1`, one recoverable Legacy Installation diagnosis, direct update/uninstall choices, no seven-symptom list, and byte-identical state.
- [x] **LIR-WF-006 - Default provenance matrix:** Exercise correct legacy, empty, safe external, mixed shadowed legacy, Default/Added records, absent provenance, Removed/wrong-MIME records, modern IDs, wrong roles, desktop-specific files, malformed input, query failure, and special path types. Only decided rows classify as recoverable.
- [x] **LIR-WF-007 - Adversarial ownership near-misses:** Change one release, link, root entry, desktop semantic, asset, default, state, cache, temporary, path type, or identity invariant at a time. Each mutation command exits before ownership changes with its stable reason code and preserved snapshot.
- [x] **LIR-WF-010 - Doctor-to-mutation revalidation:** Let doctor report a recoverable profile, then change one ownership invariant before a lifecycle command. Verify the lifecycle command independently reclassifies under lock and refuses before mutation; no doctor result is persisted or consumed.
- [x] **LIR-WF-011 - Read-only commands:** Run `status`, `check`, and doctor against recoverable/refused layouts with filesystem/network fakes as applicable; assert no marker, lock, state, cache content, desktop, MIME, link, or release mutation.
- [x] **LIR-WF-012 - Compatibility baseline:** Re-run fresh, public pre-activation, public post-link-unclaimed, public stateful `0.1.0`, owned, interrupted, and existing near-miss fixtures; their characterized outcomes do not change except for the named complete-profile extension.

### Lifecycle mutation and recovery

- [x] **LIR-WF-002 - Recover and update:** From the affected fixture, update to a newer offline release. Verify app-stop precedes mutation, schema-`1` markers/metadata, mode-`0600` state, modern integration, normalized/preserved originals, one rollback release, and healthy doctor/status.
- [x] **LIR-WF-003 - Composite install and retry:** Run `make install` from fixed source, inject application-stage failure after manager publication, verify the partial-install message and recoverable state, then rerun the same command to completion.
- [x] **LIR-WF-004 - Recover and rollback:** Seed current/previous legacy releases, run rollback once to swap them and publish modern state/integration, then run rollback again and prove the original current release is restored without duplicate state/default records.
- [x] **LIR-WF-005 - Recover and uninstall:** In separate disposable fixtures, cover interactive yes/no/blank/invalid/EOF/SIGINT/non-TTY and prompt-free uninstall. Only affirmative/prompt-free paths remove proven manager files/defaults; all retain the separate Devin CLI, user config, external defaults, and unrelated associations.
- [x] **LIR-WF-008 - Running application:** Start a synchronized process whose executable resolves to the active legacy release, invoke every relevant lifecycle entry point, and verify refusal before marker, metadata, journal, default, state, or integration mutation. Stop it and retry successfully.
- [x] **LIR-WF-009 - Interruption and same-command retry:** Kill at each named migration/transaction boundary. Verify only recognized temporaries, markers, metadata, journal, prune, or cleanup records remain; same-command retry completes exactly once or preserves an actionable validated recovery record.

### Portability, release, and live acceptance

- [ ] **LIR-WF-013 - Cross-userland focused smoke:** Prove the runner selects classifier success/refusal, doctor, and interruption scenarios; zero selection fails. Run the existing non-root offline canonical, Debian-family, Fedora, and minimum-toolchain lanes without adding another full-suite owner.
- [x] **LIR-WF-014 - Documentation and `0.1.1` readiness:** Follow README/install/support/concepts/releasing/security guidance from a verified source archive and Git checkout. Confirm version/schema consistency, affected-user bootstrap guidance, deterministic archive/checksum generation, and absence of marker/lock deletion or force-repair advice.
- [ ] **LIR-WF-015 - Preserved affected-host upgrade:** Record the pre-fix fingerprint and exact fixed-source commit, run `make install-manager`, verify direct manager version `0.1.1`, then run `make update`, status/doctor/app-version, and launcher/URL/workspace checks. Run rollback twice to prove reversibility and leave the upgraded release current. Compare protected before/after snapshots and do not publish or delete the original evidence.
- [ ] **LIR-WF-016 - Disposable clean environment:** From verified `0.1.1` source in a second supported desktop environment, run install, repeat update, doctor, launcher/URL/workspace behavior, the documented no-previous-release rollback refusal when no second version exists, and uninstall. Record native desktop and user-namespace evidence separately from containers.

## Commands and Environments

| Tier | Command or method | Environment | Planned evidence |
|---|---|---|---|
| Focused U1 | `bats --filter '^\[LIR-U1-[CR][0-9][0-9]\]' tests/manager.bats` | Local synthetic HOME/XDG | Classification, semantics, provenance, no mutation |
| Focused U2 | `bats --filter '^\[LIR-U2-R[0-9][0-9]\]' tests/manager.bats tests/makefile.bats tests/desktop.bats` | Local synthetic HOME/XDG | Lifecycle, app-stop, MIME rewrite, failure recovery |
| Focused U3 | `bats --filter '^\[LIR-U3-R[0-9][0-9]\]' tests/manager.bats tests/makefile.bats` | Local synthetic HOME/XDG | Doctor/refusal terminal contract and race |
| Focused U4 | `bats --filter '^\[LIR-U4-R[0-9][0-9]\]' tests/repository.bats tests/manager.bats` | Exact Git checkout | Portability selection, docs, version/schema policy |
| Aggregate manager | `bats tests/manager.bats tests/makefile.bats tests/desktop.bats` | Local | Existing ownership/transaction/desktop regression |
| Aggregate repository | `make verify` | Local exact checkout | Syntax, ShellCheck, complete offline suite |
| Coverage | `bundle exec make coverage` | Local exact checkout, locked bundle | One complete suite, at least 84% line coverage |
| Portability | `tests/run-portability-smoke --assert-offline` through the existing isolated non-root CI wrappers | Hosted/current compatible local isolation | Non-root, loopback-only, non-empty focused set |
| Release readiness | `bundle exec make release-check` | Clean exact Git root, no release tag | Version, coverage, deterministic `0.1.1` package |
| Hosted | Existing four CI jobs at one commit SHA | GitHub Actions | Canonical plus focused userland compatibility |
| Manual affected | LIR-WF-015 checklist | Preserved affected desktop | Real upgrade, doctor, launcher/defaults, reversible rollback |
| Manual clean | LIR-WF-016 checklist | Disposable supported desktop | Fresh lifecycle and uninstall |

## Fixtures and Failure Injection

### Canonical complete-profile fixture

- Valid current and previous legacy releases with metadata lacking only `schemaVersion` and `managerId`.
- Canonical relative `current`/`previous` links, `.manager.lock`, absent root/cache/state ownership markers, absent `state.json`, and absent manager-specific integration.
- Canonical application symlink through `current/app/bin/devin-desktop`.
- Full main/URL legacy desktop semantics from the plan, release-matching legacy icon/MIME assets, and the three expected legacy default IDs in transaction-owned MIME files.
- Variants for current-only inventory, empty cache, absent/empty safe state root, Default/Added records, empty/external defaults, and safe ordering/comments.

### Test doubles and controls

- Existing manifest/download/package fixtures; no real Devin artifact.
- Existing `xdg-mime`, desktop-cache, process, lock, filesystem, and app-running fakes.
- Exact-call failure counters and readiness/continue barriers for process death and races; no timing sleeps as the oracle.
- Before/after snapshots excluding harness-only files, with path types, modes, links, hashes, and MIME-default query output.
- A query fake that distinguishes effective defaults from persisted Default/Added/Removed records and desktop-specific precedence.

### Sensitive-data handling

- Use synthetic HOME/XDG paths locally and redact the real username/path from shareable manual evidence.
- Capture hashes and bounded escaped path/ID diagnostics, never desktop/MIME file bodies from the affected host.
- Do not include tokens, workspaces, user configuration content, or upstream application binaries in fixtures or logs.

## Manual Affected-Host Safety Gate

Before LIR-WF-015 mutates the reported installation:

- [ ] Implementation, focused tests, `make verify`, coverage, release-check, and current-head hosted jobs are green.
- [ ] The installed/checkout manager identity and intended fixed commit are recorded; `make install-manager` is the only manager publication step before application recovery.
- [ ] The complete pre-update fingerprint and unrelated protected paths/defaults are captured read-only.
- [ ] No Devin Desktop process is running.
- [ ] The user understands rollback will run twice so the upgraded release remains current.
- [ ] No uninstall is performed on the affected host; destructive uninstall acceptance uses the disposable environment.

## Execution Record

| Date | Commit SHA | Scenario/tier | Environment | Command/method | Result | Evidence | Issues |
|---|---|---|---|---|---|---|---|
| 2026-08-09 | This implementation commit | LIR-WF-001 through LIR-WF-012 | Synthetic HOME/XDG on local Linux | Focused Bats plus `make verify` | Pass; aggregate 325/325 | Current implementation session and stable scenario IDs | None open locally |
| 2026-08-09 | This implementation commit | Coverage | Unprivileged Ruby 3.2.11 container | Pinned Bundler 2.4.20/Bashcov 3.3.0 `make coverage` | Pass; 85.82% (5,545/6,461), required 84.00% | Generated report validated before cleanup | None |
| 2026-08-09 | This implementation commit | Local portion of LIR-WF-013 | Pinned Debian, pinned Fedora, and checksummed Bash 4.4/GNU Make 4.3 containers | Existing offline non-root portability runner | Pass; 52/52 in each container | Read-only checkout and disabled network | Hosted jobs pending |
| 2026-08-09 | `07b73b58ea549379495203bc6c4c46751ec5f5fd` | LIR-WF-014 release readiness | Clean exact Git checkout in an unprivileged Ruby 3.2.11 container | `make release-check` with pinned Bundler 2.4.20/Bashcov 3.3.0 | Pass; coverage 85.85%, release contract consistent, archive and checksum pair created | Current implementation session; generated outputs retained only for local inspection | None |
| Pending | Pending | LIR-WF-013 hosted, LIR-WF-015, LIR-WF-016 | GitHub Actions and native desktop environments | Hosted and manual procedures above | Not executed | Requires published head and explicit live-host approval | LIR-ISS-008/010 |

## Completion Gate

- [ ] Every LIR-WF-001 through LIR-WF-016 scenario has exact evidence or an explicit accepted blocker.
- [x] Every `[LIR-U*-*]` focused selection passes and selects at least one test.
- [x] Aggregate, coverage, local portability, package, and release-check gates pass for the implementation; the final evidence-only commit is revalidated separately.
- [ ] All four hosted compatibility jobs pass on that head.
- [ ] Affected-host and disposable-environment evidence are complete and separately attributed.
- [ ] The linked workorder has zero Open, Blocked-unaccepted, or implementation-regressed P0/P1 issues.
- [ ] No implementation, hosted, manual, tag, or release result is inferred from this planning artifact.
