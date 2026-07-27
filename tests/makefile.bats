#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CALL_LOG="${BATS_TEST_TMPDIR}/manager-calls"
  MOCK_MANAGER="${BATS_TEST_TMPDIR}/mock-manager"
  TEST_HOME="${BATS_TEST_TMPDIR}/home"
  export CALL_LOG

  mkdir -p "${TEST_HOME}"
  cat >"${MOCK_MANAGER}" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == internal-preflight ]]; then
  printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 0
  exit 0
fi
printf '%s\n' "$*" >>"${CALL_LOG}"
EOF
  chmod 0755 "${MOCK_MANAGER}"

  MAKE_COMMAND="$(command -v make)"
  HARNESS_BASH="$(command -v bash)"
  TRUE_COMMAND="$(type -P true)"
  TIMEOUT_COMMAND="$(command -v timeout)"
}

make_fixture() {
  local root="$1"

  mkdir -p "${root}/bin" "${root}/scripts"
  cp "${PROJECT_ROOT}/Makefile" "${root}/Makefile"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" \
    "${root}/bin/devin-desktop-manager"
  cp "${PROJECT_ROOT}/scripts/install-manager" \
    "${root}/scripts/install-manager"
  if [[ -f "${PROJECT_ROOT}/scripts/preflight" ]]; then
    cp "${PROJECT_ROOT}/scripts/preflight" "${root}/scripts/preflight"
  fi
}

@test "[PMC-U3-R04] Make composites use one explicit ordered preflight" {
  grep -Fq 'RUN_PREFLIGHT' "${PROJECT_ROOT}/Makefile"
  grep -Eq '^install:' "${PROJECT_ROOT}/Makefile"
  grep -Eq '^verify:' "${PROJECT_ROOT}/Makefile"
  grep -Eq '^release-check:' "${PROJECT_ROOT}/Makefile"
  run grep -Eq '^install:[[:space:]]+install-manager' "${PROJECT_ROOT}/Makefile"
  [ "${status}" -ne 0 ]
  run grep -Eq '^verify:[[:space:]]+lint[[:space:]]+test' "${PROJECT_ROOT}/Makefile"
  [ "${status}" -ne 0 ]
  run grep -Eq '^release-check:[[:space:]]+lint[[:space:]]+coverage' "${PROJECT_ROOT}/Makefile"
  [ "${status}" -ne 0 ]
}

write_recorder() {
  local path="$1"
  local identity="$2"

  cat >"${path}" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == internal-preflight ]]; then
  printf 'DDM-PREFLIGHT\\0%s\\0%s\\0' 1 0
  exit 0
fi
printf '%s' '${identity}' >>"\${CALL_LOG}"
printf ' <%s>' "\$@" >>"\${CALL_LOG}"
printf '\n' >>"\${CALL_LOG}"
EOF
  chmod 0755 "${path}"
}

@test "[PMC-U1-R01] help needs only Make and literal POSIX shell" {
  local stdout_file="${BATS_TEST_TMPDIR}/stdout"
  local stderr_file="${BATS_TEST_TMPDIR}/stderr"

  run /bin/sh -c 'env -u HOME -u BASH -u RUBYOPT -u XDG_CONFIG_HOME \
    -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME -u XDG_RUNTIME_DIR \
    PATH=/missing "$1" --no-print-directory -s -C "$2" >"$3" 2>"$4"' \
    _ "${MAKE_COMMAND}" "${PROJECT_ROOT}" "${stdout_file}" "${stderr_file}"

  [ "${status}" -eq 0 ]
  [ -s "${stdout_file}" ]
  [ ! -s "${stderr_file}" ]

  run env -u HOME -u BASH -u RUBYOPT PATH=/missing \
    "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" help
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Devin Desktop Manager"* ]]
}

@test "[PMC-U1-R02] manager targets always execute checkout source" {
  local root="${BATS_TEST_TMPDIR}/checkout"
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local stale_log="${BATS_TEST_TMPDIR}/stale-calls"

  make_fixture "${root}"
  write_recorder "${root}/bin/devin-desktop-manager" checkout
  mkdir -p "$(dirname "${installed}")"
  cat >"${installed}" <<EOF
#!${HARNESS_BASH}
printf 'stale\n' >>'${stale_log}'
EOF
  chmod 0755 "${installed}"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${TEST_HOME}" BASH="${HARNESS_BASH}" status

  [ "${status}" -eq 0 ]
  [ "$(<"${CALL_LOG}")" = "checkout <status>" ]
  [ ! -e "${stale_log}" ]
}

