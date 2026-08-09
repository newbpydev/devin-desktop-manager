# Portable Make Commands - User Workflow Test Plan

**Feature ID:** portable-make-commands  
**Status:** U8 Workflow plan executed - hosted CI evidence awaits its runner<br>
**Owner:** Implementation agent and repository maintainer  
**Linked plan:** `docs/plans/2026-07-27-001-fix-portable-make-commands-plan.md`  
**Issue workorder:** `docs/workorders/portable-make-commands-issues-workorder.md`

## Purpose

Validate the complete terminal experience for all 22 Make targets on supported native glibc Linux x86_64 environments. This workflow is pessimistic by design: it stresses clean checkout behavior, command identity, dependency diagnostics, interactive and noninteractive use, filesystem safety, ordinary and process failure, repeat runs, contention, exact-Git release behavior, and focused cross-userland compatibility.

This repository has no browser or graphical surface in scope. Browser URLs, viewport breakpoints, themes, touch targets, DOM accessibility, and screenshots are explicitly not applicable. Equivalent terminal concerns are tested through PTY behavior, stream/status semantics, plain-text accessibility, process restart, concurrency, path handling, and state preservation.

## Environment Setup

### Prerequisites

- A clean or disposable checkout of this repository on supported native glibc Linux x86_64 local storage.
- GNU Make compatible with 4.3 behavior and Bash 4.4 or newer.
- Repository development dependencies required by the target under test.
- Bats and the capability-checked util-linux `script` PTY driver for automated workflow scenarios.
- Permission to create disposable HOME, XDG, TMPDIR, checkout, coverage, and dist fixtures.
- Container tooling only for the focused Debian-family, Fedora, and minimum-toolchain evidence lanes.

### Start and Access

1. Open a terminal in the repository root.
2. Confirm the terminal path is the physical directory containing `Makefile`.
3. Use `make help` as the bootstrap smoke check.
4. There is no local URL, browser server, account, or seeded application database for this feature.
5. Run destructive scenarios only in disposable test roots produced by the Bats fixtures.

### Evidence Capture

- Record the exact command and environment overrides.
- Capture stdout and stderr separately plus the direct helper status or Make zero/nonzero outcome.
- Capture before/after state snapshots for every failure, cleanup, publication, and race scenario.
- Record PTY transcript, prompt count, signal, and exit status for interactive scenarios.
- Record compatibility job name, image digest, observed tool versions, effective UID, and network-denial proof.
- Log every defect immediately in the linked workorder before continuing.

### Canonical Path Fixtures

Use the exact accepted component strings `plain`, `space dir`, `single-'quote`, `double-"quote`, `glob-[*?]`, `dollar-$value`, `subshell-$(touch sentinel)`, `semi-;amp-&pipe-|`, `--leading`, and `backtick-` + byte `0x60` + `touch sentinel` + byte `0x60`. Apply each to checkout root, HOME, every XDG root, TMPDIR, APP/tool executable paths, canonical manager paths through HOME, direct installer source/destination, and project-relative coverage/dist/package output as allowed by the plan's interface matrix. The executable rejected corpus is empty required value, `../escape`, disallowed absolute output, literal tab, LF, CR, ESC, bytes `0x01-0x1f`, DEL `0x7f`, symlinked root, equal output roots, and nested output roots. NUL is structurally unrepresentable and N/A. Record sentinel non-execution and escaped diagnostics.

## User Stories

### Core Stories

- As a first-time contributor, I can discover every Make command from a clean checkout without first installing the manager or development stack.
- As a Linux user, I receive one complete, target-specific, distro-neutral diagnostic when requirements are missing or incompatible.
- As an installer, I can install, update, retry a partial install, and uninstall without stale-manager execution or manager-command races.
- As a contributor, I can run lint, tests, verify, and coverage with stable suite ownership and without stale evidence.
- As a releaser, I can package and validate one exact Git root into one deterministic archive/checksum pair.
- As a maintainer, I can clean generated output without deleting foreign files or broadening a caller-controlled path.

