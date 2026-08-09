#!/usr/bin/env bats

set -e

load helpers/portable

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  PACKAGE_LIBRARY="${PROJECT_ROOT}/scripts/lib/package-output.bash"
  FIXTURE="${BATS_TEST_TMPDIR}/repository"
  mkdir -p "${FIXTURE}/bin" "${FIXTURE}/scripts"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" "${FIXTURE}/bin/"
  cp "${PROJECT_ROOT}/scripts/release-check" "${PROJECT_ROOT}/scripts/preflight" \
    "${FIXTURE}/scripts/"
  cp "${PROJECT_ROOT}/Makefile" "${PROJECT_ROOT}/CHANGELOG.md" \
    "${PROJECT_ROOT}/LICENSE" "${FIXTURE}/"
  printf '/dist/\n/.devin-desktop-manager.outputs.lock\n' >"${FIXTURE}/.gitignore"
  git -C "${FIXTURE}" init --quiet
  git -C "${FIXTURE}" add .
  git -C "${FIXTURE}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet -m fixture
  resolve_harness_tools bash chmod cmp find flock git gzip mkdir mv readlink rm sha256sum sleep sort stat tar
}

classify_package() {
  local root="$1" result="${BATS_TEST_TMPDIR}/package-classification"
  run bash -c 'source "$1"; package_classify "$2" >"$3"; status=$?; mapfile -d "" -t fields <"$3"; printf "%s|%s\n" "${fields[0]:-}" "${fields[1]:-}"; exit "$status"' \
    _ "${PACKAGE_LIBRARY}" "${root}" "${result}"
}

@test "[PMC-U7-R02] unsafe coverage preserves a valid package pair" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout"
  make_clean_checkout "${root}"
  make_coverage_tree "${root}/coverage"
  printf 'foreign\n' >"${root}/coverage/unknown"
  make_package_pair "${root}/dist"
  snapshot_tree "${root}/coverage" "${BATS_TEST_TMPDIR}/coverage-before"
  snapshot_tree "${root}/dist" "${BATS_TEST_TMPDIR}/dist-before"

  run "${root}/scripts/clean-generated" --project-root "${root}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"unknown-coverage-entry"* ]]
  snapshot_tree "${root}/coverage" "${BATS_TEST_TMPDIR}/coverage-after"
  snapshot_tree "${root}/dist" "${BATS_TEST_TMPDIR}/dist-after"
  cmp "${BATS_TEST_TMPDIR}/coverage-before" "${BATS_TEST_TMPDIR}/coverage-after"
  cmp "${BATS_TEST_TMPDIR}/dist-before" "${BATS_TEST_TMPDIR}/dist-after"
}

@test "[PMC-U7-R06] direct clean enforces FD6 root usage and stderr failures" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout"
  local stdout_file="${BATS_TEST_TMPDIR}/stdout" stderr_file="${BATS_TEST_TMPDIR}/stderr"
  make_clean_checkout "${root}"

  run "${root}/scripts/clean-generated" --output-lock-fd 6 --project-root "${root}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == Usage:* ]]

  mkdir -p "${root}/coverage"
  printf 'foreign\n' >"${root}/coverage/unknown"
  run "${HARNESS_TOOLS[bash]}" -c '"$1" --project-root "$2" >"$3" 2>"$4"' \
    _ "${root}/scripts/clean-generated" "${root}" "${stdout_file}" "${stderr_file}"
  [ "${status}" -eq 1 ]
  [ ! -s "${stdout_file}" ]
  grep -Fq 'unknown-coverage-entry' "${stderr_file}"

  run "${PROJECT_ROOT}/scripts/clean-generated" --project-root "${root}"
  [ "${status}" -eq 2 ]
}

repair_package() {
  local root="$1" expected="$2" lock="${BATS_TEST_TMPDIR}/package.lock"
  : >"${lock}"
  run bash -c 'source "$1"; exec 6<>"$3"; flock -n 6; package_repair "$2" "$4"' \
    _ "${PACKAGE_LIBRARY}" "${root}" "${lock}" "${expected}"
}