@test "[PMC-U1-R03] invalid Make entry is rejected before mutation" {
  local root="${BATS_TEST_TMPDIR}/checkout"
  local sentinel="${BATS_TEST_TMPDIR}/injected"
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  make_fixture "${root}"
  write_recorder "${root}/bin/devin-desktop-manager" checkout
  write_recorder "${root}/scripts/install-manager" installer
  mkdir -p "$(dirname "${installed}")"
  write_recorder "${installed}" installed

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" unknown
  [ "${status}" -ne 0 ]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" status status
  [ "${status}" -ne 0 ]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" status check
  [ "${status}" -ne 0 ]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    MANAGER="${installed}" status
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"MANAGER"* ]]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="bash; touch ${sentinel}" status
  [ "${status}" -ne 0 ]
  [ ! -e "${sentinel}" ]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BATS="bats; touch ${sentinel}" test
  [ "${status}" -ne 0 ]
  [ ! -e "${sentinel}" ]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    SHELLCHECK="shellcheck; touch ${sentinel}" lint
  [ "${status}" -ne 0 ]
  [ ! -e "${sentinel}" ]
  [ ! -e "${CALL_LOG}" ]

  mkdir -p "${root}/coverage"
  printf 'preserve\n' >"${root}/coverage/.resultset.json"
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASHCOV="bashcov; touch ${sentinel}" coverage
  [ "${status}" -ne 0 ]
  [ ! -e "${sentinel}" ]
  [ "$(<"${root}/coverage/.resultset.json")" = preserve ]
  [ ! -e "${CALL_LOG}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -j -C "${root}" \
    install package
  [ "${status}" -ne 0 ]
  [ ! -e "${CALL_LOG}" ]
}

@test "[PMC-U1-R04] caller paths are data and controls are rejected" {
  local component='space single-'"'"' double-" glob-[*?] dollar-$value subshell-$(touch injected) semi-;pipe-| backtick-`touch injected`'
  local root="${BATS_TEST_TMPDIR}/${component}"
  local home="${BATS_TEST_TMPDIR}/home ${component}"
  local app="${BATS_TEST_TMPDIR}/app ${component}"
  local bats_command="${BATS_TEST_TMPDIR}/bats ${component}"
  local sentinel="${root}/injected"

  make_fixture "${root}"
  write_recorder "${root}/bin/devin-desktop-manager" checkout
  write_recorder "${root}/scripts/install-manager" installer
  write_recorder "${app}" app
  cat >"${bats_command}" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == --version ]]; then
  printf 'Bats 1.14.0\n'
  exit 0
fi
printf '%s' bats >>"\${CALL_LOG}"
printf ' <%s>' "\$@" >>"\${CALL_LOG}"
printf '\n' >>"\${CALL_LOG}"
EOF
  chmod 0755 "${bats_command}"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${home}" BASH="${HARNESS_BASH}" status
  [ "${status}" -eq 0 ]
  [ "$(<"${CALL_LOG}")" = "checkout <status>" ]
  [ ! -e "${sentinel}" ]

  : >"${CALL_LOG}"
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" APP="${app}" app-version
  [ "${status}" -eq 0 ]
  [ "$(<"${CALL_LOG}")" = "app <--version>" ]
  [ ! -e "${sentinel}" ]

  : >"${CALL_LOG}"
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" BATS="${bats_command}" test
  [ "${status}" -eq 0 ]
  [ "$(<"${CALL_LOG}")" = "bats <tests>" ]
  [ ! -e "${sentinel}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH=$'bad\tidentity' status
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"BASH"* ]]
  [[ "${output}" == *"control"* ]]
  [[ "${output}" != *$'\t'* ]]
}