### Alternate And Failure Stories

- A stale globally installed manager must not influence checkout commands.
- Multiple blockers must aggregate without creating state or reaching the network.
- A command that exists but lacks the required behavior must be diagnosed as incompatible.
- Noninteractive uninstall must refuse prompting and point to `uninstall-yes`.
- Busy operations must fail quickly, preserve state, and tell the user to rerun the same command.
- Failed coverage or package generation must preserve prior accepted output.
- Process death must resolve only through the documented public/backup/stage precedence.
- Extracted releases must remain usable for applicable lifecycle work and reject release-engineering targets with Git-checkout guidance.

## Workflow Coverage Matrix

| ID | Workflow | Setup and action | Expected outcome | Automated evidence |
|---|---|---|---|---|
| PMC-WF-001 | Bootstrap discovery | Use clean HOME, no installed manager, minimal PATH with POSIX shell and Make; run bare `make` and `make help`. | Both return 0, print the same ordered 22-target help to stdout, and create no files. | PMC-U1-R01, PMC-U1-R05 |
| PMC-WF-002 | Checkout authority | Place an executable sentinel at the canonical installed-manager destination; run representative read and mutation wrappers with mutation commands shimmed. | Checkout `bin/devin-desktop-manager` is invoked; sentinel is untouched and unexecuted. | PMC-U1-R02 |
| PMC-WF-003 | Invalid command entry | Run unknown, duplicate, and two-goal invocations, including `make -j install package`, legacy `MANAGER=...`, and shell-fragment tool overrides. | Usage failure occurs before any recipe or state change and names the valid contract/migration. | PMC-U1-R03 |
| PMC-WF-004 | Path-as-data safety | Repeat representative targets from checkout/HOME/TMPDIR paths containing spaces, quotes, glob characters, dollar signs, separators, and leading hyphens; inject command sentinels in values. | Exact values arrive as one argument, no sentinel executes, and controls/tabs/newlines fail with one escaped diagnostic. | PMC-U1-R04, PMC-U5-R05 |
| PMC-WF-005 | Missing application | Run `make run` and `make app-version` with absent and non-executable APP paths. | Status is nonzero, stderr names the application-state problem, and shell status 127 is not exposed. | PMC-U1-R05 |
| PMC-WF-006 | Aggregated preflight | Remove several target-reachable tools from the SUT PATH while retaining absolute harness tools; run install, test, coverage, package, and release-check profiles. | Every relevant blocker appears once in stable order; no lock, output, destination, network, or manager state is created. | PMC-U2-R01, PMC-U3-R02, PMC-U3-R06 |
| PMC-WF-007 | Capability mismatch | Supply executable shims that reject the exact manager/repository option or semantic required. | Findings say incompatible rather than missing and identify capability purpose without package-manager instructions. | PMC-U2-R02, PMC-U3-R03 |
| PMC-WF-008 | Probe containment | Give probes open stdin, `BASH_ENV`, `ENV`, `SHELLOPTS`, `BASHOPTS`, `PS4`, command-shadowing exported functions, hostile tool config, hanging/verbose/paused shims, and network sentinels. | Probes use closed stdin, bounds, isolated temp state, neutral config, and denied network; paused shims time out 124 without REAL and retain barriers; failures remain target-scoped. | PMC-U3-R05, PMC-U3-R07, PMC-U3-R08 |
| PMC-WF-009 | Runtime network policy | Provide hostile `.curlrc`, proxy/CA/credential variables, redirects, large responses, and timeout cases to manager network commands. | Ambient curl config cannot weaken TLS or alter explicit redirect, credential, size, and timeout policy. | PMC-U2-R05 |
| PMC-WF-010 | Install fail-before-mutate | Use root/invalid HOME/XDG/destination/capability fixtures and run install paths. | Before/after snapshots match exactly and no request occurs. | PMC-U4-R01 |
| PMC-WF-011 | Mixed-version upgrade | Pause the current released manager while it holds its lifecycle lock, then start new checkout publication; release the holder and retry. | Direct publisher returns 1 and Make returns nonzero without replacement; retry succeeds with publication/current/legacy order and retains the canonical command. | PMC-U4-R02, PMC-U4-R03 |
| PMC-WF-012 | Partial install retry | Allow manager publication, force later application failure, inspect message/state, then rerun `make install` without the fault. | Direct helper returns 1 and Make returns nonzero with exact partial-state/retry text; second run resumes safely. | PMC-U4-R07 |
| PMC-WF-013 | Noninteractive uninstall | Pipe data and `/dev/null` into `make uninstall`; run `make uninstall-yes` with a stdin-read sentinel. | Interactive command fails before lock/state and names `uninstall-yes`; noninteractive command never reads stdin. | PMC-U4-R05, PMC-U4-R06 |
| PMC-WF-014 | PTY uninstall | Run `script --quiet --return --command 'exec bin/devin-desktop-manager uninstall >"$BATS_TEST_TMPDIR/uninstall.stdout"' "$BATS_TEST_TMPDIR/uninstall.typescript"`; wait for the prompt barrier; send terminal VEOF byte `0x04` on an empty canonical line then close input for EOF, or send SIGINT to the foreground process group. Repeat Make wrappers for zero/nonzero only. | One `[y/N]` prompt appears in the explicit transcript; only y/yes mutates; direct decline/EOF/invalid is 0, direct SIGINT is 130, Make SIGINT is nonzero, and Bats-temp transcript/stdout files are excluded from product-state snapshots. | PMC-U4-R05 |
| PMC-WF-015 | Busy manager lock and retry | Hold publication/lifecycle lock with a synchronized process; run direct and Make install/uninstall; release holder and rerun. | Direct loser returns 1 and Make returns nonzero quickly, names target/resource, says not to delete lock, mutates nothing, and retry succeeds. | PMC-U4-R08 |
| PMC-WF-016 | Output-lock lifecycle | Hold checkout output lock, kill only the parent while child survives, test forged/special lock objects, then release child. | Contention lasts through child lifetime; invalid locks fail closed; persistent valid lock file is reused. | PMC-U10-R01 through PMC-U10-R03 |
| PMC-WF-017 | Coverage ordinary failure | Seed valid coverage, fail Bashcov/Bats/parser/threshold/publication one point at a time, then run successfully. | Every failed run preserves prior output; successful run publishes one fresh 84%+ result and runs every test exactly once. | PMC-U5-R01, PMC-U5-R02, PMC-U5-R06 |
| PMC-WF-018 | Coverage process repair | Construct public/backup/stage combinations and kill at synchronized move boundaries. | Valid public wins, one valid backup restores missing public, orphan stage is discarded, and ambiguous candidates fail closed. | PMC-U5-R03 |
| PMC-WF-019 | Legacy coverage | Seed each characterized current legacy coverage shape and one unknown-entry shape. | Valid legacy output can be replaced/cleaned; unknown entry blocks mutation and survives. | PMC-U5-R04 |
| PMC-WF-020 | Exact-root package | Package a normal/dirty checkout, no-HEAD repo, extracted release, and checkout nested in unrelated parent Git. | Local tracked working-tree behavior remains characterized; only exact-root Git with HEAD packages; unsupported sources fail before dist mutation. | PMC-U6-C01, PMC-U6-R01 |
| PMC-WF-021 | Official release provenance | Exercise clean matching tag/commit and dirty, mismatched, extra-artifact, or changed checksum cases. | Only one clean expected archive/checksum pair bound to the workflow/tag commit reaches attestation/upload. | PMC-U6-R02, PMC-U6-R06, PMC-U8-R05 |
| PMC-WF-022 | Package failure, death, legacy, and repair | Seed the pre-revision archive/checksum pair plus foreign `dist/keep.txt`; fail handled generation calls, kill after backup/archive/checksum/public completion barriers, and construct exact sidecar/public combinations. | Prior/legacy pair and foreign files survive ordinary failure; process death yields old, new, exact target repair, or explicit preserved failure; ambiguous pairs fail closed. | PMC-U6-R03, PMC-U6-R04, PMC-U6-R07 |
| PMC-WF-023 | Safe clean | Seed valid coverage/package output, foreign dist siblings, unsafe coverage, invalid checksum, symlink/FIFO/hard-link, and escaping overrides; run clean twice. | Valid owned output is removed, foreign dist files survive, repeat is 0, and any unsafe candidate blocks both sets unchanged; stderr names candidate/reason, confirms no change, gives safe corrective action, and says to rerun `make clean`. | PMC-U7-R01 through PMC-U7-R04 |
| PMC-WF-024 | Output contention | Synchronize coverage, package, release-check, and clean pairwise, including holder death and retry. | One winner mutates; loser returns bounded busy guidance; no mixed state; same command succeeds after holder exit. | PMC-U7-R05, PMC-U10-R02, PMC-U10-R03 |
| PMC-WF-025 | Cross-userland smoke | Canonical runs the plan `sudo unshare` command. Each focused job builds from its literal digest/checksummed fixture, resolves immutable `IMAGE_ID`, and runs `docker run --rm --network none --user 10001:10001 --read-only --tmpfs /tmp:rw,exec,uid=10001,gid=10001,mode=1777 -v "$PWD:/workspace:ro" -w /workspace -e HOME=/tmp/home -e TMPDIR=/tmp "$IMAGE_ID" tests/run-portability-smoke --assert-offline`. The isolated tmpfs is executable because Bats creates trusted per-test command shims there. | Loopback-only plus bounded curl proves denial; exact nonzero-on-zero-selection filter/files/status match the plan; diagnostics/outcomes match; focused lanes include manager capability checks and do not duplicate the full suite. | PMC-U8-R01 through PMC-U8-R04 |
| PMC-WF-026 | Documentation journey | Follow README/install/contributing/releasing/security guidance from paths with spaces and no globally installed manager. | Commands match executable behavior, migration/retry/cleanup/Git scope is discoverable, and no distro package manager is assumed. | PMC-U8-R06 |
| PMC-WF-027 | Repeat update and rollback | Install two valid releases, run `make update` twice against the same latest release, then run `make rollback` twice. | Repeated update creates no duplicate release/state; each rollback toggles current/previous, and the second returns to the original current release. | PMC-U4-R09 |

