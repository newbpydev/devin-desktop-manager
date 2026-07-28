#!/usr/bin/env bats

set -e

load helpers/portable

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

  resolve_harness_tools bash chmod cmp cp env find flock git make mkdir mv readlink rm sha256sum sleep stat tar timeout true
  MAKE_COMMAND="${HARNESS_TOOLS[make]}"
  HARNESS_BASH="${HARNESS_TOOLS[bash]}"
  TRUE_COMMAND="${HARNESS_TOOLS[true]}"
  TIMEOUT_COMMAND="${HARNESS_TOOLS[timeout]}"
}

make_fixture() {
  local root="$1"

  mkdir -p "${root}/bin" "${root}/scripts/lib"
  cp "${PROJECT_ROOT}/Makefile" "${root}/Makefile"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" \
    "${root}/bin/devin-desktop-manager"
  cp "${PROJECT_ROOT}/scripts/install-manager" \
    "${root}/scripts/install-manager"
  if [[ -f "${PROJECT_ROOT}/scripts/preflight" ]]; then
    cp "${PROJECT_ROOT}/scripts/preflight" "${root}/scripts/preflight"
  fi
  if [[ -f "${PROJECT_ROOT}/scripts/run-coverage" ]]; then
    cp "${PROJECT_ROOT}/scripts/run-coverage" "${PROJECT_ROOT}/scripts/output-lock" \
      "${PROJECT_ROOT}/scripts/check-coverage" "${root}/scripts/"
    cp "${PROJECT_ROOT}/scripts/lib/coverage-output.bash" "${root}/scripts/lib/"
  fi
  if [[ -f "${PROJECT_ROOT}/scripts/clean-generated" ]]; then
    cp "${PROJECT_ROOT}/scripts/clean-generated" "${root}/scripts/"
    cp "${PROJECT_ROOT}/scripts/lib/package-output.bash" "${root}/scripts/lib/"
  fi
}

make_package_fixture() {
  local root="$1"
  mkdir -p "${root}/bin" "${root}/scripts/lib"
  cp "${PROJECT_ROOT}/Makefile" "${root}/Makefile"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" "${root}/bin/"
  cp "${PROJECT_ROOT}/scripts/package-release" "${PROJECT_ROOT}/scripts/preflight" \
    "${PROJECT_ROOT}/scripts/output-lock" "${root}/scripts/"
  cp "${PROJECT_ROOT}/scripts/lib/package-output.bash" "${root}/scripts/lib/"
  printf '/dist*/\n/.devin-desktop-manager.outputs.lock\n' >"${root}/.gitignore"
  printf 'tracked\n' >"${root}/README.md"
  git -C "${root}" init --quiet
  git -C "${root}" add .
  git -C "${root}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet -m fixture
}

run_locked_package_fixture() {
  local root="$1" lock="${1}/.devin-desktop-manager.outputs.lock"
  shift
  : >"${lock}"
  run "${HARNESS_BASH}" -c 'exec 6<>"$1"; flock -n 6; shift; exec "$@"' \
    _ "${lock}" "${root}/scripts/package-release" --project-root "${root}" \
    --output-lock-fd 6 "$@"
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
  local app target

  : >"${nonexec}"
  chmod 0644 "${nonexec}"

  for app in "${missing}" "${nonexec}"; do
    for target in run app-version; do
      run /bin/sh -c '"$1" --no-print-directory -s -C "$2" APP="$3" "$6" \
        >"$4" 2>"$5"' _ "${MAKE_COMMAND}" "${PROJECT_ROOT}" "${app}" \
        "${stdout_file}" "${stderr_file}" "${target}"
      [ "${status}" -ne 0 ]
      [ ! -s "${stdout_file}" ]
      grep -Fq "${target}: error: APP is not an executable file:" "${stderr_file}"
    done
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
  [ -x "${PROJECT_ROOT}/scripts/run-coverage" ]
  [ -x "${PROJECT_ROOT}/scripts/package-release" ]
  [ -x "${PROJECT_ROOT}/scripts/release-check" ]
}

@test "help exposes install lifecycle quality and release commands" {
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"install-manager"* ]]
  [[ "${output}" == *"set-defaults"* ]]
  [[ "${output}" == *"rollback"* ]]
  [[ "${output}" == *"doctor"* ]]
  [[ "${output}" == *"verify"* ]]
  [[ "${output}" == *"package"* ]]
  [[ "${output}" == *"release-check"* ]]
}