@test "[PMC-U1-R05] APP failures are explicit and help labels every target" {
  local missing="${BATS_TEST_TMPDIR}/missing-app"
  local nonexec="${BATS_TEST_TMPDIR}/nonexec-app"
  local stdout_file="${BATS_TEST_TMPDIR}/stdout"
  local stderr_file="${BATS_TEST_TMPDIR}/stderr"
  local target

  : >"${nonexec}"
  chmod 0644 "${nonexec}"

  for target in "${missing}" "${nonexec}"; do
    run /bin/sh -c '"$1" --no-print-directory -s -C "$2" APP="$3" run \
      >"$4" 2>"$5"' _ "${MAKE_COMMAND}" "${PROJECT_ROOT}" "${target}" \
      "${stdout_file}" "${stderr_file}"
    [ "${status}" -ne 0 ]
    [ ! -s "${stdout_file}" ]
    grep -Fq 'run: error: APP is not an executable file:' "${stderr_file}"
  done

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" help
  [ "${status}" -eq 0 ]
  for target in help install-manager link link-dev install status check update \
    rollback set-defaults doctor run app-version test lint verify package \
    release-check coverage uninstall uninstall-yes clean; do
    [[ "${output}" == *"make ${target}"* ]]
  done
}

@test "project keeps executable manager and release scripts" {
  [ -x "${PROJECT_ROOT}/bin/devin-desktop-manager" ]
  [ -x "${PROJECT_ROOT}/scripts/install-manager" ]
  [ -x "${PROJECT_ROOT}/scripts/check-coverage" ]
  [ -x "${PROJECT_ROOT}/scripts/package-release" ]
  [ -x "${PROJECT_ROOT}/scripts/release-check" ]
}

@test "help exposes install lifecycle quality and release commands" {
  run make --no-print-directory -s -C "${PROJECT_ROOT}" help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"install-manager"* ]]
  [[ "${output}" == *"set-defaults"* ]]
  [[ "${output}" == *"rollback"* ]]
  [[ "${output}" == *"doctor"* ]]
  [[ "${output}" == *"verify"* ]]
  [[ "${output}" == *"package"* ]]
  [[ "${output}" == *"release-check"* ]]
}

@test "coverage target enforces the public repository threshold" {
  grep -Fq 'coverage:' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'COVERAGE_MINIMUM ?= 90' "${PROJECT_ROOT}/Makefile"
  grep -Fq '$(call RUN_PREFLIGHT,release-check)' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'make coverage' "${PROJECT_ROOT}/CONTRIBUTING.md"
  grep -Fq 'minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "90")' \
    "${PROJECT_ROOT}/.simplecov"
}

@test "coverage target rejects a stale result when the runner produces nothing" {
  local coverage_dir="${BATS_TEST_TMPDIR}/coverage"

  mkdir -p "${coverage_dir}"
  cat >"${coverage_dir}/.resultset.json" <<'JSON'
{
  "stale": {
    "coverage": {
      "/project/bin/tool": [1, 1, 1, 1]
    }
  }
}
JSON

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    BASHCOV="${TRUE_COMMAND}" COVERAGE_DIR="${coverage_dir}" \
    COVERAGE_MINIMUM=100 coverage

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"result set is missing"* ]]
}

@test "lifecycle targets forward exactly one command to the manager" {
  local root="${BATS_TEST_TMPDIR}/checkout"
  local target

  make_fixture "${root}"
  cp "${MOCK_MANAGER}" "${root}/bin/devin-desktop-manager"
  for target in status check update rollback set-defaults doctor; do
    run make --no-print-directory -s -C "${root}" BASH="${HARNESS_BASH}" "${target}"
    [ "${status}" -eq 0 ]
  done

  run cat "${CALL_LOG}"
  [ "${status}" -eq 0 ]
  [ "${output}" = $'status\ncheck\nupdate\nrollback\nset-defaults\ndoctor' ]
}

@test "uninstall-yes forwards explicit noninteractive confirmation" {
  local root="${BATS_TEST_TMPDIR}/checkout"

  make_fixture "${root}"
  cp "${MOCK_MANAGER}" "${root}/bin/devin-desktop-manager"
  run make --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" uninstall-yes

  [ "${status}" -eq 0 ]
  run tail -n 1 "${CALL_LOG}"
  [ "${output}" = "uninstall --yes" ]
}

@test "install-manager atomically copies an independent executable" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager

  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
  [ ! -L "${installed}" ]
  [ "$("${installed}" --version)" = "devin-desktop-manager 0.1.0" ]

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
}

@test "install-manager migrates the project development symlink" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  mkdir -p "$(dirname "${installed}")"
  ln -s "${PROJECT_ROOT}/bin/devin-desktop-manager" "${installed}"
  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager

  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
  [ ! -L "${installed}" ]
}

