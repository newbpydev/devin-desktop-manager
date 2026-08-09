#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "[LIR-U4-R01] portability smoke selects recovery success refusal doctor and retry" {
  local runner="${PROJECT_ROOT}/tests/run-portability-smoke"

  grep -Fq 'LIR-(U1-R0[14]|U2-R06|U3-R01' "${runner}"
  grep -Fq "tests/manager.bats" "${runner}"
  grep -Fq "tests/repository.bats" "${runner}"
  grep -Fq "No tests were selected" "${runner}"
}

@test "preflight associative keys satisfy canonical ShellCheck" {
  local preflight="${PROJECT_ROOT}/scripts/preflight"

  grep -Fq '["install-manager"]=' "${preflight}"
  grep -Fq '["release-check-official"]=' "${preflight}"
  run shellcheck -x -P "${PROJECT_ROOT}" "${preflight}"
  [ "${status}" -eq 0 ]
}

@test "[LIR-U4-R02] compatibility lanes run recovery smoke offline as non-root" {
  local ci="${PROJECT_ROOT}/.github/workflows/ci.yml"
  local job

  for job in portable-canonical portable-debian portable-fedora portable-minimum-toolchain; do
    grep -Fq "${job}:" "${ci}"
  done
  [ "$(grep -c 'tests/run-portability-smoke --assert-offline' "${ci}")" -eq 4 ]
  [ "$(grep -c -- '--network none --user 10001:10001 --read-only' "${ci}")" -eq 3 ]
  grep -Fq 'unshare --net --setuid "$(id -u)" --setgid "$(id -g)"' "${ci}"
}

@test "[LIR-U4-R03] patch release policy aligns version schema docs and companions" {
  local manager="${PROJECT_ROOT}/bin/devin-desktop-manager"
  local plan="${PROJECT_ROOT}/docs/plans/2026-08-09-001-fix-legacy-installation-recovery-plan.md"
  local workflow="${PROJECT_ROOT}/docs/user-workflows-test-plans/legacy-installation-recovery-user-workflow-test.md"
  local workorder="${PROJECT_ROOT}/docs/workorders/legacy-installation-recovery-issues-workorder.md"
  local docs

  grep -Fq 'VERSION := 0.1.1' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'MANAGER_VERSION="0.1.1"' "${manager}"
  grep -Fq 'LEGACY_MANAGER_VERSION="0.1.0"' "${manager}"
  [ "$(grep -c 'SCHEMA_VERSION=1' "${manager}")" -eq 3 ]
  grep -Fq '## [0.1.1] - 2026-08-09' "${PROJECT_ROOT}/CHANGELOG.md"
  grep -Fq 'verification_plan: docs/user-workflows-test-plans/legacy-installation-recovery-user-workflow-test.md' "${plan}"
  grep -Fq 'issue_workorder: docs/workorders/legacy-installation-recovery-issues-workorder.md' "${plan}"
  [ -s "${workflow}" ]
  [ -s "${workorder}" ]

  docs="$(cat "${PROJECT_ROOT}/README.md" "${PROJECT_ROOT}/docs/INSTALL.md" \
    "${PROJECT_ROOT}/SUPPORT.md" "${PROJECT_ROOT}/CONCEPTS.md" \
    "${PROJECT_ROOT}/docs/RELEASING.md")"
  [[ "${docs}" == *"complete initial-manager"* ]]
  [[ "${docs}" == *"recoverable Legacy Installation"* ]]
  [[ "${docs}" == *"Do not add a marker by hand"* ]]
  [[ "${docs}" == *"do not remove persistent lock files"* ]]
  [[ "${docs}" != *"--force-repair"* ]]
}