@test "[PMC-U5-C01] coverage target enforces the public repository threshold" {
  local default_profile official_profile union_preflight locked_coverage
  grep -Fq 'coverage:' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'COVERAGE_MINIMUM ?= 90' "${PROJECT_ROOT}/Makefile"
  default_profile="$(grep -nF 'preflight_profile=release-check;' "${PROJECT_ROOT}/Makefile")"
  official_profile="$(grep -nF 'preflight_profile=release-check-official;' "${PROJECT_ROOT}/Makefile")"
  union_preflight="$(grep -nF '$(call RUN_PREFLIGHT,$$preflight_profile);' "${PROJECT_ROOT}/Makefile")"
  locked_coverage="$(grep -nF '$(DO_LOCKED_COVERAGE);' "${PROJECT_ROOT}/Makefile")"
  [ "${default_profile%%:*}" -lt "${official_profile%%:*}" ]
  [ "${official_profile%%:*}" -lt "${union_preflight%%:*}" ]
  [ "${union_preflight%%:*}" -lt "${locked_coverage%%:*}" ]
  [ "$(grep -Fc '$(DO_LOCKED_COVERAGE)' "${PROJECT_ROOT}/Makefile")" -eq 2 ]
  grep -Fq 'make coverage' "${PROJECT_ROOT}/CONTRIBUTING.md"
  run grep -F 'minimum_coverage' "${PROJECT_ROOT}/.simplecov"
  [ "${status}" -ne 0 ]
  grep -Fq 'scripts/run-coverage' "${PROJECT_ROOT}/Makefile"
}

@test "[PMC-U5-C01] coverage target rejects a stale result when the runner produces nothing" {
  local root="${BATS_TEST_TMPDIR}/checkout" coverage_dir="${BATS_TEST_TMPDIR}/checkout/coverage"
  local bashcov="${BATS_TEST_TMPDIR}/bashcov-no-output"
  local bats="${BATS_TEST_TMPDIR}/bats-ok"

  make_fixture "${root}"
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
  cat >"${bashcov}" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == --version ]]; then printf 'bashcov 3.3.0\n'; fi
EOF
  chmod 0755 "${bashcov}"
  cat >"${bats}" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == --version ]]; then printf 'Bats 1.14.0\n'; fi
EOF
  chmod 0755 "${bats}"
  cat >"${BATS_TEST_TMPDIR}/bundle" <<EOF
#!${HARNESS_BASH}
printf 'Bundler version 2.4.20\n'
EOF
  cat >"${BATS_TEST_TMPDIR}/ruby" <<EOF
#!${HARNESS_BASH}
printf 'ruby 3.2.0\n'
EOF
  chmod 0755 "${BATS_TEST_TMPDIR}/bundle" "${BATS_TEST_TMPDIR}/ruby"

  run env PATH="${BATS_TEST_TMPDIR}:${PATH}" "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" BATS="${bats}" BASHCOV="${bashcov}" COVERAGE_DIR=coverage \
    COVERAGE_MINIMUM=100 coverage

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"result set is missing"* || "${output}" == *"coverage validation failed"* ]]
}

@test "lifecycle targets forward exactly one command to the manager" {
  local root="${BATS_TEST_TMPDIR}/checkout"
  local target

  make_fixture "${root}"
  cp "${MOCK_MANAGER}" "${root}/bin/devin-desktop-manager"
  for target in status check update rollback set-defaults doctor; do
    run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
      BASH="${HARNESS_BASH}" "${target}"
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
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" uninstall-yes

  [ "${status}" -eq 0 ]
  run tail -n 1 "${CALL_LOG}"
  [ "${output}" = "uninstall --yes" ]
}

@test "install-manager atomically copies an independent executable" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager

  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
  [ ! -L "${installed}" ]
  [ "$("${installed}" --version)" = "devin-desktop-manager 0.1.0" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
}