@test "install-manager refuses an unrelated executable" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  mkdir -p "$(dirname "${installed}")"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${installed}"
  chmod 0755 "${installed}"
  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"refusing to replace unrelated path"* ]]
  grep -q 'exit 0' "${installed}"
}

@test "install-manager validates its arguments and source identity" {
  local installer="${PROJECT_ROOT}/scripts/install-manager"
  local destination="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local unrelated="${BATS_TEST_TMPDIR}/unrelated"

  run "${installer}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Usage: install-manager"* ]]

  run "${installer}" "${BATS_TEST_TMPDIR}/missing" "${destination}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"source is not an executable file"* ]]

  printf '#!/usr/bin/env bash\nexit 0\n' >"${unrelated}"
  chmod 0755 "${unrelated}"
  run "${installer}" "${unrelated}" "${destination}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"source does not identify this project"* ]]
}

@test "development link is explicit and resolves to project source" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" link-dev

  [ "${status}" -eq 0 ]
  [ -L "${installed}" ]
  [ "$(readlink -f "${installed}")" = "${PROJECT_ROOT}/bin/devin-desktop-manager" ]
}

@test "[PMC-U4-R03] canonical helper rejects missing inherited lock descriptors" {
  local installer="${PROJECT_ROOT}/scripts/install-manager"
  local destination="${TEST_HOME}/.local/bin/devin-desktop-manager"

  mkdir -p "$(dirname "${destination}")"
  run env HOME="${TEST_HOME}" bash -c 'exec 9>&- 8>&-; exec "$@"' _ \
    "${installer}" --canonical \
    --publication-lock-fd 9 --lifecycle-lock-fd 8 \
    "${PROJECT_ROOT}/bin/devin-desktop-manager" "${destination}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"publication lock descriptor"* ]]
  [ ! -e "${destination}" ]
}

@test "[PMC-U4-R01] invalid canonical HOME fails before lock or manager publication" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  run env -u HOME make --no-print-directory -s -C "${PROJECT_ROOT}" install-manager

  [ "${status}" -ne 0 ]
  [ ! -e "${installed}" ]
  [ ! -e "${TEST_HOME}/.local/bin/.devin-desktop-manager.publication.lock" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager.lock" ]

  mkdir -p "$(dirname "${installed}")"
  printf 'caller-owned\n' >"${installed}"
  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  [ "${status}" -ne 0 ]
  [ "$(cat "${installed}")" = caller-owned ]
  [ ! -e "${TEST_HOME}/.local/bin/.devin-desktop-manager.publication.lock" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager.lock" ]
}

@test "[PMC-U4-R02] current lifecycle contention blocks publication before replacement" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local lifecycle_lock="${TEST_HOME}/.local/state/devin-desktop-manager.lock"
  local ready="${BATS_TEST_TMPDIR}/lifecycle.ready"
  local release="${BATS_TEST_TMPDIR}/lifecycle.release"
  local holder

  mkdir -p "$(dirname "${installed}")" "$(dirname "${lifecycle_lock}")"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" "${installed}"
  printf 'preserve-current-manager\n' >>"${installed}"
  (
    exec 8<>"${lifecycle_lock}"
    flock -n 8
    : >"${ready}"
    while [[ ! -e "${release}" ]]; do read -r -t 0.05 _ || true; done
  ) </dev/null &
  holder=$!
  for _ in {1..200}; do [[ -e "${ready}" ]] && break; read -r -t 0.05 _ || true; done
  [ -e "${ready}" ]

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  : >"${release}"
  wait "${holder}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"manager lifecycle operation is active"* ]]
  grep -Fq preserve-current-manager "${installed}"
}