make_package_checkout() {
  local root="$1"
  mkdir -p "${root}/scripts/lib"
  cp "${PROJECT_ROOT}/scripts/package-release" "${PROJECT_ROOT}/scripts/output-lock" \
    "${PROJECT_ROOT}/scripts/preflight" "${root}/scripts/"
  cp "${PACKAGE_LIBRARY}" "${root}/scripts/lib/package-output.bash"
  chmod 0755 "${root}/scripts/package-release" "${root}/scripts/output-lock" \
    "${root}/scripts/preflight"
  printf '/dist*/\n/.devin-desktop-manager.outputs.lock\n' >"${root}/.gitignore"
  printf 'tracked\n' >"${root}/README.md"
  git -C "${root}" init --quiet
  git -C "${root}" add .
  git -C "${root}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet -m fixture
}

run_locked_package() {
  local root="$1" lock="${1}/.devin-desktop-manager.outputs.lock"
  shift
  : >"${lock}"
  run bash -c 'exec 6<>"$1"; flock -n 6; shift; exec "$@"' \
    _ "${lock}" "${root}/scripts/package-release" --project-root "${root}" \
    --output-lock-fd 6 "$@"
}

@test "[PMC-U6-C01] release checker accepts a consistent release contract" {
  run "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -eq 0 ]
  [ "${output}" = "Release contract is consistent for v0.1.0" ]
}

@test "release checker rejects a manager version mismatch" {
  sed -i 's/MANAGER_VERSION="0.1.0"/MANAGER_VERSION="9.9.9"/' \
    "${FIXTURE}/bin/devin-desktop-manager"

  run "${FIXTURE}/scripts/release-check" --project-root "${FIXTURE}" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"manager version 9.9.9 does not match 0.1.0"* ]]
}

@test "release checker rejects a Makefile version mismatch" {
  sed -i 's/VERSION := 0.1.0/VERSION := 9.9.9/' "${FIXTURE}/Makefile"

  run "${FIXTURE}/scripts/release-check" --project-root "${FIXTURE}" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Makefile version 9.9.9 does not match 0.1.0"* ]]
}

@test "release checker rejects a missing changelog entry" {
  sed -i 's/## \[0.1.0\]/## [unreleased]/' "${FIXTURE}/CHANGELOG.md"

  run "${FIXTURE}/scripts/release-check" --project-root "${FIXTURE}" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"CHANGELOG.md has no 0.1.0 release entry"* ]]
}

@test "release checker rejects a missing license" {
  rm "${FIXTURE}/LICENSE"

  run "${FIXTURE}/scripts/release-check" --project-root "${FIXTURE}" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"LICENSE is missing"* ]]
}

@test "[PMC-U6-C01] release checker rejects explicit and GitHub tag mismatches" {
  run "${PROJECT_ROOT}/scripts/release-check" --release-tag v9.9.9 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"tag v9.9.9 must match v0.1.0"* ]]

  run "${PROJECT_ROOT}/scripts/release-check" --release-tag v9.9.9 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"tag v9.9.9 must match v0.1.0"* ]]
}

@test "[PMC-U6-R02] official release requires clean annotated tag and workflow commit provenance" {
  local repository="${BATS_TEST_TMPDIR}/official"
  cp -a "${PROJECT_ROOT}/." "${repository}"
  rm -rf "${repository}/.git" "${repository}/dist" "${repository}/coverage"
  git -C "${repository}" init --quiet
  git -C "${repository}" add .
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet -m fixture
  local commit
  commit="$(git -C "${repository}" rev-parse HEAD)"

  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    tag -a v0.1.0 -m release
  mkdir -p "${repository}/dist"
  make_package_pair "${repository}/dist" devin-desktop-manager-0.1.0.tar.gz
  run env GITHUB_SHA="${commit}" "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 0 ]

  mkdir -p "${repository}/generated [release]/coverage" \
    "${repository}/generated [release]/dist"
  printf 'generated coverage\n' \
    >"${repository}/generated [release]/coverage/result.json"
  make_package_pair "${repository}/generated [release]/dist" \
    devin-desktop-manager-0.1.0.tar.gz
  run env GITHUB_SHA="${commit}" MAKE_COVERAGE_DIR='generated [release]/coverage' \
    MAKE_DIST_DIR='generated [release]/dist' "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 0 ]

  printf 'tracked input\n' \
    >"${repository}/generated [release]/coverage/tracked.txt"
  git -C "${repository}" add -- 'generated [release]/coverage/tracked.txt'
  run env GITHUB_SHA="${commit}" MAKE_COVERAGE_DIR='generated [release]/coverage' \
    MAKE_DIST_DIR='generated [release]/dist' "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 1 ]
  [[ "${output}" == *'generated output roots must not contain tracked release inputs'* ]]
  git -C "${repository}" rm --cached --quiet -- \
    'generated [release]/coverage/tracked.txt'
  rm -rf "${repository}/generated [release]"

  printf 'dirty\n' >>"${repository}/README.md"
  run env GITHUB_SHA="${commit}" "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"clean index and working tree"* ]]
  git -C "${repository}" checkout -- README.md

  run env GITHUB_SHA=0000000000000000000000000000000000000000 \
    "${repository}/scripts/release-check" --project-root "${repository}" \
    --release-tag v0.1.0 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"workflow commit"* ]]

  git -C "${repository}" tag -d v0.1.0 >/dev/null
  git -C "${repository}" tag v0.1.0
  run env GITHUB_SHA="${commit}" "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"annotated tag"* ]]
}

