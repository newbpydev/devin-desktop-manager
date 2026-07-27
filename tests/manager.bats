#!/usr/bin/env bats

set -e

setup_file() {
  local project_root fixture_builder

  project_root="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  fixture_builder="${project_root}/tests/fixtures/build-mini-deb"
  "${fixture_builder}" "${BATS_FILE_TMPDIR}/devin.deb"
  chmod 0444 "${BATS_FILE_TMPDIR}/devin.deb"
}

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  MANAGER="${PROJECT_ROOT}/bin/devin-desktop-manager"
  FIXTURE_BUILDER="${PROJECT_ROOT}/tests/fixtures/build-mini-deb"
  TEST_HOME="${BATS_TEST_TMPDIR}/home"
  MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
  CURL_LOG="${BATS_TEST_TMPDIR}/curl.log"
  DEFAULTS_FILE="${TEST_HOME}/.config/mimeapps.list"
  FIXTURE="${BATS_FILE_TMPDIR}/devin.deb"
  LOCK_HOLDER_PID=""
  export TEST_HOME MOCK_BIN CURL_LOG DEFAULTS_FILE

  mkdir -p "${TEST_HOME}" "${MOCK_BIN}"
  write_platform_mocks
}

stop_lock_holder() {
  [[ -n "${LOCK_HOLDER_PID:-}" ]] || return 0
  kill "${LOCK_HOLDER_PID}" 2>/dev/null || true
  wait "${LOCK_HOLDER_PID}" 2>/dev/null || true
  LOCK_HOLDER_PID=""
}

start_lock_holder() {
  local lock_path="$1"
  local ready_path="$2"
  local attempt

  env READY_FILE="${ready_path}" \
    flock --no-fork -x "${lock_path}" bash -c '
      printf "ready\n" >"${READY_FILE}"
      exec sleep 30
    ' &
  LOCK_HOLDER_PID=$!
  for attempt in {1..500}; do
    [[ -e "${ready_path}" ]] && return 0
    sleep 0.01
  done
  stop_lock_holder
  return 1
}

teardown() {
  stop_lock_holder
}