@test "install-manager migrates the project development symlink" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  mkdir -p "$(dirname "${installed}")"
  ln -s "${PROJECT_ROOT}/bin/devin-desktop-manager" "${installed}"
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
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
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
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

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
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

  run "${HARNESS_TOOLS[env]}" -u HOME "${MAKE_COMMAND}" \
    --no-print-directory -s -C "${PROJECT_ROOT}" install-manager

  [ "${status}" -ne 0 ]
  [ ! -e "${installed}" ]
  [ ! -e "${TEST_HOME}/.local/bin/.devin-desktop-manager.publication.lock" ]
  [ ! -e "${TEST_HOME}/.local/state/devin-desktop-manager.lock" ]

  mkdir -p "$(dirname "${installed}")"
  printf 'caller-owned\n' >"${installed}"
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
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
  wait_for_ready "${ready}"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  release_barrier "${release}"
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
  wait_for_ready "${ready}"
  ln -s "${external}" "${legacy_lock}"

  run "${TIMEOUT_COMMAND}" --signal=TERM --kill-after=1s 5s \
    "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${TEST_HOME}" install
  release_barrier "${release}"
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
  wait_for_ready "${ready}"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" install-manager
  release_barrier "${release}"
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

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${TEST_HOME}" install
  [ "${status}" -ne 0 ]
  [ -x "${installed}" ]
  [[ "${output}" == *"manager installation succeeded, but application installation did not"* ]]
  [[ "${output}" == *"rerun make install to resume"* ]]

  : >"${TEST_HOME}/succeed"
  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    HOME="${TEST_HOME}" install
  [ "${status}" -eq 0 ]
}

@test "[PMC-U6-C01] package output is byte-for-byte deterministic" {
  local repository="${BATS_TEST_TMPDIR}/repository"
  local first="${repository}/first" second="${repository}/second"
  make_package_fixture "${repository}"

  run_locked_package_fixture "${repository}" 0.1.0 first
  [ "${status}" -eq 0 ]
  run_locked_package_fixture "${repository}" 0.1.0 second
  [ "${status}" -eq 0 ]

  cmp "${first}/devin-desktop-manager-0.1.0.tar.gz" \
    "${second}/devin-desktop-manager-0.1.0.tar.gz"
  cmp "${first}/SHA256SUMS" "${second}/SHA256SUMS"
  tar -tzf "${first}/devin-desktop-manager-0.1.0.tar.gz" \
    >"${BATS_TEST_TMPDIR}/archive-contents"
  grep -qx 'devin-desktop-manager-0.1.0/bin/devin-desktop-manager' \
    "${BATS_TEST_TMPDIR}/archive-contents"
}

@test "[PMC-U6-C01] package uses tracked working-tree bytes and excludes untracked files" {
  local repository="${BATS_TEST_TMPDIR}/repository"
  local dist_dir="${repository}/dist"

  mkdir -p "${repository}/scripts/lib"
  cp "${PROJECT_ROOT}/scripts/package-release" "${repository}/scripts/package-release"
  cp "${PROJECT_ROOT}/scripts/preflight" "${repository}/scripts/preflight"
  cp "${PROJECT_ROOT}/scripts/output-lock" "${repository}/scripts/output-lock"
  cp "${PROJECT_ROOT}/scripts/lib/package-output.bash" "${repository}/scripts/lib/package-output.bash"
  chmod 0755 "${repository}/scripts/package-release"
  printf 'tracked\n' >"${repository}/README.md"
  git -C "${repository}" init --quiet
  git -C "${repository}" add scripts/package-release README.md
  git -C "${repository}" \
    -c user.name='Test User' \
    -c user.email='test@example.invalid' \
    commit --quiet -m 'test fixture'
  printf 'must not ship\n' >"${repository}/untracked-secret.txt"
  printf 'dirty tracked\n' >"${repository}/README.md"

  run_locked_package_fixture "${repository}" 0.1.0 dist

  [ "${status}" -eq 0 ]
  run tar -tzf "${dist_dir}/devin-desktop-manager-0.1.0.tar.gz"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"devin-desktop-manager-0.1.0/README.md"* ]]
  [[ "${output}" != *"untracked-secret.txt"* ]]
  run tar -xOzf "${dist_dir}/devin-desktop-manager-0.1.0.tar.gz" \
    devin-desktop-manager-0.1.0/README.md
  [ "${status}" -eq 0 ]
  [ "${output}" = "dirty tracked" ]
}

@test "[PMC-U6-R01] package-release rejects usage version and empty repository errors" {
  local packager="${PROJECT_ROOT}/scripts/package-release"
  local repository="${BATS_TEST_TMPDIR}/empty-repository"
  local dist_dir="${BATS_TEST_TMPDIR}/empty-dist"

  run "${packager}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Usage: package-release"* ]]

  run "${packager}" --output-lock-fd 6 latest dist
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"invalid release version"* ]]

  mkdir -p "${repository}/scripts/lib"
  cp "${packager}" "${repository}/scripts/package-release"
  cp "${PROJECT_ROOT}/scripts/preflight" "${repository}/scripts/preflight"
  cp "${PROJECT_ROOT}/scripts/output-lock" "${repository}/scripts/output-lock"
  cp "${PROJECT_ROOT}/scripts/lib/package-output.bash" "${repository}/scripts/lib/package-output.bash"
  git -C "${repository}" init --quiet
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet --allow-empty -m empty
  run_locked_package_fixture "${repository}" 0.1.0 dist
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"no repository files found"* ]]
}

