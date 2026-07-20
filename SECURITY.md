# Security Policy

## Supported versions

Until 1.0, only the latest v0.x release receives security fixes. Users should
upgrade the manager before reporting a problem and confirm the issue still
reproduces.

## Reporting a manager vulnerability

Use GitHub private vulnerability reporting for this repository. Do not open a
public issue containing exploit details, credentials, private paths, or
unredacted logs. Include:

- the manager version and Linux distribution;
- the affected command and minimal reproduction;
- the expected and observed behavior;
- security impact and any suggested mitigation;
- whether the issue has been disclosed elsewhere.

If private vulnerability reporting is temporarily unavailable, open a public
issue that only asks the maintainer for a private contact path; do not include
the vulnerability details.

Maintainers follow [docs/SECURITY-MAINTAINERS.md](docs/SECURITY-MAINTAINERS.md)
for triage and coordinated disclosure.

## Upstream boundary

This repository does not redistribute Devin Desktop. It downloads an official
artifact and validates transport, metadata, digest, package structure, and
local activation. The SHA-256 digest authenticates the artifact against the
official manifest; it does not replace upstream code signing or make this
project the security contact for Devin itself.

Report vulnerabilities in the Devin Desktop application, Cognition services,
accounts, or the official release infrastructure to
[Windsurf Support](https://windsurf.com/support), not to this repository.
