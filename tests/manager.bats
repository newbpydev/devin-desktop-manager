#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  MANAGER="${PROJECT_ROOT}/bin/devin-desktop-manager"
  FIXTURE_BUILDER="${PROJECT_ROOT}/tests/fixtures/build-mini-deb"
  TEST_HOME="${BATS_TEST_TMPDIR}/home"
  MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
  CURL_LOG="${BATS_TEST_TMPDIR}/curl.log"
  DEFAULTS_FILE="${TEST_HOME}/.config/mimeapps.list"
  FIXTURE="${BATS_TEST_TMPDIR}/devin.deb"
  export TEST_HOME MOCK_BIN CURL_LOG DEFAULTS_FILE

  mkdir -p "${TEST_HOME}" "${MOCK_BIN}"
  "${FIXTURE_BUILDER}" "${FIXTURE}"
  write_platform_mocks
}

write_platform_mocks() {
  cat >"${MOCK_BIN}/unshare" <<'EOF'
#!/usr/bin/env bash
[[ "${MOCK_UNSHARE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/ldd" <<'EOF'
#!/usr/bin/env bash
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
[[ "${MOCK_DESKTOP_CACHE_FAIL:-0}" != "1" ]]
EOF
  cat >"${MOCK_BIN}/update-mime-database" <<'EOF'
#!/usr/bin/env bash
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
  cat >"${MOCK_BIN}/rm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${MOCK_RM_FAIL_PATH:-}" ]]; then
  for argument in "$@"; do
    [[ "${argument}" != "${MOCK_RM_FAIL_PATH}" ]] || exit 73
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
printf '%s\n' "\$*" >>"${CURL_LOG}"
output=""
url="\${!#}"
while ((\$# > 0)); do
  if [[ "\$1" == "--output" ]]; then
    output="\$2"
    shift 2
  else
    shift
  fi
done
if [[ "\${url}" == "https://windsurf-stable.codeium.com/api/update/linux-x64-deb/stable/latest" ]]; then
  cat <<'JSON'
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

@test "status is read-only and reports an empty installation" {
  run manager_env status

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Current:  not installed"* ]]
  [[ "${output}" == *"Previous: none"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager" ]
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

  run env MOCK_UNSHARE_FAIL=1 \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" check

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

@test "update refuses an unowned pre-existing installation root" {
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

  run env MOCK_ARTIFACT_DOWNLOAD_FAIL=1 \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" update

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

@test "KDE cache refresh is optional and cannot break installation" {
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  run env MOCK_KDE_FAIL=1 \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" update

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"KDE cache refresh failed"* ]]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "integration failure restores release links files and defaults" {
  seed_defaults
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  run env MOCK_DESKTOP_CACHE_FAIL=1 \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" update

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"restoring the previous release and desktop state"* ]]
  [ ! -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
  [ ! -e "${TEST_HOME}/.local/share/applications/devin-desktop-manager.desktop" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" ]
  [ "$(query_default x-scheme-handler/devin)" = "browser.desktop" ]
}

@test "a failed default query aborts without changing user defaults" {
  local defaults_before="${BATS_TEST_TMPDIR}/defaults.before"

  seed_defaults
  cp "${DEFAULTS_FILE}" "${defaults_before}"
  write_manifest_curl \
    "https://windsurf-stable.codeiumdata.com/linux-x64-deb/stable/0d4bf12ed4a7597cb8ae9016fe8474468aad98a2/Devin-linux-x64-3.4.27.deb"

  run env MOCK_XDG_QUERY_FAIL=1 \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" update

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
      printf "original\n" >"${MAIN_DESKTOP}"
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

@test "rollback swaps releases and refreshes managed state" {
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

  run env MOCK_CHMOD_FAIL_PATTERN="mimeapps.list.new." \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" uninstall --yes

  [ "${status}" -ne 0 ]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  [ -f "${TEST_HOME}/.local/state/devin-desktop-manager/state.json" ]
}

@test "uninstall restores the installation when final command removal fails" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local manager_command="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local current_before

  install_fixture
  ln -s "${MANAGER}" "${manager_command}"
  current_before="$(readlink "${install_root}/current")"

  run env MOCK_RM_FAIL_PATH="${manager_command}" \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" uninstall --yes

  [ "${status}" -ne 0 ]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  [ -x "${install_root}/${current_before}/app/bin/devin-desktop" ]
  [ -L "${manager_command}" ]
}

@test "termination after manager command removal restores the full installation" {
  local install_root="${TEST_HOME}/.local/opt/devin-desktop"
  local manager_command="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local current_before

  install_fixture
  ln -s "${MANAGER}" "${manager_command}"
  current_before="$(readlink "${install_root}/current")"

  run env MOCK_RM_SIGNAL_AFTER_PATH="${manager_command}" \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" uninstall --yes

  [ "${status}" -eq 143 ]
  [ -L "${manager_command}" ]
  [ "$(readlink "${install_root}/current")" = "${current_before}" ]
  [ -x "${install_root}/${current_before}/app/bin/devin-desktop" ]
}

@test "the next mutation finishes an interrupted committed uninstall cleanup" {
  local cleanup_record="${TEST_HOME}/.local/state/devin-desktop-manager.cleanup"
  local staged_before

  install_fixture

  run env MOCK_RM_SIGNAL_BEFORE_PATTERN=".uninstall-" \
    HOME="${TEST_HOME}" \
    XDG_CACHE_HOME="${TEST_HOME}/.cache" \
    XDG_CONFIG_HOME="${TEST_HOME}/.config" \
    XDG_DATA_HOME="${TEST_HOME}/.local/share" \
    XDG_STATE_HOME="${TEST_HOME}/.local/state" \
    PATH="${MOCK_BIN}:${PATH}" \
    "${MANAGER}" uninstall --yes

  [ "${status}" -eq 143 ]
  [ -f "${cleanup_record}" ]
  staged_before="$(find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print -quit)"
  [ -n "${staged_before}" ]

  run install_fixture

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"finishing an interrupted uninstall cleanup"* ]]
  [ ! -e "${cleanup_record}" ]
  run find "${TEST_HOME}/.local/opt" -maxdepth 1 \
    -type d -name 'devin-desktop.uninstall-*' -print
  [ -z "${output}" ]
  [ -L "${TEST_HOME}/.local/opt/devin-desktop/current" ]
}

@test "relative XDG paths are rejected before any mutation" {
  run env HOME="${TEST_HOME}" XDG_DATA_HOME=relative/path \
    PATH="${MOCK_BIN}:${PATH}" "${MANAGER}" status

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"XDG_DATA_HOME must be set to an absolute path"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}

@test "unknown commands fail without creating installation state" {
  run manager_env explode

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"unknown command: explode"* ]]
  [ ! -e "${TEST_HOME}/.local/opt/devin-desktop" ]
}
