#!/usr/bin/env bash

_package_record() {
  printf '%s\0%s\0' "$1" "$2"
}

_package_path_kind() {
  local path="$1" links
  if [[ -L "${path}" ]]; then
    printf 'symbolic\n'
  elif [[ -d "${path}" ]]; then
    printf 'directory\n'
  elif [[ -f "${path}" ]]; then
    links="$(stat -Lc '%h' -- "${path}" 2>/dev/null)" || {
      printf 'special\n'
      return
    }
    [[ "${links}" == 1 ]] && printf 'file\n' || printf 'hard-linked\n'
  elif [[ -e "${path}" ]]; then
    printf 'special\n'
  else
    printf 'absent\n'
  fi
}

_package_archive_name_valid() {
  [[ "$1" =~ ^devin-desktop-manager-[0-9]+[.][0-9]+[.][0-9]+([.-][0-9A-Za-z][0-9A-Za-z.-]*)?[.]tar[.]gz$ ]]
}

_package_list_entries() {
  local directory="$1" list= attempt
  _PACKAGE_ENTRIES=()
  for attempt in {0..15}; do
    list="${TMPDIR:-/tmp}/devin-desktop-manager.package-list.${UID}.$$.$RANDOM.${attempt}"
    if (umask 077; set -o noclobber; : >"${list}") 2>/dev/null; then break; fi
    list=
  done
  [[ -n "${list}" ]] || { _PACKAGE_REASON=invalid-public; return 1; }
  if ! (ulimit -f 8192; find "${directory}" -mindepth 1 -maxdepth 1 -print0 >"${list}") 2>/dev/null; then
    rm -f -- "${list}"
    _PACKAGE_REASON=invalid-public
    return 1
  fi
  mapfile -d '' -t _PACKAGE_ENTRIES <"${list}"
  rm -f -- "${list}" || { _PACKAGE_REASON=invalid-public; return 1; }
}

_package_validate_file() {
  local path="$1" root_device="$2" kind
  kind="$(_package_path_kind "${path}")"
  case "${kind}" in
    file) ;;
    symbolic|special|hard-linked) _PACKAGE_REASON="${kind}"; return 1 ;;
    *) _PACKAGE_REASON=invalid-public; return 1 ;;
  esac
  [[ "$(stat -Lc '%d' -- "${path}" 2>/dev/null)" == "${root_device}" ]] || {
    _PACKAGE_REASON=wrong-device
    return 1
  }
}

_package_validate_checksum() {
  local archive="$1" checksum="$2" archive_name="$3"
  local line extra expected actual
  IFS= read -r line <"${checksum}" || {
    _PACKAGE_REASON=invalid-public
    return 1
  }
  if IFS= read -r extra < <(tail -n +2 -- "${checksum}"); then
    _PACKAGE_REASON=invalid-public
    return 1
  fi
  [[ "${line}" =~ ^([0-9a-f]{64})[[:space:]][[:space:]]([^/]+)$ &&
    "${BASH_REMATCH[2]}" == "${archive_name}" ]] || {
    _PACKAGE_REASON=invalid-public
    return 1
  }
  expected="${BASH_REMATCH[1]}"
  actual="$(sha256sum -- "${archive}" 2>/dev/null)" || {
    _PACKAGE_REASON=invalid-public
    return 1
  }
  actual="${actual%% *}"
  [[ "${actual}" == "${expected}" ]] || {
    _PACKAGE_REASON=checksum-mismatch
    return 1
  }
}

