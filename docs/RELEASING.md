# Releasing

Only repository maintainers publish releases.

## Prepare

1. Update `MANAGER_VERSION` in `bin/devin-desktop-manager` and `VERSION` in the
   `Makefile`.
2. Move relevant changelog entries into a dated version heading.
3. Install Ruby and Bundler, run `bundle config set --local deployment true`
   followed by `bundle install`, then run `bundle exec make release-check`. The
   committed lockfile fixes Bashcov 3.3.0 and its dependency graph; the command
   runs lint, behavior tests, the 84% line-coverage ratchet, version consistency,
    and deterministic packaging with `SHA256SUMS`.
4. Review the archive contents and test installation from that archive in a
   disposable user account or VM.
5. For 0.1.1, confirm the complete initial-manager recovery fixture, one
   refusal, doctor diagnosis, interruption retry, and clean-install workflow.
   Keep affected-host evidence separate from disposable-environment evidence.
6. Confirm all four compatibility jobs pass on the same commit and the
   scheduled manifest canary is green.

Release engineering requires the selected physical directory to be the exact
Git root with a valid HEAD on a local same-device filesystem. Extracted source
is supported for help, installation, lifecycle, and applicable development
target classes, but never for `package` or `release-check`. Do not redirect
`DIST_DIR` to outside-root output; migrate legacy output to a project-relative
directory before release validation. The legacy `MANAGER` override is not a
release input because checkout targets always execute reviewed source.

Affected 0.1.0 users must obtain the verified 0.1.1 archive or checkout and run
`make install-manager` before `make update`; the old installed manager cannot
publish its own replacement. Never advise users to create ownership markers,
delete lock files, or use a force-repair path.

## Tag and draft

Create an annotated tag whose name exactly matches the manager version:

```bash
git tag -a v0.1.1 -m "Devin Desktop Manager v0.1.1"
git push origin v0.1.1
```

The release workflow rejects lightweight tags, version mismatches, and coverage
below 84%. It re-runs verification, creates the deterministic source archive and
`SHA256SUMS`, generates a GitHub artifact attestation, and creates a draft
GitHub release. It never packages or uploads Devin Desktop.

Immediately before attestation and upload, the workflow reruns the official
release contract against the clean workflow/tag commit. It rejects dirty input,
extra archives, an altered checksum, or a workflow/tag mismatch and hands off
exactly one explicitly named archive plus one `SHA256SUMS`. Status 1 requires
preserving the pair, applying the printed remediation, and retrying the same
command; direct status 2 means the invocation itself is invalid.

## Publish

1. Verify workflow permissions and the attestation summary.
2. Download the draft assets and run `sha256sum --check SHA256SUMS`.
3. Verify provenance with:

   ```bash
   gh attestation verify devin-desktop-manager-0.1.1.tar.gz \
     --repo newbpydev/devin-desktop-manager
   ```

4. Review generated notes and the changelog link.
5. Publish the draft manually.

Enable immutable releases in repository settings when available. Do not
replace assets on an existing version; publish a new patch release.
