#!/usr/bin/env bash

_coverage_record() {
  printf '%s\0%s\0' "$1" "$2"
}

_coverage_path_kind() {
  local path="$1" metadata
  if [[ -L "${path}" ]]; then
    printf 'symbolic\n'
  elif [[ -d "${path}" ]]; then
    printf 'directory\n'
  elif [[ -f "${path}" ]]; then
    metadata="$(stat -Lc '%h' -- "${path}" 2>/dev/null)" || {
      printf 'special\n'
      return
    }
    [[ "${metadata}" == 1 ]] && printf 'file\n' || printf 'hard-linked\n'
  elif [[ -e "${path}" ]]; then
    printf 'special\n'
  else
    printf 'absent\n'
  fi
}

_coverage_validate_entries() {
  local root="$1" list="$2" root_device="$3"
  local path relative top kind device
  while IFS= read -r -d '' path; do
    [[ "${path}" != "${root}" ]] || continue
    relative="${path#"${root}"/}"
    top="${relative%%/*}"
    case "${top}" in
      index.html|assets|.last_run.json|.resultset.json|.resultset.json.lock) ;;
      *) _COVERAGE_REASON=unknown-coverage-entry; return 1 ;;
    esac
    kind="$(_coverage_path_kind "${path}")"
    case "${kind}" in
      symbolic|special|hard-linked) _COVERAGE_REASON="${kind}"; return 1 ;;
      directory)
        [[ "${top}" == assets &&
          ("${relative}" == assets || "${relative}" == assets/*) ]] || {
          _COVERAGE_REASON=invalid-public
          return 1
        }
        ;;
      file)
        if [[ "${top}" == assets ]]; then
          [[ "${relative}" == assets/* ]] || {
            _COVERAGE_REASON=invalid-public
            return 1
          }
        elif [[ "${relative}" != "${top}" ]]; then
          _COVERAGE_REASON=invalid-public
          return 1
        fi
        ;;
    esac
    device="$(stat -Lc '%d' -- "${path}" 2>/dev/null)" || {
      _COVERAGE_REASON=special
      return 1
    }
    [[ "${device}" == "${root_device}" ]] || {
      _COVERAGE_REASON=wrong-device
      return 1
    }
  done <"${list}"
}

_coverage_validate_tree() {
  local root="$1" role="$2" root_device list="" attempt status
  [[ "$(_coverage_path_kind "${root}")" == directory ]] || {
    _COVERAGE_REASON=invalid-public
    return 1
  }
  root_device="$(stat -Lc '%d' -- "${root}" 2>/dev/null)" || {
    _COVERAGE_REASON=special
    return 1
  }
  for attempt in {0..15}; do
    list="${TMPDIR:-/tmp}/devin-desktop-manager.coverage-list.${UID}.$$.$RANDOM.${attempt}"
    if (umask 077; set -o noclobber; : >"${list}") 2>/dev/null; then break; fi
    list=
  done
  [[ -n "${list}" ]] || {
    _COVERAGE_REASON=invalid-public
    return 1
  }
  if ! (ulimit -f 8192; find "${root}" -mindepth 0 -print0 >"${list}") 2>/dev/null; then
    rm -f -- "${list}"
    _COVERAGE_REASON=invalid-public
    return 1
  fi
  if _coverage_validate_entries "${root}" "${list}" "${root_device}"; then
    status=0
  else
    status=$?
  fi
  rm -f -- "${list}" || {
    _COVERAGE_REASON=invalid-public
    return 1
  }
  ((status == 0)) || return "${status}"
  [[ -f "${root}/.resultset.json" && ! -L "${root}/.resultset.json" ]] || {
    _COVERAGE_REASON=invalid-public
    return 1
  }
  jq -e 'type == "object" and length == 1 and
    ([.[] | .coverage? | type] == ["object"])' \
    "${root}/.resultset.json" >/dev/null 2>&1 || {
    _COVERAGE_REASON=invalid-public
    return 1
  }
  if [[ "${role}" == stage ]]; then
    [[ "$(stat -Lc '%a' -- "${root}")" == 700 ]] || {
      _COVERAGE_REASON=invalid-public
      return 1
    }
  fi
}

_coverage_classify() {
  local root="$1" parent leaf public_kind candidate name suffix parent_device candidate_device
  local -a stages=() backups=()
  _COVERAGE_STATE=unsafe
  _COVERAGE_REASON=

  [[ "${root}" == /* && "${root}" != *[!\ -~]* && "${root}" != / ]] || {
    _COVERAGE_REASON=outside-root
    return 1
  }
  parent="${root%/*}"
  leaf="${root##*/}"
  if [[ ! -e "${root}" && ! -L "${root}" && ! -e "${parent}" && ! -L "${parent}" ]]; then
    _COVERAGE_STATE=absent
    return 0
  fi
  [[ -n "${leaf}" && -d "${parent}" && ! -L "${parent}" ]] || {
    _COVERAGE_REASON=outside-root
    return 1
  }
  parent_device="$(stat -Lc '%d' -- "${parent}" 2>/dev/null)" || {
    _COVERAGE_REASON=outside-root
    return 1
  }

  for candidate in "${parent}/.${leaf}.stage."*; do
    [[ -e "${candidate}" || -L "${candidate}" ]] || continue
    name="${candidate##*/}"
    suffix="${name#".${leaf}.stage."}"
    [[ "${name}" == ".${leaf}.stage.${suffix}" &&
      "${suffix}" =~ ^[0-9]+\.[0-9a-f]{6}$ ]] || {
      _COVERAGE_REASON=invalid-public
      return 1
    }
    stages+=("${candidate}")
  done
  for candidate in "${parent}/.${leaf}.backup"*; do
    [[ -e "${candidate}" || -L "${candidate}" ]] || continue
    backups+=("${candidate}")
  done
  ((${#stages[@]} <= 1)) || { _COVERAGE_REASON=multiple-stage; return 1; }
  ((${#backups[@]} <= 1)) || { _COVERAGE_REASON=multiple-backup; return 1; }
  if ((${#backups[@]} == 1)) &&
    [[ "${backups[0]}" != "${parent}/.${leaf}.backup" ]]; then
    _COVERAGE_REASON=invalid-public
    return 1
  fi

  public_kind="$(_coverage_path_kind "${root}")"
  case "${public_kind}" in
    symbolic|special|hard-linked) _COVERAGE_REASON="${public_kind}"; return 1 ;;
    file) _COVERAGE_REASON=invalid-public; return 1 ;;
    directory) _coverage_validate_tree "${root}" public || return 1 ;;
  esac
  for candidate in "${stages[@]}"; do
    case "$(_coverage_path_kind "${candidate}")" in
      symbolic|special|hard-linked) _COVERAGE_REASON="$(_coverage_path_kind "${candidate}")"; return 1 ;;
      directory) _coverage_validate_tree "${candidate}" stage || return 1 ;;
      *) _COVERAGE_REASON=invalid-public; return 1 ;;
    esac
    candidate_device="$(stat -Lc '%d' -- "${candidate}")" || return 1
    [[ "${candidate_device}" == "${parent_device}" ]] || { _COVERAGE_REASON=wrong-device; return 1; }
  done
  for candidate in "${backups[@]}"; do
    case "$(_coverage_path_kind "${candidate}")" in
      symbolic|special|hard-linked) _COVERAGE_REASON="$(_coverage_path_kind "${candidate}")"; return 1 ;;
      directory) _coverage_validate_tree "${candidate}" backup || return 1 ;;
      *) _COVERAGE_REASON=invalid-public; return 1 ;;
    esac
    candidate_device="$(stat -Lc '%d' -- "${candidate}")" || return 1
    [[ "${candidate_device}" == "${parent_device}" ]] || { _COVERAGE_REASON=wrong-device; return 1; }
  done

  if [[ "${public_kind}" == directory ]]; then
    if ((${#stages[@]} + ${#backups[@]} > 0)); then
      _COVERAGE_STATE=public-valid-cleanup
    else
      _COVERAGE_STATE=public-valid
    fi
  elif ((${#backups[@]} == 1)); then
    _COVERAGE_STATE=repair-backup
  elif ((${#stages[@]} == 1)); then
    _COVERAGE_STATE=discard-stage
  else
    _COVERAGE_STATE=absent
  fi
}

coverage_classify() {
  (($# == 1)) || return 2
  if _coverage_classify "$1"; then
    _coverage_record "${_COVERAGE_STATE}" ""
  else
    _coverage_record unsafe "${_COVERAGE_REASON}"
    return 1
  fi
}

_coverage_require_lock() {
  [[ -e /proc/$$/fd/6 ]] && flock -n 6 >/dev/null 2>&1
}

coverage_repair() {
  (($# == 2)) || return 2
  local root="$1" expected="$2" parent leaf stage
  case "${expected}" in repair-backup|discard-stage|public-valid-cleanup) ;; *) return 2 ;; esac
  _coverage_require_lock || return 2
  _coverage_classify "${root}" || return 1
  [[ "${_COVERAGE_STATE}" == "${expected}" ]] || return 1
  parent="${root%/*}"
  leaf="${root##*/}"
  stage=("${parent}/.${leaf}.stage."*)
  case "${expected}" in
    repair-backup)
      mv -T -- "${parent}/.${leaf}.backup" "${root}" || return 1
      [[ ! -e "${stage[0]}" && ! -L "${stage[0]}" ]] || rm -rf -- "${stage[0]}"
      ;;
    discard-stage)
      rm -rf -- "${stage[0]}" || return 1
      ;;
    public-valid-cleanup)
      [[ ! -e "${parent}/.${leaf}.backup" ]] || rm -rf -- "${parent}/.${leaf}.backup" || return 1
      [[ ! -e "${stage[0]}" && ! -L "${stage[0]}" ]] || rm -rf -- "${stage[0]}" || return 1
      ;;
  esac
}

coverage_removal_set() {
  (($# == 1)) || return 2
  local root="$1"
  _coverage_require_lock || return 2
  _coverage_classify "${root}" || return 1
  case "${_COVERAGE_STATE}" in
    absent) return 0 ;;
    public-valid) find "${root}" -print0 | LC_ALL=C sort -z ;;
    *) return 1 ;;
  esac
}