write_platform_mocks() {
  cat >"${MOCK_BIN}/unshare" <<'EOF'
#!/usr/bin/env bash
[[ "${MOCK_UNSHARE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/ldd" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'ldd (GNU libc) 2.39\n'
fi
exit 0
EOF
  cat >"${MOCK_BIN}/timeout" <<'EOF'
#!/usr/bin/env bash
if [[ "${MOCK_TIMEOUT_FAIL:-0}" == "1" ]]; then
  exit 124
fi
exec "$(command -p -v timeout)" "$@"
EOF
  cat >"${MOCK_BIN}/desktop-file-validate" <<'EOF'
#!/usr/bin/env bash
[[ "${MOCK_DESKTOP_VALIDATE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/update-desktop-database" <<'EOF'
#!/usr/bin/env bash
if [[ "${MOCK_CACHE_REQUIRE_DIRECTORY:-0}" == "1" ]]; then
  [[ -d "$1" ]] || exit 75
fi
[[ "${MOCK_DESKTOP_CACHE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/update-mime-database" <<'EOF'
#!/usr/bin/env bash
if [[ "${MOCK_CACHE_REQUIRE_DIRECTORY:-0}" == "1" ]]; then
  [[ -d "$1" ]] || exit 75
fi
[[ "${MOCK_MIME_CACHE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/kbuildsycoca6" <<'EOF'
#!/usr/bin/env bash
[[ "${MOCK_KDE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/xdg-mime" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
database="${XDG_CONFIG_HOME}/mimeapps.list"
mkdir -p "$(dirname "${database}")"

case "${1:-}" in
  query)
    [[ "${2:-}" == "default" && $# -eq 3 ]] || exit 2
    [[ "${MOCK_XDG_QUERY_FAIL:-0}" != "1" ]] || exit 70
    if [[ "${MOCK_XDG_KDE_UNSET_FAIL:-0}" == "1" &&
      "${XDG_CURRENT_DESKTOP:-}" == "KDE" &&
      "${KDE_SESSION_VERSION:-}" == "5" ]]; then
      exit 4
    fi
    [[ -f "${database}" ]] || exit 0
    awk -F= -v key="$3" '
      $0 == "[Default Applications]" { defaults = 1; next }
      /^\[/ { defaults = 0 }
      defaults && $1 == key {
        sub(/;.*/, "", $2)
        print $2
        exit
      }
    ' "${database}"
    ;;
  default)
    [[ $# -eq 3 ]] || exit 2
    desktop_id="$2"
    mime_type="$3"
    temporary="${database}.tmp"
    [[ -f "${database}" ]] || printf '[Default Applications]\n' >"${database}"
    awk -v key="${mime_type}" -v value="${desktop_id};" '
      BEGIN { in_defaults = 0; wrote = 0; saw_defaults = 0 }
      $0 == "[Default Applications]" {
        print
        in_defaults = 1
        saw_defaults = 1
        next
      }
      in_defaults && /^\[/ {
        if (!wrote) {
          print key "=" value
          wrote = 1
        }
        in_defaults = 0
      }
      in_defaults && index($0, key "=") == 1 {
        if (!wrote) {
          print key "=" value
          wrote = 1
        }
        next
      }
      { print }
      END {
        if (!saw_defaults) {
          print "[Default Applications]"
        }
        if (!wrote) {
          print key "=" value
        }
      }
    ' "${database}" >"${temporary}"
    mv "${temporary}" "${database}"
    ;;
  *)
    exit 2
    ;;
esac
EOF
  cat >"${MOCK_BIN}/chmod" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${MOCK_CHMOD_FAIL_PATTERN:-}" && "$*" == *"${MOCK_CHMOD_FAIL_PATTERN}"* ]]; then
  exit 71
fi
exec "$(command -p -v chmod)" "$@"
EOF
  cat >"${MOCK_BIN}/cp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${MOCK_CP_FAIL_PATTERN:-}" && "$*" == *"${MOCK_CP_FAIL_PATTERN}"* ]]; then
  exit 72
fi
exec "$(command -p -v cp)" "$@"
EOF
  cat >"${MOCK_BIN}/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${MOCK_MV_FAIL_PATH:-}" ]]; then
  for argument in "$@"; do
    [[ "${argument}" != "${MOCK_MV_FAIL_PATH}" ]] || exit 74
  done
fi
exec "$(command -p -v mv)" "$@"
EOF
  cat >"${MOCK_BIN}/rm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${MOCK_RM_FAIL_PATH:-}" ]]; then
  for argument in "$@"; do
    [[ "${argument}" != "${MOCK_RM_FAIL_PATH}" ]] || exit 73
  done
fi
if [[ -n "${MOCK_RM_PARTIAL_SIGNAL_PATH:-}" ]]; then
  for argument in "$@"; do
    if [[ "${argument}" == "${MOCK_RM_PARTIAL_SIGNAL_PATH}" ||
      "${argument}" == "${MOCK_RM_PARTIAL_SIGNAL_PATH}/"* ]]; then
      "$(command -p -v rm)" -rf -- "${argument}"
      kill -TERM "${PPID}"
      exit 143
    fi
  done
fi
if [[ -n "${MOCK_RM_SIGNAL_AFTER_PATH:-}" ]]; then
  for argument in "$@"; do
    if [[ "${argument}" == "${MOCK_RM_SIGNAL_AFTER_PATH}" ]]; then
      "$(command -p -v rm)" "$@"
      kill -TERM "${PPID}"
      exit 0
    fi
  done
fi
if [[ -n "${MOCK_RM_SIGNAL_BEFORE_PATTERN:-}" &&
  "$*" == *"${MOCK_RM_SIGNAL_BEFORE_PATTERN}"* ]]; then
  kill -TERM "${PPID}"
  exit 143
fi
exec "$(command -p -v rm)" "$@"
EOF
  chmod 0755 "${MOCK_BIN}"/*
}

write_manifest_curl() {
  local artifact_url="$1"
  local fixture="${2:-${FIXTURE}}"
  local version="${3:-3.4.27}"
  local build="${4:-0d4bf12ed4a7597cb8ae9016fe8474468aad98a2}"
  local timestamp="${5:-1783378473000}"
  local sha256

  sha256="$(sha256sum "${fixture}" | awk '{print $1}')"
  cat >"${MOCK_BIN}/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--disable" && "\${2:-}" == "--version" ]]; then
  printf 'curl 8.0 test\nProtocols: http https\nFeatures: SSL\n'
  exit 0
fi
printf '%s\n' "\$*" >>"${CURL_LOG}"
output=""
header=""
url="\${!#}"
while ((\$# > 0)); do
  case "\$1" in
    --output) output="\$2"; shift 2 ;;
    --dump-header) header="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'HTTP/1.1 200 OK\r\n\r\n' >"\${header}"
if [[ "\${url}" == "https://windsurf-stable.codeium.com/api/update/linux-x64-deb/stable/latest" ]]; then
  cat >"\${output}" <<'JSON'
{
  "url": "${artifact_url}",
  "name": "1.110.1",
  "notes": "${build}",
  "version": "${build}",
  "productVersion": "1.110.1",
  "hash": "4055e5e6f3303ca706bf01236cca3f304e0aef09",
  "timestamp": ${timestamp},
  "sha256hash": "${sha256}",
  "supportsFastUpdate": true,
  "windsurfVersion": "${version}",
  "displayName": "Linux x64 for Debian (.deb)"
}
JSON
else
  if [[ "\${MOCK_ARTIFACT_DOWNLOAD_FAIL:-0}" == "1" ]]; then
    printf 'partial fixture\n' >"\${output}"
    exit 22
  fi
  cp -- "${fixture}" "\${output}"
fi
EOF
  chmod 0755 "${MOCK_BIN}/curl"
}

manager_env() {
  env \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" "$@"
}

record_prune_intent_for_release() {
  local release_dir="$1"
  local record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local release_name identity device inode quarantine_name metadata_sha256

  release_name="$(basename "${release_dir}")"
  identity="$(stat -c '%d %i' -- "${release_dir}")"
  read -r device inode <<<"${identity}"
  metadata_sha256="$(sha256sum "${release_dir}/release.json" | awk '{print $1}')"
  quarantine_name=".release-prune-${release_name}-${device}-${inode}"
  [[ ! -e "${record}" && ! -L "${record}" ]]
  jq -n \
    --arg manager_id "io.github.newbpydev.devin-desktop-manager" \
    --arg release_name "${release_name}" \
    --arg quarantine_name "${quarantine_name}" \
    --arg device "${device}" \
    --arg inode "${inode}" \
    --arg metadata_sha256 "${metadata_sha256}" '{
      schemaVersion: 1,
      managerId: $manager_id,
      releaseName: $release_name,
      quarantineName: $quarantine_name,
      device: $device,
      inode: $inode,
      metadataSha256: $metadata_sha256
    }' >"${record}"
  chmod 0600 "${record}"
}

prune_quarantine_path() {
  local release_dir="$1"
  local identity device inode

  identity="$(stat -c '%d %i' -- "${release_dir}")"
  read -r device inode <<<"${identity}"
  printf '%s/.release-prune-%s-%s-%s\n' \
    "${TEST_HOME}/.local/opt/devin-desktop" \
    "$(basename "${release_dir}")" "${device}" "${inode}"
}

copy_release_with_identity() {
  local source_dir="$1"
  local version="$2"
  local build="$3"
  local sha256="$4"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local release_id destination temporary

  release_id="${version}-${build:0:12}-${sha256:0:12}"
  destination="${install_root}/releases/${release_id}"
  cp -a -- "${source_dir}" "${destination}"
  temporary="${destination}/release.json.test"
  jq \
    --arg version "${version}" \
    --arg build "${build}" \
    --arg sha256 "${sha256}" \
    --arg artifact_url "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${build}/Devin-linux-x64-${version}.deb" '
      .windsurfVersion = $version |
      .productVersion = $version |
      .build = $build |
      .artifactUrl = $artifact_url |
      .sha256 = $sha256
    ' "${destination}/release.json" >"${temporary}"
  mv -Tf -- "${temporary}" "${destination}/release.json"
  printf '%s\n' "${destination}"
}

seed_defaults() {
  mkdir -p "$(dirname "${DEFAULTS_FILE}")"
  cat >"${DEFAULTS_FILE}" <<'EOF'
[Default Applications]
x-scheme-handler/devin=browser.desktop;
x-scheme-handler/windsurf=editor.desktop;
application/x-devin-desktop-workspace=workspace.desktop;
EOF
}

query_default() {
  env XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    "${MOCK_BIN}/xdg-mime" query default "$1"
}

install_fixture() {
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"
  manager_env update
}

downgrade_to_public_0_1_layout() {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cache_root="${TEST_HOME}/.cache/devin-desktop-manager"
  local state_root="${TEST_HOME}/.local/state/devin-desktop-manager"
  local metadata temporary

  while IFS= read -r -d '' metadata; do
    temporary="${metadata}.legacy"
    jq 'del(.schemaVersion, .managerId)' "${metadata}" >"${temporary}"
    mv -Tf -- "${temporary}" "${metadata}"
  done < <(find "${install_root}/releases" -name release.json -type f -print0)
  rm -f -- \
    "${install_root}/.devin-desktop-manager-owned" \
    "${cache_root}/.devin-desktop-manager-owned" \
    "${state_root}/.devin-desktop-manager-owned"
  : >"${install_root}/.manager.lock"
}

@test "version reports the public CLI contract" {
  run "${MANAGER}" --version

  [ "${status}" -eq 0 ]
  [ "${output}" = "devin-desktop-manager 0.1.0" ]
}

@test "no arguments show help successfully" {
  run "${MANAGER}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Usage: devin-desktop-manager <command>"* ]]
}

@test "[PMC-U4-R05] non-TTY uninstall rejects before publication or lifecycle state" {
  local publication_lock="${TEST_HOME}/.local/bin/.devin-desktop-manager.publication.lock"
  local lifecycle_lock="${TEST_HOME}/.local/state/devin-desktop-manager.lock"

  run manager_env uninstall </dev/null

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"make uninstall-yes"* ]]
  [ ! -e "${publication_lock}" ]
  [ ! -e "${lifecycle_lock}" ]
}

@test "[PMC-U4-R06] uninstall-yes never reads stdin and remains a no-op when absent" {
  run bash -c 'printf "must-not-be-read\n" | "$@"' _ env \
    HOME="${TEST_HOME}" XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" uninstall-yes

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"managed application removed"* ]]
}

@test "[PMC-U2-C01] status is read-only and reports an empty installation" {
  run manager_env status

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Current:  not installed"* ]]
  [[ "${output}" == *"Previous: none"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager" ]
}

@test "[PMC-U2-R01] runtime blockers aggregate before state or network access" {
  local sparse_bin="${BATS_TEST_TMPDIR}/sparse-bin"

  mkdir -p "${sparse_bin}"
  ln -s "$(command -v bash)" "${sparse_bin}/bash"
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/state" \
    PATH="${sparse_bin}" "${MANAGER}" update

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"update: error:"* ]]
  [[ "${output}" == *"curl"* ]]
  [[ "${output}" == *"jq"* ]]
  [[ "${output}" == *"bsdtar"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
  [ ! -e "${TEST_HOME}/state" ]
  [ ! -e "${CURL_LOG}" ]
}

@test "[PMC-U2-R02] incompatible tools are distinct and profiles stay scoped" {
  cat >"${MOCK_BIN}/readlink" <<'EOF'
#!/usr/bin/env bash
printf 'not-a-canonical-path\n'
EOF
  chmod 0755 "${MOCK_BIN}/readlink"

  run manager_env status

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"incompatible"* ]]
  [[ "${output}" == *"readlink"* ]]
  [[ "${output}" != *"bsdtar"* ]]
  [ ! -e "${TEST_HOME}/.local/state" ]
}

@test "[PMC-U2-R03] private profiles reject unknown commands as usage" {
  local stdout_file="${BATS_TEST_TMPDIR}/stdout"
  local stderr_file="${BATS_TEST_TMPDIR}/stderr"

  run bash -c '"$1" internal-preflight 1 unknown >"$2" 2>"$3"' \
    _ "${MANAGER}" "${stdout_file}" "${stderr_file}"

  [ "${status}" -eq 2 ]
  [ ! -s "${stdout_file}" ]
  grep -Fq 'internal-preflight' "${stderr_file}"

  cat >"${MOCK_BIN}/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -s) printf 'Linux\n' ;;
  -m) printf 'aarch64\n' ;;
esac
EOF
  cat >"${MOCK_BIN}/ldd" <<'EOF'
#!/usr/bin/env bash
printf 'unknown libc evidence\n'
EOF
  chmod 0755 "${MOCK_BIN}/uname" "${MOCK_BIN}/ldd"
  run bash -c 'HOME="$1" PATH="$2:$PATH" \
    "$3" internal-preflight 1 status >"$4" 2>"$5"' \
    _ "${TEST_HOME}" "${MOCK_BIN}" "${MANAGER}" "${stdout_file}" "${stderr_file}"

  [ "${status}" -eq 1 ]
  [ ! -s "${stderr_file}" ]
  run bash -c 'mapfile -d "" -t fields <"$1"; \
    printf "%s\n" "${fields[@]}"' _ "${stdout_file}"
  [[ "${output}" == *"platform.x86-64"* ]]
  [[ "${output}" == *"platform.glibc"* ]]
}

@test "[PMC-U2-R04] private preflight emits bounded NUL records without effects" {
  local protocol="${BATS_TEST_TMPDIR}/protocol"
  local stderr_file="${BATS_TEST_TMPDIR}/stderr"

  run bash -c 'HOME="$1" XDG_STATE_HOME="$1/state" PATH="$2:$PATH" \
    "$3" internal-preflight 1 status >"$4" 2>"$5"' \
    _ "${TEST_HOME}" "${MOCK_BIN}" "${MANAGER}" "${protocol}" "${stderr_file}"

  [ "${status}" -eq 0 ]
  [ ! -s "${stderr_file}" ]
  run bash -c 'mapfile -d "" -t fields <"$1"; \
    [[ "${#fields[@]}" -eq 3 && "${fields[0]}" == DDM-PREFLIGHT && \
      "${fields[1]}" == 1 && "${fields[2]}" == 0 ]]' _ "${protocol}"
  [ "${status}" -eq 0 ]
  [ "$(stat -c %s "${protocol}")" -le 32768 ]
  [ ! -e "${TEST_HOME}/.local" ]
  [ ! -e "${CURL_LOG}" ]

  local sparse_bin="${BATS_TEST_TMPDIR}/protocol-bin"
  mkdir -p "${sparse_bin}"
  ln -s "$(command -v bash)" "${sparse_bin}/bash"
  run bash -c 'HOME="$1" PATH="$2" "$3" internal-preflight 1 update >"$4"' \
    _ "${TEST_HOME}" "${sparse_bin}" "${MANAGER}" "${protocol}"
  [ "${status}" -eq 1 ]
  run bash -c '
    mapfile -d "" -t fields <"$1"
    count=${fields[2]}
    [[ "$count" =~ ^[0-9]+$ && "$count" -le 64 ]]
    [[ "${#fields[@]}" -eq $((3 + count * 6)) ]]
    for ((i = 3; i < ${#fields[@]}; i += 6)); do
      [[ "${fields[i]}" == blocker || "${fields[i]}" == warning ]]
      [[ "${fields[i + 1]}" =~ ^(environment|path|platform|command|interaction|optional)$ ]]
      [[ "${fields[i + 2]}" =~ ^[a-z0-9.-]{1,64}$ ]]
      for ((j = i + 3; j < i + 6; j++)); do
        [[ ${#fields[j]} -le 512 ]]
      done
    done
  ' _ "${protocol}"
  [ "${status}" -eq 0 ]
  [ "$(stat -c %s "${protocol}")" -le 32768 ]
}

@test "[PMC-U2-R04] aggregate protocol overflow fails closed to one blocker" {
  local protocol="${BATS_TEST_TMPDIR}/overflow-protocol"
  local stderr_file="${BATS_TEST_TMPDIR}/overflow-stderr"

  run bash -c '
    source "$1"
    fill=$(printf "x%.0s" {1..512})
    preflight_reset
    for ((i = 0; i < 64; i++)); do
      preflight_add blocker command "command.overflow-$i" \
        "$fill" "$fill" "$fill"
    done
    preflight_emit_protocol >"$2" 2>"$3"
    if preflight_has_blockers; then
      exit 1
    fi
  ' _ "${MANAGER}" "${protocol}" "${stderr_file}"

  [ "${status}" -eq 1 ]
  [ ! -s "${stderr_file}" ]
  [ "$(stat -c %s "${protocol}")" -le 32768 ]
  run bash -c '
    mapfile -d "" -t fields <"$1"
    [[ "${#fields[@]}" -eq 9 ]]
    [[ "${fields[0]}" == DDM-PREFLIGHT && "${fields[1]}" == 1 ]]
    [[ "${fields[2]}" == 1 && "${fields[3]}" == blocker ]]
    [[ "${fields[6]}" == "diagnostic output exceeded safe limit" ]]
    [[ "${fields[7]}" != *xxxxx* && "${fields[8]}" != *xxxxx* ]]
  ' _ "${protocol}"
  [ "${status}" -eq 0 ]
}

@test "[PMC-U2-R05] curl starts disabled and clears credential configuration" {
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"
  printf '%s\n' '--insecure' >"${TEST_HOME}/.curlrc"

  run env HOME="${TEST_HOME}" XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" CURL_HOME="${TEST_HOME}" \
    NETRC="${TEST_HOME}/credentials" SSL_CERT_FILE="${TEST_HOME}/bad-ca" \
    ALL_PROXY="http://credentials.invalid" "${MANAGER}" check

  [ "${status}" -eq 0 ]
  grep -Eq '^--disable( |$)' "${CURL_LOG}"
  ! grep -Eq -- '--insecure|credentials.invalid|bad-ca' "${CURL_LOG}"
  grep -Fq -- '--max-time 60' "${CURL_LOG}"
  grep -Fq -- '--max-filesize 1048576' "${CURL_LOG}"

  rm -f "${CURL_LOG}"
  run env HOME="${TEST_HOME}" XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" PATH="${MOCK_BIN}:${PATH}" \
    HTTPS_PROXY="https://one.invalid" https_proxy="https://two.invalid" \
    "${MANAGER}" check
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"conflicting proxy settings"* ]]
  [[ "${output}" != *"one.invalid"* && "${output}" != *"two.invalid"* ]]
  [ ! -e "${CURL_LOG}" ]

  cat >"${MOCK_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--disable" && "${2:-}" == "--version" ]]; then
  printf 'curl 8.0 test\nProtocols: http https\nFeatures: SSL\n'
  exit 0
fi
printf 'request\n' >>"${CURL_LOG}"
while (($# > 0)); do
  case "$1" in
    --dump-header) header="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf 'HTTP/1.1 302 Found\r\nLocation: http://windsurf-stable.codeium.com/downgrade\r\n\r\n' >"${header}"
: >"${output}"
EOF
  chmod 0755 "${MOCK_BIN}/curl"
  run env -u HTTPS_PROXY -u https_proxy HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" check
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"could not fetch the official stable manifest"* ]]
  [ "$(wc -l <"${CURL_LOG}")" -eq 1 ]
}

@test "[PMC-U2-R06] diagnostics are deterministic escaped plain stderr" {
  local stdout_file="${BATS_TEST_TMPDIR}/stdout"
  local stderr_file="${BATS_TEST_TMPDIR}/stderr"
  local hostile_home

  hostile_home="${BATS_TEST_TMPDIR}/bad"$'\n'"home"
  run bash -c 'HOME="$1" "$2" status >"$3" 2>"$4"' \
    _ "${hostile_home}" "${MANAGER}" "${stdout_file}" "${stderr_file}"

  [ "${status}" -eq 1 ]
  [ ! -s "${stdout_file}" ]
  grep -Fq 'status: error:' "${stderr_file}"
  grep -Fq '\n' "${stderr_file}"
  ! grep -q $'\033' "${stderr_file}"
  [ "$(wc -l <"${stderr_file}")" -le 8 ]
}

@test "check accepts the exact official stable artifact shape" {
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  run manager_env check

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Latest:  3.4.27 (0d4bf12ed4a7)"* ]]
  [[ "${output}" == *"Status:  ready to install"* ]]
  grep -q -- '--proto =https' "${CURL_LOG}"
  grep -q -- '--proto-redir =https' "${CURL_LOG}"
  grep -q -- '--max-redirs 5' "${CURL_LOG}"
}

@test "check does not require working unprivileged user namespaces" {
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  export MOCK_UNSHARE_FAIL=1
  run manager_env check

  [ "${status}" -eq 0 ]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}

@test "check rejects an artifact outside the official host" {
  write_manifest_curl "https://example.invalid/Devin-linux-x64-3.4.27.deb"

  run manager_env check

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unexpected artifact URL"* ]]
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "check rejects an oversized manifest" {
  cat >"${MOCK_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
head -c 1048577 /dev/zero | tr '\0' x
EOF
  chmod 0755 "${MOCK_BIN}/curl"

  run manager_env check

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"exceeds 1048576 bytes"* ]]
}

@test "check accepts future stable version and build identifier formats" {
  local future_fixture="${BATS_TEST_TMPDIR}/future.deb"
  local build="release_2027-10-abcdef"

  "${FIXTURE_BUILDER}" "${future_fixture}" safe "${build}" "2027.10.0+build.5"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${build}/Devin-linux-x64-2027.10.0+build.5.deb" \
    "${future_fixture}" "2027.10.0+build.5" "${build}" 1810000000000

  run manager_env check

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Latest:  2027.10.0+build.5 (release_2027)"* ]]
  [[ "${output}" == *"Status:  ready to install"* ]]
}

@test "update refuses an official manifest older than the active release" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_release="${install_root}/releases/4.0.0-newerbuild"

  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"
  mkdir -p "${current_release}"
  printf '%s\n' 'io.github.newbpydev.devin-desktop-manager schema=1' \
    >"${install_root}/.devin-desktop-manager-owned"
  cat >"${current_release}/release.json" <<'JSON'
{
  "schemaVersion": 1,
  "managerId": "io.github.newbpydev.devin-desktop-manager",
  "windsurfVersion": "4.0.0",
  "productVersion": "2.0.0",
  "build": "newerbuild",
  "artifactUrl": "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/newerbuild/Devin-linux-x64-4.0.0.deb",
  "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "releaseTimestamp": 1810000000000
}
JSON
  ln -s "releases/4.0.0-newerbuild" "${install_root}/current"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"older than the active release"* ]]
  [ "$(readlink "${install_root}/current")" = "releases/4.0.0-newerbuild" ]
}

@test "release directory names distinguish rebuilds with the same build prefix" {
  run env HOME="${TEST_HOME}" bash -c '
    source "$1"
    first="$(release_identifier "2027.10.0" "release_2027-build-a" \
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")"
    second="$(release_identifier "2027.10.0" "release_2027-build-b" \
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")"
    [[ "$first" != "$second" ]]
  ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "release identifiers always satisfy their own path contract" {
  run env HOME="${TEST_HOME}" bash -c '
    source "$1"
    long_version="$(printf "v%.0s" {1..128})"
    release_id="$(release_identifier "$long_version" \
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" \
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")"
    is_safe_release_identifier "$release_id"
  ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "[PMC-U2-C01] update refuses an unowned pre-existing installation root" {
  local foreign="${TEST_HOME}/.local/opt/devin-desktop/releases/foreign/keep.txt"

  mkdir -p "$(dirname "${foreign}")"
  printf 'user data\n' >"${foreign}"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not be safely verified"* ]] || {
    printf 'unexpected manager output: %s\n' "${output}" >&3
    return 1
  }
  [ "$(cat "${foreign}")" = "user data" ]
}

@test "update treats an unreadable installation root as non-empty" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local foreign="${install_root}/keep.txt"

  mkdir -p "${install_root}"
  printf 'user data\n' >"${foreign}"
  chmod 0300 "${install_root}"

  run install_fixture
  chmod 0700 "${install_root}"

  [ "${status}" -ne 0 ]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ "$(cat "${foreign}")" = "user data" ]
}

@test "update recovers an interrupted ownership sentinel write" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local temporary="${install_root}/.devin-desktop-manager-owned.new.12345"

  mkdir -p "${install_root}"
  printf 'io.github.newbpydev.devin-desktop-manager schema=1\n' >"${temporary}"

  run install_fixture

  [ "${status}" -eq 0 ]
  [ -f "${install_root}/.devin-desktop-manager-owned" ]
  [ ! -e "${temporary}" ]
}

@test "ownership recovery rejects an unproven temporary-only root" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local temporary="${install_root}/.devin-desktop-manager-owned.new.12345"

  mkdir -p "${install_root}"
  printf 'user data\n' >"${temporary}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [ "$(cat "${temporary}")" = "user data" ]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
}

@test "ownership recovery preserves manager-looking files in a foreign root" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local temporary="${install_root}/.devin-desktop-manager-owned.new.12345"
  local foreign="${install_root}/keep.txt"

  mkdir -p "${install_root}"
  printf 'not manager state\n' >"${temporary}"
  printf 'user data\n' >"${foreign}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [ "$(cat "${temporary}")" = "not manager state" ]
  [ "$(cat "${foreign}")" = "user data" ]
}

@test "update safely migrates the public 0.1.0 installation layout" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  downgrade_to_public_0_1_layout
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000

  run manager_env update

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ -f "${install_root}/.devin-desktop-manager-owned" ]
  [ -f "${TEST_HOME}/.cache/devin-desktop-manager/.devin-desktop-manager-owned" ]
  [ -f "${TEST_HOME}/.local/state/devin-desktop-manager/.devin-desktop-manager-owned" ]
  run jq -e \
    --arg manager "io.github.newbpydev.devin-desktop-manager" \
    '.schemaVersion == 1 and .managerId == $manager' \
    "${install_root}"/releases/*/release.json
  [ "${status}" -eq 0 ]
  case "$(readlink "${install_root}/current")" in
    releases/3.4.28-*) ;;
    *) return 1 ;;
  esac
}

@test "migration waits for the public 0.1.0 lock without changing the legacy layout" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local legacy_lock="${install_root}/.manager.lock"
  local ready="${BATS_TEST_TMPDIR}/legacy-lock.ready"
  local release_metadata metadata_before

  install_fixture
  downgrade_to_public_0_1_layout
  release_metadata="$(find "${install_root}/releases" -name release.json \
    -type f -print -quit)"
  metadata_before="$(sha256sum "${release_metadata}" | awk '{print $1}')"
  printf 'legacy lock content\n' >"${legacy_lock}"

  start_lock_holder "${legacy_lock}" "${ready}"

  run install_fixture
  stop_lock_holder

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"another Devin Desktop manager operation is running"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ "$(sha256sum "${release_metadata}" | awk '{print $1}')" = \
    "${metadata_before}" ]
  [ "$(cat "${legacy_lock}")" = "legacy lock content" ]
}

@test "migration rejects an unsafe public 0.1.0 lock path" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local legacy_lock="${install_root}/.manager.lock"
  local external="${BATS_TEST_TMPDIR}/missing-legacy-lock-target"

  install_fixture
  downgrade_to_public_0_1_layout
  rm -f -- "${legacy_lock}"
  ln -s "${external}" "${legacy_lock}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"legacy manager lock must be a non-symbolic regular file"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ -L "${legacy_lock}" ]
  [ ! -e "${external}" ]
}

@test "fresh mutations create and hold the public manager lock before ownership" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      mkdir -p "${STATE_HOME}"
      acquire_legacy_lock_if_needed
      [[ "${LEGACY_LOCK_HELD:-false}" == "true" ]]
      [[ -f "${INSTALL_ROOT}/.manager.lock" &&
        "${INSTALL_ROOT}/.manager.lock" -ef /proc/self/fd/7 ]]
      if bash -c '\''exec 7>&-; flock -n "$1" true'\'' \
        _ "${INSTALL_ROOT}/.manager.lock"; then
        exit 1
      fi
      migrate_legacy_layout_if_needed
      owned_root_is_valid "${INSTALL_ROOT}"
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "migration recovers a public pre-lock bootstrap root" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  mkdir -p "${install_root}/releases"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ -f "${install_root}/.manager.lock" ]
  [ -f "${install_root}/.devin-desktop-manager-owned" ]
  [ -L "${install_root}/current" ]
}