@test "[LIR-U4-R06] affected 0.1.0 users bootstrap the fixed manager first" {
  local install="${PROJECT_ROOT}/docs/INSTALL.md"
  local readme="${PROJECT_ROOT}/README.md"

  grep -Fq 'verified 0.1.1 source' "${install}"
  grep -Fq 'make install-manager' "${install}"
  grep -Fq 'devin-desktop-manager 0.1.1' "${install}"
  grep -Fq 'old 0.1.0 manager cannot update itself' "${install}"
  grep -Fq 'make install-manager' "${readme}"
  grep -Fq 'make update' "${readme}"
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
  grep -Fq '$(call RUN_BUNDLED_PREFLIGHT,$$preflight_profile)' "${makefile}"
  grep -Fq 'preflight_profile=release-check-official' "${makefile}"
  grep -Eq '^test:' "${makefile}"
  grep -Eq '^coverage:' "${makefile}"
  grep -Fq 'BASHCOV_COMMAND_NAME="bats-suite-${name}"' \
    "${PROJECT_ROOT}/scripts/run-coverage-suite"
}

@test "[PMC-U1-C01] lint policy covers manager scripts and source libraries without directories" {
  local makefile="${PROJECT_ROOT}/Makefile"

  grep -Fq '"$$PROJECT_ROOT/bin/devin-desktop-manager"' "${makefile}"
  grep -Fq '"$$PROJECT_ROOT"/scripts/*' "${makefile}"
  grep -Fq '"$$PROJECT_ROOT"/scripts/lib/*.bash' "${makefile}"
  grep -Fq '[ -f "$$shell_file" ] || continue' "${makefile}"
  grep -Fq 'set -- "$$@" "$$shell_file"' "${makefile}"
  grep -Fq '"$$shellcheck_path" -x -P "$$PROJECT_ROOT" "$$@"' "${makefile}"
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
    tests/fixtures/build-mini-deb; do
    grep -Fq 'preflight"' "${PROJECT_ROOT}/${helper}"
  done
  grep -Fq 'readonly -A PROFILE_MEMBERS' "${preflight}"
  grep -Fq '["verify"]=' "${preflight}"
  grep -Fq '["release-check"]=' "${preflight}"
  grep -Fq '["package-run"]=' "${preflight}"
  grep -Fq '["release-contract"]=' "${preflight}"
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
  grep -Fq 'COVERAGE_MINIMUM ?= 84' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'scripts/run-coverage' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'scripts/check-coverage' "${PROJECT_ROOT}/scripts/run-coverage"
  grep -Fq 'BASHCOV_COMMAND_NAME="bats-suite-${name}"' \
    "${PROJECT_ROOT}/scripts/run-coverage-suite"
  grep -Fq '"${root}" "${output}" bats-suite "${resultsets[@]}"' \
    "${PROJECT_ROOT}/scripts/run-coverage-suite"
  run grep -F 'minimum_coverage' "${PROJECT_ROOT}/.simplecov"
  [ "${status}" -ne 0 ]
  [ "$(grep -Fc 'test_files=("${root}"/tests/*.bats)' \
    "${PROJECT_ROOT}/scripts/run-coverage-suite")" -eq 1 ]
}