@test "[PMC-U4-R02] unsafe legacy lock objects fail bounded before publication" {
  local root="${BATS_TEST_TMPDIR}/unsafe-legacy-checkout"
  local legacy_root="${TEST_HOME}/.local/opt/devin-desktop"
  local legacy_lock="${legacy_root}/.manager.lock"
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local external="${BATS_TEST_TMPDIR}/external-lock"
  local ready="${BATS_TEST_TMPDIR}/external.ready"
  local release="${BATS_TEST_TMPDIR}/external.release"
  local holder

  make_fixture "${root}"
  cat >"${root}/bin/devin-desktop-manager" <<'EOF'
#!/usr/bin/env bash
readonly MANAGER_ID="io.github.newbpydev.devin-desktop-manager"
if [[ "${1:-}" == internal-preflight ]]; then
  printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 0
  exit 0
fi
exit 0
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager"
  mkdir -p "${legacy_root}"

  mkfifo "${legacy_lock}"
  run "${TIMEOUT_COMMAND}" --signal=TERM --kill-after=1s 5s \
    "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${TEST_HOME}" install
  [ "${status}" -ne 0 ]
  [ "${status}" -ne 124 ]
  [[ "${output}" == *"unsafe manager lock path"* ]]
  [ ! -e "${installed}" ]

  rm -f "${legacy_lock}"
  : >"${external}"
  (
    exec 7<>"${external}"
    flock -n 7
    : >"${ready}"
    while [[ ! -e "${release}" ]]; do read -r -t 0.05 _ || true; done
  ) </dev/null &
  holder=$!
  for _ in {1..200}; do [[ -e "${ready}" ]] && break; read -r -t 0.05 _ || true; done
  [ -e "${ready}" ]
  ln -s "${external}" "${legacy_lock}"

  run "${TIMEOUT_COMMAND}" --signal=TERM --kill-after=1s 5s \
    "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${TEST_HOME}" install
  : >"${release}"
  wait "${holder}"
  [ "${status}" -ne 0 ]
  [ "${status}" -ne 124 ]
  [[ "${output}" == *"unsafe manager lock path"* ]]
  [[ "${output}" != *"operation is active"* ]]
  [ ! -e "${installed}" ]
}

@test "[PMC-U3-R04] manager publication lock tools fail before canonical state" {
  local root="${BATS_TEST_TMPDIR}/lock-tool-checkout"
  local shim_bin="${BATS_TEST_TMPDIR}/lock-tool-bin"
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  make_fixture "${root}"
  mkdir -p "${shim_bin}"
  cat >"${shim_bin}/flock" <<'EOF'
#!/usr/bin/env bash
printf 'not util-linux\n'
exit 0
EOF
  chmod 0755 "${shim_bin}/flock"

  run env PATH="${shim_bin}:${PATH}" "${MAKE_COMMAND}" --no-print-directory -s \
    -C "${root}" HOME="${TEST_HOME}" install-manager

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"command.flock"* ]]
  [[ "${output}" == *"incompatible command"* ]]
  [ ! -e "${installed}" ]
  [ ! -e "${TEST_HOME}/.local/bin" ]
  [ ! -e "${TEST_HOME}/.local/state" ]
  grep -Fq "[manager-publication-lock]='manager-publication-lock-local'" \
    "${root}/scripts/preflight"

  run env PATH="${shim_bin}:${PATH}" "${root}/scripts/install-manager" \
    "${root}/bin/devin-desktop-manager" "${BATS_TEST_TMPDIR}/custom-manager"
  [ "${status}" -eq 0 ]
}

@test "[PMC-U4-R04] direct custom helper publication remains caller-owned" {
  local destination="${BATS_TEST_TMPDIR}/custom/manager"

  mkdir -p "$(dirname "${destination}")"
  run "${PROJECT_ROOT}/scripts/install-manager" \
    "${PROJECT_ROOT}/bin/devin-desktop-manager" "${destination}"
  [ "${status}" -eq 0 ]
  [ -x "${destination}" ]

  run env HOME="${TEST_HOME}" "${PROJECT_ROOT}/scripts/install-manager" --link \
    "${PROJECT_ROOT}/bin/devin-desktop-manager" "${destination}"
  [ "${status}" -eq 0 ]
  [ -L "${destination}" ]
  [ ! -e "${TEST_HOME}/.local/bin/.devin-desktop-manager.publication.lock" ]
}

@test "[PMC-U4-R08] busy canonical publication lock preserves the manager" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local publication_lock="${TEST_HOME}/.local/bin/.devin-desktop-manager.publication.lock"
  local ready="${BATS_TEST_TMPDIR}/publication.ready"
  local release="${BATS_TEST_TMPDIR}/publication.release"
  local holder

  mkdir -p "$(dirname "${installed}")"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" "${installed}"
  printf 'sentinel\n' >>"${installed}"
  (
    exec 9<>"${publication_lock}"
    flock -n 9
    : >"${ready}"
    while [[ ! -e "${release}" ]]; do read -r -t 0.05 _ || true; done
  ) </dev/null &
  holder=$!
  for _ in {1..200}; do [[ -e "${ready}" ]] && break; read -r -t 0.05 _ || true; done
  [ -e "${ready}" ]

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  : >"${release}"
  wait "${holder}"

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"another manager publication operation is active"* ]]
  [[ "${output}" == *"do not delete"* ]]
  grep -Fq sentinel "${installed}"
}

