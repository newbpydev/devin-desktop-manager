# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Make targets now execute checkout source, apply target-class capability
  checks, and provide stable status/remediation behavior on supported Linux.
  Legacy `MANAGER` overrides are rejected because they made source identity
  ambiguous; invoke the checkout target directly instead.
- `COVERAGE_DIR` and `DIST_DIR` are restricted to project-relative paths on the
  supported local filesystem. Migrate any outside-root output into the checkout
  before invoking coverage, package, release-check, or clean.
- Packaging and release checks require the selected directory to be the exact
  Git root with a valid HEAD. Extracted source remains supported for help,
  installation, lifecycle, and applicable development commands.

### Added

- Canonical non-root Ubuntu lint/coverage evidence plus digest-pinned focused
  Debian-family, Fedora, and checksummed Bash 4.4/GNU Make 4.3 CI lanes. All
  normal suites remain offline; the scheduled manifest canary is the sole live
  request path.

### Fixed

- Safely migrate installations created by the public 0.1.0 markerless layout
  after cache eviction or an interrupted migration, without accepting unsafe
  links or weakening ownership checks for unknown directories.
- Restore the installed manager command when an interrupted uninstall rolls
  back, and resume post-commit staged-release cleanup on the next mutation.
- Enforce the 84% coverage ratchet on tagged releases and compare exact
  fresh coverage counts before rounding the displayed percentage; lock the
  complete Ruby coverage dependency graph used by CI and releases.

## [0.1.0] - 2026-07-20

### Added

- User-local installation from the official stable Linux x86_64 manifest.
- HTTPS-only downloads, SHA-256 and Debian package validation, and safe archive
  extraction.
- Transactional update, single-release rollback, and downgrade protection.
- Cross-desktop launcher, icon, URL handler, and workspace MIME integration.
- Ownership state, non-destructive default handling, and safe uninstall.
- Offline Bats and ShellCheck verification, deterministic source packages,
  pinned GitHub Actions, release provenance, and a scheduled manifest canary.

[Unreleased]: https://github.com/newbpydev/devin-desktop-manager/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/newbpydev/devin-desktop-manager/releases/tag/v0.1.0
