#!/usr/bin/env bats

set -e

load helpers/portable

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  PREFLIGHT="${PROJECT_ROOT}/scripts/preflight"
  FIXTURE_BUILDER="${PROJECT_ROOT}/tests/fixtures/build-mini-deb"
  resolve_harness_tools bash chmod find make mkdir mv readlink rm script sha256sum sleep stat true
  HARNESS_BASH="${HARNESS_TOOLS[bash]}"
  HARNESS_MAKE="${HARNESS_TOOLS[make]}"
}

make_sparse_bin() {
  local bin="${BATS_TEST_TMPDIR}/sparse-bin" name
  mkdir -p "${bin}"
  for name in "$@"; do
    ln -s "$(type -P -- "${name}")" "${bin}/${name}"
  done
  printf '%s\n' "${bin}"
}

@test "[PMC-U3-R01] profiles are centralized root-scoped keys and ordered unions" {
  local profile

  for profile in install-manager check-coverage fixture-mini-deb; do
    run "${HARNESS_BASH}" "${PREFLIGHT}" "${profile}"
    [ "${status}" -ne 2 ]
  done

  for profile in test lint verify package release-contract release-contract-official \
    release-check release-check-official manager-status; do
    run "${HARNESS_BASH}" "${PREFLIGHT}" "${profile}"
    [ "${status}" -eq 2 ]
    [[ "${output}" == *"--project-root"* ]]
  done

  grep -Fq 'preflight" install-manager' "${PROJECT_ROOT}/scripts/install-manager"
  grep -Fq 'preflight" check-coverage' "${PROJECT_ROOT}/scripts/check-coverage"
  grep -Fq "[package-run]='exact-git-root-local package-local package-output-local output-lock'" \
    "${PROJECT_ROOT}/scripts/preflight"
  grep -Fq "[release-contract]='exact-git-root-local release-contract-local'" \
    "${PROJECT_ROOT}/scripts/preflight"
  grep -Fq "[release-contract-official]='release-contract release-handoff-local'" \
    "${PROJECT_ROOT}/scripts/preflight"
  grep -Fq 'preflight" fixture-mini-deb' "${FIXTURE_BUILDER}"
}

@test "[PMC-U3-R02] sparse SUT PATH aggregates while resolved harness tools remain usable" {
  local sparse stdout_file stderr_file
  sparse="$(make_sparse_bin sh)"
  stdout_file="${BATS_TEST_TMPDIR}/stdout"
  stderr_file="${BATS_TEST_TMPDIR}/stderr"

  run env PATH="${sparse}" PREFLIGHT_BATS=bats PREFLIGHT_SHELLCHECK=shellcheck \
    "${HARNESS_BASH}" "${PREFLIGHT}" verify --project-root "${PROJECT_ROOT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"command.bats"* ]]
  [[ "${output}" == *"command.shellcheck"* ]]
  "${HARNESS_TOOLS[true]}"
  : >"${stdout_file}"
  : >"${stderr_file}"
  [ -f "${stdout_file}" ]
  [ -f "${stderr_file}" ]
}

@test "[PMC-U3-R03] incompatible versions and fixture modes fail before output mutation" {
  local shim_bin="${BATS_TEST_TMPDIR}/shim-bin" output="${BATS_TEST_TMPDIR}/fixture.deb"
  mkdir -p "${shim_bin}"
  cat >"${shim_bin}/bats" <<'EOF'
#!/usr/bin/env bash
printf 'Bats 1.3.0\n'
EOF
  chmod 0755 "${shim_bin}/bats"

  run env PATH="${shim_bin}" PREFLIGHT_BATS=bats \
    "${HARNESS_BASH}" "${PREFLIGHT}" test --project-root "${PROJECT_ROOT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Bats 1.4"*"incompatible"* ]]

  run "${FIXTURE_BUILDER}" "${output}" unknown-mode
  [ "${status}" -eq 2 ]
  [ ! -e "${output}" ]
  [[ "${output}" == *"safe|unsafe-symlink|unsafe-hardlink|control-no-dot"* ]]
}

@test "[PMC-U3-R03] absolute executable controls are rejected before execution" {
  local shim="${BATS_TEST_TMPDIR}/bats"$'\t'"control"
  local printable_shim="${BATS_TEST_TMPDIR}/printable bats"
  local marker="${BATS_TEST_TMPDIR}/executed"
  cat >"${printable_shim}" <<EOF
#!${HARNESS_BASH}
printf 'Bats 1.14.0\n'
EOF
  cat >"${shim}" <<EOF
#!${HARNESS_BASH}
: >$(printf '%q' "${marker}")
printf 'Bats 1.14.0\n'
EOF
  chmod 0755 "${printable_shim}" "${shim}"

  run env PREFLIGHT_BATS="${printable_shim}" \
    "${HARNESS_BASH}" "${PREFLIGHT}" test --project-root "${PROJECT_ROOT}"
  [ "${status}" -eq 0 ]

  run env PREFLIGHT_BATS="${shim}" \
    "${HARNESS_BASH}" "${PREFLIGHT}" test --project-root "${PROJECT_ROOT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"command.bats"*"control"* ]]
  [[ "${output}" == *'bats\tcontrol'* ]]
  [ ! -e "${marker}" ]
}