@test "owned installations keep taking the public manager lock" {
  local legacy_lock="${TEST_HOME}/.local/opt/devin-desktop/.manager.lock"
  local ready="${BATS_TEST_TMPDIR}/owned-legacy-lock.ready"

  install_fixture
  start_lock_holder "${legacy_lock}" "${ready}"

  run install_fixture
  stop_lock_holder

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"another Devin Desktop manager operation is running"* ]]
}

@test "migration rejects a near-miss legacy layout without claiming it" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"

  install_fixture
  downgrade_to_public_0_1_layout
  printf '# user modification\n' >>"${desktop}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not be safely verified"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  run jq -e 'has("managerId") or has("schemaVersion")' \
    "${install_root}/releases"/*/release.json
  [ "${status}" -ne 0 ]
  grep -Fq '# user modification' "${desktop}"
}

@test "migration is restartable after manager temporary files are left behind" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cache_root="${TEST_HOME}/.cache/devin-desktop-manager"
  local state_root="${TEST_HOME}/.local/state/devin-desktop-manager"
  local release

  install_fixture
  downgrade_to_public_0_1_layout
  release="$(find "${install_root}/releases" -mindepth 1 -maxdepth 1 \
    -type d -print -quit)"
  for root in "${install_root}" "${cache_root}" "${state_root}"; do
    printf 'io.github.newbpydev.devin-desktop-manager schema=1\n' \
      >"${root}/.devin-desktop-manager-owned.new.12345"
  done
  printf 'partial\n' >"${release}/release.json.new.12345"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  run find "${install_root}" "${cache_root}" "${state_root}" \
    -name '*.new.12345' -print
  [ -z "${output}" ]
}

@test "migration removes an interrupted legacy state write temporary" {
  local state_root="${TEST_HOME}/.local/state/devin-desktop-manager"
  local temporary="${state_root}/state.json.new.12345"

  install_fixture
  downgrade_to_public_0_1_layout
  printf 'partial state\n' >"${temporary}"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ ! -e "${temporary}" ]
  [ -f "${state_root}/state.json" ]
}

@test "migration removes interrupted legacy staging and link temporaries" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target release_name staging integration

  install_fixture
  downgrade_to_public_0_1_layout
  current_target="$(readlink "${install_root}/current")"
  release_name="${current_target#releases/}"
  staging="${install_root}/.staging-${release_name}-12345"
  integration="${install_root}/.integration-12345"
  mkdir -p "${staging}/root"
  mkdir -p "${integration}"
  printf 'partial extraction\n' >"${staging}/root/partial"
  printf 'partial desktop integration\n' >"${integration}/partial"
  ln -s "${current_target}" "${install_root}/.current.new.12345"
  ln -s "${current_target}" "${install_root}/.previous.new.12345"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ ! -e "${staging}" ]
  [ ! -e "${integration}" ]
  [ ! -L "${install_root}/.current.new.12345" ]
  [ ! -L "${install_root}/.previous.new.12345" ]
}

@test "migration prunes a fully valid legacy release left before activation" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target current_release extra_version extra_build extra_sha
  local extra_id extra_release temporary

  install_fixture
  downgrade_to_public_0_1_layout
  current_target="$(readlink "${install_root}/current")"
  current_release="${install_root}/${current_target}"
  extra_version="3.4.26"
  extra_build="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  extra_sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  extra_id="${extra_version}-${extra_build:0:12}-${extra_sha:0:12}"
  extra_release="${install_root}/releases/${extra_id}"
  cp -a -- "${current_release}" "${extra_release}"
  temporary="${extra_release}/release.json.test"
  jq \
    --arg version "${extra_version}" \
    --arg build "${extra_build}" \
    --arg sha "${extra_sha}" \
    --arg url "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${extra_build}/Devin-linux-x64-${extra_version}.deb" '
      .windsurfVersion = $version |
      .productVersion = $version |
      .build = $build |
      .artifactUrl = $url |
      .sha256 = $sha
    ' "${extra_release}/release.json" >"${temporary}"
  mv -Tf -- "${temporary}" "${extra_release}/release.json"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [[ "${output}" == *"removing superseded release ${extra_id}"* ]]
  [ ! -e "${extra_release}" ]
}

@test "migration refuses to prune a running legacy release" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target current_release extra_version extra_build extra_sha
  local extra_id extra_release temporary running_pid

  install_fixture
  downgrade_to_public_0_1_layout
  current_target="$(readlink "${install_root}/current")"
  current_release="${install_root}/${current_target}"
  extra_version="3.4.26"
  extra_build="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  extra_sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  extra_id="${extra_version}-${extra_build:0:12}-${extra_sha:0:12}"
  extra_release="${install_root}/releases/${extra_id}"
  cp -a -- "${current_release}" "${extra_release}"
  temporary="${extra_release}/release.json.test"
  jq \
    --arg version "${extra_version}" \
    --arg build "${extra_build}" \
    --arg sha "${extra_sha}" \
    --arg url "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${extra_build}/Devin-linux-x64-${extra_version}.deb" '
      .windsurfVersion = $version |
      .productVersion = $version |
      .build = $build |
      .artifactUrl = $url |
      .sha256 = $sha
    ' "${extra_release}/release.json" >"${temporary}"
  mv -Tf -- "${temporary}" "${extra_release}/release.json"
  cp -- /bin/sleep "${extra_release}/app/devin-desktop"
  chmod 0755 "${extra_release}/app/devin-desktop"

  "${extra_release}/app/devin-desktop" 30 &
  running_pid=$!
  sleep 0.1
  run install_fixture
  kill "${running_pid}" 2>/dev/null || true
  wait "${running_pid}" 2>/dev/null || true

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Devin Desktop is running"* ]]
  [ -d "${extra_release}" ]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
}

@test "migration resumes a validated public download left before first activation" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local release_before

  install_fixture
  downgrade_to_public_0_1_layout
  release_before="$(find "${install_root}/releases" -mindepth 1 -maxdepth 1 \
    -type d -print -quit)"
  rm -f -- \
    "${install_root}/current" \
    "${TEST_HOME}/.local/bin/devin-desktop" \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" \
    "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" \
    "${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml" \
    "${DEFAULTS_FILE}"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ -L "${install_root}/current" ]
  [ -d "${release_before}" ]
  run find "${install_root}/releases" -mindepth 1 -maxdepth 1 -type d -print
  [ "$(printf '%s\n' "${output}" | sed '/^$/d' | wc -l)" -eq 1 ]
}

@test "migration resumes an empty public root left before the first download" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  downgrade_to_public_0_1_layout
  rm -f -- \
    "${install_root}/current" \
    "${install_root}/previous" \
    "${TEST_HOME}/.local/bin/devin-desktop" \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" \
    "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" \
    "${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml" \
    "${DEFAULTS_FILE}"
  rm -rf -- "${install_root}/releases"/*

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ -L "${install_root}/current" ]
  run find "${install_root}/releases" -mindepth 1 -maxdepth 1 -type d -print
  [ "$(printf '%s\n' "${output}" | sed '/^$/d' | wc -l)" -eq 1 ]
}

@test "migration resumes a public release linked before state publication" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local state_temporary="${TEST_HOME}/.local/state/devin-desktop-manager/state.json.new.12345"

  install_fixture
  downgrade_to_public_0_1_layout
  rm -f -- \
    "${TEST_HOME}/.local/bin/devin-desktop" \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" \
    "${DEFAULTS_FILE}"
  printf 'partial state\n' >"${state_temporary}"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"migrating verified public 0.1.0 installation"* ]]
  [ -L "${install_root}/current" ]
  [ -f "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" ]
  [ ! -e "${state_temporary}" ]
}

@test "migration rejects a post-link layout after manager defaults were claimed" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  downgrade_to_public_0_1_layout
  rm -f -- \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" \
    "${TEST_HOME}/.local/bin/devin-desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" \
    "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" \
    "${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"post-link installation could not be safely verified"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ "$(query_default x-scheme-handler/devin)" = \
    "devin-desktop-manager-url-handler.desktop" ]
}

@test "uninstall removes verified post-link assets without published state" {
  local icon="${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png"
  local mime="${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml"

  install_fixture
  downgrade_to_public_0_1_layout
  rm -f -- \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" \
    "${TEST_HOME}/.local/bin/devin-desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" \
    "${DEFAULTS_FILE}"
  [ -f "${icon}" ]
  [ -f "${mime}" ]

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [ ! -e "${icon}" ]
  [ ! -e "${mime}" ]
}

@test "migration rejects a symlinked manager temporary without changing its target" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local external="${BATS_TEST_TMPDIR}/external-temporary"
  local temporary="${install_root}/.devin-desktop-manager-owned.new.12345"

  install_fixture
  downgrade_to_public_0_1_layout
  printf 'user data\n' >"${external}"
  ln -s "${external}" "${temporary}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not be safely verified"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ -L "${temporary}" ]
  grep -Fqx 'user data' "${external}"
}

@test "migration accepts a valid legacy installation after cache eviction" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cache_root="${TEST_HOME}/.cache/devin-desktop-manager"

  install_fixture
  downgrade_to_public_0_1_layout
  rm -rf -- "${cache_root}"

  run install_fixture

  [ "${status}" -eq 0 ]
  [ -f "${install_root}/.devin-desktop-manager-owned" ]
  [ -f "${cache_root}/.devin-desktop-manager-owned" ]
}

@test "migration rejects an unreadable legacy cache root without claiming it" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cache_root="${TEST_HOME}/.cache/devin-desktop-manager"
  local foreign="${cache_root}/keep.txt"

  install_fixture
  downgrade_to_public_0_1_layout
  printf 'user data\n' >"${foreign}"
  chmod 0300 "${cache_root}"

  run install_fixture
  chmod 0700 "${cache_root}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not be safely verified"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ "$(cat "${foreign}")" = "user data" ]
}

@test "migration rejects an invalid legacy previous link without claiming it" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  downgrade_to_public_0_1_layout
  ln -s "releases/missing-release" "${install_root}/previous"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not be safely verified"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
}

@test "migration rejects a symlinked legacy release without changing its target" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local release release_name external metadata_before

  install_fixture
  downgrade_to_public_0_1_layout
  release="$(find "${install_root}/releases" -mindepth 1 -maxdepth 1 \
    -type d -print -quit)"
  release_name="$(basename "${release}")"
  external="${BATS_TEST_TMPDIR}/external-release"
  mv -- "${release}" "${external}"
  ln -s "${external}" "${install_root}/releases/${release_name}"
  metadata_before="$(sha256sum "${external}/release.json" | awk '{print $1}')"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not be safely verified"* ]]
  [ ! -e "${install_root}/.devin-desktop-manager-owned" ]
  [ "$(sha256sum "${external}/release.json" | awk '{print $1}')" = \
    "${metadata_before}" ]
}

@test "update refuses a symlinked installation root" {
  local target="${BATS_TEST_TMPDIR}/foreign-root"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  mkdir -p "${target}" "$(dirname "${install_root}")"
  printf 'user data\n' >"${target}/keep.txt"
  ln -s "${target}" "${install_root}"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"must not be a symbolic link"* ]] || {
    printf 'unexpected manager output: %s\n' "${output}" >&3
    return 1
  }
  [ "$(cat "${target}/keep.txt")" = "user data" ]
}

@test "owned-root cleanup refuses a symlinked releases directory" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local releases="${install_root}/releases"
  local parked="${BATS_TEST_TMPDIR}/parked-releases"
  local external="${BATS_TEST_TMPDIR}/external-releases"
  local external_temp="${external}/foreign/release.json.new.12345"

  install_fixture
  mv -T -- "${releases}" "${parked}"
  mkdir -p "$(dirname "${external_temp}")"
  printf 'external data\n' >"${external_temp}"
  ln -s "${external}" "${releases}"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"could not safely recover interrupted installation temporaries"* ]]
  [ "$(cat "${external_temp}")" = "external data" ]
  [ -d "${parked}" ]
}

@test "update refuses an unowned release directory without pruning it" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_before

  install_fixture
  current_before="$(readlink "${install_root}/current")"
  mkdir -p "${install_root}/releases/foreign"
  printf 'user data\n' >"${install_root}/releases/foreign/keep.txt"
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unowned release directory"* ]]
  [ "$(cat "${install_root}/releases/foreign/keep.txt")" = "user data" ]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
}

@test "pruning rejects superficially valid metadata without a full release payload" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_release foreign_release second second_build

  install_fixture
  current_release="${install_root}/$(readlink "${install_root}/current")"
  foreign_release="${install_root}/releases/foreign-metadata"
  mkdir -p "${foreign_release}"
  cp -- "${current_release}/release.json" "${foreign_release}/release.json"
  printf 'preserve foreign data\n' >"${foreign_release}/keep.txt"
  second="${BATS_TEST_TMPDIR}/second.deb"
  second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"refusing to activate while an unowned release would be pruned"* ]]
  [ "$(cat "${foreign_release}/keep.txt")" = "preserve foreign data" ]
}

@test "release links cannot traverse above the releases directory" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  mkdir -p "${install_root}/releases"
  ln -s "releases/.." "${install_root}/current"

  run manager_env status

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Current:  not installed"* ]]
}

@test "release validation rejects a failing version probe with plausible output" {
  local release="${BATS_TEST_TMPDIR}/release"

  mkdir -p "${release}/app/bin" "${release}/integration"
  cat >"${release}/app/devin-desktop" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"${release}/app/bin/devin-desktop" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "1.110.1" "future-build" "x64"
exit 9
EOF
  chmod 0755 "${release}/app/devin-desktop" "${release}/app/bin/devin-desktop"
  printf '{}\n' >"${release}/release.json"
  : >"${release}/integration/devin-desktop.png"
  : >"${release}/integration/devin-desktop-workspace.xml"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:${PATH}" bash -c '
    source "$1"
    validate_release "$2" "future-build" "1.110.1"
  ' _ "${MANAGER}" "${release}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"release version probe failed"* ]]
}

@test "release validation rejects a timed out version probe" {
  local release="${BATS_TEST_TMPDIR}/release"

  mkdir -p "${release}/app/bin" "${release}/integration"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${release}/app/devin-desktop"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${release}/app/bin/devin-desktop"
  chmod 0755 "${release}/app/devin-desktop" "${release}/app/bin/devin-desktop"
  printf '{}\n' >"${release}/release.json"
  : >"${release}/integration/devin-desktop.png"
  : >"${release}/integration/devin-desktop-workspace.xml"

  run env MOCK_TIMEOUT_FAIL=1 HOME="${TEST_HOME}" PATH="${MOCK_BIN}:${PATH}" \
    bash -c '
      source "$1"
      validate_release "$2" "future-build" "1.110.1"
    ' _ "${MANAGER}" "${release}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"release version probe timed out"* ]]
}

@test "update accepts a control archive whose control member omits dot slash" {
  local fixture="${BATS_TEST_TMPDIR}/control-no-dot.deb"

  "${FIXTURE_BUILDER}" "${fixture}" control-no-dot
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb" \
    "${fixture}"

  run manager_env update

  [ "${status}" -eq 0 ]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "update installs validated release and unique cross-desktop integration" {
  run install_fixture

  [ "${status}" -eq 0 ]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
  [ -L "${TEST_HOME}/.local/bin/devin-desktop" ]
  [ -f "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" ]
  [ -f "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" ]
  [ -f "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" ]
  [ -f "${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml" ]
  [ ! -e "${TEST_HOME}/.local/share/applications/devin-desktop.desktop" ]
  [ "$(stat -c '%a' "${TEST_HOME}/.local/state/devin-desktop-manager/state.json")" = "600" ]
  [ "$(query_default x-scheme-handler/devin)" = "devin-desktop-manager-url-handler.desktop" ]
}

@test "an up-to-date update still rejects a corrupted active release" {
  local current_target

  install_fixture
  current_target="$(readlink "${TEST_HOME}/.local/opt/devin-desktop/current")"
  chmod 0644 \
    "${TEST_HOME}/.local/opt/devin-desktop/${current_target}/app/bin/devin-desktop"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"release is missing the terminal launcher"* ]]
}

@test "an up-to-date update rejects damaged active release metadata" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target current_release temporary

  install_fixture
  current_target="$(readlink "${install_root}/current")"
  current_release="${install_root}/${current_target}"
  temporary="${current_release}/release.json.test"
  jq '.artifactUrl = "https://example.invalid/foreign.deb"' \
    "${current_release}/release.json" >"${temporary}"
  mv -Tf -- "${temporary}" "${current_release}/release.json"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"retained or reused release is invalid"* ]]
  [ "$(readlink "${install_root}/current")" = "${current_target}" ]
}

@test "an up-to-date update rejects a malformed existing previous link" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  ln -s "../other" "${install_root}/previous"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"previous release link is invalid"* ]]
  [ "$(readlink "${install_root}/previous")" = "../other" ]
}

@test "linked release validation rejects a malformed current link" {
  run env HOME="${TEST_HOME}" bash -c '
    source "$1"
    mkdir -p "${RELEASES_DIR}"
    ln -s "../other" "${CURRENT_LINK}"
    validate_linked_releases
  ' _ "${MANAGER}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"current release link is invalid"* ]]
}

@test "update rejects malformed current and previous links before activation" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  ln -sfn "../broken-current" "${install_root}/current"
  ln -s "../broken-previous" "${install_root}/previous"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"current release link is invalid"* ]]
  [ "$(readlink "${install_root}/current")" = "../broken-current" ]
  [ "$(readlink "${install_root}/previous")" = "../broken-previous" ]
}

@test "update rejects a previous release link without a current release" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target

  install_fixture
  current_target="$(readlink "${install_root}/current")"
  rm -f -- "${install_root}/current"
  ln -s "${current_target}" "${install_root}/previous"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"previous release link exists without a current release"* ]]
  [ "$(readlink "${install_root}/previous")" = "${current_target}" ]
}

@test "check distinguishes up-to-date and update-available installations" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  install_fixture
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  run manager_env check

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Status:  up to date"* ]]

  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000

  run manager_env check

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Status:  update available"* ]]
}

@test "update discards a corrupt cached artifact before downloading" {
  local cache="${TEST_HOME}/.cache/devin-desktop-manager"
  local sha release_id artifact

  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"
  sha="$(sha256sum "${FIXTURE}" | awk '{print $1}')"
  release_id="3.4.27-0d4bf12ed4a7-${sha:0:12}"
  artifact="${cache}/Devin-linux-x64-${release_id}.deb"
  mkdir -p "${cache}"
  printf '%s\n' 'io.github.newbpydev.devin-desktop-manager schema=1' \
    >"${cache}/.devin-desktop-manager-owned"
  printf 'corrupt\n' >"${artifact}"

  run manager_env update

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"discarding a cached artifact with the wrong checksum"* ]]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "update resumes an existing partial download" {
  local cache="${TEST_HOME}/.cache/devin-desktop-manager"
  local sha release_id partial

  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"
  sha="$(sha256sum "${FIXTURE}" | awk '{print $1}')"
  release_id="3.4.27-0d4bf12ed4a7-${sha:0:12}"
  partial="${cache}/Devin-linux-x64-${release_id}.deb.part"
  mkdir -p "${cache}"
  printf '%s\n' 'io.github.newbpydev.devin-desktop-manager schema=1' \
    >"${cache}/.devin-desktop-manager-owned"
  printf 'partial\n' >"${partial}"

  run manager_env update

  [ "${status}" -eq 0 ]
  grep -Fq -- '--continue-at -' "${CURL_LOG}"
}

@test "failed download keeps its partial file for retry" {
  local cache="${TEST_HOME}/.cache/devin-desktop-manager"

  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  export MOCK_ARTIFACT_DOWNLOAD_FAIL=1
  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"partial file was kept for retry"* ]]
  run find "${cache}" -maxdepth 1 -name '*.part' -type f
  [ "${status}" -eq 0 ]
  [ -n "${output}" ]
}

@test "install preserves unrelated defaults and records their originals" {
  seed_defaults

  run install_fixture

  [ "${status}" -eq 0 ]
  [ "$(query_default x-scheme-handler/devin)" = "browser.desktop" ]
  [ "$(query_default x-scheme-handler/windsurf)" = "editor.desktop" ]
  [ "$(query_default application/x-devin-desktop-workspace)" = "workspace.desktop" ]
  run jq -r '.originalDefaults["x-scheme-handler/devin"]' \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json"
  [ "${output}" = "browser.desktop" ]
}

@test "set-defaults is explicit and uninstall restores previous defaults" {
  seed_defaults
  install_fixture

  run manager_env set-defaults
  [ "${status}" -eq 0 ]
  [ "$(query_default x-scheme-handler/devin)" = "devin-desktop-manager-url-handler.desktop" ]

  run manager_env uninstall --yes
  [ "${status}" -eq 0 ]
  [ "$(query_default x-scheme-handler/devin)" = "browser.desktop" ]
  [ "$(query_default x-scheme-handler/windsurf)" = "editor.desktop" ]
  [ "$(query_default application/x-devin-desktop-workspace)" = "workspace.desktop" ]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager" ]
}

@test "uninstall is idempotent when the application is not installed" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cache_root="${TEST_HOME}/.cache/devin-desktop-manager"
  local state_dir="${TEST_HOME}/.local/state/devin-desktop-manager"

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"managed application removed"* ]]
  [ ! -e "${install_root}" ]
  [ ! -e "${cache_root}" ]
  [ ! -e "${state_dir}" ]
  run find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [ ! -e "${install_root}" ]
  [ ! -e "${cache_root}" ]
  [ ! -e "${state_dir}" ]
}

@test "uninstall cleans a failed first-install release before activation" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  rm -f -- \
    "${install_root}/current" \
    "${install_root}/previous" \
    "${TEST_HOME}/.local/bin/devin-desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" \
    "${TEST_HOME}/.local/share/applications/devin-desktop-manager-url-handler.desktop" \
    "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" \
    "${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml"
  rm -rf -- \
    "${TEST_HOME}/.cache/devin-desktop-manager" \
    "${TEST_HOME}/.local/state/devin-desktop-manager" \
    "${TEST_HOME}/.local/share"

  export MOCK_CACHE_REQUIRE_DIRECTORY=1
  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [ ! -e "${install_root}" ]
}

@test "uninstall preserves a default changed by the user after installation" {
  install_fixture
  env XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    "${MOCK_BIN}/xdg-mime" default user-choice.desktop x-scheme-handler/devin

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [ "$(query_default x-scheme-handler/devin)" = "user-choice.desktop" ]
}

@test "uninstall removes its stale handler without changing the user default" {
  install_fixture
  sed -i \
    's|^x-scheme-handler/devin=.*|x-scheme-handler/devin=user-choice.desktop;devin-desktop-manager-url-handler.desktop;backup.desktop;|' \
    "${DEFAULTS_FILE}"

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [ "$(query_default x-scheme-handler/devin)" = "user-choice.desktop" ]
  run grep -F 'devin-desktop-manager-url-handler.desktop' "${DEFAULTS_FILE}"
  [ "${status}" -ne 0 ]
  grep -Fq 'backup.desktop;' "${DEFAULTS_FILE}"
}

@test "[PMC-U2-C01] KDE cache refresh is optional and cannot break installation" {
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  export MOCK_KDE_FAIL=1
  run manager_env update

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"KDE cache refresh failed"* ]]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "KDE Plasma 5 treats a missing default as unset" {
  export XDG_CURRENT_DESKTOP=KDE
  export KDE_SESSION_VERSION=5
  export MOCK_XDG_KDE_UNSET_FAIL=1

  run install_fixture

  [ "${status}" -eq 0 ]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
  run jq -e '.originalDefaults | all(. == "")' \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json"
  [ "${status}" -eq 0 ]
}

@test "integration failure restores release links files and defaults" {
  seed_defaults
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  export MOCK_DESKTOP_CACHE_FAIL=1
  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"restoring the previous release and desktop state"* ]]
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
  [ ! -e "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" ]
  [ ! -e "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" ]
  [ ! -e "${TEST_HOME}/.local/share/mime/packages/devin-desktop-manager-workspace.xml" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager.transaction" ]
  [ "$(query_default x-scheme-handler/devin)" = "browser.desktop" ]
}

@test "a failed default query aborts without changing user defaults" {
  local defaults_before="${BATS_TEST_TMPDIR}/defaults.before"

  seed_defaults
  cp "${DEFAULTS_FILE}" "${defaults_before}"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  export MOCK_XDG_QUERY_FAIL=1
  run manager_env update

  [ "${status}" -ne 0 ]
  cmp "${defaults_before}" "${DEFAULTS_FILE}"
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "restore failure preserves the live path and recovery backup" {
  local destination="${BATS_TEST_TMPDIR}/live-file"
  local backup="${BATS_TEST_TMPDIR}/devin-desktop-manager.restore-test"

  mkdir -p "${backup}"
  printf 'original\n' >"${destination}"
  printf 'snapshot\n' >"${backup}/snapshot"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:${PATH}" \
    MOCK_CP_FAIL_PATTERN="${backup}/snapshot" bash -c '
      source "$1"
      TRANSACTION_BACKUP="$2"
      restore_path "$3" snapshot
    ' _ "${MANAGER}" "${backup}" "${destination}"

  [ "${status}" -ne 0 ]
  [ "$(cat "${destination}")" = "original" ]
  [ -f "${backup}/snapshot" ]

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:${PATH}" \
    MOCK_MV_FAIL_PATH="${destination}" bash -c '
      source "$1"
      TRANSACTION_BACKUP="$2"
      restore_path "$3" snapshot
    ' _ "${MANAGER}" "${backup}" "${destination}"

  [ "${status}" -ne 0 ]
  [ "$(cat "${destination}")" = "original" ]
  [ -z "$(find "$(dirname "${destination}")" -maxdepth 1 \
    -name '.devin-desktop-manager-restore.*' -print -quit)" ]
}

@test "restore preserves a pre-existing PID-shaped path" {
  local destination="${BATS_TEST_TMPDIR}/live-file"
  local backup="${BATS_TEST_TMPDIR}/devin-desktop-manager.restore-test"

  mkdir -p "${backup}"
  printf 'original\n' >"${destination}"
  printf 'snapshot\n' >"${backup}/snapshot"

  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:${PATH}" bash -c '
    source "$1"
    TRANSACTION_BACKUP="$2"
    collision="$3.restore.$$"
    mkdir -p "${collision}"
    printf "user data\n" >"${collision}/keep.txt"
    restore_path "$3" snapshot
    [[ "$(cat "$3")" == "snapshot" &&
      "$(cat "${collision}/keep.txt")" == "user data" ]]
  ' _ "${MANAGER}" "${backup}" "${destination}"

  [ "${status}" -eq 0 ]
}

@test "restore cleanup removes only its tracked owned temporary" {
  run env HOME="${TEST_HOME}" PATH="${MOCK_BIN}:${PATH}" bash -c '
    source "$1"
    mkdir -p "${STATE_HOME}"
    proof_temp="${UNINSTALL_CLEANUP_PROOF}.new.$$"
    CLEANUP_PROOF_TEMP="${proof_temp}"
    printf "proof\n" >"${CLEANUP_PROOF_TEMP}"
    cleanup
    [[ ! -e "${proof_temp}" && -z "${CLEANUP_PROOF_TEMP}" ]]

    owned="${TEST_HOME}/.devin-desktop-manager-restore.owned"
    mkdir -p "${owned}"
    printf "temporary\n" >"${owned}/payload"
    RESTORE_TEMP_ROOT="${owned}"
    cleanup
    [[ ! -e "${owned}" && -z "${RESTORE_TEMP_ROOT}" ]]

    target="${TEST_HOME}/user-data"
    unsafe="${TEST_HOME}/.devin-desktop-manager-restore.unsafe"
    mkdir -p "${target}"
    printf "keep\n" >"${target}/keep.txt"
    ln -s -- "${target}" "${unsafe}"
    RESTORE_TEMP_ROOT="${unsafe}"
    cleanup
    [[ -L "${unsafe}" && "$(cat "${target}/keep.txt")" == "keep" &&
      -z "${RESTORE_TEMP_ROOT}" ]]

    unexpected="${TEST_HOME}/unrelated-restore-path"
    mkdir -p "${unexpected}"
    RESTORE_TEMP_ROOT="${unexpected}"
    cleanup
    [[ -d "${unexpected}" && -z "${RESTORE_TEMP_ROOT}" ]]
  ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "transaction recovery rejects a slash-containing staged install path" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local staged_root="${install_root}.uninstall-123"
  local tampered="${staged_root}/nested"
  local journal="${BATS_TEST_TMPDIR}/tampered-transaction"

  mkdir -p "${tampered}" "${journal}"
  printf 'preserve\n' >"${tampered}/keep.txt"
  printf '%s\n' "${tampered}" >"${journal}/staged-install-root"

  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      TRANSACTION_BACKUP="$2"
      restore_staged_install_root
    ' _ "${MANAGER}" "${journal}"

  [ "${status}" -ne 0 ]
  [ "$(cat "${tampered}/keep.txt")" = "preserve" ]
  [ ! -e "${install_root}" ]
}

@test "cleanup record writers remove temporary files when publication fails" {
  local writer failure

  for writer in uninstall prune; do
    for failure in jq chmod mv; do
      run env HOME="${TEST_HOME}" \
        XDG_STATE_HOME="${TEST_HOME}/.local/state" \
        PATH="${MOCK_BIN}:${PATH}" \
        RECORD_WRITER="${writer}" RECORD_FAILURE="${failure}" bash -c '
          source "$1"
          mkdir -p "${STATE_HOME}"
          staged_root="${INSTALL_ROOT}.uninstall-123"
          mkdir -p "${staged_root}"
          printf "%s" "$(ownership_sentinel_content)" \
            >"${staged_root}/${OWNERSHIP_SENTINEL_NAME}"
          case "${RECORD_FAILURE}" in
            jq) jq() { return 1; } ;;
            chmod) chmod() { return 1; } ;;
            mv) mv() { return 1; } ;;
          esac
          case "${RECORD_WRITER}" in
            uninstall)
              record="${UNINSTALL_CLEANUP_RECORD}"
              if write_uninstall_cleanup_record "${staged_root}"; then
                exit 1
              fi
              ;;
            prune)
              record="${RELEASE_PRUNE_CLEANUP_RECORD}"
              if write_release_prune_cleanup_record \
                "stale-release" "1" "2" \
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"; then
                exit 1
              fi
              ;;
          esac
          temporary="${record}.new.$$"
          [[ ! -e "${record}" && ! -L "${record}" &&
            ! -e "${temporary}" && ! -L "${temporary}" ]]
        ' _ "${MANAGER}"

      [ "${status}" -eq 0 ] || {
        printf '%s/%s failure left a temporary: %s\n' \
          "${writer}" "${failure}" "${output}" >&3
        return 1
      }
    done
  done
}

@test "cleanup proof publication recovers only a matching stale temporary" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      mkdir -p "${STATE_HOME}"
      source_record="${STATE_HOME}/cleanup-source"
      proof="${STATE_HOME}/cleanup-proof"
      temporary="${proof}.new.$$"
      printf "manager proof\n" >"${source_record}"
      cp -- "${source_record}" "${temporary}"
      publish_cleanup_proof "${source_record}" "${proof}"
      cmp -s -- "${source_record}" "${proof}"
      [[ ! -e "${temporary}" && ! -L "${temporary}" ]]

      rm -f -- "${proof}"
      printf "user data\n" >"${temporary}"
      if publish_cleanup_proof "${source_record}" "${proof}"; then
        exit 1
      fi
      [[ "$(cat "${temporary}")" == "user data" && ! -e "${proof}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "cleanup record writers recover validated stale temporaries" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      mkdir -p "${STATE_HOME}"
      staged_root="${INSTALL_ROOT}.uninstall-123"
      mkdir -p "${staged_root}"
      printf "%s" "$(ownership_sentinel_content)" \
        >"${staged_root}/${OWNERSHIP_SENTINEL_NAME}"
      read -r device inode < <(stat -c "%d %i" -- "${staged_root}")
      uninstall_temp="${UNINSTALL_CLEANUP_RECORD}.new.$$"
      jq -n \
        --arg manager_id "${MANAGER_ID}" \
        --argjson schema_version "${OWNERSHIP_SCHEMA_VERSION}" \
        --arg staged_root "${staged_root}" \
        --arg device "${device}" \
        --arg inode "${inode}" "{
          schemaVersion: \$schema_version,
          managerId: \$manager_id,
          stagedInstallRoot: \$staged_root,
          device: \$device,
          inode: \$inode
        }" >"${uninstall_temp}"
      write_uninstall_cleanup_record "${staged_root}"
      [[ -f "${UNINSTALL_CLEANUP_RECORD}" && ! -e "${uninstall_temp}" ]]
      rm -f -- "${UNINSTALL_CLEANUP_RECORD}"

      release_name="stale-release"
      prune_temp="${RELEASE_PRUNE_CLEANUP_RECORD}.new.$$"
      quarantine_name="$(
        release_prune_quarantine_name "${release_name}" "${device}" "${inode}"
      )"
      metadata_sha256="$(
        printf "metadata" | sha256sum | awk "{print \$1}"
      )"
      jq -n \
        --arg manager_id "${MANAGER_ID}" \
        --argjson schema_version "${OWNERSHIP_SCHEMA_VERSION}" \
        --arg release_name "${release_name}" \
        --arg quarantine_name "${quarantine_name}" \
        --arg device "${device}" \
        --arg inode "${inode}" \
        --arg metadata_sha256 "${metadata_sha256}" "{
          schemaVersion: \$schema_version,
          managerId: \$manager_id,
          releaseName: \$release_name,
          quarantineName: \$quarantine_name,
          device: \$device,
          inode: \$inode,
          metadataSha256: \$metadata_sha256
        }" >"${prune_temp}"
      write_release_prune_cleanup_record \
        "${release_name}" "${device}" "${inode}" "${metadata_sha256}"
      [[ -f "${RELEASE_PRUNE_CLEANUP_RECORD}" && ! -e "${prune_temp}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "cleanup record writers reject unproven stale temporaries" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      mkdir -p "${STATE_HOME}"
      staged_root="${INSTALL_ROOT}.uninstall-123"
      mkdir -p "${staged_root}"
      printf "%s" "$(ownership_sentinel_content)" \
        >"${staged_root}/${OWNERSHIP_SENTINEL_NAME}"
      read -r device inode < <(stat -c "%d %i" -- "${staged_root}")

      uninstall_temp="${UNINSTALL_CLEANUP_RECORD}.new.$$"
      jq -n \
        --arg manager_id "${MANAGER_ID}" \
        --argjson schema_version "${OWNERSHIP_SCHEMA_VERSION}" \
        --arg staged_root "${INSTALL_ROOT}.uninstall-999" \
        --arg device "${device}" \
        --arg inode "${inode}" "{
          schemaVersion: \$schema_version,
          managerId: \$manager_id,
          stagedInstallRoot: \$staged_root,
          device: \$device,
          inode: \$inode
        }" >"${uninstall_temp}"
      ! write_uninstall_cleanup_record "${staged_root}"
      [[ -s "${uninstall_temp}" &&
        ! -e "${UNINSTALL_CLEANUP_RECORD}" ]]
      rm -f -- "${uninstall_temp}"

      prune_temp="${RELEASE_PRUNE_CLEANUP_RECORD}.new.$$"
      metadata_sha256="$(
        printf "metadata" | sha256sum | awk "{print \$1}"
      )"
      jq -n \
        --arg manager_id "${MANAGER_ID}" \
        --argjson schema_version "${OWNERSHIP_SCHEMA_VERSION}" \
        --arg release_name "stale-release" \
        --arg quarantine_name ".release-prune-other-1-2" \
        --arg device "${device}" \
        --arg inode "${inode}" \
        --arg metadata_sha256 "${metadata_sha256}" "{
          schemaVersion: \$schema_version,
          managerId: \$manager_id,
          releaseName: \$release_name,
          quarantineName: \$quarantine_name,
          device: \$device,
          inode: \$inode,
          metadataSha256: \$metadata_sha256
        }" >"${prune_temp}"
      ! write_release_prune_cleanup_record \
        "stale-release" "${device}" "${inode}" "${metadata_sha256}"
      [[ -s "${prune_temp}" &&
        ! -e "${RELEASE_PRUNE_CLEANUP_RECORD}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "transaction backup clears its partial path when mkdir fails" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      command mkdir -p "${STATE_HOME}"
      partial="${TRANSACTION_JOURNAL}.new.$$"
      saw_backup=false
      mkdir() {
        [[ "${TRANSACTION_BACKUP}" == "${partial}" ]] && saw_backup=true
        return 1
      }
      if backup_transaction; then
        exit 1
      fi
      [[ "${saw_backup}" == "true" && -z "${TRANSACTION_BACKUP}" &&
        ! -e "${partial}" && ! -L "${partial}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "signals do not restore an incomplete transaction backup" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_before partial

  install_fixture
  current_before="$(readlink "${install_root}/current")"
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      snapshot_path() {
        kill -TERM "$$"
      }
      backup_transaction
    ' _ "${MANAGER}"

  [ "${status}" -eq 143 ]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  partial="$(find "${TEST_HOME}/.local/state" -maxdepth 1 \
    -name 'devin-desktop-manager.transaction.new.*' -print -quit)"
  [ -z "${partial}" ]
}

@test "the next mutation removes an orphan transaction partial before PID reuse" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      mkdir -p "${STATE_HOME}"
      partial="${TRANSACTION_JOURNAL}.new.$$"
      mkdir -p "${partial}"
      printf "%s" "$(ownership_sentinel_content)" >"${partial}/owner"
      printf "orphaned\n" >"${partial}/partial"
      acquire_lock
      [[ ! -e "${partial}" && ! -L "${partial}" ]]
      backup_transaction
      [[ "${TRANSACTION_BACKUP}" == "${TRANSACTION_JOURNAL}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "orphan transaction recovery rejects an unproven directory" {
  local partial="${TEST_HOME}/.local/state/devin-desktop-manager.transaction.new.12345"

  mkdir -p "${partial}"
  printf 'preserve user data\n' >"${partial}/keep.txt"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction temporary is unsafe"* ]]
  [ "$(cat "${partial}/keep.txt")" = "preserve user data" ]
}

@test "orphan transaction recovery rejects a symlink without touching its target" {
  local external="${BATS_TEST_TMPDIR}/external-transaction-data"

  printf 'preserve\n' >"${external}"
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      mkdir -p "${STATE_HOME}"
      ln -s "$2" "${TRANSACTION_JOURNAL}.new.12345"
      acquire_lock
    ' _ "${MANAGER}" "${external}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction temporary is unsafe"* ]]
  [ "$(cat "${external}")" = "preserve" ]
}

@test "the next mutation recovers an interrupted durable transaction" {
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      mkdir -p "$(dirname "${MAIN_DESKTOP}")"
      printf "%s\noriginal\n" \
        "${MANAGER_DESKTOP_MARKER}" >"${MAIN_DESKTOP}"
      backup_transaction
      printf "interrupted\n" >"${MAIN_DESKTOP}"
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [ "$(cat "${desktop}")" = "interrupted" ]

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      cat "${MAIN_DESKTOP}"
  ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"recovering an unfinished manager transaction"* ]]
  [ "${lines[-1]}" = "original" ]
}

@test "[PMC-U2-C01] transaction recovery preserves a user file created after an absent snapshot" {
  local mimeapps="${TEST_HOME}/.config/mimeapps.list"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${journal}" ]

  mkdir -p "$(dirname "${mimeapps}")"
  printf 'user-created after crash\n' >"${mimeapps}"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
    ' _ "${MANAGER}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction recovery failed"* ]]
  [ "$(cat "${mimeapps}")" = "user-created after crash" ]
  [ -d "${journal}" ]
}

@test "transaction recovery removes a recorded manager MIME file after an absent snapshot" {
  local mimeapps="${TEST_HOME}/.config/mimeapps.list"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      mkdir -p "$(dirname "${CONFIG_HOME}/mimeapps.list")"
      printf "manager-created\n" >"${CONFIG_HOME}/mimeapps.list"
      record_user_configuration_results
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${journal}" ]

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"recovering an unfinished manager transaction"* ]]
  [ ! -e "${mimeapps}" ]
  [ ! -e "${journal}" ]
}

@test "transaction recovery preserves user defaults edited after a crash" {
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"

  seed_defaults
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${journal}" ]

  printf '[Default Applications]\nx-scheme-handler/devin=user-after-crash.desktop;\n' \
    >"${DEFAULTS_FILE}"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
    ' _ "${MANAGER}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction recovery failed"* ]]
  grep -Fqx \
    'x-scheme-handler/devin=user-after-crash.desktop;' "${DEFAULTS_FILE}"
  [ -d "${journal}" ]
}

@test "transaction recovery preserves user-owned files edited after a crash" {
  local command="${TEST_HOME}/.local/bin/devin-desktop"
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"

  install_fixture
  rm -f -- "${command}"
  printf 'user before crash\n' >"${command}"
  printf '# user before crash\n' >>"${desktop}"
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${journal}" ]

  printf 'user after crash\n' >"${command}"
  printf '# user after crash\n' >>"${desktop}"
  run install_fixture

  [ "${status}" -ne 0 ]
  [ "$(cat "${command}")" = "user after crash" ]
  grep -Fqx '# user after crash' "${desktop}"
  [ ! -e "${journal}" ]
}

@test "association batches record each result before the next rewrite" {
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      calls=0
      register_one_association() {
        calls=$((calls + 1))
        if ((calls == 1)); then
          mkdir -p "${CONFIG_HOME}"
          printf "manager result\n" >"${CONFIG_HOME}/mimeapps.list"
          return 0
        fi
        result="${TRANSACTION_BACKUP}/results/config-mimeapps.result"
        [[ -f "${result}" && ! -L "${result}" ]]
        [[ "$(cat "${result}")" == \
          "sha256 $(sha256sum "${CONFIG_HOME}/mimeapps.list" | awk '\''{print $1}'\'')" ]]
        : >"${TRANSACTION_BACKUP}/proof-seen-before-second-rewrite"
        return 1
      }
      if register_associations false; then
        exit 1
      fi
      [[ -f "${TRANSACTION_BACKUP}/proof-seen-before-second-rewrite" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "association restore records the result at its mutation boundary" {
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      mkdir -p "${CONFIG_HOME}"
      printf "[Default Applications]\n%s=%s;\n" \
        "${MIME_DEVIN}" "${URL_DESKTOP_ID}" >"${CONFIG_HOME}/mimeapps.list"
      restore_one_association "${MIME_DEVIN}" "${URL_DESKTOP_ID}" ""
      result="${TRANSACTION_BACKUP}/results/config-mimeapps.result"
      [[ -f "${result}" && ! -L "${result}" ]]
      [[ "$(cat "${result}")" == \
        "sha256 $(sha256sum "${CONFIG_HOME}/mimeapps.list" | awk '\''{print $1}'\'')" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "configuration result recording rejects an unsupported path" {
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    bash -c '
      source "$1"
      TRANSACTION_BACKUP="${STATE_HOME}/transaction"
      record_user_configuration_path_result "${HOME_DIR}/unsupported"
    ' _ "${MANAGER}"

  [ "${status}" -ne 0 ]
}

@test "MIME result publication preserves the prior proof when replacement fails" {
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      mkdir -p "${CONFIG_HOME}"
      printf "first manager result\n" >"${CONFIG_HOME}/mimeapps.list"
      record_user_configuration_result \
        "${CONFIG_HOME}/mimeapps.list" config-mimeapps
      result="${TRANSACTION_BACKUP}/results/config-mimeapps.result"
      [[ -f "${result}" && ! -L "${result}" ]]
      proof_before="$(cat "${result}")"
      printf "second manager result\n" >"${CONFIG_HOME}/mimeapps.list"
      export MOCK_MV_FAIL_PATH="${result}"
      if record_user_configuration_result \
        "${CONFIG_HOME}/mimeapps.list" config-mimeapps; then
        exit 1
      fi
      [[ "$(cat "${result}")" == "${proof_before}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
}

@test "transaction recovery takes an existing public manager lock" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"
  local legacy_lock="${install_root}/.manager.lock"
  local ready="${BATS_TEST_TMPDIR}/legacy-recovery-lock-ready"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${journal}" ]

  start_lock_holder "${legacy_lock}" "${ready}"
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c 'source "$1"; acquire_lock' \
    _ "${MANAGER}"
  stop_lock_holder

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"another Devin Desktop manager operation is running"* ]]
  [ -d "${journal}" ]
}

@test "a partial transaction discard is cleaned without replaying snapshots" {
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"
  local discard="${TEST_HOME}/.local/state/devin-desktop-manager.transaction.discard"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      mkdir -p "$(dirname "${MAIN_DESKTOP}")"
      printf "original\n" >"${MAIN_DESKTOP}"
      backup_transaction
      printf "committed\n" >"${MAIN_DESKTOP}"
      mv -T -- "${TRANSACTION_JOURNAL}" "${TRANSACTION_DISCARD}"
      rm -f -- "${TRANSACTION_DISCARD}/main-desktop"
      TRANSACTION_BACKUP=""
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${discard}" ]

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      cat "${MAIN_DESKTOP}"
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"finishing an interrupted transaction discard"* ]]
  [[ "${output}" != *"recovering an unfinished manager transaction"* ]]
  [ "${lines[-1]}" = "committed" ]
  [ "$(cat "${desktop}")" = "committed" ]
  [ ! -e "${discard}" ]
}

@test "transaction discard recovery rejects an unproven directory" {
  local discard="${TEST_HOME}/.local/state/devin-desktop-manager.transaction.discard"

  mkdir -p "${discard}"
  printf 'preserve user data\n' >"${discard}/keep.txt"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction discard is unsafe"* ]]
  [ "$(cat "${discard}/keep.txt")" = "preserve user data" ]
}

@test "termination restores an active transaction before exiting" {
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      mkdir -p "$(dirname "${MAIN_DESKTOP}")"
      printf "original\n" >"${MAIN_DESKTOP}"
      backup_transaction
      printf "interrupted\n" >"${MAIN_DESKTOP}"
      kill -TERM "$$"
    ' _ "${MANAGER}"

  [ "${status}" -eq 143 ]
  [ "$(cat "${desktop}")" = "original" ]
}

@test "integration refuses to overwrite an unowned unique path" {
  local collision="${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png"

  mkdir -p "$(dirname "${collision}")"
  printf 'user file\n' >"${collision}"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"cannot be safely replaced"* ]]
  [ "$(cat "${collision}")" = "user file" ]
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "update preserves unowned desktop files that use legacy names" {
  local data_archive="${BATS_TEST_TMPDIR}/data.tar.gz"
  local data_home="${TEST_HOME}/.local/share"

  mkdir -p \
    "${data_home}/applications" \
    "${data_home}/icons/hicolor/512x512/apps" \
    "${data_home}/mime/packages"
  printf '[Desktop Entry]\nType=Application\nName=Independent Devin\n' \
    >"${data_home}/applications/devin-desktop.desktop"
  printf '[Desktop Entry]\nType=Application\nName=Independent URL\n' \
    >"${data_home}/applications/devin-desktop-url-handler.desktop"
  bsdtar -xOf "${FIXTURE}" data.tar.gz >"${data_archive}"
  bsdtar -xOf "${data_archive}" ./usr/share/pixmaps/devin-desktop.png \
    >"${data_home}/icons/hicolor/512x512/apps/devin-desktop.png"
  bsdtar -xOf "${data_archive}" \
    ./usr/share/mime/packages/devin-desktop-workspace.xml \
    >"${data_home}/mime/packages/devin-desktop-workspace.xml"
  mkdir -p "$(dirname "${DEFAULTS_FILE}")"
  cat >"${DEFAULTS_FILE}" <<'EOF'
[Default Applications]
x-scheme-handler/devin=devin-desktop-url-handler.desktop;
x-scheme-handler/windsurf=devin-desktop-url-handler.desktop;
application/x-devin-desktop-workspace=devin-desktop.desktop;
EOF

  run install_fixture

  [ "${status}" -eq 0 ]
  [ -f "${data_home}/applications/devin-desktop.desktop" ]
  [ -f "${data_home}/applications/devin-desktop-url-handler.desktop" ]
  [ -f "${data_home}/icons/hicolor/512x512/apps/devin-desktop.png" ]
  [ -f "${data_home}/mime/packages/devin-desktop-workspace.xml" ]
  [ "$(query_default x-scheme-handler/devin)" = "devin-desktop-url-handler.desktop" ]
  run jq -r '.originalDefaults["x-scheme-handler/devin"]' \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json"
  [ "${output}" = "devin-desktop-url-handler.desktop" ]
}

@test "update migrates integration created by the pre-0.1 manager" {
  local data_archive="${BATS_TEST_TMPDIR}/data.tar.gz"
  local data_home="${TEST_HOME}/.local/share"

  mkdir -p \
    "${TEST_HOME}/.local/bin" \
    "${data_home}/applications" \
    "${data_home}/icons/hicolor/512x512/apps" \
    "${data_home}/mime/packages"
  ln -s "${TEST_HOME}/.local/opt/devin-desktop/current/app/bin/devin-desktop" \
    "${TEST_HOME}/.local/bin/devin-desktop"
  printf '[Desktop Entry]\nType=Application\nName=Legacy Devin\nX-Devin-Desktop-Manager=true\n' \
    >"${data_home}/applications/devin-desktop.desktop"
  printf '[Desktop Entry]\nType=Application\nName=Legacy URL\nX-Devin-Desktop-Manager=true\n' \
    >"${data_home}/applications/devin-desktop-url-handler.desktop"
  bsdtar -xOf "${FIXTURE}" data.tar.gz >"${data_archive}"
  bsdtar -xOf "${data_archive}" ./usr/share/pixmaps/devin-desktop.png \
    >"${data_home}/icons/hicolor/512x512/apps/devin-desktop.png"
  bsdtar -xOf "${data_archive}" \
    ./usr/share/mime/packages/devin-desktop-workspace.xml \
    >"${data_home}/mime/packages/devin-desktop-workspace.xml"
  mkdir -p "$(dirname "${DEFAULTS_FILE}")"
  cat >"${DEFAULTS_FILE}" <<'EOF'
[Default Applications]
x-scheme-handler/devin=devin-desktop-url-handler.desktop;
x-scheme-handler/windsurf=devin-desktop-url-handler.desktop;
application/x-devin-desktop-workspace=devin-desktop.desktop;
EOF

  run install_fixture

  [ "${status}" -eq 0 ]
  [ ! -e "${data_home}/applications/devin-desktop.desktop" ]
  [ ! -e "${data_home}/applications/devin-desktop-url-handler.desktop" ]
  [ ! -e "${data_home}/icons/hicolor/512x512/apps/devin-desktop.png" ]
  [ ! -e "${data_home}/mime/packages/devin-desktop-workspace.xml" ]
  [ "$(query_default x-scheme-handler/devin)" = "devin-desktop-manager-url-handler.desktop" ]
  run jq -r '.originalDefaults["x-scheme-handler/devin"]' \
    "${TEST_HOME}/.local/state/devin-desktop-manager/state.json"
  [ -z "${output}" ]
}

@test "update refuses a manager desktop entry modified after installation" {
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"

  install_fixture
  printf '# user customization\n' >>"${desktop}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"was modified and cannot be safely replaced"* ]]
  grep -Fq '# user customization' "${desktop}"
}

@test "archive validation rejects a symlink escaping the extraction root" {
  local unsafe="${BATS_TEST_TMPDIR}/unsafe.deb"

  "${FIXTURE_BUILDER}" "${unsafe}" unsafe-symlink
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb" \
    "${unsafe}"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"link that escapes its extraction root"* ]]
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "archive validation rejects a hard link to a missing payload member" {
  local unsafe="${BATS_TEST_TMPDIR}/unsafe-hardlink.deb"

  "${FIXTURE_BUILDER}" "${unsafe}" unsafe-hardlink
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb" \
    "${unsafe}"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"hard link target is outside the payload"* ]]
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "[PMC-U2-C01] rollback swaps releases and refreshes managed state" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update

  run manager_env rollback

  [ "${status}" -eq 0 ]
  run manager_env status
  [[ "${output}" == *"Current:  3.4.27"* ]]
  [[ "${output}" == *"Previous: 3.4.28"* ]]
  run manager_env doctor
  [ "${status}" -eq 0 ]
}

@test "[PMC-U4-R09] repeat update is idempotent and repeat rollback toggles intentionally" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local original_current upgraded_current

  install_fixture
  original_current="$(readlink "${install_root}/current")"
  run install_fixture
  [ "${status}" -eq 0 ]
  [ "$(readlink "${install_root}/current")" = "${original_current}" ]
  [ "$(find "${install_root}/releases" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]

  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  upgraded_current="$(readlink "${install_root}/current")"

  manager_env rollback
  manager_env rollback
  [ "$(readlink "${install_root}/current")" = "${upgraded_current}" ]
  [ "$(readlink "${install_root}/previous")" = "${original_current}" ]
}

@test "rollback refuses a previous release corrupted after installation" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local previous_path current_before

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  current_before="$(readlink "${TEST_HOME}/.local/opt/devin-desktop/current")"
  previous_path="$(
    readlink "${TEST_HOME}/.local/opt/devin-desktop/previous"
  )"
  chmod 0644 \
    "${TEST_HOME}/.local/opt/devin-desktop/${previous_path}/app/bin/devin-desktop"

  run manager_env rollback

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"release is missing the terminal launcher"* ]]
  [ "$(readlink "${TEST_HOME}/.local/opt/devin-desktop/current")" = "${current_before}" ]
}

@test "rollback refuses a previous release with damaged ownership metadata" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_before previous_target previous_path temporary

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  current_before="$(readlink "${install_root}/current")"
  previous_target="$(readlink "${install_root}/previous")"
  previous_path="${install_root}/${previous_target}"
  temporary="${previous_path}/release.json.test"
  jq '.artifactUrl = "https://example.invalid/foreign.deb"' \
    "${previous_path}/release.json" >"${temporary}"
  mv -Tf -- "${temporary}" "${previous_path}/release.json"

  run manager_env rollback

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"retained or reused release is invalid"* ]]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  [ "$(readlink "${install_root}/previous")" = "${previous_target}" ]
}

@test "rollback refuses to retain a corrupted current release as previous" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_before previous_before

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  current_before="$(readlink "${install_root}/current")"
  previous_before="$(readlink "${install_root}/previous")"
  chmod 0644 "${install_root}/${current_before}/app/bin/devin-desktop"

  run manager_env rollback

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"retained or reused release is invalid"* ]]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  [ "$(readlink "${install_root}/previous")" = "${previous_before}" ]
}

@test "a third update keeps exactly the current and rollback releases" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local third="${BATS_TEST_TMPDIR}/third.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local third_build="cccccccccccccccccccccccccccccccccccccccc"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target previous_target

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  "${FIXTURE_BUILDER}" "${third}" safe "${third_build}" "3.4.29"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${third_build}/Devin-linux-x64-3.4.29.deb" \
    "${third}" "3.4.29" "${third_build}" 1783378475000

  run manager_env update

  [ "${status}" -eq 0 ]
  [ "$(find "${install_root}/releases" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 2 ]
  current_target="$(readlink "${install_root}/current")"
  previous_target="$(readlink "${install_root}/previous")"
  [ -d "${install_root}/${current_target}" ]
  [ -d "${install_root}/${previous_target}" ]

  run manager_env rollback

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Current:  3.4.28"* ]]
}

@test "update validates a soon-to-be-pruned release before activation" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local third="${BATS_TEST_TMPDIR}/third.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local third_build="cccccccccccccccccccccccccccccccccccccccc"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_before stale_target

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  current_before="$(readlink "${install_root}/current")"
  stale_target="$(readlink "${install_root}/previous")"
  rm -f -- "${install_root}/${stale_target}/app/bin/devin-desktop"
  "${FIXTURE_BUILDER}" "${third}" safe "${third_build}" "3.4.29"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${third_build}/Devin-linux-x64-3.4.29.deb" \
    "${third}" "3.4.29" "${third_build}" 1783378475000

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"refusing to activate while an unowned release would be pruned"* ]]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
}

@test "the next mutation resumes an interrupted release prune before inventory validation" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local third="${BATS_TEST_TMPDIR}/third.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local third_build="cccccccccccccccccccccccccccccccccccccccc"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local stale_target stale_dir stale_name quarantine_dir
  local identity device inode quarantine_name

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update
  stale_target="$(readlink "${install_root}/previous")"
  stale_dir="${install_root}/${stale_target}"
  stale_name="$(basename "${stale_dir}")"
  identity="$(stat -c '%d %i' -- "${stale_dir}")"
  read -r device inode <<<"${identity}"
  quarantine_name=".release-prune-${stale_name}-${device}-${inode}"
  quarantine_dir="${install_root}/${quarantine_name}"
  "${FIXTURE_BUILDER}" "${third}" safe "${third_build}" "3.4.29"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${third_build}/Devin-linux-x64-3.4.29.deb" \
    "${third}" "3.4.29" "${third_build}" 1783378475000

  export MOCK_RM_PARTIAL_SIGNAL_PATH="${quarantine_dir}"
  run manager_env update
  unset MOCK_RM_PARTIAL_SIGNAL_PATH

  [ "${status}" -eq 143 ]
  [ -f "${cleanup_record}" ]
  [ ! -e "${stale_dir}" ]
  [ -d "${quarantine_dir}" ]
  [ -f "${quarantine_dir}/release.json" ]
  [ -f "${cleanup_record}.proof" ]
  run jq -e \
    --arg manager "io.github.newbpydev.devin-desktop-manager" \
    --arg release_name "${stale_name}" \
    --arg quarantine_name "${quarantine_name}" \
    --arg device "${device}" \
    --arg inode "${inode}" \
    --arg metadata_sha256 "$(
      sha256sum "${quarantine_dir}/release.json" | awk '{print $1}'
    )" '
      .schemaVersion == 1 and
      .managerId == $manager and
      .releaseName == $release_name and
      .quarantineName == $quarantine_name and
      .device == $device and
      .inode == $inode and
      .metadataSha256 == $metadata_sha256
    ' "${cleanup_record}"
  [ "${status}" -eq 0 ]

  run manager_env update

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"finishing an interrupted release prune"* ]]
  [ ! -e "${stale_dir}" ]
  [ ! -e "${quarantine_dir}" ]
  [ ! -e "${cleanup_record}" ]
  [ ! -e "${cleanup_record}.proof" ]
}

@test "uninstall cleanup proof survives removal of the in-tree ownership marker" {
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.cleanup"
  local staged_root sentinel

  install_fixture
  export MOCK_RM_SIGNAL_BEFORE_PATTERN=".uninstall-"
  run manager_env uninstall --yes
  unset MOCK_RM_SIGNAL_BEFORE_PATTERN

  [ "${status}" -eq 143 ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  sentinel="${staged_root}/.devin-desktop-manager-owned"
  [ -f "${cleanup_record}" ]
  [ -f "${cleanup_record}.proof" ]
  find "${staged_root}" -mindepth 1 -maxdepth 1 \
    ! -path "${sentinel}" -exec rm -rf -- {} +
  rm -f -- "${sentinel}"
  [ -d "${staged_root}" ]
  [ -z "$(find "${staged_root}" -mindepth 1 -maxdepth 1 -print -quit)" ]

  run install_fixture

  [ "${status}" -eq 0 ]
  [ ! -e "${staged_root}" ]
  [ ! -e "${cleanup_record}" ]
  [ ! -e "${cleanup_record}.proof" ]
}

@test "release prune recovery preserves a replacement at the original path" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir quarantine_dir

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="$(copy_release_with_identity \
    "${source_dir}" "3.4.25" \
    "dddddddddddddddddddddddddddddddddddddddd" \
    "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")"
  quarantine_dir="$(prune_quarantine_path "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"
  mv -T -- "${stale_dir}" "${quarantine_dir}"
  mkdir -p "${stale_dir}"
  printf 'foreign replacement\n' >"${stale_dir}/keep.txt"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"finishing an interrupted release prune"* ]]
  [[ "${output}" == *"unowned release directory"* ]]
  [ "$(cat "${stale_dir}/keep.txt")" = "foreign replacement" ]
  [ ! -e "${cleanup_record}" ]
  [ ! -e "${quarantine_dir}" ]
}

@test "record-before-rename prune recovery rejects an original-path replacement" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir quarantine_dir parked

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="${install_root}/releases/stale-before-replacement"
  cp -a -- "${source_dir}" "${stale_dir}"
  quarantine_dir="$(prune_quarantine_path "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"
  parked="${BATS_TEST_TMPDIR}/parked-before-replacement"
  mv -T -- "${stale_dir}" "${parked}"
  mkdir -p "${stale_dir}"
  printf 'foreign before rename\n' >"${stale_dir}/keep.txt"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"release prune directory identity does not match"* ]]
  [ "$(cat "${stale_dir}/keep.txt")" = "foreign before rename" ]
  [ -d "${parked}" ]
  [ -f "${cleanup_record}" ]
  [ ! -e "${quarantine_dir}" ]
}

@test "release prune recovery rejects an in-place replacement with the recorded inode" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir quarantine_dir

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="${install_root}/releases/stale-in-place"
  cp -a -- "${source_dir}" "${stale_dir}"
  quarantine_dir="$(prune_quarantine_path "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"
  find "${stale_dir}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  printf 'foreign replacement\n' >"${stale_dir}/keep.txt"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"not a fully valid manager release"* ]]
  [ "$(cat "${stale_dir}/keep.txt")" = "foreign replacement" ]
  [ -f "${cleanup_record}" ]
  [ ! -e "${quarantine_dir}" ]
}

@test "release prune recovery quarantines a matching record-before-rename directory" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir quarantine_dir

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="$(copy_release_with_identity \
    "${source_dir}" "3.4.24" \
    "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" \
    "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")"
  quarantine_dir="$(prune_quarantine_path "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"

  run manager_env update

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"finishing an interrupted release prune"* ]]
  [ ! -e "${stale_dir}" ]
  [ ! -e "${quarantine_dir}" ]
  [ ! -e "${cleanup_record}" ]
}

@test "release prune recovery preserves a mismatched quarantine object" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir quarantine_dir parked

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="${install_root}/releases/stale-quarantine"
  cp -a -- "${source_dir}" "${stale_dir}"
  quarantine_dir="$(prune_quarantine_path "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"
  parked="${BATS_TEST_TMPDIR}/parked-stale-quarantine"
  mv -T -- "${stale_dir}" "${parked}"
  mkdir -p "${quarantine_dir}"
  printf 'foreign quarantine\n' >"${quarantine_dir}/keep.txt"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"quarantine identity does not match"* ]]
  [ "$(cat "${quarantine_dir}/keep.txt")" = "foreign quarantine" ]
  [ -f "${cleanup_record}" ]
  [ ! -e "${stale_dir}" ]
}

@test "release prune recovery rejects a quarantine name unrelated to its identity" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir temporary

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="${install_root}/releases/stale-record"
  cp -a -- "${source_dir}" "${stale_dir}"
  record_prune_intent_for_release "${stale_dir}"
  temporary="${cleanup_record}.tampered"
  jq '.quarantineName = ".release-prune-unrelated-1-2"' \
    "${cleanup_record}" >"${temporary}"
  mv -Tf -- "${temporary}" "${cleanup_record}"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"release prune quarantine is invalid"* ]]
  [ -d "${stale_dir}" ]
  [ -f "${cleanup_record}" ]
}

@test "release prune records cannot target current or previous releases" {
  local second="${BATS_TEST_TMPDIR}/second.deb"
  local second_build="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local link target release_dir quarantine_dir

  install_fixture
  "${FIXTURE_BUILDER}" "${second}" safe "${second_build}" "3.4.28"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/${second_build}/Devin-linux-x64-3.4.28.deb" \
    "${second}" "3.4.28" "${second_build}" 1783378474000
  manager_env update

  for link in current previous; do
    target="$(readlink "${install_root}/${link}")"
    release_dir="${install_root}/${target}"
    quarantine_dir="$(prune_quarantine_path "${release_dir}")"
    record_prune_intent_for_release "${release_dir}"

    run manager_env update

    [ "${status}" -ne 0 ]
    [[ "${output}" == *"release prune targets an active release"* ]]
    [ -d "${release_dir}" ]
    [ ! -e "${quarantine_dir}" ]
    [ -f "${cleanup_record}" ]
    rm -f -- "${cleanup_record}"
  done
}

@test "release prune recovery rejects malformed active links before cleanup" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir stale_name

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="${install_root}/releases/stale-active-release"
  cp -a -- "${source_dir}" "${stale_dir}"
  stale_name="$(basename "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"
  rm -f -- "${install_root}/current"
  ln -s "releases/./${stale_name}" "${install_root}/current"

  run manager_env update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"current release link is invalid"* ]]
  [ -d "${stale_dir}" ]
  [ -f "${cleanup_record}" ]
}

@test "pending release prune recovery refuses to delete a running release" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.prune"
  local source_dir stale_dir quarantine_dir running_pid

  install_fixture
  source_dir="${install_root}/$(readlink "${install_root}/current")"
  stale_dir="${install_root}/releases/running-stale-release"
  cp -a -- "${source_dir}" "${stale_dir}"
  cp -- /bin/sleep "${stale_dir}/app/bin/devin-desktop"
  chmod 0755 "${stale_dir}/app/bin/devin-desktop"
  quarantine_dir="$(prune_quarantine_path "${stale_dir}")"
  record_prune_intent_for_release "${stale_dir}"
  mv -T -- "${stale_dir}" "${quarantine_dir}"

  "${quarantine_dir}/app/bin/devin-desktop" 30 &
  running_pid=$!
  sleep 0.1
  rm -f -- "${quarantine_dir}/app/bin/devin-desktop"
  run manager_env update
  kill "${running_pid}" 2>/dev/null || true
  wait "${running_pid}" 2>/dev/null || true

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Devin Desktop is running"* ]]
  [ -d "${quarantine_dir}" ]
  [ -f "${cleanup_record}" ]
}

@test "pending uninstall cleanup refuses to delete a running staged release" {
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.cleanup"
  local staged_root staged_app running_pid

  install_fixture
  export MOCK_RM_SIGNAL_BEFORE_PATTERN=".uninstall-"
  run manager_env uninstall --yes
  unset MOCK_RM_SIGNAL_BEFORE_PATTERN
  [ "${status}" -eq 143 ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  staged_app="$(find "${staged_root}/releases" -mindepth 4 -maxdepth 4 \
    -path '*/app/bin/devin-desktop' -type f -print -quit)"
  [ -n "${staged_app}" ]
  cp -- /bin/sleep "${staged_app}"
  chmod 0755 "${staged_app}"

  "${staged_app}" 30 &
  running_pid=$!
  sleep 0.1
  rm -f -- "${staged_app}"
  run install_fixture
  kill "${running_pid}" 2>/dev/null || true
  wait "${running_pid}" 2>/dev/null || true

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Devin Desktop is running"* ]]
  [ -d "${staged_root}" ]
  [ -f "${cleanup_record}" ]
}

