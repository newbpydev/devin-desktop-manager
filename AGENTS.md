# Agent Instructions

This repository is an unofficial, user-local installer and update manager for
the official stable Devin Desktop Linux bundle. It downloads the official
package directly, verifies it, and manages transactional updates and rollback.
It does not redistribute Devin Desktop.

## Read first

- `README.md` — supported scope, commands, ownership model, and security
  invariants.
- `CONTRIBUTING.md` — development setup, TDD expectations, validation, and PR
  requirements.
- `docs/RELEASING.md` — versioning, release checks, tags, publishing, and
  release-note labels.
- `SECURITY.md` — vulnerability reporting and the upstream support boundary.
- `docs/INSTALL.md` — capability-based dependencies and legacy recovery
  guidance.

## Non-negotiable boundaries

- Do not add an official Devin Desktop package, extracted application payload,
  credentials, private paths, or user data to the repository or its fixtures.
- Do not weaken fail-closed checks: official HTTPS hosts, SHA-256 verification,
  Debian identity and architecture, archive path and link validation, ownership
  markers, transaction journals, or lock semantics.
- Do not add Electron's `--no-sandbox` option or run the manager as root.
- Do not force-push, rewrite published tags, or replace assets on an immutable
  release. Publish a new patch release instead.
- Do not commit `dist/`, `coverage/`, local state, or `.kilo/` worktrees.
- Do not advise users to create ownership markers, delete lock files, or use a
  force-repair path. Recover through the documented retry and migration paths.
- Keep `main` PR-only. The repository uses squash merges, linear history,
  required CI checks, and resolved review threads.

## Development workflow

1. Start from an up-to-date `main` and create a focused branch.
2. Read the relevant implementation and tests before editing.
3. Add a focused failing Bats regression test for behavior changes. Use the
   deterministic miniature package fixtures under `tests/fixtures`; tests must
   remain offline.
4. Implement the smallest safe change in the existing Bash style. Preserve
   `set -Eeuo pipefail`, Bash 4.4 compatibility, and the manager's fail-closed
   behavior.
5. Run the focused test, then `make verify`.
6. If Ruby, Bundler, and Bashcov are available, run `bundle exec make coverage`.
   Do not lower the 84% coverage ratchet.
7. Update `CHANGELOG.md` and any user or maintainer documentation affected by
   the change.
8. Use a conventional, imperative commit subject (`fix:`, `feat:`, `docs:`,
   `chore:`). Prefer `fix:` when the change remedies broken or missing behavior.
9. Open a PR with the repository template, state the user-visible outcome, list
   the validation actually run, and record any local tooling blocker without
   weakening isolation or coverage requirements.

## Definition of done

- The behavior change has a regression test that fails for the intended reason
  before the fix.
- `make verify` passes on the exact commit being pushed.
- Relevant docs and the changelog are updated.
- CI passes, review threads are resolved, and the PR is squash-merged.
- No generated output, credentials, private paths, or user data are committed.

## Release workflow

Follow `docs/RELEASING.md` as the source of truth. The short form is:

1. Update `MANAGER_VERSION` in `bin/devin-desktop-manager` and `VERSION` in the
   `Makefile`.
2. Move the `Unreleased` changelog entries under a dated `## [X.Y.Z]` heading
   and update the compare links.
3. Update current-version examples and assertions in the README, support and
   installation docs, and the test suite.
4. Run `make verify`, `make package`, and `scripts/release-check X.Y.Z`. Run
   `bundle exec make release-check` when the locked Ruby toolchain is
   available.
5. Merge the release-preparation PR, then create an annotated tag `vX.Y.Z` on
   the merge commit and push it.
6. The release workflow reruns the full contract, creates the deterministic
   source archive and `SHA256SUMS`, attests provenance, and creates a draft
   release.
7. Verify the draft assets: download them, run
   `sha256sum --check SHA256SUMS`, confirm the archive reports `X.Y.Z`, and run
   `gh attestation verify devin-desktop-manager-X.Y.Z.tar.gz --repo newbpydev/devin-desktop-manager`.
8. Curate the release notes, then publish with
   `gh release edit vX.Y.Z --draft=false --latest`.
9. Confirm the release is published, marked Latest, and immutable releases are
   enabled in repository settings. Never replace assets on a published version;
   ship a new patch release.

## Release-note labels

Generated notes are configured by `.github/release.yml`. Apply labels before
tagging:

- `bug` and `regression` appear under Fixes.
- `compatibility` and `upstream` appear under Compatibility.
- `enhancement` appears under Features.
- `documentation` appears under Documentation.
- `dependencies`, `github-actions`, and `release` are excluded.

Dependabot applies `dependencies` and `github-actions` automatically. Keep the
label contract, `.github/dependabot.yml`, and `docs/RELEASING.md` aligned.

## Repository presentation

- Keep the README release badge pointed at the latest release.
- The social preview source is `docs/assets/social-preview.svg`; render the PNG
  with the command in `docs/RELEASING.md`.
- The social preview upload itself is a manual repository setting because
  GitHub exposes no API for it.

## When blocked

Report the exact failing command, the observed and expected result, and the
capability or environment that is missing. Preserve state and retry through the
documented path. Do not bypass a security gate, delete a lock, rewrite a
published tag, or replace an immutable release asset to make a check pass.
