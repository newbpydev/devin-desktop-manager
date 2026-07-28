## Summary

<!-- What user-visible value does this change provide? -->

## Testing

- [ ] I added or updated tests before implementation for behavior changes.
- [ ] `make verify` passes.
- [ ] Tests and fixtures do not download or redistribute Devin Desktop.
- [ ] Full-suite ownership remains in `portable-canonical`; focused Linux lanes
      use `tests/run-portability-smoke --assert-offline` only.
- [ ] I recorded any local CI/environment blocker without weakening isolation,
      non-root, immutable-input, or offline requirements.

## Safety

- [ ] I reviewed download, archive, path ownership, transaction, and uninstall
      implications where relevant.
- [ ] I updated user or maintainer documentation where behavior changed.
- [ ] This change contains no credentials, private paths, or user data.
- [ ] Public guidance remains distro-neutral and documents target classes,
      status/remediation, supported floors, migration, and retry behavior.