@test "[PMC-U3-R03] manager protocol uses selected Bash when PATH Bash is unusable" {
  local root="${BATS_TEST_TMPDIR}/checkout" shim_bin="${BATS_TEST_TMPDIR}/shim-bin"
  mkdir -p "${root}/bin" "${shim_bin}"
  cat >"${root}/bin/devin-desktop-manager" <<'EOF'
#!/usr/bin/env bash
printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 0
EOF
  cat >"${shim_bin}/bash" <<'EOF'
#!/bin/sh
exit 86
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager" "${shim_bin}/bash"

  run env PATH="${shim_bin}:${PATH}" "${HARNESS_BASH}" "${PREFLIGHT}" \
    manager-status --project-root "${root}"

  [ "${status}" -eq 0 ]
}

@test "[PMC-U3-R04] composite preflight completes before sequential or parallel child effects" {
  local root="${BATS_TEST_TMPDIR}/checkout" log="${BATS_TEST_TMPDIR}/effects"
  mkdir -p "${root}/bin" "${root}/scripts"
  cp "${PROJECT_ROOT}/Makefile" "${root}/Makefile"
  cp "${PROJECT_ROOT}/scripts/preflight" "${root}/scripts/preflight"
  cat >"${root}/scripts/install-manager" <<EOF
#!${HARNESS_BASH}
printf 'installer\n' >>$(printf '%q' "${log}")
EOF
  cat >"${root}/bin/devin-desktop-manager" <<EOF
#!${HARNESS_BASH}
  if [[ "\${1:-}" == internal-preflight ]]; then printf 'DDM-PREFLIGHT\\0' >&2; exit 2; fi
printf 'manager\n' >>$(printf '%q' "${log}")
EOF
  chmod 0755 "${root}/scripts/preflight" "${root}/scripts/install-manager" \
    "${root}/bin/devin-desktop-manager"

  run "${HARNESS_MAKE}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" HOME="${BATS_TEST_TMPDIR}/home" install
  [ "${status}" -ne 0 ]
  [ ! -e "${log}" ]

  run "${HARNESS_MAKE}" --no-print-directory -s -j -C "${root}" \
    BASH="${HARNESS_BASH}" HOME="${BATS_TEST_TMPDIR}/home" install
  [ "${status}" -ne 0 ]
  [ ! -e "${log}" ]
}

