# Contributing

Thank you for improving Devin Desktop Manager.

## Before opening a change

1. Search existing issues.
2. For security-sensitive reports, follow [SECURITY.md](SECURITY.md) instead of
   opening a public issue.
3. Keep changes within this project's scope: a user-local manager for the
   official Linux x86_64 stable bundle.

## Development setup

Install the dependencies listed in [docs/INSTALL.md](docs/INSTALL.md), fork and
clone the repository, then run:

```bash
make verify
```

Development requires Bash 4.4 or newer, GNU Make 4.3 behavior or newer, and the
target-specific tools reported by preflight on a supported local same-device
filesystem. Install them using your system documentation; repository scripts
must not assume or invoke a distro package manager. Run from the physical
project root. Extracted source can run applicable development targets, but
`package` and `release-check` require the exact Git root with a valid HEAD.

Use test-driven development for behavior changes:

1. Add a focused Bats test and observe it fail for the intended reason.
2. Implement the smallest safe change.
3. Run the focused test until green.
4. Run `make verify`.

Tests must remain offline and deterministic. Never add an upstream Devin
Desktop package or captured user data to a fixture. The miniature package
fixture under `tests/fixtures` is generated locally from harmless test files.

The public coverage gate requires at least 90% line coverage across `bin/` and
`scripts/`. Install Ruby and Bundler, then install the exact locked dependency
set and run:

```bash
bundle install
bundle exec make coverage
```

Coverage is a backstop, not a substitute for behavior assertions. New failure
paths should be exercised through the public command whenever practical.

The canonical `portable-canonical` Ubuntu job owns lint and exactly one
coverage-owned full suite. `portable-debian`, `portable-fedora`, and
`portable-minimum-toolchain` own only the focused offline smoke set; do not add
a duplicate full-suite gate to those jobs. The manifest canary is the sole live
request path.

Do not use the removed `MANAGER` override: Make targets deliberately execute
checkout source. Keep `COVERAGE_DIR` and `DIST_DIR` project-relative rather than
redirecting generated output outside-root. On a busy or recoverable status 1,
preserve state and retry the same command after applying its remediation. A
direct helper status 2 is usage failure; Make assertions use zero/nonzero.

## Pull requests

- Keep each pull request focused and explain the user-visible value.
- Add or update tests and documentation with behavior changes.
- Preserve the security invariants documented in the README.
- Use a conventional, imperative commit subject when practical.
- Confirm `make verify` and `make coverage`, and describe any validation that
  cannot run locally.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
