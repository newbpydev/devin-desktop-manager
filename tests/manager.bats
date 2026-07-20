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

@test "version reports the public CLI contract" {
  run "${MANAGER}" --version

  [ "${status}" -eq 0 ]
  [ "${output}" = "devin-desktop-manager 0.1.0" ]
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
  cat >"${current_release}/release.json" <<'JSON'
{
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