@test "doctor reports a damaged command link" {
  install_fixture
  rm "${TEST_HOME}/.local/bin/devin-desktop"

  run manager_env doctor

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"terminal command is not a symlink"* ]]
  [[ "${output}" == *"Installation problems:"* ]]
}

@test "uninstall leaves a manager file modified by the user" {
  install_fixture
  printf 'user replacement\n' \
    >"${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png"

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"leaving modified or non-manager-owned path"* ]]
  [ -f "${TEST_HOME}/.local/share/icons/hicolor/512x512/apps/devin-desktop-manager.png" ]
}

@test "uninstall leaves a manager desktop entry modified by the user" {
  local desktop="${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop"

  install_fixture
  printf '# user customization\n' >>"${desktop}"

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"leaving modified or non-manager-owned path"* ]]
  [ -f "${desktop}" ]
  grep -Fq '# user customization' "${desktop}"
}

@test "uninstall propagates MIME rewrite failure and keeps the installation usable" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_before

  install_fixture
  current_before="$(readlink "${install_root}/current")"

  export MOCK_CHMOD_FAIL_PATTERN="mimeapps.list.new."
  run manager_env uninstall --yes

  [ "${status}" -ne 0 ]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  [ -f "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" ]
}

@test "uninstall commits before attempting final manager command removal" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local manager_command="${TEST_HOME}/.local/bin/devin-desktop-manager"

  install_fixture
  ln -s "${MANAGER}" "${manager_command}"

  export MOCK_RM_FAIL_PATH="${manager_command}"
  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"could not remove the manager command"* ]]
  [ ! -e "${install_root}" ]
  [ -L "${manager_command}" ]
}