@test "[PMC-U6-R01] package requires its exact Git root and contained output before mutation" {
  local repository="${BATS_TEST_TMPDIR}/repository" extracted="${BATS_TEST_TMPDIR}/extracted"
  local outside="${BATS_TEST_TMPDIR}/outside" nested="${BATS_TEST_TMPDIR}/parent/child"

  mkdir -p "${repository}/scripts/lib" "${extracted}/scripts/lib" "${nested}/scripts/lib"
  for root in "${repository}" "${extracted}" "${nested}"; do
    cp "${PROJECT_ROOT}/scripts/package-release" "${root}/scripts/package-release"
    cp "${PROJECT_ROOT}/scripts/preflight" "${root}/scripts/preflight"
    cp "${PROJECT_ROOT}/scripts/output-lock" "${root}/scripts/output-lock"
    [[ ! -f "${PROJECT_ROOT}/scripts/lib/package-output.bash" ]] || \
      cp "${PROJECT_ROOT}/scripts/lib/package-output.bash" "${root}/scripts/lib/"
    printf 'tracked\n' >"${root}/README.md"
  done
  git -C "${repository}" init --quiet
  git -C "${repository}" add .
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet -m fixture

  run_locked_package_fixture "${repository}" 0.1.0 dist
  [ "${status}" -eq 0 ]
  [ -f "${repository}/dist/SHA256SUMS" ]

  run_locked_package_fixture "${extracted}" 0.1.0 dist
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"exact Git root"* ]]
  [ ! -e "${extracted}/dist" ]

  git -C "${BATS_TEST_TMPDIR}/parent" init --quiet
  run_locked_package_fixture "${nested}" 0.1.0 dist
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"exact Git root"* ]]
  [ ! -e "${nested}/dist" ]

  run_locked_package_fixture "${repository}" 0.1.0 "${outside}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"OUTPUT_DIRECTORY"* ]]
  [[ "${output}" == *"project-relative"* ]]
  [ ! -e "${outside}" ]
}

@test "[PMC-U6-R05] release-check runs one union preflight lint coverage contract and package" {
  local root="${BATS_TEST_TMPDIR}/release-routing" log="${BATS_TEST_TMPDIR}/release-routing.log"
  local shim_bin="${BATS_TEST_TMPDIR}/release-bin"
  mkdir -p "${root}/bin" "${root}/scripts" "${shim_bin}"
  cp "${PROJECT_ROOT}/Makefile" "${root}/Makefile"
  cat >"${root}/bin/devin-desktop-manager" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"${root}/scripts/preflight" <<EOF
#!/usr/bin/env bash
printf 'preflight <%s>\n' "\$*" >>$(printf '%q' "${log}")
EOF
  cat >"${root}/scripts/output-lock" <<EOF
#!/usr/bin/env bash
printf 'output-lock <%s>\n' "\$*" >>$(printf '%q' "${log}")
root=\$1; shift 2; helper=\$1; shift
exec "\$helper" --output-lock-fd 6 "\$@"
EOF
  cat >"${root}/scripts/run-coverage" <<EOF
#!/usr/bin/env bash
printf 'coverage <%s>\n' "\$*" >>$(printf '%q' "${log}")
EOF
  cat >"${root}/scripts/release-check" <<EOF
#!/usr/bin/env bash
printf 'contract <%s>\n' "\$*" >>$(printf '%q' "${log}")
EOF
  cat >"${root}/scripts/package-release" <<EOF
#!/usr/bin/env bash
printf 'package <%s>\n' "\$*" >>$(printf '%q' "${log}")
EOF
  cat >"${shim_bin}/shellcheck" <<EOF
#!/usr/bin/env bash
[[ "\${1:-}" != --version ]] || { printf 'ShellCheck - shell script analysis tool\nversion: 0.10.0\n'; exit 0; }
printf 'lint\n' >>$(printf '%q' "${log}")
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager" "${root}/scripts/"* \
    "${shim_bin}/shellcheck"

  run env PATH="${shim_bin}:${PATH}" "${MAKE_COMMAND}" --no-print-directory -s \
    -C "${root}" BASH="${HARNESS_BASH}" SHELLCHECK="${shim_bin}/shellcheck" \
    DIST_DIR=dist release-check
  [ "${status}" -eq 0 ]
  [ "$(grep -c '^preflight <release-check --project-root ' "${log}")" -eq 1 ]
  [ "$(grep -c '^lint$' "${log}")" -eq 1 ]
  [ "$(grep -c '^coverage ' "${log}")" -eq 1 ]
  [ "$(grep -c '^contract ' "${log}")" -eq 1 ]
  [ "$(grep -c '^package ' "${log}")" -eq 1 ]
  grep -Fq "coverage <--output-lock-fd 6 --project-root ${root}>" "${log}"
  grep -Fq "contract <--project-root ${root} 0.1.0>" "${log}"
  grep -Fq "package <--output-lock-fd 6 --project-root ${root} 0.1.0 dist>" "${log}"
  run grep -F 'tests' "${log}"
  [ "${status}" -eq 1 ]
}