@test "[PMC-U4-R07] partial install reports resumable manager-only state" {
  local root="${BATS_TEST_TMPDIR}/partial-checkout"
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  make_fixture "${root}"
  cat >"${root}/bin/devin-desktop-manager" <<'EOF'
#!/usr/bin/env bash
readonly MANAGER_ID="io.github.newbpydev.devin-desktop-manager"
if [[ "${1:-}" == internal-preflight ]]; then
  printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 0
  exit 0
fi
while [[ "${1:-}" == --*-lock-fd ]]; do shift 2; done
[[ -e "${HOME}/succeed" ]] || exit 42
exit 0
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager"

  run make --no-print-directory -s -C "${root}" HOME="${TEST_HOME}" install
  [ "${status}" -ne 0 ]
  [ -x "${installed}" ]
  [[ "${output}" == *"manager installation succeeded, but application installation did not"* ]]
  [[ "${output}" == *"rerun make install to resume"* ]]

  : >"${TEST_HOME}/succeed"
  run make --no-print-directory -s -C "${root}" HOME="${TEST_HOME}" install
  [ "${status}" -eq 0 ]
}

@test "package output is byte-for-byte deterministic" {
  local first="${BATS_TEST_TMPDIR}/first"
  local second="${BATS_TEST_TMPDIR}/second"

  run "${PROJECT_ROOT}/scripts/package-release" 0.1.0 "${first}"
  [ "${status}" -eq 0 ]
  run "${PROJECT_ROOT}/scripts/package-release" 0.1.0 "${second}"
  [ "${status}" -eq 0 ]

  cmp "${first}/devin-desktop-manager-0.1.0.tar.gz" \
    "${second}/devin-desktop-manager-0.1.0.tar.gz"
  cmp "${first}/SHA256SUMS" "${second}/SHA256SUMS"
  tar -tzf "${first}/devin-desktop-manager-0.1.0.tar.gz" \
    >"${BATS_TEST_TMPDIR}/archive-contents"
  grep -qx 'devin-desktop-manager-0.1.0/bin/devin-desktop-manager' \
    "${BATS_TEST_TMPDIR}/archive-contents"
}

@test "package excludes untracked files once the repository has a commit" {
  local repository="${BATS_TEST_TMPDIR}/repository"
  local dist_dir="${BATS_TEST_TMPDIR}/dist"

  mkdir -p "${repository}/scripts"
  cp "${PROJECT_ROOT}/scripts/package-release" "${repository}/scripts/package-release"
  cp "${PROJECT_ROOT}/scripts/preflight" "${repository}/scripts/preflight"
  chmod 0755 "${repository}/scripts/package-release"
  printf 'tracked\n' >"${repository}/README.md"
  git -C "${repository}" init --quiet
  git -C "${repository}" add scripts/package-release README.md
  git -C "${repository}" \
    -c user.name='Test User' \
    -c user.email='test@example.invalid' \
    commit --quiet -m 'test fixture'
  printf 'must not ship\n' >"${repository}/untracked-secret.txt"

  run "${repository}/scripts/package-release" 0.1.0 "${dist_dir}"

  [ "${status}" -eq 0 ]
  run tar -tzf "${dist_dir}/devin-desktop-manager-0.1.0.tar.gz"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"devin-desktop-manager-0.1.0/README.md"* ]]
  [[ "${output}" != *"untracked-secret.txt"* ]]
}

@test "package-release rejects usage version and empty repository errors" {
  local packager="${PROJECT_ROOT}/scripts/package-release"
  local repository="${BATS_TEST_TMPDIR}/empty-repository"
  local dist_dir="${BATS_TEST_TMPDIR}/empty-dist"

  run "${packager}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Usage: package-release"* ]]

  run "${packager}" latest "${dist_dir}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"invalid release version"* ]]

  mkdir -p "${repository}/scripts"
  cp "${packager}" "${repository}/scripts/package-release"
  git -C "${repository}" init --quiet
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet --allow-empty -m empty
  run "${repository}/scripts/package-release" 0.1.0 "${dist_dir}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"no repository files found"* ]]
}
