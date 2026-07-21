# Installation

## Supported environment

Devin Desktop Manager v0.1 supports glibc-based Linux x86_64 desktops with:

- Bash 4.4 or newer;
- `curl`, `jq`, `bsdtar`, `sha256sum`, `flock`, `ldd`, `readlink`, `find`,
  `timeout`, `unshare`, and standard POSIX text tools;
- `desktop-file-validate`, `update-desktop-database`,
  `update-mime-database`, and `xdg-mime`;
- unprivileged user namespaces.

KDE's `kbuildsycoca6` is optional. When present, the manager refreshes the KDE
cache; its absence does not prevent installation on GNOME, Cinnamon, XFCE, or
other XDG-compatible desktops.

## Dependencies

Ubuntu 24.04 / Debian:

```bash
sudo apt-get update
sudo apt-get install curl jq libarchive-tools util-linux \
  desktop-file-utils shared-mime-info xdg-utils
```

Arch Linux / CachyOS:

```bash
sudo pacman -S --needed bash curl jq libarchive util-linux \
  desktop-file-utils shared-mime-info xdg-utils
```

Fedora:

```bash
sudo dnf install bash curl jq bsdtar util-linux \
  desktop-file-utils shared-mime-info xdg-utils
```

Package names can differ on derivatives. The manager reports every missing
command before changing an installation.

## Install from a versioned release

Download the source archive and `SHA256SUMS` from the same GitHub release,
verify it, then extract and install:

```bash
sha256sum --check SHA256SUMS
tar -xzf devin-desktop-manager-0.1.0.tar.gz
cd devin-desktop-manager-0.1.0
make install
make doctor
```

Release artifacts also receive GitHub artifact attestations. See
[docs/RELEASING.md](RELEASING.md) for verification guidance.

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

## Existing path collisions

The manager creates versioned ownership markers in its installation, cache,
and state roots. It automatically migrates the public 0.1.0 markerless layout
only after validating its release links, release metadata, state paths, and
managed-file hashes. A near-miss or any other path containing data without a
valid marker is left unchanged. Move that conflicting path aside, inspect its
contents, and retry. Do not add a marker by hand: ownership metadata is part of
the manager's deletion safety boundary.

Interrupted mutations leave a private transaction journal beside the state
directory. The next mutating command acquires the manager lock and restores
that journal before starting new work. If interruption happens after an
uninstall commits, a separate validated cleanup record lets the next mutation
remove only the manager-owned staged release tree.

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
`/tmp` are rejected.