_package_validate_sidecar() {
  local directory="$1" root_device="$2" path name kind archive= checksum= count=0
  local -a entries=()
  [[ "$(_package_path_kind "${directory}")" == directory ]] || {
    kind="$(_package_path_kind "${directory}")"
    case "${kind}" in
      symbolic|special|hard-linked) _PACKAGE_REASON="${kind}" ;;
      *) _PACKAGE_REASON=invalid-public ;;
    esac
    return 1
  }
  [[ "$(stat -Lc '%a' -- "${directory}" 2>/dev/null)" == 700 ]] || {
    _PACKAGE_REASON=invalid-public
    return 1
  }
  [[ "$(stat -Lc '%d' -- "${directory}" 2>/dev/null)" == "${root_device}" ]] || {
    _PACKAGE_REASON=wrong-device
    return 1
  }

  _package_list_entries "${directory}" || return 1
  entries=("${_PACKAGE_ENTRIES[@]}")
  for path in "${entries[@]}"; do
    count=$((count + 1))
    name="${path##*/}"
    _package_validate_file "${path}" "${root_device}" || return 1
    if [[ "${name}" == SHA256SUMS ]]; then
      [[ -z "${checksum}" ]] || { _PACKAGE_REASON=invalid-public; return 1; }
      checksum="${path}"
    elif [[ "${name}" == devin-desktop-manager-*.tar.gz ]] &&
      _package_archive_name_valid "${name}"; then
      [[ -z "${archive}" ]] || { _PACKAGE_REASON=invalid-public; return 1; }
      archive="${path}"
    else
      _PACKAGE_REASON=invalid-public
      return 1
    fi
  done
  [[ "${count}" == 2 && -n "${archive}" && -n "${checksum}" ]] || {
    _PACKAGE_REASON=invalid-public
    return 1
  }
  _package_validate_checksum "${archive}" "${checksum}" "${archive##*/}" || return 1
  _PACKAGE_VALIDATED_ARCHIVE="${archive}"
}

