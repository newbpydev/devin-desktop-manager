#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "[PMC-U1-C01] all Make targets retain routes and quality-suite ownership" {
  local makefile="${PROJECT_ROOT}/Makefile"
  local expected target

  expected='app-version check clean coverage doctor help install install-manager link link-dev lint package release-check rollback run set-defaults status test uninstall uninstall-yes update verify'
  run bash -c 'awk '\''
    /^\.PHONY:/ { collecting = 1 }
    collecting {
      continued = ($0 ~ /\\$/)
      sub(/^\.PHONY:[[:space:]]*/, "")
      sub(/[[:space:]]*\\$/, "")
      for (i = 1; i <= NF; i++) print $i
      if (!continued) collecting = 0
    }
  '\'' "$1" | LC_ALL=C sort | tr "\n" " "' _ "${makefile}"
  [ "${status}" -eq 0 ]
  [ "${output% }" = "${expected}" ]

  for target in ${expected}; do
    grep -Eq "(^|[[:space:]])${target}([[:space:]:]|$)" "${makefile}"
  done

  grep -Eq '^link:[[:space:]]+link-dev$' "${makefile}"
  grep -Eq '^verify:$' "${makefile}"
  grep -Eq '^release-check:$' "${makefile}"
  grep -Fq '$(call RUN_PREFLIGHT,verify)' "${makefile}"
  grep -Fq '$(call RUN_PREFLIGHT,release-check)' "${makefile}"
  grep -Eq '^test:' "${makefile}"
  grep -Eq '^coverage:' "${makefile}"
  grep -Fq 'BASHCOV_COMMAND_NAME=bats-suite' "${PROJECT_ROOT}/scripts/run-coverage"
}

@test "[PMC-U1-C02] manifest canary executes checkout source directly" {
  local canary="${PROJECT_ROOT}/.github/workflows/manifest-canary.yml"

  grep -Fq 'run: bin/devin-desktop-manager check' "${canary}"
  run grep -F 'make check' "${canary}"
  [ "${status}" -ne 0 ]
}

@test "[PMC-U3-R01] repository keeps prerequisite policy in the preflight registry" {
  local preflight="${PROJECT_ROOT}/scripts/preflight"
  local helper

  [ -x "${preflight}" ]
  for helper in scripts/install-manager scripts/check-coverage scripts/run-coverage \
    scripts/package-release scripts/release-check tests/fixtures/build-mini-deb; do
    grep -Fq 'preflight"' "${PROJECT_ROOT}/${helper}"
  done
  grep -Fq 'readonly -A PROFILE_MEMBERS' "${preflight}"
  grep -Fq '[verify]=' "${preflight}"
  grep -Fq '[release-check]=' "${preflight}"
}

@test "[PMC-U3-R05] repository policy treats hostile MAKEFILES as caller ingress" {
  run grep -F 'MAKEFILES' "${PROJECT_ROOT}/Makefile"
  [ "${status}" -ne 0 ]
  grep -Fq 'MAKEFILES' "${PROJECT_ROOT}/tests/repository.bats"
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
  grep -Fq 'make lint' "${ci}"
  grep -Fq 'bundle exec make coverage' "${ci}"
  grep -Fq 'bundle config set --local deployment true' "${ci}"
  grep -Fq 'bundle install' "${ci}"
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
  grep -Fq 'bundle exec make release-check' "${workflow}"
  grep -Fq 'bundle config set --local deployment true' "${workflow}"
  grep -Fq 'bundle install' "${workflow}"
  run grep -F 'sudo gem install' "${workflow}"
  [ "${status}" -ne 0 ]
  grep -Fq 'SHA256SUMS' "${workflow}"
  grep -Fq 'actions/attest-build-provenance' "${workflow}"
  grep -Fq -- '--draft' "${workflow}"
  grep -Fq 'id-token: write' "${workflow}"
  grep -Fq 'attestations: write' "${workflow}"
}

@test "Ruby coverage dependencies are fully locked" {
  [ -s "${PROJECT_ROOT}/Gemfile" ]
  [ -s "${PROJECT_ROOT}/Gemfile.lock" ]
  grep -Fq 'gem "bashcov", "3.3.0"' "${PROJECT_ROOT}/Gemfile"
  grep -Fq 'bashcov (3.3.0)' "${PROJECT_ROOT}/Gemfile.lock"
  grep -Fq 'BUNDLED WITH' "${PROJECT_ROOT}/Gemfile.lock"
}

@test "[PMC-U5-C01] coverage publication has one threshold and one suite owner" {
  grep -Fq 'COVERAGE_MINIMUM ?= 90' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'scripts/run-coverage' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'scripts/check-coverage' "${PROJECT_ROOT}/scripts/run-coverage"
  grep -Fq 'BASHCOV_COMMAND_NAME=bats-suite' "${PROJECT_ROOT}/scripts/run-coverage"
  run grep -F 'minimum_coverage' "${PROJECT_ROOT}/.simplecov"
  [ "${status}" -ne 0 ]
  [ "$(grep -c -- '--.*tests' "${PROJECT_ROOT}/scripts/run-coverage")" -eq 1 ]
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
