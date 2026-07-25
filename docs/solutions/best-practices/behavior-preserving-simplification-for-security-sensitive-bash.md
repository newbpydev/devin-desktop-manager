---
title: Behavior-Preserving Simplification for Security-Sensitive Bash
date: 2026-07-20
category: best-practices
module: devin-desktop-manager safety and verification
problem_type: best_practice
component: tooling
severity: high
applies_when:
  - Simplifying Bash that validates ownership or migrates user installations
  - Persisted metadata formats currently share the same schema number
  - CI or release targets execute the same complete test suite more than once
  - Bats setup repeatedly rebuilds an immutable fixture
  - A refactor must preserve fail-closed behavior and coverage guarantees
related_components:
  - development_workflow
  - testing_framework
tags:
  - bash
  - security
  - fail-closed
  - schema-versioning
  - bats
  - ci
  - coverage
  - refactoring
---

# Behavior-Preserving Simplification for Security-Sensitive Bash

## Context

The manager's update, migration, uninstall, and release paths operate on
user-owned files. Simplifying them requires distinguishing incidental
repetition from independent checks that merely happen to use the same value.

During the review and simplification session, three kinds of repetition
appeared together (session history):

- CI and the release gate ran the Bats suite once through `verify` and again
  through `coverage`, even though coverage already runs all tests under BashCov
  and enforces the configured minimum (`Makefile:68-83`).
- Every manager test rebuilt the same mini Debian fixture even though Bats
  provides file-scoped setup. The immutable fixture is now built once, while
  each test still receives isolated home and mock directories
  (`tests/manager.bats:5-26`).
- Migration validators repeated the same temporary-file invariant across
  validation and cleanup paths (`bin/devin-desktop-manager:301-310`).

Earlier review sessions showed that aggregate coverage was only a signal: the
important gaps were concrete release-contract and recovery scenarios. They
also established that ownership checks and transaction ordering were
non-negotiable constraints on later simplification. (session history)

In this session, the refactor followed a characterization-first TDD loop.
Repository-policy tests failed against the old CI and Makefile wiring before
the implementation changed. The full suite then exposed two assumptions
missed by targeted tests:

- `setup_file` could own the shared fixture, but per-test setup still needed
  `FIXTURE_BUILDER` because several tests construct variant packages
  (`tests/manager.bats:14-22`, `tests/manager.bats:342-349`,
  `tests/manager.bats:430-440`).
- An exported termination mock had to be unset before the same test triggered
  its recovery mutation (`tests/manager.bats:1286-1306`).

The session's final verification output recorded 99 passing tests and 92.58%
BashCov line coverage (2033 of 2196 relevant lines). Those numbers are a dated
session result, not a persistent code property. The durable guarantees are the
checked targets and the repository's explicit 90% minimum (`Makefile:71-77`,
`tests/makefile.bats:41-47`).

## Guidance

### Let one test invocation satisfy overlapping gates

When coverage already executes the complete suite and rejects results below
the threshold, run lint separately and let coverage own the test execution.
CI now runs `make lint` followed by `bundle exec make coverage`
(`.github/workflows/ci.yml:42-45`), and `release-check` depends on
`lint coverage` before release validation and packaging (`Makefile:88-90`).
The fast local `make verify` command remains lint plus ordinary tests
(`Makefile:79-83`).

Policy tests pin both optimized paths (`tests/repository.bats:78-90`,
`tests/makefile.bats:41-47`). This keeps the optimization visible and prevents
a future edit from silently restoring duplicate work or dropping a gate.

### Hoist only immutable fixtures

Build an expensive immutable fixture at the narrowest shared lifecycle.
`setup_file` creates a read-only package in `BATS_FILE_TMPDIR`, while `setup`
continues to create mutable per-test state in `BATS_TEST_TMPDIR`
(`tests/manager.bats:5-26`). Preserve builders and helpers required for
test-specific variants.

### Centralize the complete safety predicate

Share an invariant only when every caller requires the same contract. The
temporary-file helper checks the exact allowed prefix, a numeric suffix, a
regular file, and the absence of a symlink
(`bin/devin-desktop-manager:301-310`). Legacy installation, cache, state, and
release validators call it (`bin/devin-desktop-manager:391-392`,
`bin/devin-desktop-manager:497-499`, `bin/devin-desktop-manager:523-525`,
`bin/devin-desktop-manager:550-552`), and cleanup calls the same predicate
before deletion (`bin/devin-desktop-manager:577-599`). Acceptance and removal
therefore cannot drift into different definitions of a manager temporary.