_package_classify() {
  local root="$1" root_device path name suffix
  local public_checksum= backup_archive
  local -a entries=() public_archives=() stages=() backups=()
  _PACKAGE_STATE=unsafe
  _PACKAGE_REASON=
  _PACKAGE_PUBLIC_ARCHIVE=
  _PACKAGE_STAGE=
  _PACKAGE_BACKUP=

  [[ "${root}" == /* && "${root}" != *[!\ -~]* && "${root}" != / &&
    -d "${root}" && ! -L "${root}" ]] || {
    _PACKAGE_REASON=outside-root
    return 1
  }
  root_device="$(stat -Lc '%d' -- "${root}" 2>/dev/null)" || {
    _PACKAGE_REASON=outside-root
    return 1
  }

  _package_list_entries "${root}" || return 1
  entries=("${_PACKAGE_ENTRIES[@]}")
  for path in "${entries[@]}"; do
    name="${path##*/}"
    case "${name}" in
      devin-desktop-manager-*.tar.gz)
        _package_validate_file "${path}" "${root_device}" || return 1
        _package_archive_name_valid "${name}" || { _PACKAGE_REASON=invalid-public; return 1; }
        public_archives+=("${path}")
        ;;
      SHA256SUMS)
        _package_validate_file "${path}" "${root_device}" || return 1
        public_checksum="${path}"
        ;;
      .devin-desktop-manager.package.stage.*)
        stages+=("${path}")
        ;;
      .devin-desktop-manager.package.backup*)
        backups+=("${path}")
        ;;
    esac
  done

  ((${#public_archives[@]} <= 1)) || { _PACKAGE_REASON=invalid-public; return 1; }
  ((${#stages[@]} <= 1)) || { _PACKAGE_REASON=multiple-stage; return 1; }
  ((${#backups[@]} <= 1)) || { _PACKAGE_REASON=multiple-backup; return 1; }

  if ((${#stages[@]} == 1)); then
    name="${stages[0]##*/}"
    suffix="${name#'.devin-desktop-manager.package.stage.'}"
    [[ "${suffix}" =~ ^[0-9]+[.][0-9a-f]{6}$ ]] || {
      _PACKAGE_REASON=invalid-public
      return 1
    }
    _package_validate_sidecar "${stages[0]}" "${root_device}" || return 1
    _PACKAGE_STAGE="${stages[0]}"
  fi
  if ((${#backups[@]} == 1)); then
    [[ "${backups[0]##*/}" == .devin-desktop-manager.package.backup ]] || {
      _PACKAGE_REASON=invalid-public
      return 1
    }
    _package_validate_sidecar "${backups[0]}" "${root_device}" || return 1
    _PACKAGE_BACKUP="${backups[0]}"
    backup_archive="${_PACKAGE_VALIDATED_ARCHIVE}"
  fi

  if ((${#public_archives[@]} == 1)) && [[ -n "${public_checksum}" ]]; then
    _package_validate_file "${public_archives[0]}" "${root_device}" || return 1
    _package_validate_checksum "${public_archives[0]}" "${public_checksum}" \
      "${public_archives[0]##*/}" || return 1
    _PACKAGE_PUBLIC_ARCHIVE="${public_archives[0]}"
    if [[ -n "${_PACKAGE_STAGE}${_PACKAGE_BACKUP}" ]]; then
      _PACKAGE_STATE=public-valid-cleanup
    else
      _PACKAGE_STATE=public-valid
    fi
  elif ((${#public_archives[@]} == 0)) && [[ -z "${public_checksum}" ]]; then
    if [[ -n "${_PACKAGE_BACKUP}" ]]; then
      _PACKAGE_STATE=repair-backup
    elif [[ -n "${_PACKAGE_STAGE}" ]]; then
      _PACKAGE_STATE=discard-stage
    else
      _PACKAGE_STATE=absent
    fi
  elif [[ -n "${_PACKAGE_BACKUP}" ]]; then
    _PACKAGE_PUBLIC_ARCHIVE="${public_archives[0]:-}"
    _PACKAGE_STATE=repair-partial
  else
    _PACKAGE_REASON=invalid-public
    return 1
  fi

  _PACKAGE_BACKUP_ARCHIVE="${backup_archive:-}"
}

package_classify() {
  (($# == 1)) || return 2
  if _package_classify "$1"; then
    _package_record "${_PACKAGE_STATE}" ""
  else
    _package_record unsafe "${_PACKAGE_REASON}"
    return 1
  fi
}

_package_require_lock() {
  local owner="${BASHPID}" metadata
  [[ -e "/proc/${owner}/fd/6" ]] || return 1
  metadata="$(stat -Lc '%F:%h' -- "/proc/${owner}/fd/6" 2>/dev/null)" || return 1
  [[ "${metadata}" == regular*' file:1' ]] || return 1
  if (exec 6>&-; flock -n "/proc/${owner}/fd/6" true) >/dev/null 2>&1; then
    return 1
  fi
  flock -n 6 >/dev/null 2>&1
}

package_repair() {
  (($# == 2)) || return 2
  local root="$1" expected="$2" backup_archive archive_name
  case "${expected}" in
    repair-backup|repair-partial|discard-stage|public-valid-cleanup) ;;
    *) return 2 ;;
  esac
  _package_require_lock || return 2
  _package_classify "${root}" || return 1
  [[ "${_PACKAGE_STATE}" == "${expected}" ]] || return 1

  case "${expected}" in
    repair-backup|repair-partial)
      backup_archive="${_PACKAGE_BACKUP_ARCHIVE}"
      archive_name="${backup_archive##*/}"
      [[ -z "${_PACKAGE_PUBLIC_ARCHIVE}" ]] || rm -f -- "${_PACKAGE_PUBLIC_ARCHIVE}" || return 1
      [[ ! -e "${root}/SHA256SUMS" ]] || rm -f -- "${root}/SHA256SUMS" || return 1
      mv -T -- "${backup_archive}" "${root}/${archive_name}" || return 1
      mv -T -- "${_PACKAGE_BACKUP}/SHA256SUMS" "${root}/SHA256SUMS" || return 1
      rmdir -- "${_PACKAGE_BACKUP}" || return 1
      [[ -z "${_PACKAGE_STAGE}" ]] || rm -rf -- "${_PACKAGE_STAGE}" || return 1
      ;;
    discard-stage)
      rm -rf -- "${_PACKAGE_STAGE}" || return 1
      ;;
    public-valid-cleanup)
      [[ -z "${_PACKAGE_BACKUP}" ]] || rm -rf -- "${_PACKAGE_BACKUP}" || return 1
      [[ -z "${_PACKAGE_STAGE}" ]] || rm -rf -- "${_PACKAGE_STAGE}" || return 1
      ;;
  esac
}

package_removal_set() {
  (($# == 1)) || return 2
  local root="$1"
  _package_require_lock || return 2
  _package_classify "${root}" || return 1
  case "${_PACKAGE_STATE}" in
    absent) return 0 ;;
    public-valid)
      printf '%s\0%s\0' "${_PACKAGE_PUBLIC_ARCHIVE}" "${root}/SHA256SUMS" |
        LC_ALL=C sort -z
      ;;
    *) return 1 ;;
  esac
}