## Dimension Disposition

| Template dimension | Disposition and terminal equivalent |
|---|---|
| Create, read, update, delete | Covered through install/status/update/uninstall and coverage/package/clean workflows. |
| Browser navigation and URL state | N/A: no browser routes. Command/goal selection and physical project root are covered by PMC-WF-001 through PMC-WF-005. |
| Reload, tab close, tab reopen | N/A: process restart, repeat runs, parent/child death, and retry are covered by PMC-WF-012 and PMC-WF-016 through PMC-WF-024. |
| Keyboard tab order and focus | N/A: no focus model. PTY input, EOF, cancellation, signals, and redirected streams are covered by PMC-WF-013 and PMC-WF-014. |
| Responsive breakpoints and zoom | N/A: no visual layout. Diagnostics must remain one-line, bounded, and meaningful at narrow terminal widths without relying on wrapping. |
| Light and dark themes | N/A: semantics do not depend on color, theme, TERM, or ANSI support. |
| Touch targets | N/A: no touch surface. |
| Rapid clicking/navigation | N/A: rapid/repeated commands and synchronized process contention are covered by PMC-WF-015, PMC-WF-016, and PMC-WF-024. |
| Browser console errors | N/A: process stderr, status, state snapshots, and CI logs are the observable diagnostics. |
| URL/query/hash privacy | N/A: command arguments, paths, environment, logs, and network credential redaction are the privacy surfaces. |
| Screenshot/visual diff evidence | N/A: transcript, stream/status, filesystem snapshot, lock trace, checksum, and CI job evidence are required instead. |

