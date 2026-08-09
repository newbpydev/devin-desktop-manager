#!/usr/bin/env bats

set -e

load helpers/portable

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  resolve_harness_tools bash chmod cp env flock ln mkdir mkfifo mv rm sleep stat
  HARNESS_BASH="${HARNESS_TOOLS[bash]}"
  CHECKOUT="${BATS_TEST_TMPDIR}/checkout"
  mkdir -p "${CHECKOUT}/scripts"
  cp "${PROJECT_ROOT}/scripts/output-lock" "${CHECKOUT}/scripts/output-lock"
  cp "${PROJECT_ROOT}/scripts/preflight" "${CHECKOUT}/scripts/preflight"
  create_output_helper "${CHECKOUT}"
}

create_output_helper() {
  local root="$1"
  mkdir -p "${root}/scripts"
  cat >"${root}/scripts/run-coverage" <<EOF
#!${HARNESS_BASH}
set -u
[[ "\${1:-}" == --output-lock-fd && "\${2:-}" == 6 ]] || exit 2
shift 2
lock="\${OUTPUT_HELPER_ROOT:?}/.devin-desktop-manager.outputs.lock"
[[ -e /proc/\$\$/fd/6 ]] || exit 2
fd_identity="\$(stat -Lc '%d:%i:%u:%F:%h' -- /proc/\$\$/fd/6 2>/dev/null)" || exit 2
path_identity="\$(stat -Lc '%d:%i:%u:%F:%h' -- "\${lock}" 2>/dev/null)" || exit 2
[[ "\${fd_identity}" == "\${path_identity}" ]] || exit 2
if flock -n "\${lock}" true 2>/dev/null; then exit 2; fi
flock -n 6 || exit 2
case "\${1:-check}" in
  check) printf 'locked\n' ;;
  replace)
    rm -f -- "\${lock}"
    : >"\${lock}"
    exit 2
    ;;
  hold|child-hold)
    ready="\$2"
    continue="\$3"
    temporary="\${ready}.tmp.\$\$"
    (umask 077; : >"\${temporary}")
    mv -f -- "\${temporary}" "\${ready}"
    deadline=\$((SECONDS + \${PORTABLE_TEST_TIMEOUT:-10}))
    while [[ ! -f "\${continue}" ]]; do
      ((SECONDS < deadline)) || exit 124
      sleep 0.05
    done
    ;;
  spawn-child)
    "\$0" --output-lock-fd 6 child-hold "\$2" "\$3" </dev/null >/dev/null 2>&1 &
    kill -KILL "\$\$"
    ;;
  mark) : >"\$2" ;;
  status) exit "\$2" ;;
  *) exit 2 ;;
esac
EOF
  chmod 0755 "${root}/scripts/run-coverage"
}

run_lock() {
  OUTPUT_HELPER_ROOT="${CHECKOUT}" run "${HARNESS_BASH}" \
    "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
    "${CHECKOUT}/scripts/run-coverage" "$@"
}

wait_until_unlocked() {
  local lock="$1" deadline=$((SECONDS + PORTABLE_TEST_TIMEOUT))
  until flock -n "${lock}" true 2>/dev/null; do
    ((SECONDS < deadline)) || return 1
    sleep 0.05
  done
}

@test "[PMC-U10-R01] descriptor identity and lock object matrix has no bypass" {
  local lock="${CHECKOUT}/.devin-desktop-manager.outputs.lock"
  local other="${BATS_TEST_TMPDIR}/other-lock"

  run_lock check
  [ "${status}" -eq 0 ]
  [ "${output}" = locked ]

  run_lock status 23
  [ "${status}" -eq 23 ]

  OUTPUT_HELPER_ROOT="${CHECKOUT}" run "${CHECKOUT}/scripts/run-coverage" \
    --output-lock-fd 6 check
  [ "${status}" -eq 2 ]

  run "${HARNESS_BASH}" -c 'exec 6<>"$1"; OUTPUT_HELPER_ROOT="$2" "$3" --output-lock-fd 6 check' \
    _ "${lock}" "${CHECKOUT}" "${CHECKOUT}/scripts/run-coverage"
  [ "${status}" -eq 2 ]

  : >"${other}"
  run "${HARNESS_BASH}" -c 'exec 6<>"$1"; flock -n 6; OUTPUT_HELPER_ROOT="$2" "$3" --output-lock-fd 6 check' \
    _ "${other}" "${CHECKOUT}" "${CHECKOUT}/scripts/run-coverage"
  [ "${status}" -eq 2 ]

  rm -f -- "${lock}"
  cat >"${BATS_TEST_TMPDIR}/replace-flock" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == --version ]]; then exec ${HARNESS_TOOLS[flock]@Q} "\$@"; fi
