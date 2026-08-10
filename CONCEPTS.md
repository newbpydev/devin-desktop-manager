# Concepts

Shared domain vocabulary for this project — entities, named processes, and
status concepts with project-specific meaning. Seeded with core domain
vocabulary, then accretes as ce-compound and ce-compound-refresh process
learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Installation ownership and release lifecycle

### Managed Installation

A user-local Devin Desktop installation whose managed roots and release
inventory carry the ownership evidence required before destructive changes.

### Manager-Owned Root

A directory whose ownership marker identifies Devin Desktop Manager and a
supported ownership contract.

An existing non-empty directory without that proof is treated as user-owned
and is not claimed, overwritten, or recursively removed.

### Managed Release

An official Devin Desktop payload that has passed the manager's release
validation and is recorded in a Managed Installation's release inventory.

### Current Release

The Managed Release selected as the active application target.

### Previous Release

The last displaced Current Release retained as the rollback target.

### Legacy Installation

A Managed Installation candidate created before ownership evidence was
recorded, eligible to be claimed only after its recognized roots, release
inventory, integration, and state pass legacy verification.

An Initial-Manager Profile may be described by `doctor` as a recoverable Legacy
Installation, but mutating commands always classify it again under their
lifecycle locks.

### Initial-Manager Profile

The exact markerless Legacy Installation shape produced before ownership state
was recorded, distinguished by matching release, desktop integration, and
reversible user-association evidence.

It is recoverable only when every ownership signal agrees; a modified,
untraceable, or foreign-owned signal makes it a Legacy Conflict.

### Legacy Conflict

A markerless candidate that misses any recognized profile invariant. The
manager reports one bounded reason and does not claim ownership. A Legacy
Conflict cannot be converted by manually adding markers, editing release
metadata, or deleting locks.

### Manager Temporary

A transient regular file with an explicitly recognized name and numeric suffix
that the manager may validate or remove while completing ownership migration.

Manager Temporaries never include symbolic links; an unexpected type, name, or
suffix makes the surrounding migration fail closed.

## Relationships

A Managed Installation owns its Managed Releases. A healthy installed
application selects one Current Release and may retain one Previous Release;
activation moves the displaced Current Release into the Previous Release role.
