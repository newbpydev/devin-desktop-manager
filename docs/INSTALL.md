# Installation

## Supported environment

Devin Desktop Manager v0.1 supports glibc-based Linux x86_64 desktops with:

- Bash 4.4 or newer;
- GNU Make compatible with 4.3 behavior or newer;
- `curl`, `jq`, `bsdtar`, `sha256sum`, `flock`, `ldd`, `readlink`,
  `find`, `timeout`, `unshare`, and standard POSIX text tools;
- `desktop-file-validate`, `update-desktop-database`,
  `update-mime-database`, and `xdg-mime`;
- unprivileged user namespaces.
- a local same-device filesystem that supports atomic rename, advisory `flock`,
  stable inode identity, and single-link regular files for managed output.

KDE's `kbuildsycoca6` is optional. When present, the manager refreshes the KDE
cache; its absence does not prevent installation on GNOME, Cinnamon, XFCE, or
other XDG-compatible desktops.

## Dependencies

Install the capabilities above using your operating system's documentation.
Package names and package manager commands differ between distributions, so the
project does not guess or run one. Preflight reports every missing or
incompatible target-specific capability before changing an installation; use
that generic remediation list to select packages for your system.

## Install from a versioned release

Download the source archive and `SHA256SUMS` from the same GitHub release,
verify it, then extract and install:

```bash
sha256sum --check SHA256SUMS
tar -xzf devin-desktop-manager-0.1.1.tar.gz
cd devin-desktop-manager-0.1.1
make install
make doctor
```

Release artifacts also receive GitHub artifact attestations. See
[docs/RELEASING.md](RELEASING.md) for verification guidance.

An extracted source archive supports `make help`, installation, lifecycle, and
applicable development target classes. `make package` and `make release-check`
intentionally refuse extracted source because release provenance requires the
selected path to be the exact Git root with a valid HEAD. Clone the repository
and run those release-engineering targets from its physical top level.

## Install from Git

```bash
git clone https://github.com/newbpydev/devin-desktop-manager.git
cd devin-desktop-manager
make verify
make install
make doctor
```

No command requires `sudo`. Running the manager as root is intentionally
refused. Add `~/.local/bin` to `PATH` if your distribution does not already.

## Recover an installation made by the initial manager

Start from verified 0.1.1 source. The old 0.1.0 manager cannot update itself;
its `update` command updates Devin Desktop only. From the verified Git checkout
or extracted 0.1.1 archive, publish the repaired manager first and prove which
binary will run:

```bash
make install-manager
devin-desktop-manager --version
# Expected: devin-desktop-manager 0.1.1
make doctor
make update
make doctor
```

Before recovery, `doctor` returns status 1 and identifies an exact complete
initial-manager profile as a recoverable Legacy Installation. `update`,
`rollback`, and uninstall revalidate that profile under their normal locks;
they never treat the earlier diagnosis as ownership authority. Close Devin
Desktop if requested, then retry the same command.

A refusal naming an invariant means the layout is not safely attributable.
Ownership was not claimed. Preserve the files, inspect or move aside only the
reported conflict, and retry. Do not add a marker by hand, edit release
metadata, delete transaction state, or remove persistent lock files.

Checkout targets always execute `bin/devin-desktop-manager`. The legacy
`MANAGER=...` Make override is no longer accepted; call a separately installed
manager directly when that is what you intend to test. `COVERAGE_DIR` and
`DIST_DIR` must be project-relative. Move legacy outside-root output into a
project-relative directory or archive it elsewhere, then retry the same
command.

## Existing path collisions

The manager creates versioned ownership markers in its installation, cache,
and state roots. It automatically migrates the recognized public 0.1.0 layouts
and the complete initial-manager profile only after validating their release
links, metadata, state paths, desktop semantics, assets, and MIME provenance. A
near-miss or any other path containing data without valid proof is left
unchanged. Move that conflicting path aside, inspect its contents, and retry.
Do not add a marker by hand: ownership metadata is part of the manager's
deletion safety boundary.

Interrupted mutations leave a private transaction journal beside the state
directory. The next mutating command acquires the manager lock and restores
that journal before starting new work. If interruption happens after an
uninstall commits, a separate validated cleanup record lets the next mutation
remove only the manager-owned staged release tree.

Busy operations fail without mutation. Wait for the named holder to exit and
retry the same command; do not remove persistent lock files. For an unsafe
coverage or package candidate, preserve it, follow the exact inspection or
move-aside remediation printed on stderr, and rerun the command. Direct helper
usage errors return status 2, operational/isolation failures return status 1,
and Make callers should rely only on zero versus nonzero.

## User namespaces

The extracted Electron bundle cannot use a root-owned setuid sandbox in a
user-local installation. The manager therefore requires working unprivileged
user namespaces and will not fall back to `--no-sandbox`. Consult your
distribution documentation if `unshare --user --map-root-user true` fails.

## XDG paths

The manager respects absolute `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`,
`XDG_DATA_HOME`, and `XDG_STATE_HOME` values. Relative XDG paths are refused to
avoid writing to an unexpected directory. Because transaction journals and
locks live in `XDG_STATE_HOME`, that directory must be owned by the current
user and must not be group- or world-writable; shared directories such as
`/tmp` are rejected. XDG homes also cannot live beneath the manager's install,
cache, or state roots, and the derived manager cache and state roots cannot
overlap, because uninstall removes those manager-owned trees recursively.