@test "[PMC-U3-R04] manager protocol sees network settings before mutation" {
  local root="${BATS_TEST_TMPDIR}/checkout"
  mkdir -p "${root}/bin"
  cat >"${root}/bin/devin-desktop-manager" <<'EOF'
#!/usr/bin/env bash
if [[ -v HTTPS_PROXY && -v https_proxy && "${HTTPS_PROXY}" != "${https_proxy}" ]]; then
  printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 1
  printf 'blocker\0environment\0environment.https-proxy\0purpose\0conflict\0retry\0'
  exit 1
fi
if [[ -n "${CURL_CA_BUNDLE:-}" && "${CURL_CA_BUNDLE}" != /* ]]; then
  printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 1
  printf 'blocker\0path\0path.curl-ca-bundle\0purpose\0unsafe\0retry\0'
  exit 1
fi
printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 0
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager"

  run env HTTPS_PROXY=https://one.invalid https_proxy=https://two.invalid \
    "${HARNESS_BASH}" "${PREFLIGHT}" manager-check --project-root "${root}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *'manager.environment.https-proxy'* ]]

  run env -u HTTPS_PROXY -u https_proxy CURL_CA_BUNDLE=relative-ca.pem \
    "${HARNESS_BASH}" "${PREFLIGHT}" manager-check --project-root "${root}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *'manager.path.curl-ca-bundle'* ]]
}

@test "[PMC-U3-R05] Make sanitizes Bash startup locale timezone and tool configuration" {
  local root="${BATS_TEST_TMPDIR}/checkout" sentinel="${BATS_TEST_TMPDIR}/startup-ran"
  mkdir -p "${root}/bin" "${root}/scripts"
  cp "${PROJECT_ROOT}/Makefile" "${root}/Makefile"
  cp "${PROJECT_ROOT}/scripts/preflight" "${root}/scripts/preflight"
  cat >"${BATS_TEST_TMPDIR}/bash-env" <<EOF
touch $(printf '%q' "${sentinel}")
EOF
  cat >"${root}/bin/devin-desktop-manager" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == internal-preflight ]]; then
  printf 'DDM-PREFLIGHT\\0%s\\0%s\\0' 1 0
  exit 0
fi
[[ -z "\${BASH_ENV:-}" && -z "\${ENV:-}" && "\${LC_ALL:-}" == C && "\${TZ:-}" == UTC ]]
EOF
  chmod 0755 "${root}/scripts/preflight" "${root}/bin/devin-desktop-manager"

  run env BASH_ENV="${BATS_TEST_TMPDIR}/bash-env" ENV="${BATS_TEST_TMPDIR}/bash-env" \
    PS4='$(touch ignored)' RUBYOPT=-rhostile GIT_CONFIG_GLOBAL=/hostile \
    "${HARNESS_MAKE}" --no-print-directory -s -C "${root}" \
    BASH="${HARNESS_BASH}" HOME="${BATS_TEST_TMPDIR}/home" status
  [ "${status}" -eq 0 ]
  [ ! -e "${sentinel}" ]
}

@test "[PMC-U3-R06] diagnostics are bounded deterministic blocker-first plain stderr" {
  local sparse
  sparse="$(make_sparse_bin sh)"

  run env PATH="${sparse}" PREFLIGHT_BATS=$'missing\\tool\tname' \
    PREFLIGHT_SHELLCHECK=also-missing NO_COLOR=1 TERM=dumb \
    "${HARNESS_BASH}" "${PREFLIGHT}" verify --project-root "${PROJECT_ROOT}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == verify:* ]]
  [[ "${output}" == *'missing\\tool\tname'* ]]
  [[ "${output}" != *$'\e'* ]]
  [ "${#output}" -le 32768 ]
}

@test "[PMC-U3-R06] aggregate overflow emits only the output-limit blocker" {
  local root="${BATS_TEST_TMPDIR}/checkout"
  local expected='manager-status: error: diagnostic.output-limit: diagnostic output exceeded safe limit. Correct the reported environment and retry.'
  mkdir -p "${root}/bin"
  cat >"${root}/bin/devin-desktop-manager" <<EOF
#!${HARNESS_BASH}
printf 'DDM-PREFLIGHT\\0%s\\0%s\\0' 1 64
printf -v observed '%*s' 300 ''
observed=\${observed// /\$'\\001'}
for ((index = 0; index < 64; index++)); do
  printf 'blocker\\0command\\0test.%02d\\0purpose\\0%s\\0retry\\0' \
    "\${index}" "\${observed}"
done
exit 1
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager"

  run "${HARNESS_BASH}" "${PREFLIGHT}" manager-status --project-root "${root}"

  [ "${status}" -eq 1 ]
  [ "${output}" = "${expected}" ]
}

@test "[PMC-U3-R06] warning-only manager findings do not block the target" {
  local root="${BATS_TEST_TMPDIR}/warning-checkout"
  mkdir -p "${root}/bin"
  cat >"${root}/bin/devin-desktop-manager" <<EOF
#!${HARNESS_BASH}
printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 1
printf 'warning\0optional\0optional.kde-cache\0purpose\0missing\0no action\0'
exit 1
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager"

  run "${HARNESS_BASH}" "${PREFLIGHT}" manager-doctor --project-root "${root}"

  [ "${status}" -eq 0 ]
  [[ "${output}" == *'manager-doctor: warning: manager.optional.kde-cache'* ]]
}

@test "[PMC-U4-R05] uninstall manager preflight preserves the caller terminal" {
  local root="${BATS_TEST_TMPDIR}/tty-checkout" command
  mkdir -p "${root}/bin"
  cat >"${root}/bin/devin-desktop-manager" <<EOF
#!${HARNESS_BASH}
if [[ -t 0 ]]; then
  printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 0
  exit 0
fi
printf 'DDM-PREFLIGHT\0%s\0%s\0' 1 1
printf 'blocker\0interaction\0interaction.terminal\0purpose\0not a terminal\0retry\0'
exit 1
EOF
  chmod 0755 "${root}/bin/devin-desktop-manager"
  printf -v command '%q %q manager-uninstall --project-root %q' \
    "${HARNESS_BASH}" "${PREFLIGHT}" "${root}"

  run "${HARNESS_TOOLS[script]}" --quiet --return --command "${command}" \
    /dev/null </dev/null

  [ "${status}" -eq 0 ]
  [[ "${output}" != *'interaction.terminal'* ]]
}

@test "[PMC-U3-R07] probes close stdin bound execution and isolate temporary state" {
  local shim_bin="${BATS_TEST_TMPDIR}/shim-bin" marker="${BATS_TEST_TMPDIR}/stdin-read"
  mkdir -p "${shim_bin}"
  cat >"${shim_bin}/bats" <<EOF
#!${HARNESS_BASH}
if read -r value; then : >$(printf '%q' "${marker}"); fi
printf 'Bats 1.14.0\n'
EOF
  chmod 0755 "${shim_bin}/bats"

  run /bin/sh -c 'printf hostile | env PATH="$1" PREFLIGHT_BATS=bats "$2" "$3" test --project-root "$4"' \
    _ "${shim_bin}" "${HARNESS_BASH}" "${PREFLIGHT}" "${PROJECT_ROOT}"
  [ "${status}" -eq 1 ]
  [ ! -e "${marker}" ]
  [ ! -e "${PROJECT_ROOT}/.preflight-tmp" ]
}

@test "[PMC-U3-R08] pause shims and readiness helpers share one deterministic timeout" {
  local log="${BATS_TEST_TMPDIR}/calls" ready="${BATS_TEST_TMPDIR}/ready"
  local continue="${BATS_TEST_TMPDIR}/continue" shim stderr_file
  PORTABLE_TEST_TIMEOUT=1
  shim="$(make_command_shim pause-command "${HARNESS_TOOLS[true]}" "${log}" \
    "pause:1:${ready}:${continue}")"
  stderr_file="${BATS_TEST_TMPDIR}/stderr"

  run /bin/sh -c '"$1" 2>"$2"' _ "${shim}" "${stderr_file}"
  [ "${status}" -eq 124 ]
  [ -f "${ready}" ]
  [ ! -e "${continue}" ]
  [ "$(wc -l <"${stderr_file}")" -eq 1 ]

  run wait_for_ready "${BATS_TEST_TMPDIR}/never"
  [ "${status}" -eq 1 ]
}

@test "[PMC-U10-R04] output-lock is a root-scoped capability profile" {
  run "${HARNESS_BASH}" "${PREFLIGHT}" output-lock
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"--project-root"* ]]

  run "${HARNESS_BASH}" "${PREFLIGHT}" output-lock --project-root "${PROJECT_ROOT}"
  [ "${status}" -ne 2 ]
}

@test "[PMC-U5-R06] coverage runner owns a root-scoped local profile" {
  run "${HARNESS_BASH}" "${PREFLIGHT}" coverage-run
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"--project-root"* ]]

  grep -Fq 'preflight" coverage-run' "${PROJECT_ROOT}/scripts/run-coverage"
}

@test "[PMC-U6-R01] package and release profiles reject roots without exact Git HEAD" {
  local root="${BATS_TEST_TMPDIR}/extracted" profile
  mkdir -p "${root}"

  for profile in package release-contract release-check; do
    run "${HARNESS_BASH}" "${PREFLIGHT}" "${profile}" --project-root "${root}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"exact Git root"*"HEAD"* ]]
  done
}

@test "[PMC-U6-C01] release composite reuses package coverage and contract profiles" {
  grep -Fq "[package]='package-run'" "${PREFLIGHT}"
  grep -Fq "[release-check]='lint coverage package release-contract'" "${PREFLIGHT}"
  grep -Fq "[release-check-official]='release-check release-contract-official'" "${PREFLIGHT}"
  [ "$(grep -c '^    package-output-local)' "${PREFLIGHT}")" -eq 1 ]
  [ "$(grep -c '^    release-contract-local)' "${PREFLIGHT}")" -eq 1 ]
  [ "$(grep -c '^    release-handoff-local)' "${PREFLIGHT}")" -eq 1 ]
}

@test "[PMC-U6-R06] handoff-only tools are required only by tagged direct contracts" {
  local sparse
  sparse="$(make_sparse_bin bash git awk grep timeout env mkdir rm find sha256sum readlink stat)"

  run env PATH="${sparse}" "${HARNESS_BASH}" "${PROJECT_ROOT}/scripts/release-check" \
    --project-root "${PROJECT_ROOT}" 0.1.0
  [ "${status}" -eq 0 ]

  run env PATH="${sparse}" "${HARNESS_BASH}" "${PROJECT_ROOT}/scripts/release-check" \
    --project-root "${PROJECT_ROOT}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"command.tail"* ]]
  [[ "${output}" != *"package handoff"* ]]
}

@test "[PMC-U7-R06] clean owns one root-scoped local profile" {
  run "${HARNESS_BASH}" "${PREFLIGHT}" clean
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"--project-root"* ]]

  run "${HARNESS_BASH}" "${PREFLIGHT}" clean --project-root "${PROJECT_ROOT}"
  [ "${status}" -ne 2 ]
  grep -Fq "[clean]='clean-local output-lock'" "${PREFLIGHT}"
}