@test "release checker rejects a missing version argument" {
  run "${PROJECT_ROOT}/scripts/release-check"

  [ "${status}" -eq 2 ]
  [[ "${output}" == "Usage: release-check [--project-root ROOT]"* ]]
}

@test "release checker rejects a relative project root override" {
  run "${PROJECT_ROOT}/scripts/release-check" --project-root relative 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"project root must be an absolute directory"* ]]
}

@test "[PMC-U6-R01] release checker rejects extracted nested and no-HEAD roots" {
  local extracted="${BATS_TEST_TMPDIR}/extracted" parent="${BATS_TEST_TMPDIR}/parent"
  local nested="${parent}/nested" no_head="${BATS_TEST_TMPDIR}/no-head" root
  for root in "${extracted}" "${nested}" "${no_head}"; do
    mkdir -p "${root}"
  done
  git -C "${parent}" init --quiet
  git -C "${no_head}" init --quiet

  for root in "${extracted}" "${nested}" "${no_head}"; do
    run "${PROJECT_ROOT}/scripts/release-check" --project-root "${root}" 0.1.0
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"exact Git root"*"HEAD"* ]]
  done
}

@test "[PMC-U6-R06] official handoff requires the immediate exact archive checksum pair" {
  local repository="${BATS_TEST_TMPDIR}/handoff" commit archive
  cp -a "${PROJECT_ROOT}/." "${repository}"
  rm -rf "${repository}/.git" "${repository}/dist" "${repository}/coverage"
  git -C "${repository}" init --quiet
  git -C "${repository}" add .
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet -m fixture
  commit="$(git -C "${repository}" rev-parse HEAD)"
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    tag -a v0.1.0 -m release
  make_package_pair "${repository}/dist" devin-desktop-manager-0.1.0.tar.gz

  run env GITHUB_SHA="${commit}" "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 0 ]

  archive="${repository}/dist/devin-desktop-manager-0.1.0.tar.gz"
  printf 'changed\n' >>"${archive}"
  run env GITHUB_SHA="${commit}" "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"package handoff"* ]]
  make_package_pair "${repository}/dist" devin-desktop-manager-0.1.0.tar.gz
  printf 'extra\n' >"${repository}/dist/other.tar.gz"
  run env GITHUB_SHA="${commit}" "${repository}/scripts/release-check" \
    --project-root "${repository}" --release-tag v0.1.0 0.1.0
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"package handoff"* ]]
}

@test "[PMC-U6-R04] package classifier preserves unknown siblings and valid public wins" {
  local root="${BATS_TEST_TMPDIR}/dist"
  mkdir -p "${root}"
  printf 'foreign\n' >"${root}/keep.txt"

  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "absent|" ]

  make_package_pair "${root}"
  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "public-valid|" ]

  make_package_pair "${root}/.devin-desktop-manager.package.backup"
  chmod 0700 "${root}/.devin-desktop-manager.package.backup"
  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "public-valid-cleanup|" ]
  [ "$(<"${root}/keep.txt")" = foreign ]
}