@test "staged uninstall keeps the public legacy lock continuously held until rollback" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      saw_staging_move=false
      mv() {
        command mv "$@" || return
        public_lock="${INSTALL_ROOT}/.manager.lock"
        [[ -f "${public_lock}" && ! -L "${public_lock}" ]] || return 1
        if bash -c '\''exec 7>&-; flock -n "$1" true'\'' _ "${public_lock}"; then
          return 1
        fi
        saw_staging_move=true
      }
      stage_install_root_for_uninstall
      unset -f mv
      public_lock="${INSTALL_ROOT}/.manager.lock"
      staged_lock="${STAGED_INSTALL_ROOT}/.manager.lock"
      [[ "${saw_staging_move}" == "true" &&
        -f "${public_lock}" && ! -L "${public_lock}" &&
        "${public_lock}" -ef "${staged_lock}" ]]
      if bash -c '\''exec 7>&-; flock -n "$1" true'\'' _ "${public_lock}"; then
        exit 1
      fi
      restore_transaction
      [[ -L "${CURRENT_LINK}" && ! -e "${STAGED_INSTALL_ROOT}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [ -L "${install_root}/current" ]
}

@test "failed legacy lock bridge publication cleans its placeholder" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      ln() { return 1; }
      if stage_install_root_for_uninstall; then
        exit 1
      fi
      unset -f ln
      [[ -L "${CURRENT_LINK}" &&
        ! -e "${STAGED_INSTALL_ROOT}" && ! -L "${STAGED_INSTALL_ROOT}" ]]
      restore_transaction
      [[ -L "${CURRENT_LINK}" && ! -e "${STAGED_INSTALL_ROOT}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [ -L "${install_root}/current" ]
}

@test "partial locked-root staging restores without exposing another lock inode" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      mv() {
        if [[ "$*" == *"${INSTALL_ROOT}/releases"* ]]; then
          return 1
        fi
        command mv "$@"
      }
      if stage_install_root_for_uninstall; then
        exit 1
      fi
      unset -f mv
      public_lock="${INSTALL_ROOT}/.manager.lock"
      staged_lock="${STAGED_INSTALL_ROOT}/.manager.lock"
      [[ -f "${public_lock}" && -f "${staged_lock}" &&
        "${public_lock}" -ef "${staged_lock}" ]]
      if bash -c '\''exec 7>&-; flock -n "$1" true'\'' _ "${public_lock}"; then
        exit 1
      fi
      restore_transaction
      [[ -L "${CURRENT_LINK}" && ! -e "${STAGED_INSTALL_ROOT}" ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [ -L "${install_root}/current" ]
}

@test "recovery discards only lock staging shells created before record publication" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction

      STAGED_INSTALL_ROOT="${INSTALL_ROOT}.uninstall-$$"
      mkdir -- "${STAGED_INSTALL_ROOT}"
      restore_staged_install_root
      [[ ! -e "${STAGED_INSTALL_ROOT}" ]]

      STAGED_INSTALL_ROOT="${INSTALL_ROOT}.uninstall-$$"
      create_legacy_lock_bridge "${STAGED_INSTALL_ROOT}"
      [[ "${INSTALL_ROOT}/.manager.lock" -ef \
        "${STAGED_INSTALL_ROOT}/.manager.lock" ]]
      restore_staged_install_root
      [[ ! -e "${STAGED_INSTALL_ROOT}" &&
        -L "${CURRENT_LINK}" &&
        "${INSTALL_ROOT}/.manager.lock" -ef /proc/self/fd/7 ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [ -L "${install_root}/current" ]
}

@test "uninstall recovers verified current-manager temporaries before validation" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local current_target release_name staging integration

  install_fixture
  current_target="$(readlink "${install_root}/current")"
  release_name="$(basename "${current_target}")"
  staging="${install_root}/.staging-${release_name}-12345"
  integration="${install_root}/.integration-12345"
  mkdir -p "${staging}/partial" "${integration}"
  printf 'partial staging\n' >"${staging}/partial/keep.txt"
  printf 'partial integration\n' >"${integration}/keep.txt"
  ln -s "${current_target}" "${install_root}/.current.new.12345"
  ln -s "${current_target}" "${install_root}/.previous.new.12345"

  run manager_env uninstall --yes

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"managed application removed"* ]]
  [ ! -e "${install_root}" ]
}

@test "uninstall transaction cleanup failure reports deferred recovery" {
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"
  local discard="${journal}.discard"

  install_fixture

  export MOCK_MV_FAIL_PATH="${discard}"
  run manager_env uninstall --yes
  unset MOCK_MV_FAIL_PATH

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"uninstall was not durably committed"* ]]
  [[ "${output}" == *"transaction journal preserved at ${journal}"* ]]
  [[ "${output}" == *"recovery is required before another installation change"* ]]
  [[ "${output}" != *"will be attempted"* ]]
  [[ "${output}" != *"uninstall completed"* ]]
  [ -d "${journal}" ]
}

