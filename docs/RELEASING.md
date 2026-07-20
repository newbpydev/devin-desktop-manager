# Releasing

Only repository maintainers publish releases.

## Prepare

1. Update `MANAGER_VERSION` in `bin/devin-desktop-manager` and `VERSION` in the
   `Makefile`.
2. Move relevant changelog entries into a dated version heading.
3. Install Ruby and Bundler, run `bundle config set --local deployment true`
   followed by `bundle install`, then run `bundle exec make release-check`. The
   committed lockfile fixes Bashcov 3.3.0 and its dependency graph; the command
   runs lint, behavior tests, the 90% line-coverage gate, version consistency,
   and deterministic packaging with `SHA256SUMS`.
4. Review the archive contents and test installation from that archive in a
   disposable user account or VM.
5. Confirm the scheduled manifest canary is green.

To validate an extracted or staged source tree with the checker from this
checkout, set `RELEASE_CHECK_PROJECT_ROOT` to that absolute directory.

## Tag and draft

Create an annotated tag whose name exactly matches the manager version:

```bash
git tag -a v0.1.0 -m "Devin Desktop Manager v0.1.0"
git push origin v0.1.0
```

The release workflow rejects lightweight tags, version mismatches, and coverage
below 90%. It re-runs verification, creates the deterministic source archive and
`SHA256SUMS`, generates a GitHub artifact attestation, and creates a draft
GitHub release. It never packages or uploads Devin Desktop.

## Publish

1. Verify workflow permissions and the attestation summary.
2. Download the draft assets and run `sha256sum --check SHA256SUMS`.
3. Verify provenance with:

   ```bash
   gh attestation verify devin-desktop-manager-0.1.0.tar.gz \
     --repo newbpydev/devin-desktop-manager
   ```

4. Review generated notes and the changelog link.
5. Publish the draft manually.

Enable immutable releases in repository settings when available. Do not
replace assets on an existing version; publish a new patch release.
