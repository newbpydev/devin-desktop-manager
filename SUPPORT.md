# Support

## Manager problems

For installation, update, rollback, desktop integration, or uninstall problems:

1. Run `devin-desktop-manager status`.
2. Run `devin-desktop-manager doctor`.
3. Search the repository's existing issues.
4. Open a bug report with the manager version, distribution, desktop
   environment, command output, and reproduction steps.

Remove usernames, tokens, private paths, workspace names, and other sensitive
data before posting logs. Do not publish vulnerability details; use
[SECURITY.md](SECURITY.md).

When preflight reports a missing or incompatible command, use your
distribution's documentation to provide that capability; support guidance does
not assume a package manager. For status 1 busy or recoverable failures, retain
the reported state, wait for any holder to exit, and retry the same command.
Never delete a lock or ownership marker. Status 2 from a direct helper means its
invocation is invalid and should be corrected before retrying.

If `doctor` reports a recoverable Legacy Installation, obtain verified 0.1.1
source and run `make install-manager` before the lifecycle command it names.
The old 0.1.0 manager cannot update itself. A diagnostic that instead names a
failed invariant is a conflict: ownership was not claimed, so preserve the
layout and inspect or move aside only the reported path or association. Do not
create ownership markers, edit metadata, or remove persistent lock files.

Report whether the failing target class is bootstrap, checkout-manager,
installed-application, installer-local, development, release engineering, or
generated-output cleanup. Also report whether the physical checkout is an
exact Git root or extracted source and whether output is on a local same-device
filesystem. Legacy `MANAGER` and outside-root output overrides are unsupported;
use checkout source and project-relative output paths.

## Devin product problems

This is an unofficial installer project and cannot support the Devin Desktop
application, accounts, billing, or upstream service availability. Contact
[Windsurf Support](https://windsurf.com/support) for product support.

## Scope

The supported platform is a glibc-based Linux x86_64 desktop using an
unprivileged user install. Packaging for distributions and other operating
systems or architectures is not currently supported.