@test "the next mutation restores an uninstall journal before recreating the root" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"
  local discard="${journal}.discard"
  local staged_root

  install_fixture

  export MOCK_MV_FAIL_PATH="${discard}"
  run manager_env uninstall --yes
  unset MOCK_MV_FAIL_PATH

  [ "${status}" -ne 0 ]
  [ -d "${journal}" ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  [ "${install_root}/.manager.lock" -ef "${staged_root}/.manager.lock" ]

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"recovering an unfinished manager transaction"* ]]
  [ ! -e "${journal}" ]
  [ -L "${install_root}/current" ]
}

@test "transaction recovery handles a staged-root record published before its move" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      read -r device inode < <(stat -c "%d %i" -- "${INSTALL_ROOT}")
      jq -n \
        --arg staged_root "${INSTALL_ROOT}.uninstall-12345" \
        --arg device "${device}" \
        --arg inode "${inode}" "{
          stagedInstallRoot: \$staged_root,
          device: \$device,
          inode: \$inode
        }" >"${TRANSACTION_BACKUP}/staged-install-root"
      chmod 0600 "${TRANSACTION_BACKUP}/staged-install-root"
    ' _ "${MANAGER}"
  [ "${status}" -eq 0 ]
  [ -d "${journal}" ]
  [ -d "${install_root}" ]

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"recovering an unfinished manager transaction"* ]]
  [ ! -e "${journal}" ]
  [ -L "${install_root}/current" ]
}