@test "[PMC-U6-R04] one valid backup repairs absent and exact one-file partial public" {
  local root="${BATS_TEST_TMPDIR}/dist" backup
  mkdir -p "${root}"
  backup="${root}/.devin-desktop-manager.package.backup"
  make_package_pair "${backup}"
  chmod 0700 "${backup}"

  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "repair-backup|" ]
  repair_package "${root}" repair-backup
  [ "${status}" -eq 0 ]
  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "public-valid|" ]

  mv "${root}/devin-desktop-manager-1.2.3.tar.gz" "${BATS_TEST_TMPDIR}/saved-archive"
  make_package_pair "${backup}"
  chmod 0700 "${backup}"
  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "repair-partial|" ]
  repair_package "${root}" repair-partial
  [ "${status}" -eq 0 ]
  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "public-valid|" ]
}

@test "[PMC-U6-R04] one exact orphan stage is discarded" {
  local root="${BATS_TEST_TMPDIR}/dist"
  local stage="${root}/.devin-desktop-manager.package.stage.42.abcdef"
  mkdir -p "${root}"
  make_package_pair "${stage}"
  chmod 0700 "${stage}"

  classify_package "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "discard-stage|" ]
  repair_package "${root}" discard-stage
  [ "${status}" -eq 0 ]
  [ ! -e "${stage}" ]
  classify_package "${root}"
  [ "${output}" = "absent|" ]
}

@test "[PMC-U6-R04] malformed multiple symbolic special hard-linked and mismatched states fail closed" {
  local root="${BATS_TEST_TMPDIR}/dist" archive stage

  mkdir -p "${root}/.devin-desktop-manager.package.stage.bad"
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|invalid-public" ]
  rm -rf "${root}" && mkdir -p "${root}"

  for stage in .devin-desktop-manager.package.stage.1.abcdef \
    .devin-desktop-manager.package.stage.2.abcdef; do
    make_package_pair "${root}/${stage}"
    chmod 0700 "${root}/${stage}"
  done
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|multiple-stage" ]
  rm -rf "${root}" && mkdir -p "${root}"

  make_package_pair "${root}/.devin-desktop-manager.package.backup"
  make_package_pair "${root}/.devin-desktop-manager.package.backup.extra"
  chmod 0700 "${root}"/.devin-desktop-manager.package.backup*
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|multiple-backup" ]
  rm -rf "${root}" && mkdir -p "${root}"

  archive="${root}/devin-desktop-manager-1.2.3.tar.gz"
  ln -s nowhere "${archive}"
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|symbolic" ]
  rm -rf "${root}" && mkdir -p "${root}"

  mkfifo "${archive}"
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|special" ]
  rm -rf "${root}" && mkdir -p "${root}"

  printf 'linked\n' >"${BATS_TEST_TMPDIR}/linked-archive"
  ln "${BATS_TEST_TMPDIR}/linked-archive" "${archive}"
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|hard-linked" ]
  rm -rf "${root}" && mkdir -p "${root}"

  make_package_pair "${root}"
  printf 'changed\n' >>"${archive}"
  classify_package "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|checksum-mismatch" ]
}

