# Devin Desktop Manager

[![CI](https://github.com/newbpydev/devin-desktop-manager/actions/workflows/ci.yml/badge.svg)](https://github.com/newbpydev/devin-desktop-manager/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

An unofficial, user-local installer and update manager for the official stable
Devin Desktop Linux bundle. It downloads directly from Cognition's official
release channel, verifies the published SHA-256 digest and package invariants,
and provides transactional updates and rollback without AUR packaging or
`sudo`.

This project is not affiliated with, endorsed by, or supported by Cognition.
It does not redistribute Devin Desktop or include an upstream `.deb`; every
application install is downloaded directly from the official release host.

## Compatibility

- glibc-based Linux x86_64 (amd64)
- Bash 4.4 or newer
- GNU Make 4.3 behavior or newer
- a local same-device filesystem with atomic rename and advisory locking
- an XDG-compatible desktop; KDE integration is optional
- unprivileged user namespaces for Electron sandboxing

See [Installation](docs/INSTALL.md) for capability-based dependencies. The
project reports missing or incompatible tools but never assumes a package
manager or installs system packages.
ARM64, macOS, Windows, musl-only distributions, system-wide installs, and
distribution packages are outside the v0.1 scope.

## Install

```bash
git clone https://github.com/newbpydev/devin-desktop-manager.git
cd devin-desktop-manager
make install
make doctor
```

`make install` first atomically copies the manager to
`~/.local/bin/devin-desktop-manager`, then installs the current official stable
application. Use `make install-manager` if you only want the manager command and
do not want to download Devin Desktop yet.

Ensure `~/.local/bin` is on your `PATH`, then the manager can also be called
directly:

```bash
devin-desktop-manager --version
devin-desktop-manager status
```

## Normal workflow

```bash
make check
make update
make doctor
```

`check` reads the official manifest without creating installation state.
`update` downloads, validates, stages, and transactionally activates a release.
One previous release is retained:

```bash
make rollback
```

The manager registers its desktop entries without replacing an unrelated
default application. To explicitly make Devin the default for its URL schemes
and workspace files:

```bash
make set-defaults
```

## Commands

| Command | Purpose |
| --- | --- |
| `make install` | Install the manager and current official stable app |
| `make install-manager` | Copy only the manager command |
| `make status` | Show current and previous releases |
| `make check` | Check the stable manifest without mutation |
| `make update` | Validate and transactionally activate stable |
| `make rollback` | Swap current and previous releases |
| `make set-defaults` | Explicitly claim Devin URL/workspace defaults |
| `make doctor` | Validate the app, sandbox, state, and integration |
| `make uninstall` | Interactively remove manager-owned files |
| `make verify` | Run the complete offline lint and test gate |
| `make coverage` | Run the suite with the enforced 84% line-coverage ratchet |

`make link-dev` is only for contributors; public installs are independent
copies and do not break when the clone is moved or deleted.

The target classes are: bootstrap discovery (`help`); checkout-manager reads
and lifecycle mutations; installed-application queries and launch;
installer-local publication (`install-manager`, `link-dev`, and `link`);
development gates (`lint`, `test`, `verify`, and `coverage`); exact-root release
engineering (`package` and `release-check`); and bounded generated-output
cleanup (`clean`). Each class checks only the capabilities it needs before its
first mutation or external effect.

Normal results use status 0. Direct runtime, preflight, busy, or recoverable
operation failures use status 1; direct helper usage errors use status 2; GNU
Make reports only zero or nonzero. Follow the generic remediation in stderr,
correct the named capability or path, and retry the same command. Never delete
a lock file to bypass a busy diagnostic.

## Security and ownership

The manager:

- accepts only the official HTTPS manifest and artifact hosts;
- restricts redirects to HTTPS and bounds retries, redirects, and timeouts;
- checks SHA-256, Debian package identity, architecture, metadata, paths, and
  escaping archive links before activation;
- validates the extracted application and its reported build;
- never adds Electron's insecure `--no-sandbox` option;
- records a durable transaction journal before changing release links,
  integration files, MIME defaults, or state, and recovers it after interruption;
- records committed uninstall cleanup separately, so the next mutation can
  safely remove a staged release tree left by interruption;
- marks manager roots and releases with versioned ownership metadata, refusing
  to overwrite or recursively remove paths it cannot prove it owns.

Releases live under `~/.local/opt/devin-desktop`. Manager state is stored with
mode `0600` at
`${XDG_STATE_HOME:-~/.local/state}/devin-desktop-manager/state.json`.
Desktop, icon, and MIME files use manager-specific names under
`${XDG_DATA_HOME:-~/.local/share}`. A hidden, manager-owned
`devin-desktop.desktop` compatibility entry matches the application's runtime
identity so desktop shells can persist pinned launchers without adding a
duplicate application-menu entry.

Recognized markerless installations are migrated automatically only after all
profile-specific ownership evidence validates. This includes the public 0.1.0
layouts and the complete initial-manager layout with exact legacy desktop
semantics, release-matching assets, and traceable MIME associations. `doctor`
reports that exact state as a recoverable Legacy Installation. A near-miss,
modern manager default without state, modified file, or untraceable association
is left unchanged; inspect or move aside the reported conflict. Do not add a
marker by hand or delete a lock to force adoption.

If an installed 0.1.0 manager refuses this legacy profile, first obtain the
verified 0.1.1 source, then install the fixed manager before updating the app:

```bash
make install-manager
devin-desktop-manager --version
make update
make doctor
```

The old manager's `update` command updates Devin Desktop, not the manager
binary, so it cannot bootstrap this compatibility fix by itself.

The separate official `devin` CLI and Devin/Windsurf user configuration are
outside this project's ownership and are preserved by uninstall.

For vulnerability reporting and the supported-version policy, read
[SECURITY.md](SECURITY.md). For usage help, read [SUPPORT.md](SUPPORT.md).

## Uninstall

```bash
make uninstall
```

Uninstall restores a previous MIME default only when the manager is still the
current default. Defaults or managed-looking files changed by the user are
preserved. For automation, use `make uninstall-yes`.

## Development

```bash
bundle install
make verify
bundle exec make coverage
make package
```

Tests use deterministic miniature Debian-package fixtures and never download
Devin Desktop. The separate scheduled canary checks the live official manifest.
The canonical Ubuntu CI job owns lint and the single coverage/full-suite run;
Debian-family, Fedora, and minimum Bash 4.4/GNU Make 4.3 lanes run only the
focused offline portability smoke set.
See [CONTRIBUTING.md](CONTRIBUTING.md) for locked Bashcov setup and the TDD workflow,
and [docs/RELEASING.md](docs/RELEASING.md) for the release process.

## License

The manager source is available under the [MIT License](LICENSE). Devin Desktop
is third-party software governed by its upstream terms.