@test "transaction recovery remains compatible with a whole-root staged journal" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"

  install_fixture
  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" bash -c '
      source "$1"
      acquire_lock
      backup_transaction
      staged_root="${INSTALL_ROOT}.uninstall-123"
      mv -T -- "${INSTALL_ROOT}" "${staged_root}"
      read -r device inode < <(stat -c "%d %i" -- "${staged_root}")
      jq -n \
        --arg staged_root "${staged_root}" \
        --arg device "${device}" \
        --arg inode "${inode}" "{
          stagedInstallRoot: \$staged_root,
          device: \$device,
          inode: \$inode
        }" >"${TRANSACTION_BACKUP}/staged-install-root"
      restore_staged_install_root
      [[ -L "${CURRENT_LINK}" &&
        ! -e "${staged_root}" &&
        "${INSTALL_ROOT}/.manager.lock" -ef /proc/self/fd/7 ]]
    ' _ "${MANAGER}"

  [ "${status}" -eq 0 ]
  [ -L "${install_root}/current" ]
}

@test "transaction recovery preserves its journal when the staged root is missing" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"
  local discard="${journal}.discard"
  local staged_root

  install_fixture
  export MOCK_MV_FAIL_PATH="${discard}"
  run manager_env uninstall --yes
  unset MOCK_MV_FAIL_PATH
  [ "${status}" -ne 0 ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  rm -rf -- "${staged_root}"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction recovery failed"* ]]
  [ -d "${journal}" ]
  [ -f "${install_root}/.manager.lock" ]
  [ -z "$(find "${install_root}" -mindepth 1 -maxdepth 1 \
    ! -name .manager.lock -print -quit)" ]
}