### Name compatibility contracts by domain

Ownership sentinels, release metadata, and state documents have independent
schema constants even though all currently equal `1`
(`bin/devin-desktop-manager:14-17`). Their consumers remain separate:
ownership cleanup records use `OWNERSHIP_SCHEMA_VERSION`
(`bin/devin-desktop-manager:1735-1744`), state validation uses
`STATE_SCHEMA_VERSION` (`bin/devin-desktop-manager:1175-1182`), and release
ownership uses `RELEASE_METADATA_SCHEMA_VERSION`
(`bin/devin-desktop-manager:1799-1816`). Equal current values do not make these
persisted formats one protocol.

### Prefer auditability at trust boundaries

Keep staged validation when the stages expose the invariant. Legacy release
metadata first validates object shape and types, then validates identifiers,
digest, URL, and directory identity (`bin/devin-desktop-manager:320-368`).
Legacy state migration separately checks structure, safe desktop identifiers,
managed-file hashes, and the command link
(`bin/devin-desktop-manager:420-472`).

Do not collapse these paths into TSV extraction or a broad state snapshot just
to save a few `jq` calls during a rare migration. Optimize frequent mechanical
work; prefer explicit, reviewable checks for ownership, migration, cleanup,
and release decisions.

## Why This Matters

Performance-oriented refactoring in a security-sensitive shell program can
accidentally trade visible invariants for cleverness. The selected changes
remove repeated suite execution and fixture construction while retaining the
configured lint, test, coverage, migration, release, and packaging guarantees.

Centralizing the migration predicate improves safety because validation and
cleanup share one fail-closed definition. The regression suite proves the
critical boundary: a symlinked manager temporary causes migration to fail,
does not claim the installation, and leaves the external target unchanged
(`tests/manager.bats:503-519`).

Conversely, merging independent schema constants or flattening staged
validators would reduce superficial repetition while increasing semantic
coupling and review difficulty. The simplest implementation is the one whose
guarantees remain obvious.

## When to Apply

Apply this pattern when:

- two quality-gate commands execute the same full suite and the retained
  command proves both execution and threshold enforcement;
- a fixture is expensive, immutable, and safe to share for one test file while
  mutable state remains isolated;
- several callers enforce the same complete file-safety predicate;
- equal numeric values belong to independently versioned persisted formats;
  or
- a proposed micro-optimization crosses a migration, ownership, cleanup, or
  release trust boundary.

Do not apply it when shared setup can be mutated, a narrower command omits a
gate, or consolidation would hide validation order and failure boundaries.

## Examples

Avoid running the same suite twice in a release gate:

```make
# coverage already runs the Bats suite and checks the threshold.
release-check: lint coverage
	@./scripts/release-check "$(VERSION)"
	@./scripts/package-release "$(VERSION)" "$(DIST_DIR)"
```

Share the complete temporary-file invariant:

```bash
migration_temporary_is_valid() {
  local path="$1"
  local prefix="$2"
  local name="${path##*/}"
  local expected_prefix="${prefix}."
  local suffix

  [[ "${name}" == "${expected_prefix}"* ]] || return 1
  suffix="${name#"${expected_prefix}"}"
  [[ "${suffix}" =~ ^[0-9]+$ && -f "${path}" && ! -L "${path}" ]]
}
```

Keep equal schema values semantically separate:

```bash
readonly OWNERSHIP_SCHEMA_VERSION=1
readonly RELEASE_METADATA_SCHEMA_VERSION=1
readonly STATE_SCHEMA_VERSION=1
```

Hoist the immutable default fixture without removing variant-fixture support:

```bash
setup_file() {
  local project_root fixture_builder

  project_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  fixture_builder="${project_root}/tests/fixtures/build-mini-deb"
  "${fixture_builder}" "${BATS_FILE_TMPDIR}/devin.deb"
  chmod 0444 "${BATS_FILE_TMPDIR}/devin.deb"
}

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  FIXTURE_BUILDER="${PROJECT_ROOT}/tests/fixtures/build-mini-deb"
  FIXTURE="${BATS_FILE_TMPDIR}/devin.deb"
  TEST_HOME="${BATS_TEST_TMPDIR}/home"
}
```

## Related

- [Manager implementation](../../../bin/devin-desktop-manager)
- [Manager regression suite](../../../tests/manager.bats)
- [Project quality gates](../../../Makefile)
