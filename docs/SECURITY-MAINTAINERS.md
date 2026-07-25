# Security Maintainer Runbook

## Repository settings

- Enable GitHub private vulnerability reporting.
- Require pull-request review and the CI check on the default branch.
- Restrict tag creation for `v*` to maintainers.
- Enable immutable releases when available.
- Keep Dependabot updates enabled for GitHub Actions.

These hosted settings cannot be enforced by repository files and must be
checked after the repository is created.

## Triage

1. Acknowledge a private report promptly without confirming impact prematurely.
2. Preserve the report, reproduction, affected versions, and disclosure status.
3. Reproduce in an isolated account with harmless fixtures; do not use real
   credentials or user workspaces.
4. Decide whether the issue belongs to this manager or upstream Devin. Redirect
   upstream issues without copying confidential reporter data.
5. Prepare a regression test before the fix whenever safely possible.

## Remediation

1. Develop the smallest fix on a private security fork when confidentiality is
   required.
2. Run `make verify`, `make coverage`, and focused adversarial tests.
3. Review archive, ownership, downloader, workflow-permission, and release
   implications.
4. Request a CVE through the GitHub security advisory when appropriate.
5. Agree on disclosure timing with the reporter.

## Release and disclosure

Publish a new patch version; never replace an existing release asset. Credit
the reporter if they consent. Include impact, affected versions, remediation,
and upgrade instructions without unnecessary exploit detail. After release,
verify the checksum, artifact attestation, and public advisory.