${HARNESS_TOOLS[flock]@Q} "\$@" || exit
rm -f -- ${lock@Q}
: >${lock@Q}
EOF
  chmod 0755 "${BATS_TEST_TMPDIR}/replace-flock"
  mkdir -p "${BATS_TEST_TMPDIR}/replace-bin"
  ln -s -- "${BATS_TEST_TMPDIR}/replace-flock" "${BATS_TEST_TMPDIR}/replace-bin/flock"
  ln -s -- "${HARNESS_TOOLS[stat]}" "${BATS_TEST_TMPDIR}/replace-bin/stat"
  OUTPUT_HELPER_ROOT="${CHECKOUT}" run env \
    PATH="${BATS_TEST_TMPDIR}/replace-bin:/usr/bin:/bin" "${HARNESS_BASH}" \
    "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
    "${CHECKOUT}/scripts/run-coverage" check
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"changed during acquisition"* ]]

  rm -f -- "${lock}"
  : >"${lock}"
  cat >"${BATS_TEST_TMPDIR}/wrong-owner-stat" <<EOF
#!${HARNESS_BASH}
output="\$(${HARNESS_TOOLS[stat]@Q} "\$@")" || exit
last="\${!#}"
if [[ "\${1:-}" == -Lc && ("\${last}" == ${lock@Q} || "\${last}" == /proc/*/fd/6) ]]; then
  IFS=: read -r device inode owner type links <<<"\${output}"
  printf '%s:%s:%s:%s:%s\n' "\${device}" "\${inode}" "\$((owner + 1))" "\${type}" "\${links}"
else
  printf '%s\n' "\${output}"
fi
EOF
  chmod 0755 "${BATS_TEST_TMPDIR}/wrong-owner-stat"
  mkdir -p "${BATS_TEST_TMPDIR}/owner-bin"
  ln -s -- "${HARNESS_TOOLS[flock]}" "${BATS_TEST_TMPDIR}/owner-bin/flock"
  ln -s -- "${BATS_TEST_TMPDIR}/wrong-owner-stat" "${BATS_TEST_TMPDIR}/owner-bin/stat"
  OUTPUT_HELPER_ROOT="${CHECKOUT}" run env \
    PATH="${BATS_TEST_TMPDIR}/owner-bin:/usr/bin:/bin" "${HARNESS_BASH}" \
    "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
    "${CHECKOUT}/scripts/run-coverage" check
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"current-UID"* ]]

  for kind in symlink fifo hardlink; do
    rm -f -- "${lock}" "${other}"
    case "${kind}" in
      symlink) ln -s -- "${other}" "${lock}" ;;
      fifo) mkfifo -- "${lock}" ;;
      hardlink) : >"${other}"; ln -- "${other}" "${lock}" ;;
    esac
    run_lock check
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"coverage"*"output lock"* ]]
  done

  rm -f -- "${lock}" "${other}"
  chmod 0777 "${CHECKOUT}"
  run_lock check
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"coverage"*"output lock parent"* ]]
}

@test "[PMC-U10-R02] same checkout contends and separate checkouts do not" {
  local ready="${BATS_TEST_TMPDIR}/ready" continue="${BATS_TEST_TMPDIR}/continue"
  local other_checkout="${BATS_TEST_TMPDIR}/other-checkout" holder
  mkdir -p "${other_checkout}/scripts"
  cp "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}/scripts/preflight" \
    "${other_checkout}/scripts/"
  create_output_helper "${other_checkout}"

  OUTPUT_HELPER_ROOT="${CHECKOUT}" "${HARNESS_BASH}" \
    "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
    "${CHECKOUT}/scripts/run-coverage" hold "${ready}" "${continue}" &
  holder=$!
  wait_for_ready "${ready}"

  run_lock check
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"coverage"*"busy"*"do not delete"*"retry"* ]]

  OUTPUT_HELPER_ROOT="${other_checkout}" run "${HARNESS_BASH}" \
    "${other_checkout}/scripts/output-lock" "${other_checkout}" -- \
    "${other_checkout}/scripts/run-coverage" check
  [ "${status}" -eq 0 ]

  release_barrier "${continue}"
  wait "${holder}"
  run_lock check
  [ "${status}" -eq 0 ]
}

@test "[PMC-U10-R03] surviving child retains lock and persistent unlocked inode is reused" {
  local ready="${BATS_TEST_TMPDIR}/child-ready"
  local continue="${BATS_TEST_TMPDIR}/child-continue"
  local lock="${CHECKOUT}/.devin-desktop-manager.outputs.lock" before after

  OUTPUT_HELPER_ROOT="${CHECKOUT}" run "${HARNESS_BASH}" \
    "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
    "${CHECKOUT}/scripts/run-coverage" spawn-child "${ready}" "${continue}"
  [ "${status}" -eq 137 ]
  wait_for_ready "${ready}"

  run_lock check
  [ "${status}" -eq 1 ]
  release_barrier "${continue}"
  wait_until_unlocked "${lock}"

  before="$(stat -Lc '%d:%i' -- "${lock}")"
  run_lock check
  [ "${status}" -eq 0 ]
  after="$(stat -Lc '%d:%i' -- "${lock}")"
  [ "${after}" = "${before}" ]
}

@test "[PMC-U10-R04] missing lock capabilities fail before the child" {
  local marker="${BATS_TEST_TMPDIR}/child-ran" shim_bin="${BATS_TEST_TMPDIR}/shim-bin"
  local real_stat="${HARNESS_TOOLS[stat]}" mode
  mkdir -p "${shim_bin}"

  for mode in flock opened-inode local-filesystem; do
    rm -f -- "${marker}" "${shim_bin}/flock" "${shim_bin}/stat"
    ln -s -- "${HARNESS_TOOLS[flock]}" "${shim_bin}/flock"
    ln -s -- "${real_stat}" "${shim_bin}/stat"
    if [[ "${mode}" == flock ]]; then
      rm "${shim_bin}/flock"
      cat >"${shim_bin}/flock" <<EOF
#!${HARNESS_BASH}
exit 1
EOF
      chmod 0755 "${shim_bin}/flock"
    else
      rm "${shim_bin}/stat"
      cat >"${shim_bin}/stat" <<EOF
#!${HARNESS_BASH}
if [[ "\${1:-}" == --version ]]; then exec ${real_stat@Q} "\$@"; fi
if [[ ${mode@Q} == local-filesystem && "\${1:-}" == -f ]]; then printf 'nfs\n'; exit 0; fi
if [[ ${mode@Q} == opened-inode && "\${1:-}" == -Lc ]]; then exit 1; fi
exec ${real_stat@Q} "\$@"
EOF
      chmod 0755 "${shim_bin}/stat"
    fi

    OUTPUT_HELPER_ROOT="${CHECKOUT}" run env PATH="${shim_bin}:/usr/bin:/bin" \
      "${HARNESS_BASH}" "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
      "${CHECKOUT}/scripts/run-coverage" mark "${marker}"
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"coverage"*"output lock"* ]]
    [ ! -e "${marker}" ]
  done
}

@test "[PMC-U10-R04] non-mutating release check is rejected before lock creation" {
  local marker="${BATS_TEST_TMPDIR}/release-check-ran"
  local lock="${CHECKOUT}/.devin-desktop-manager.outputs.lock"

  cat >"${CHECKOUT}/scripts/release-check" <<EOF
#!${HARNESS_BASH}
: >$(printf '%q' "${marker}")
EOF
  chmod 0755 "${CHECKOUT}/scripts/release-check"

  run "${HARNESS_BASH}" "${CHECKOUT}/scripts/output-lock" "${CHECKOUT}" -- \
    "${CHECKOUT}/scripts/release-check"

  [ "${status}" -eq 2 ]
  [ ! -e "${marker}" ]
  [ ! -e "${lock}" ]
}