@test "[PMC-U6-C01] release route owns one coverage suite and one package handoff" {
  local makefile="${PROJECT_ROOT}/Makefile" release_check="${PROJECT_ROOT}/scripts/release-check"
  grep -Fq '$(call RUN_BUNDLED_PREFLIGHT,$$preflight_profile)' "${makefile}"
  grep -Fq 'preflight_profile=release-check-official' "${makefile}"
  [ "$(grep -Fc '$(DO_LOCKED_COVERAGE);' "${makefile}")" -eq 1 ]
  [ "$(grep -Fc '$(DO_LOCKED_COVERAGE)' "${makefile}")" -eq 2 ]
  [ "$(grep -c 'scripts/package-release' "${makefile}")" -eq 1 ]
  grep -Fq -- '--project-root "$$PROJECT_ROOT"' "${makefile}"
  grep -Fq -- '--release-tag' "${makefile}"
  grep -Fq 'package handoff' "${release_check}"
  run grep -F '$(DO_TEST)' "${makefile}"
  [ "${status}" -eq 0 ]
  [ "$(grep -c '\$(DO_TEST)' "${makefile}")" -eq 2 ]
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

@test "[PMC-U8-R01] repository policy pins portability jobs and one-suite ownership" {
  local ci="${PROJECT_ROOT}/.github/workflows/ci.yml"
  local workflow

  for workflow in "${PROJECT_ROOT}"/.github/workflows/*.yml; do
    run grep -E 'uses: [^@]+@(v[0-9]+|main|master)([[:space:]#]|$)' "${workflow}"
    [ "${status}" -ne 0 ]
  done
  for job in portable-canonical portable-debian portable-fedora portable-minimum-toolchain; do
    grep -Fq "  ${job}:" "${ci}"
  done
  grep -Fq 'runs-on: ubuntu-24.04' "${ci}"
  grep -Fq 'bundle exec make coverage' "${ci}"
  [ "$(grep -c 'bundle exec make coverage' "${ci}")" -eq 1 ]
  grep -Fq 'sudo env HOME="$HOME" TMPDIR="${TMPDIR:-/tmp}" unshare --net --setuid "$(id -u)" --setgid "$(id -g)" -- tests/run-portability-smoke --assert-offline' "${ci}"
  [ "$(grep -c 'BASE_IMAGE: .*@sha256:[0-9a-f]\{64\}' "${ci}")" -eq 3 ]
  [ "$(grep -c 'docker image inspect --format' "${ci}")" -eq 3 ]
  [ "$(grep -c -- '--network none --user 10001:10001 --read-only' "${ci}")" -eq 3 ]
  [ "$(grep -c -- '--tmpfs /tmp:rw,exec,uid=10001,gid=10001,mode=1777' "${ci}")" -eq 3 ]
  grep -Fq 'Legacy `MANAGER`' "${PROJECT_ROOT}/CHANGELOG.md"
  grep -Fq 'outside-root output' "${PROJECT_ROOT}/CHANGELOG.md"
}

@test "[PMC-U8-R02] focused userland jobs share the tagged smoke suite" {
  local ci="${PROJECT_ROOT}/.github/workflows/ci.yml"
  local runner="${PROJECT_ROOT}/tests/run-portability-smoke"
  local fixture="${PROJECT_ROOT}/tests/fixtures/portability-userland.Dockerfile"

  [ -x "${runner}" ]
  for file in makefile preflight output-lock manager coverage release-check repository; do
    grep -Fq "tests/${file}.bats" "${runner}"
  done
  grep -Fq 'U2-R0[2345]' "${runner}"
  grep -Fq 'U8-R0[1-4]' "${runner}"
  [ "$(grep -c 'bats binutils' "${fixture}")" -eq 2 ]
  [ "$(grep -c 'tests/run-portability-smoke --assert-offline' "${ci}")" -eq 4 ]
  run bash -c 'for job in portable-debian portable-fedora portable-minimum-toolchain; do
    block="$(sed -n "/^  ${job}:/,/^  [a-z]/p" "$1")"
    grep -Eq "make (test|verify|coverage)" <<<"${block}" && exit 1
  done
  exit 0' _ "${ci}"
  [ "${status}" -eq 0 ]
}

@test "[PMC-U8-R02] Fedora fixture installs the split script utility" {
  local fixture="${PROJECT_ROOT}/tests/fixtures/portability-userland.Dockerfile"

  run bash -c 'sed -n "/elif command -v dnf/,/dnf clean all/p" "$1" |
    grep -Fq "tar util-linux util-linux-script xdg-utils"' _ "${fixture}"
  [ "${status}" -eq 0 ]
}

@test "[PMC-U8-R03] minimum fixture pins Bash 4.4 and GNU Make 4.3 inputs" {
  local ci="${PROJECT_ROOT}/.github/workflows/ci.yml"
  local fixture="${PROJECT_ROOT}/tests/fixtures/minimum-toolchain.Dockerfile"

  grep -Fq 'ARG BASH_VERSION=4.4' "${fixture}"
  grep -Fq 'ARG MAKE_VERSION=4.3' "${fixture}"
  [ "$(grep -c 'ARG .*_SHA256=[0-9a-f]\{64\}' "${fixture}")" -eq 2 ]
  grep -Fq 'bash --version' "${ci}"
  grep -Fq 'make --version' "${ci}"
  grep -Fq 'Observed moving Ubuntu tool versions' "${ci}"
}

@test "[PMC-U8-R04] smoke runner proves enforced offline isolation" {
  local runner="${PROJECT_ROOT}/tests/run-portability-smoke"
  local canary="${PROJECT_ROOT}/.github/workflows/manifest-canary.yml"

  run "${runner}"
  [ "${status}" -eq 2 ]
  run env PORTABILITY_SMOKE_SKIP_TESTS=1 "${runner}" --assert-offline
  [ "${status}" -eq 1 ]
  grep -Fq '$(id -u)' "${runner}"
  grep -Fq '/proc/net/dev' "${runner}"
  run grep -F '/sys/class/net' "${runner}"
  [ "${status}" -ne 0 ]
  grep -Fq 'curl --disable --silent --show-error --max-time 2' "${runner}"
  grep -Fq 'https://example.com/' "${runner}"
  grep -Fq 'No tests were selected' "${runner}"
  grep -Fq 'bin/devin-desktop-manager check' "${canary}"
  run grep -R -F 'bin/devin-desktop-manager check' "${PROJECT_ROOT}/.github/workflows" --exclude=manifest-canary.yml
  [ "${status}" -ne 0 ]
}

@test "[PMC-U8-R05] release revalidates exactly one pair at final handoff" {
  local workflow="${PROJECT_ROOT}/.github/workflows/release.yml"
  local validate_line attest_line upload_line

  validate_line="$(grep -n 'scripts/release-check --project-root' "${workflow}" | cut -d: -f1)"
  attest_line="$(grep -n 'name: Attest source archive provenance' "${workflow}" | cut -d: -f1)"
  upload_line="$(grep -n 'gh release create' "${workflow}" | cut -d: -f1)"
  [ -n "${validate_line}" ]
  [ "${validate_line}" -lt "${attest_line}" ]
  [ "${attest_line}" -lt "${upload_line}" ]
  grep -Fq "archive=dist/devin-desktop-manager-%s.tar.gz" "${workflow}"
  grep -Fq 'subject-path: ${{ steps.handoff.outputs.archive }}' "${workflow}"
  grep -Fq 'RELEASE_ARCHIVE: ${{ steps.handoff.outputs.archive }}' "${workflow}"
  grep -Fq '"${RELEASE_ARCHIVE}"' "${workflow}"
  run grep -F 'dist/devin-desktop-manager-*.tar.gz' "${workflow}"
  [ "${status}" -ne 0 ]
}

@test "[PMC-U8-R06] public guidance shares compatibility and recovery boundaries" {
  local docs

  docs="$(cat "${PROJECT_ROOT}/README.md" "${PROJECT_ROOT}/docs/INSTALL.md" \
    "${PROJECT_ROOT}/SUPPORT.md" "${PROJECT_ROOT}/CONTRIBUTING.md" \
    "${PROJECT_ROOT}/docs/RELEASING.md" "${PROJECT_ROOT}/docs/SECURITY-MAINTAINERS.md")"
  for phrase in \
    'GNU Make 4.3' \
    'local same-device filesystem' \
    'target classes' \
    'status 2' \
    'exact Git root' \
    'extracted source' \
    'MANAGER' \
    'outside-root output' \
    'retry the same command' \
    'package manager'; do
    [[ "${docs}" == *"${phrase}"* ]]
  done
}

@test "[PMC-U8-R07] workflow evidence and issue signoffs are traceable" {
  local workflow="${PROJECT_ROOT}/docs/user-workflows-test-plans/portable-make-commands-user-workflow-test.md"
  local workorder="${PROJECT_ROOT}/docs/workorders/portable-make-commands-issues-workorder.md"

  grep -Fq 'PMC-WF-025' "${workflow}"
  grep -Fq 'Browser navigation and URL state | N/A' "${workflow}"
  grep -Fq 'Workflow plan executed' "${workflow}"
  grep -Fq 'Implementation |' "${workorder}"
  grep -Fq 'Test |' "${workorder}"
  grep -Fq 'Review |' "${workorder}"
  grep -Fq 'Signed off' "${workorder}"
  run awk '/^## Issue Register/{inside=1; next} /^## Issue Details/{inside=0} inside && /\| Open \|/' "${workorder}"
  [ "${status}" -eq 0 ]
  [ -z "${output}" ]
}