@test "[PMC-U7-R01] clean removes validated outputs and repeats as a no-op" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout"
  make_clean_checkout "${root}"
  make_coverage_tree "${root}/coverage"
  printf 'asset\n' >"${root}/coverage/assets/report.css"
  make_package_pair "${root}/dist" devin-desktop-manager-0.1.0.tar.gz

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" clean
  [ "${status}" -eq 0 ]
  [ ! -e "${root}/coverage" ]
  [ ! -e "${root}/dist" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" clean
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" COVERAGE_DIR=generated/reports/coverage \
    DIST_DIR=generated/releases/dist clean
  [ "${status}" -eq 0 ]
  [ ! -e "${root}/generated" ]
}

@test "[PMC-U7-R02] one unsafe domain leaves both output domains byte-identical" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout"
  make_clean_checkout "${root}"
  make_coverage_tree "${root}/coverage"
  make_package_pair "${root}/dist" devin-desktop-manager-0.1.0.tar.gz
  printf 'corrupt\n' >>"${root}/dist/devin-desktop-manager-0.1.0.tar.gz"
  snapshot_tree "${root}/coverage" "${BATS_TEST_TMPDIR}/coverage-before"
  snapshot_tree "${root}/dist" "${BATS_TEST_TMPDIR}/dist-before"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" clean
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"coverage and dist were unchanged"* ]]
  snapshot_tree "${root}/coverage" "${BATS_TEST_TMPDIR}/coverage-after"
  snapshot_tree "${root}/dist" "${BATS_TEST_TMPDIR}/dist-after"
  cmp "${BATS_TEST_TMPDIR}/coverage-before" "${BATS_TEST_TMPDIR}/coverage-after"
  cmp "${BATS_TEST_TMPDIR}/dist-before" "${BATS_TEST_TMPDIR}/dist-after"
}

@test "[PMC-U7-R03] clean preserves unknown dist regular siblings" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout"
  make_clean_checkout "${root}"
  make_package_pair "${root}/dist" devin-desktop-manager-0.1.0.tar.gz
  printf 'foreign\n' >"${root}/dist/keep.txt"
  printf 'older unrelated\n' >"${root}/dist/other-0.0.1.zip"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" clean
  [ "${status}" -eq 0 ]
  [ "$(<"${root}/dist/keep.txt")" = foreign ]
  [ "$(<"${root}/dist/other-0.0.1.zip")" = "older unrelated" ]
  [ ! -e "${root}/dist/SHA256SUMS" ]
  [ ! -e "${root}/dist/devin-desktop-manager-0.1.0.tar.gz" ]
}

@test "[PMC-U7-R05] clean fails fast on output contention and succeeds on retry" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout" ready="${BATS_TEST_TMPDIR}/ready"
  local continue="${BATS_TEST_TMPDIR}/continue" holder
  make_clean_checkout "${root}"
  make_coverage_tree "${root}/coverage"
  : >"${root}/.devin-desktop-manager.outputs.lock"
  "${HARNESS_BASH}" -c 'exec 6<>"$1"; flock 6; : >"$2"; while [[ ! -e "$3" ]]; do sleep 0.05; done' \
    _ "${root}/.devin-desktop-manager.outputs.lock" "${ready}" "${continue}" &
  holder=$!
  wait_for_ready "${ready}"

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" clean
  release_barrier "${continue}"
  wait "${holder}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"held by another output operation"* ]]
  [ -d "${root}/coverage" ]

  run "${MAKE_COMMAND}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" clean
  [ "${status}" -eq 0 ]
  [ ! -e "${root}/coverage" ]
}
