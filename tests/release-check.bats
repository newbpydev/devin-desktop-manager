#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  FIXTURE="${BATS_TEST_TMPDIR}/repository"
  mkdir -p "${FIXTURE}/bin" "${FIXTURE}/scripts"
  cp "${PROJECT_ROOT}/bin/devin-desktop-manager" "${FIXTURE}/bin/"
  cp "${PROJECT_ROOT}/scripts/release-check" "${FIXTURE}/scripts/"
  cp "${PROJECT_ROOT}/Makefile" "${PROJECT_ROOT}/CHANGELOG.md" \
    "${PROJECT_ROOT}/LICENSE" "${FIXTURE}/"
}

@test "release checker accepts a consistent release contract" {
  run "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -eq 0 ]
  [ "${output}" = "Release contract is consistent for v0.1.0" ]
}

@test "release checker rejects a manager version mismatch" {
  sed -i 's/MANAGER_VERSION="0.1.0"/MANAGER_VERSION="9.9.9"/' \
    "${FIXTURE}/bin/devin-desktop-manager"

  run env RELEASE_CHECK_PROJECT_ROOT="${FIXTURE}" \
    "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"manager version 9.9.9 does not match 0.1.0"* ]]
}

@test "release checker rejects a Makefile version mismatch" {
  sed -i 's/VERSION := 0.1.0/VERSION := 9.9.9/' "${FIXTURE}/Makefile"

  run env RELEASE_CHECK_PROJECT_ROOT="${FIXTURE}" \
    "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"Makefile version 9.9.9 does not match 0.1.0"* ]]
}

@test "release checker rejects a missing changelog entry" {
  sed -i 's/## \[0.1.0\]/## [unreleased]/' "${FIXTURE}/CHANGELOG.md"

  run env RELEASE_CHECK_PROJECT_ROOT="${FIXTURE}" \
    "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"CHANGELOG.md has no 0.1.0 release entry"* ]]
}

@test "release checker rejects a missing license" {
  rm "${FIXTURE}/LICENSE"

  run env RELEASE_CHECK_PROJECT_ROOT="${FIXTURE}" \
    "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"LICENSE is missing"* ]]
}

@test "release checker rejects explicit and GitHub tag mismatches" {
  run env RELEASE_TAG=v9.9.9 "${PROJECT_ROOT}/scripts/release-check" 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"tag v9.9.9 must match v0.1.0"* ]]

  run env GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v9.9.9 \
    "${PROJECT_ROOT}/scripts/release-check" 0.1.0
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"tag v9.9.9 must match v0.1.0"* ]]
}

@test "release checker rejects a missing version argument" {
  run "${PROJECT_ROOT}/scripts/release-check"

  [ "${status}" -eq 2 ]
  [ "${output}" = "Usage: release-check VERSION" ]
}

@test "release checker rejects a relative project root override" {
  run env RELEASE_CHECK_PROJECT_ROOT=relative \
    "${PROJECT_ROOT}/scripts/release-check" 0.1.0

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"project root must be an absolute directory"* ]]
}
