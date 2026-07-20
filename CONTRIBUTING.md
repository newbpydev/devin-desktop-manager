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

Use test-driven development for behavior changes:

1. Add a focused Bats test and observe it fail for the intended reason.
2. Implement the smallest safe change.
3. Run the focused test until green.
4. Run `make verify`.

Tests must remain offline and deterministic. Never add an upstream Devin
Desktop package or captured user data to a fixture. The miniature package
fixture under `tests/fixtures` is generated locally from harmless test files.

The public coverage gate requires at least 90% line coverage across `bin/` and
`scripts/`. Install Ruby and Bashcov 3.3.0, then run:

```bash
gem install bashcov -v 3.3.0
make coverage
```

Coverage is a backstop, not a substitute for behavior assertions. New failure
paths should be exercised through the public command whenever practical.

## Pull requests

- Keep each pull request focused and explain the user-visible value.
- Add or update tests and documentation with behavior changes.
- Preserve the security invariants documented in the README.
- Use a conventional, imperative commit subject when practical.
- Confirm `make verify` and `make coverage`, and describe any validation that
  cannot run locally.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