@test "absent-root recovery takes the staged installation legacy lock" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"
  local discard="${journal}.discard"
  local staged_root ready

  install_fixture
  export MOCK_MV_FAIL_PATH="${discard}"
  run manager_env uninstall --yes
  unset MOCK_MV_FAIL_PATH
  [ "${status}" -ne 0 ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  [ "${install_root}/.manager.lock" -ef "${staged_root}/.manager.lock" ]
  ready="${BATS_TEST_TMPDIR}/staged-recovery-lock-ready"
  start_lock_holder "${staged_root}/.manager.lock" "${ready}"

  run install_fixture
  stop_lock_holder

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"another Devin Desktop manager operation is running"* ]]
  [ -d "${journal}" ]
  [ -d "${staged_root}" ]
  [ "${install_root}/.manager.lock" -ef "${staged_root}/.manager.lock" ]
}

@test "transaction recovery rejects a partially deleted staged root" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local journal="${TEST_HOME}/.local/state/devin-desktop-manager.transaction"
  local discard="${journal}.discard"
  local staged_root

  install_fixture
  export MOCK_MV_FAIL_PATH="${discard}"
  run manager_env uninstall --yes
  unset MOCK_MV_FAIL_PATH
  [ "${status}" -ne 0 ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  rm -rf -- "${staged_root}/releases"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished transaction recovery failed"* ]]
  [ -d "${journal}" ]
  [ -d "${staged_root}" ]
  [ "${install_root}/.manager.lock" -ef "${staged_root}/.manager.lock" ]
}

@test "manager command removal happens after committed uninstall cleanup" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local manager_command="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.cleanup"

  install_fixture
  ln -s "${MANAGER}" "${manager_command}"

  export MOCK_RM_SIGNAL_AFTER_PATH="${manager_command}"
  run manager_env uninstall --yes

  [ "${status}" -eq 143 ]
  [ ! -e "${manager_command}" ]
  [ ! -e "${install_root}" ]
  [ ! -e "${cleanup_record}" ]
  run find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print
  [ -z "${output}" ]
}

@test "the next mutation finishes an interrupted committed uninstall cleanup" {
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.cleanup"
  local staged_before

  install_fixture

  export MOCK_RM_SIGNAL_BEFORE_PATTERN=".uninstall-"
  run manager_env uninstall --yes
  unset MOCK_RM_SIGNAL_BEFORE_PATTERN

  [ "${status}" -eq 143 ]
  [ -f "${cleanup_record}" ]
  staged_before="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_before}" ]
  rm -rf -- "${staged_before}/releases"

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"finishing an interrupted uninstall cleanup"* ]]
  [ ! -e "${cleanup_record}" ]
  run find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print
  [ -z "${output}" ]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "uninstall cleanup recovery preserves a replacement staged root" {
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.cleanup"
  local staged_root

  install_fixture

  export MOCK_RM_SIGNAL_BEFORE_PATTERN=".uninstall-"
  run manager_env uninstall --yes
  unset MOCK_RM_SIGNAL_BEFORE_PATTERN

  [ "${status}" -eq 143 ]
  [ -f "${cleanup_record}" ]
  staged_root="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_root}" ]
  rm -rf -- "${staged_root}"
  mkdir -p "${staged_root}"
  printf 'replacement data\n' >"${staged_root}/keep.txt"

  run install_fixture

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unfinished uninstall cleanup root"* ]]
  [ "$(cat "${staged_root}/keep.txt")" = "replacement data" ]
  [ -f "${cleanup_record}" ]
}

@test "relative XDG paths are rejected before any mutation" {
  run env HOME="${TEST_HOME}" XDG_DATA_HOME=relative/path \
    PATH="${MOCK_BIN}:${PATH}" "${MANAGER}" status

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"XDG_DATA_HOME must be set to an absolute path"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}

@test "shared state homes are rejected before journal or lock creation" {
  local state_home="${BATS_TEST_TMPDIR}/shared-state"

  mkdir -p "${state_home}"
  chmod 0777 "${state_home}"

  run env HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${state_home}" PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" uninstall --yes

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"XDG_STATE_HOME must not be writable by other users"* ]]
  [ ! -e "${state_home}/devin-desktop-manager.lock" ]
  [ ! -e "${state_home}/devin-desktop-manager.transaction" ]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}

@test "[PMC-U2-C01] state lock rejects FIFOs and hard links without opening or truncating them" {
  local state_home="${TEST_HOME}/.local/state"
  local lock_file="${state_home}/devin-desktop-manager.lock"
  local user_file="${BATS_TEST_TMPDIR}/user-file"

  mkdir -p "${state_home}"
  mkfifo "${lock_file}"
  run timeout 2 env HOME="${TEST_HOME}" XDG_STATE_HOME="${state_home}" \
    PATH="${MOCK_BIN}:${PATH}" bash -c 'source "$1"; acquire_lock' \
    _ "${MANAGER}"
  [ "${status}" -ne 0 ]
  [ "${status}" -ne 124 ]
  [[ "${output}" == *"manager lock must be a non-symbolic regular file"* ]]
  [ -p "${lock_file}" ]

  rm -f -- "${lock_file}"
  printf 'preserve user data\n' >"${user_file}"
  ln "${user_file}" "${lock_file}"
  run env HOME="${TEST_HOME}" XDG_STATE_HOME="${state_home}" \
    PATH="${MOCK_BIN}:${PATH}" bash -c 'source "$1"; acquire_lock' \
    _ "${MANAGER}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"manager lock must not have hard links"* ]]
  [ "$(cat "${user_file}")" = "preserve user data" ]
}

@test "XDG roots beneath the installation root are rejected before mutation" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local xdg_name

  for xdg_name in \
    XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CONFIG_HOME; do
    run env HOME="${TEST_HOME}" "${xdg_name}=${install_root}/${xdg_name}" \
      PATH="${MOCK_BIN}:${PATH}" "${MANAGER}" update

    [ "${status}" -ne 0 ]
    [[ "${output}" == \
      *"${xdg_name} must not be the installation root or a directory beneath it"* ]]
    [ ! -e "${install_root}" ]
  done
}

@test "data and config homes beneath removed manager roots are rejected" {
  local cache_root="${TEST_HOME}/.cache/devin-desktop-manager"
  local state_dir="${TEST_HOME}/.local/state/devin-desktop-manager"
  local xdg_name xdg_path

  for xdg_name in XDG_CONFIG_HOME XDG_DATA_HOME; do
    case "${xdg_name}" in
      XDG_CONFIG_HOME) xdg_path="${cache_root}/config" ;;
      XDG_DATA_HOME) xdg_path="${state_dir}/data" ;;
    esac
    run env HOME="${TEST_HOME}" "${xdg_name}=${xdg_path}" \
      PATH="${MOCK_BIN}:${PATH}" "${MANAGER}" update

    [ "${status}" -ne 0 ]
    [[ "${output}" == \
      *"${xdg_name} must not be a manager root removed by uninstall or a directory beneath it"* ]]
    [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
  done
}

@test "derived manager cache and state roots must not overlap" {
  local shared_home="${TEST_HOME}/.local/manager-storage"

  run env HOME="${TEST_HOME}" XDG_CACHE_HOME="${shared_home}" \
    XDG_STATE_HOME="${shared_home}" PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"manager cache and state roots must not overlap"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}

@test "state storage beneath the manager cache root is rejected before mutation" {
  local cache_home="${TEST_HOME}/.cache"
  local state_home="${cache_home}/devin-desktop-manager/state"

  run env HOME="${TEST_HOME}" XDG_CACHE_HOME="${cache_home}" \
    XDG_STATE_HOME="${state_home}" PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" update

  [ "${status}" -ne 0 ]
  [[ "${output}" == \
    *"XDG_STATE_HOME must not be a manager root removed by uninstall or a directory beneath it"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}

@test "XDG homes beneath removable state artifacts are rejected" {
  local state_home="${TEST_HOME}/.local/state"
  local artifact_path

  for artifact_path in \
    "${state_home}/devin-desktop-manager.lock/data" \
    "${state_home}/devin-desktop-manager.transaction/data" \
    "${state_home}/devin-desktop-manager.transaction.discard/data" \
    "${state_home}/devin-desktop-manager.cleanup/data" \
    "${state_home}/devin-desktop-manager.cleanup.proof/data" \
    "${state_home}/devin-desktop-manager.prune/data" \
    "${state_home}/devin-desktop-manager.prune.proof/data"; do
    run env HOME="${TEST_HOME}" XDG_STATE_HOME="${state_home}" \
      XDG_DATA_HOME="${artifact_path}" PATH="${MOCK_BIN}:${PATH}" \
      "${MANAGER}" update

    [ "${status}" -ne 0 ]
    [[ "${output}" == \
      *"XDG_DATA_HOME must not be a removable manager state artifact or a directory beneath it"* ]]
    [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
  done
}

@test "XDG homes beneath manager temporary cleanup roots are rejected" {
  local state_home="${TEST_HOME}/.local/state"
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local temporary_path

  for temporary_path in \
    "${state_home}/devin-desktop-manager.transaction.new.123/data" \
    "${install_root}.uninstall-123/data"; do
    run env HOME="${TEST_HOME}" XDG_STATE_HOME="${state_home}" \
      XDG_DATA_HOME="${temporary_path}" PATH="${MOCK_BIN}:${PATH}" \
      "${MANAGER}" update

    [ "${status}" -ne 0 ]
    [[ "${output}" == \
      *"XDG_DATA_HOME must not be a manager temporary cleanup root or a directory beneath it"* ]]
    [ ! -e "${install_root}" ]
  done
}

@test "temporary cleanup root validation canonicalizes a symlinked home" {
  local real_home="${BATS_TEST_TMPDIR}/real-home"
  local linked_home="${BATS_TEST_TMPDIR}/linked-home"

  mkdir -p "${real_home}"
  ln -s "${real_home}" "${linked_home}"
  run env HOME="${linked_home}" \
    XDG_DATA_HOME="${linked_home}/.local/opt/devin-desktop.uninstall-123/data" \
    bash -c 'source "$1"; validate_environment' _ "${MANAGER}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == \
    *"XDG_DATA_HOME must not be a manager temporary cleanup root or a directory beneath it"* ]]
}

@test "unknown commands fail without creating installation state" {
  run manager_env explode

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unknown command: explode"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}