@test "[PMC-U6-R04] mutations require locked FD6 and removal lists only package-owned public files" {
  local root="${BATS_TEST_TMPDIR}/dist" result="${BATS_TEST_TMPDIR}/removal-set"
  local lock="${BATS_TEST_TMPDIR}/package.lock"
  mkdir -p "${root}"
  make_package_pair "${root}"
  printf 'foreign\n' >"${root}/keep.txt"

  run bash -c 'exec 6>&-; source "$1"; package_repair "$2" public-valid-cleanup' \
    _ "${PACKAGE_LIBRARY}" "${root}"
  [ "${status}" -eq 2 ]
  run bash -c 'exec 6>&-; source "$1"; package_removal_set "$2"' \
    _ "${PACKAGE_LIBRARY}" "${root}"
  [ "${status}" -eq 2 ]

  : >"${lock}"
  run bash -c 'source "$1"; exec 6<>"$3"; flock -n 6; package_removal_set "$2" >"$4"; status=$?; mapfile -d "" -t paths <"$4"; printf "%s\n" "${paths[@]}"; exit "$status"' \
    _ "${PACKAGE_LIBRARY}" "${root}" "${lock}" "${result}"
  [ "${status}" -eq 0 ]
  [ "${lines[0]}" = "${root}/SHA256SUMS" ]
  [ "${lines[1]}" = "${root}/devin-desktop-manager-1.2.3.tar.gz" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "[PMC-U6-R01] package-release requires an exact Git root and contained output" {
  local repository="${BATS_TEST_TMPDIR}/repository" outside="${BATS_TEST_TMPDIR}/outside"
  local extracted="${BATS_TEST_TMPDIR}/extracted" nested="${repository}/nested"
  make_package_checkout "${repository}"

  run "${repository}/scripts/package-release" --project-root "${repository}" 1.2.3 dist
  [ "${status}" -eq 0 ]
  [ -f "${repository}/.devin-desktop-manager.outputs.lock" ]
  [ -f "${repository}/dist/devin-desktop-manager-1.2.3.tar.gz" ]
  [ -f "${repository}/dist/SHA256SUMS" ]

  mkdir -p "${extracted}/scripts/lib" "${nested}"
  cp "${repository}/scripts/package-release" "${extracted}/scripts/package-release"
  cp "${PACKAGE_LIBRARY}" "${extracted}/scripts/lib/package-output.bash"
  chmod 0755 "${extracted}/scripts/package-release"
  run bash -c 'exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --output-lock-fd 6 1.2.3 dist' \
    _ "${repository}/.devin-desktop-manager.outputs.lock" \
    "${extracted}/scripts/package-release" "${extracted}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"exact Git root"* ]]
  [ ! -e "${extracted}/dist" ]

  run_locked_package "${repository}" 1.2.3 ../outside
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"beneath the exact Git root"* ]]
  [ ! -e "${outside}" ]

  cp "${repository}/scripts/package-release" "${nested}/package-release"
  run bash -c 'exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --output-lock-fd 6 1.2.3 dist' \
    _ "${repository}/.devin-desktop-manager.outputs.lock" "${nested}/package-release" "${nested}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"exact Git root"* ]]
  [ ! -e "${nested}/dist" ]
}

@test "[PMC-U6-R02] package-release official mode requires clean annotated workflow provenance" {
  local repository="${BATS_TEST_TMPDIR}/repository" commit
  make_package_checkout "${repository}"
  commit="$(git -C "${repository}" rev-parse HEAD)"
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    tag -a v1.2.3 -m release

  run_locked_package "${repository}" --release-mode v1.2.3 "${commit}" 1.2.3 dist
  [ "${status}" -eq 0 ]

  mkdir -p "${repository}/generated [release]/coverage"
  printf 'generated coverage\n' \
    >"${repository}/generated [release]/coverage/result.json"
  : >"${repository}/.devin-desktop-manager.outputs.lock"
  run env MAKE_COVERAGE_DIR='generated [release]/coverage' bash -c \
    'exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --release-mode v1.2.3 "$4" --output-lock-fd 6 1.2.3 "generated [release]/dist"' \
    _ "${repository}/.devin-desktop-manager.outputs.lock" \
    "${repository}/scripts/package-release" "${repository}" "${commit}"
  [ "${status}" -eq 0 ]

  printf 'tracked input\n' \
    >"${repository}/generated [release]/coverage/tracked.txt"
  git -C "${repository}" add -- 'generated [release]/coverage/tracked.txt'
  run env MAKE_COVERAGE_DIR='generated [release]/coverage' bash -c \
    'exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --release-mode v1.2.3 "$4" --output-lock-fd 6 1.2.3 "generated [release]/dist"' \
    _ "${repository}/.devin-desktop-manager.outputs.lock" \
    "${repository}/scripts/package-release" "${repository}" "${commit}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *'generated output roots must not contain tracked release inputs'* ]]
  git -C "${repository}" rm --cached --quiet -- \
    'generated [release]/coverage/tracked.txt'
  rm -rf "${repository}/generated [release]"

  printf 'dirty\n' >>"${repository}/README.md"
  run_locked_package "${repository}" --release-mode v1.2.3 "${commit}" 1.2.3 dist
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"clean index and working tree"* ]]
  git -C "${repository}" checkout -- README.md

  run_locked_package "${repository}" --release-mode v1.2.3 \
    0000000000000000000000000000000000000000 1.2.3 dist
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"workflow commit"* ]]

  git -C "${repository}" tag -d v1.2.3 >/dev/null
  git -C "${repository}" tag v1.2.3
  run_locked_package "${repository}" --release-mode v1.2.3 "${commit}" 1.2.3 dist
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"annotated tag"* ]]
}