## Accessibility Review

- All meaning is present in plain text and does not depend on color or indentation.
- Help and findings use stable semantic labels and deterministic order for terminal readers.
- Prompts identify the destructive action and default choice before reading input.
- EOF, non-TTY, invalid input, cancellation, and SIGINT have explicit behavior.
- stdout and stderr separation lets assistive tooling distinguish results from guidance/errors.
- Untrusted paths and versions are escaped to one bounded line so control bytes cannot forge terminal structure.

## Privacy And Security Review

- No diagnostic prints proxy credentials, tokens, secret environment values, or unbounded external output.
- No live network request occurs in offline suites; only manifest canary retains live access.
- Curl ambient config cannot disable TLS verification or inject credentials/output policy.
- Caller-controlled values remain data and cannot become Make recipe or shell source.
- Locks and checks are not described as protection against hostile same-UID processes.
- Official release evidence binds the exact clean tag/workflow commit and one verified artifact pair.

## Issue Logging

For every mismatch:

1. Add a row to `docs/workorders/portable-make-commands-issues-workorder.md` before making a fix.
2. Record scenario ID, reproduction command/environment, expected and actual result, status/streams, and state snapshot location.
3. Assign severity P0-P3, affected unit, required specialist, fix summary, and exact retest scenario.
4. Mark Fixed only after the failing workflow and affected focused automated tests pass.
5. Keep unresolved issues visible; never hide them in implementation notes or specialist sign-off text.

