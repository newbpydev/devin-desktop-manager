#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "public repository includes the expected community health files" {
  local path

  for path in \
    LICENSE \
    CHANGELOG.md \
    CONTRIBUTING.md \
    CODE_OF_CONDUCT.md \
    SUPPORT.md \
    SECURITY.md \
    docs/INSTALL.md \
    docs/RELEASING.md \
    docs/SECURITY-MAINTAINERS.md \
    .github/ISSUE_TEMPLATE/bug_report.yml \
    .github/ISSUE_TEMPLATE/feature_request.yml \
    .github/ISSUE_TEMPLATE/config.yml \
    .github/pull_request_template.md; do
    [ -s "${PROJECT_ROOT}/${path}" ]
  done
}

@test "license and readme identify ownership and unofficial scope" {
  grep -Fq 'MIT License' "${PROJECT_ROOT}/LICENSE"
  grep -Fq 'Copyright (c) 2026 Juan Gomez' "${PROJECT_ROOT}/LICENSE"
  grep -Eqi 'unofficial|not affiliated' "${PROJECT_ROOT}/README.md"
  grep -Fq 'does not redistribute Devin Desktop' "${PROJECT_ROOT}/README.md"
  grep -Fq 'Linux x86_64' "${PROJECT_ROOT}/README.md"
  grep -Fq 'Bash 4.4' "${PROJECT_ROOT}/README.md"
}

@test "readme documents safe install update rollback defaults and uninstall" {
  local phrase

  for phrase in \
    'make install-manager' \
    'make install' \
    'make check' \
    'make update' \
    'make rollback' \
    'make set-defaults' \
    'make doctor' \
    'make uninstall' \
    'SHA-256' \
    'SECURITY.md'; do
    grep -Fq "${phrase}" "${PROJECT_ROOT}/README.md"
  done
}

@test "security policy separates manager reports from upstream product support" {
  grep -Fq 'private vulnerability reporting' "${PROJECT_ROOT}/SECURITY.md"
  grep -Fq 'Windsurf Support' "${PROJECT_ROOT}/SECURITY.md"
  grep -Fq 'latest v0.x release' "${PROJECT_ROOT}/SECURITY.md"
  grep -Fq 'does not redistribute' "${PROJECT_ROOT}/SECURITY.md"
}

@test "workflows pin third-party actions to full commit SHAs" {
  local workflow

  for workflow in "${PROJECT_ROOT}"/.github/workflows/*.yml; do
    if grep -Eq 'uses: [^@]+@v[0-9]+' "${workflow}"; then
      printf 'Unpinned action reference in %s\n' "${workflow}" >&2
      return 1
    fi
    while IFS= read -r reference; do
      [[ "${reference}" =~ @[0-9a-f]{40}$ ]]
    done < <(sed -nE 's/^[[:space:]]*uses:[[:space:]]*([^#[:space:]]+).*/\1/p' "${workflow}")
  done
}

@test "CI is offline and manifest canary is isolated" {
  local ci="${PROJECT_ROOT}/.github/workflows/ci.yml"
  local canary="${PROJECT_ROOT}/.github/workflows/manifest-canary.yml"

  grep -Fq 'ubuntu-24.04' "${ci}"
  grep -Fq 'make verify' "${ci}"
  grep -Fq 'make coverage' "${ci}"
  grep -Fq 'bashcov -v 3.3.0' "${ci}"
  grep -Fq 'pull_request:' "${ci}"
  run grep -F 'pull_request_target:' "${ci}"
  [ "${status}" -ne 0 ]
  grep -Fq 'contents: read' "${ci}"

  grep -Fq 'schedule:' "${canary}"
  grep -Fq 'workflow_dispatch:' "${canary}"
  grep -Fq 'devin-desktop-manager check' "${canary}"
  run grep -F 'pull_request:' "${canary}"
  [ "${status}" -ne 0 ]
}

@test "release workflow enforces tag version packages checksums and provenance" {
  local workflow="${PROJECT_ROOT}/.github/workflows/release.yml"

  grep -Fq "tags:" "${workflow}"
  grep -Fq "'v*'" "${workflow}"
  grep -Fq 'make release-check' "${workflow}"
  grep -Fq 'bashcov -v 3.3.0' "${workflow}"
  grep -Fq 'SHA256SUMS' "${workflow}"
  grep -Fq 'actions/attest-build-provenance' "${workflow}"
  grep -Fq -- '--draft' "${workflow}"
  grep -Fq 'id-token: write' "${workflow}"
  grep -Fq 'attestations: write' "${workflow}"
}

@test "Dependabot checks pinned GitHub Actions weekly" {
  local config="${PROJECT_ROOT}/.github/dependabot.yml"

  grep -Fq 'package-ecosystem: "github-actions"' "${config}"
  grep -Fq 'interval: "weekly"' "${config}"
}

@test "repository never commits an upstream Devin package" {
  run bash -c 'find "$1" -path "$1/.git" -prune -o -type f \
    \( -name "*.deb" -o -name "Devin-linux-*" \) -print' _ "${PROJECT_ROOT}"

  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}