@test "[PMC-U6-R05] package-release uses dirty tracked bytes deterministically" {
  local repository="${BATS_TEST_TMPDIR}/repository"
  make_package_checkout "${repository}"
  printf 'dirty tracked\n' >"${repository}/README.md"
  printf 'untracked secret\n' >"${repository}/secret.txt"

  run_locked_package "${repository}" 1.2.3 dist-one
  [ "${status}" -eq 0 ]
  run env LC_ALL=C TZ=UTC bash -c 'umask 022; exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --output-lock-fd 6 1.2.3 dist-two' \
    _ "${repository}/.devin-desktop-manager.outputs.lock" \
    "${repository}/scripts/package-release" "${repository}"
  [ "${status}" -eq 0 ]

  cmp "${repository}/dist-one/devin-desktop-manager-1.2.3.tar.gz" \
    "${repository}/dist-two/devin-desktop-manager-1.2.3.tar.gz"
  cmp "${repository}/dist-one/SHA256SUMS" "${repository}/dist-two/SHA256SUMS"
  run tar -xOzf "${repository}/dist-one/devin-desktop-manager-1.2.3.tar.gz" \
    devin-desktop-manager-1.2.3/README.md
  [ "${status}" -eq 0 ]
  [ "${output}" = "dirty tracked" ]
  run tar -tzf "${repository}/dist-one/devin-desktop-manager-1.2.3.tar.gz"
  [[ "${output}" != *"secret.txt"* ]]
}

@test "[PMC-U6-R03] package-release handled generation failure preserves prior pair and unknown siblings" {
  local repository="${BATS_TEST_TMPDIR}/repository" before="${BATS_TEST_TMPDIR}/before"
  local after="${BATS_TEST_TMPDIR}/after" shim_bin="${BATS_TEST_TMPDIR}/bin"
  make_package_checkout "${repository}"
  run_locked_package "${repository}" 1.2.3 dist
  [ "${status}" -eq 0 ]
  printf 'foreign\n' >"${repository}/dist/keep.txt"
  snapshot_tree "${repository}/dist" "${before}"

  make_command_shim tar "${HARNESS_TOOLS[tar]}" "${BATS_TEST_TMPDIR}/tar.log" fail:1:23 >/dev/null
  run env PATH="${shim_bin}:${PATH}" bash -c \
    'exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --output-lock-fd 6 1.2.3 dist' \
    _ "${repository}/.devin-desktop-manager.outputs.lock" \
    "${repository}/scripts/package-release" "${repository}"
  [ "${status}" -eq 1 ]
  snapshot_tree "${repository}/dist" "${after}"
  cmp "${before}" "${after}"
}

@test "[PMC-U6-R07] package-release rolls back every handled publication transition" {
  local repository call before after shim_bin="${BATS_TEST_TMPDIR}/bin"
  for call in 1 2 3 4; do
    repository="${BATS_TEST_TMPDIR}/repository-${call}"
    before="${BATS_TEST_TMPDIR}/before-${call}"
    after="${BATS_TEST_TMPDIR}/after-${call}"
    make_package_checkout "${repository}"
    run_locked_package "${repository}" 1.2.3 dist
    [ "${status}" -eq 0 ]
    printf 'foreign\n' >"${repository}/dist/keep.txt"
    snapshot_tree "${repository}/dist" "${before}"
    rm -rf "${shim_bin}"
    make_command_shim mv "${HARNESS_TOOLS[mv]}" "${BATS_TEST_TMPDIR}/mv-${call}.log" \
      "fail:${call}:23" >/dev/null

    run env PATH="${shim_bin}:${PATH}" bash -c \
      'exec 6<>"$1"; flock -n 6; "$2" --project-root "$3" --output-lock-fd 6 1.2.3 dist' \
      _ "${repository}/.devin-desktop-manager.outputs.lock" \
      "${repository}/scripts/package-release" "${repository}"
    [ "${status}" -eq 1 ]
    snapshot_tree "${repository}/dist" "${after}"
    cmp "${before}" "${after}"
  done
}
