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