## Execution Evidence

| Evidence | Result | Location |
|---|---|---|
| Canonical Ubuntu workflow run | Static policy executed; hosted CI cannot run locally | `.github/workflows/ci.yml`; PMC-U8-R01/R04 |
| Debian-family focused lane | Digest, command, immutable ID, and focused ownership executed statically | `.github/workflows/ci.yml`; PMC-U8-R01/R02 |
| Fedora focused lane | Digest, command, immutable ID, and focused ownership executed statically | `.github/workflows/ci.yml`; PMC-U8-R01/R02 |
| Minimum Bash/Make lane | Checksummed Bash 4.4/GNU Make 4.3 inputs and exact command executed statically | `tests/fixtures/minimum-toolchain.Dockerfile`; PMC-U8-R03 |
| Offline isolation runner | Usage, isolation refusal, loopback-only rule, bounded curl, exact filter, and zero-selection contract executed | `tests/run-portability-smoke`; PMC-U8-R02/R04 |
| Browser/UI dimensions | N/A executed: repository has no browser or graphical surface | Dimension Disposition; PMC-U8-R07 |
| Artifact/checksum handoff proof | One-pair revalidation immediately precedes attestation/upload | `.github/workflows/release.yml`; PMC-U8-R05 |
| Documentation journey | Target classes, floors, migrations, recovery, and suite ownership reviewed | PMC-WF-026; PMC-U8-R06 |
| Final issues workorder | Zero unresolved or unaccepted findings; evidence-backed U8 sign-offs recorded | `docs/workorders/portable-make-commands-issues-workorder.md` |

## Completion Gate

- [ ] All PMC-WF-001 through PMC-WF-027 scenarios pass on their required lanes.
- [ ] Every plan unit's filterable verification command passes.
- [ ] All 22 Make targets have a successful path or documented actionable refusal from a clean checkout.
- [ ] PTY, non-TTY, accessibility, stream, status, and retry contracts pass.
- [ ] Ordinary failure, process-death repair, contention, repeat-run, and cleanup snapshots pass.
- [x] Browser/UI-only dimensions remain explicitly N/A with no graphical scope added.
- [x] The issue workorder has zero unresolved unaccepted issues.
- [x] Every U8-required specialist records evidence-backed sign-off.
- [ ] Final lint, full test, verify, coverage, package, release-check, and required CI compatibility gates pass.
