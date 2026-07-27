#!/usr/bin/env bash

PORTABLE_TEST_TIMEOUT="${PORTABLE_TEST_TIMEOUT:-10}"
declare -gA HARNESS_TOOLS=()

declare -ga PORTABLE_ACCEPTED_COMPONENTS=(
  plain
  'space dir'
  "single-'quote"
  'double-"quote'
  'glob-[*?]'
  'dollar-$value'
  'subshell-$(touch sentinel)'
  'semi-;amp-&pipe-|'
  --leading
  'backtick-`touch sentinel`'
)

declare -ga PORTABLE_REJECTED_CASES=(
  ''
  '../escape'
  '/absolute'
  $'tab\tvalue'
  $'line\nvalue'
  $'return\rvalue'
  $'escape\evalue'
)

for portable_byte in {1..31} 127; do
  case "${portable_byte}" in 9|10|13|27) continue ;; esac
  printf -v portable_hex '%02x' "${portable_byte}"
  printf -v portable_value '%b' "\\x${portable_hex}"
  PORTABLE_REJECTED_CASES+=("${portable_value}")
done
unset portable_byte portable_hex portable_value

portable_test_output_path() {
  (($# == 1)) || return 2
  [[ -n "${BATS_TEST_TMPDIR:-}" && "$1" == "${BATS_TEST_TMPDIR}"/* ]] || return 1
  [[ "$1" != */../* && "$1" != */.. ]]
}

resolve_harness_tools() {
  (($# > 0)) || return 2

  local name candidate directory physical
  local -A resolved=()

  for name in "$@"; do
    candidate="$(type -P -- "${name}" 2>/dev/null || true)"
    if [[ "${candidate}" != /* || ! -f "${candidate}" || ! -x "${candidate}" ]]; then
      printf 'portable harness: required executable is unavailable: %s\n' \
        "${name}" >&2
      return 1
    fi
    directory="${candidate%/*}"
    physical="$(CDPATH= cd -P -- "${directory}" && pwd -P)" || {
      printf 'portable harness: cannot resolve executable: %s\n' "${name}" >&2
      return 1
    }
    resolved["${name}"]="${physical}/${candidate##*/}"
  done

  HARNESS_TOOLS=()
  for name in "$@"; do
    HARNESS_TOOLS["${name}"]="${resolved[${name}]}"
  done
}

make_command_shim() {
  (($# == 4)) || return 2
  [[ -n "${BATS_TEST_TMPDIR:-}" ]] || return 2

  local name="$1" real="$2" log="$3" behavior="$4"
  local shim_dir="${BATS_TEST_TMPDIR}/bin" shim
  [[ "${name}" != */* && -n "${name}" && "${real}" == /* ]] || return 2
  portable_test_output_path "${log}" || return 2
  if [[ "${behavior}" == pass ]]; then
    :
  elif [[ "${behavior}" =~ ^fail:([1-9][0-9]*):([0-9]+)$ ]] &&
    ((10#${BASH_REMATCH[2]} <= 255)); then
    :
  elif [[ "${behavior}" =~ ^pause:([1-9][0-9]*):([^:]+):([^:]+)$ ]] &&
    portable_test_output_path "${BASH_REMATCH[2]}" &&
    portable_test_output_path "${BASH_REMATCH[3]}"; then
    :
  else
    return 2
  fi

  "${HARNESS_TOOLS[mkdir]:-mkdir}" -p -- "${shim_dir}" || return 1
  shim="${shim_dir}/${name}"
  cat >"${shim}" <<EOF
#!${HARNESS_TOOLS[bash]:-${BASH}}
set -u
real=$(printf '%q' "${real}")
log=$(printf '%q' "${log}")
behavior=$(printf '%q' "${behavior}")
timeout=$(printf '%q' "${PORTABLE_TEST_TIMEOUT}")
count_file="\${log}.count"
count=0
[[ ! -f "\${count_file}" ]] || read -r count <"\${count_file}"
count=\$((count + 1))
printf '%s\\n' "\${count}" >"\${count_file}"
{
  printf 'call\\0%s\\0%s\\0' "\${count}" "\$#"
  printf '%s\\0' "\$@"
} >>"\${log}"
case "\${behavior}" in
  fail:*)
    IFS=: read -r _ fail_call fail_status <<<"\${behavior}"
    [[ "\${count}" != "\${fail_call}" ]] || exit "\${fail_status}"
    ;;
  pause:*)
    IFS=: read -r _ pause_call ready continue <<<"\${behavior}"
    if [[ "\${count}" == "\${pause_call}" ]]; then
      temporary="\${ready}.tmp.\$\$"
      (umask 077; : >"\${temporary}") && mv -f -- "\${temporary}" "\${ready}"
      deadline=\$((SECONDS + timeout))
      while [[ ! -f "\${continue}" ]]; do
        if ((SECONDS >= deadline)); then
          printf 'command shim %s timed out waiting for barrier\\n' $(printf '%q' "${name}") >&2
          exit 124
        fi
        ${HARNESS_TOOLS[sleep]:-/bin/sleep} 0.01
      done
    fi
    ;;
esac
exec "\${real}" "\$@"
EOF
  "${HARNESS_TOOLS[chmod]:-chmod}" 0755 -- "${shim}" || return 1
  printf '%s\n' "${shim}"
}

wait_for_ready() {
  (($# == 1 || $# == 2)) || return 2
  local path="$1" timeout="${2:-${PORTABLE_TEST_TIMEOUT}}"
  [[ "${timeout}" =~ ^[0-9]+$ ]] || return 2
  local deadline=$((SECONDS + timeout))
  while [[ ! -f "${path}" ]]; do
    ((SECONDS < deadline)) || return 1
    "${HARNESS_TOOLS[sleep]:-/bin/sleep}" 0.01
  done
}

release_barrier() {
  (($# == 1)) || return 2
  local path="$1" temporary="${1}.tmp.$$"
  portable_test_output_path "${path}" || return 2
  (umask 077; : >"${temporary}") || return 1
  "${HARNESS_TOOLS[mv]:-mv}" -f -- "${temporary}" "${path}" || {
    "${HARNESS_TOOLS[rm]:-rm}" -f -- "${temporary}"
    return 1
  }
}

snapshot_tree() {
  (($# == 2)) || return 2
  local root="$1" output="$2" path relative type mode links device inode digest
  [[ -d "${root}" ]] || return 1
  portable_test_output_path "${output}" || return 2
  : >"${output}" || return 1

  while IFS= read -r -d '' path; do
    relative="${path#"${root}"/}"
    [[ "${path}" != "${root}" ]] || relative=.
    if [[ -L "${path}" ]]; then
      type=link
      digest="$("${HARNESS_TOOLS[readlink]:-readlink}" -- "${path}")" || return 1
    elif [[ -d "${path}" ]]; then
      type=directory
      digest=
    elif [[ -f "${path}" ]]; then
      type=file
      digest="$("${HARNESS_TOOLS[sha256sum]:-sha256sum}" -- "${path}")" || return 1
      digest="${digest%% *}"
    else
      type=special
      digest=
    fi
    read -r mode links device inode < <(
      "${HARNESS_TOOLS[stat]:-stat}" -c '%a %h %d %i' -- "${path}"
    ) || return 1
    printf '%s\0%s\0%s\0%s\0%s\0%s\0%s\0' \
      "${relative}" "${type}" "${mode}" "${links}" "${device}" "${inode}" \
      "${digest}" >>"${output}"
  done < <("${HARNESS_TOOLS[find]:-find}" "${root}" -print0 | LC_ALL=C sort -z)
}
