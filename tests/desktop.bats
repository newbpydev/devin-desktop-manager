#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  MANAGER="${PROJECT_ROOT}/bin/devin-desktop-manager"
  TEST_HOME="${BATS_TEST_TMPDIR}/home with space"
  MAIN_ENTRY="${BATS_TEST_TMPDIR}/devin-desktop-manager.desktop"
  URL_ENTRY="${BATS_TEST_TMPDIR}/devin-desktop-manager-url-handler.desktop"
  mkdir -p "${TEST_HOME}"
}

@test "generated desktop entries pass the real freedesktop validator" {
  run env HOME="${TEST_HOME}" bash -c '
    source "$1"
    write_desktop_entries "$2" "$3"
    desktop-file-validate "$2" "$3"
  ' _ "${MANAGER}" "${MAIN_ENTRY}" "${URL_ENTRY}"

  [ "${status}" -eq 0 ]
  grep -Fq \
    "Exec=/usr/bin/env -- \"${TEST_HOME}/.local/bin/devin-desktop\" %F" \
    "${MAIN_ENTRY}"
  grep -Fq \
    "Exec=/usr/bin/env -- \"${TEST_HOME}/.local/bin/devin-desktop\" --open-url %U" \
    "${URL_ENTRY}"
  grep -Fq 'Icon=devin-desktop-manager' "${MAIN_ENTRY}"
  grep -Fq 'MimeType=x-scheme-handler/devin;x-scheme-handler/windsurf;' \
    "${URL_ENTRY}"
}
