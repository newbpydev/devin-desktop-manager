#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CALL_LOG="${BATS_TEST_TMPDIR}/manager-calls"
  MOCK_MANAGER="${BATS_TEST_TMPDIR}/mock-manager"
  TEST_HOME="${BATS_TEST_TMPDIR}/home"
  export CALL_LOG

  mkdir -p "${TEST_HOME}"
  cat >"${MOCK_MANAGER}" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CALL_LOG}"
EOF
  chmod 0755 "${MOCK_MANAGER}"
}

@test "project keeps executable manager and release scripts" {
  [ -x "${PROJECT_ROOT}/bin/devin-desktop-manager" ]
  [ -x "${PROJECT_ROOT}/scripts/install-manager" ]
  [ -x "${PROJECT_ROOT}/scripts/check-coverage" ]
  [ -x "${PROJECT_ROOT}/scripts/package-release" ]
  [ -x "${PROJECT_ROOT}/scripts/release-check" ]
}

@test "help exposes install lifecycle quality and release commands" {
  run make --no-print-directory -s -C "${PROJECT_ROOT}" help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"install-manager"* ]]
  [[ "${output}" == *"set-defaults"* ]]
  [[ "${output}" == *"rollback"* ]]
  [[ "${output}" == *"doctor"* ]]
  [[ "${output}" == *"verify"* ]]
  [[ "${output}" == *"package"* ]]
  [[ "${output}" == *"release-check"* ]]
}

@test "coverage target enforces the public repository threshold" {
  grep -Fq 'coverage:' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'COVERAGE_MINIMUM ?= 90' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'make coverage' "${PROJECT_ROOT}/CONTRIBUTING.md"
  grep -Fq 'minimum_coverage ENV.fetch("COVERAGE_MINIMUM", "90")' \
    "${PROJECT_ROOT}/.simplecov"
}

@test "lifecycle targets forward exactly one command to the manager" {
  local target

  for target in status check update rollback set-defaults doctor; do
    run make --no-print-directory -s -C "${PROJECT_ROOT}" \
      MANAGER="${MOCK_MANAGER}" "${target}"
    [ "${status}" -eq 0 ]
  done

  run cat "${CALL_LOG}"
  [ "${status}" -eq 0 ]
  [ "${output}" = $'status\ncheck\nupdate\nrollback\nset-defaults\ndoctor' ]
}

@test "uninstall-yes forwards explicit noninteractive confirmation" {
  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    MANAGER="${MOCK_MANAGER}" uninstall-yes

  [ "${status}" -eq 0 ]
  run tail -n 1 "${CALL_LOG}"
  [ "${output}" = "uninstall --yes" ]
}

@test "install-manager atomically copies an independent executable" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" MANAGER="${installed}" install-manager

  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
  [ ! -L "${installed}" ]
  [ "$("${installed}" --version)" = "devin-desktop-manager 0.1.0" ]

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" MANAGER="${installed}" install-manager
  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
}

@test "install-manager migrates the project development symlink" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  mkdir -p "$(dirname "${installed}")"
  ln -s "${PROJECT_ROOT}/bin/devin-desktop-manager" "${installed}"
  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" MANAGER="${installed}" install-manager

  [ "${status}" -eq 0 ]
  [ -x "${installed}" ]
  [ ! -L "${installed}" ]
}

@test "install-manager refuses an unrelated executable" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  mkdir -p "$(dirname "${installed}")"
  printf '#!/usr/bin/env bash\nexit 0\n' >"${installed}"
  chmod 0755 "${installed}"
  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" MANAGER="${installed}" install-manager

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"refusing to replace unrelated path"* ]]
  grep -q 'exit 0' "${installed}"
}

@test "install-manager validates its arguments and source identity" {
  local installer="${PROJECT_ROOT}/scripts/install-manager"
  local destination="${TEST_HOME}/.local/bin/devin-desktop-manager"
  local unrelated="${BATS_TEST_TMPDIR}/unrelated"

  run "${installer}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Usage: install-manager"* ]]

  run "${installer}" "${BATS_TEST_TMPDIR}/missing" "${destination}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"source is not an executable file"* ]]

  printf '#!/usr/bin/env bash\nexit 0\n' >"${unrelated}"
  chmod 0755 "${unrelated}"
  run "${installer}" "${unrelated}" "${destination}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"source does not identify this project"* ]]
}

@test "development link is explicit and resolves to project source" {
  local installed="${TEST_HOME}/.local/bin/devin-desktop-manager"

  run make --no-print-directory -s -C "${PROJECT_ROOT}" \
    HOME="${TEST_HOME}" MANAGER="${installed}" link-dev

  [ "${status}" -eq 0 ]
  [ -L "${installed}" ]
  [ "$(readlink -f "${installed}")" = "${PROJECT_ROOT}/bin/devin-desktop-manager" ]
}

@test "package output is byte-for-byte deterministic" {
  local first="${BATS_TEST_TMPDIR}/first"
  local second="${BATS_TEST_TMPDIR}/second"

  run "${PROJECT_ROOT}/scripts/package-release" 0.1.0 "${first}"
  [ "${status}" -eq 0 ]
  run "${PROJECT_ROOT}/scripts/package-release" 0.1.0 "${second}"
  [ "${status}" -eq 0 ]

  cmp "${first}/devin-desktop-manager-0.1.0.tar.gz" \
    "${second}/devin-desktop-manager-0.1.0.tar.gz"
  cmp "${first}/SHA256SUMS" "${second}/SHA256SUMS"
  tar -tzf "${first}/devin-desktop-manager-0.1.0.tar.gz" \
    >"${BATS_TEST_TMPDIR}/archive-contents"
  grep -qx 'devin-desktop-manager-0.1.0/bin/devin-desktop-manager' \
    "${BATS_TEST_TMPDIR}/archive-contents"
}

@test "package excludes untracked files once the repository has a commit" {
  local repository="${BATS_TEST_TMPDIR}/repository"
  local dist_dir="${BATS_TEST_TMPDIR}/dist"

  mkdir -p "${repository}/scripts"
  cp "${PROJECT_ROOT}/scripts/package-release" "${repository}/scripts/package-release"
  chmod 0755 "${repository}/scripts/package-release"
  printf 'tracked\n' >"${repository}/README.md"
  git -C "${repository}" init --quiet
  git -C "${repository}" add scripts/package-release README.md
  git -C "${repository}" \
    -c user.name='Test User' \
    -c user.email='test@example.invalid' \
    commit --quiet -m 'test fixture'
  printf 'must not ship\n' >"${repository}/untracked-secret.txt"

  run "${repository}/scripts/package-release" 0.1.0 "${dist_dir}"

  [ "${status}" -eq 0 ]
  run tar -tzf "${dist_dir}/devin-desktop-manager-0.1.0.tar.gz"
  [ "${status}" -eq 0 ]
  [[ "${output}" == *"devin-desktop-manager-0.1.0/README.md"* ]]
  [[ "${output}" != *"untracked-secret.txt"* ]]
}

@test "package-release rejects usage version and empty repository errors" {
  local packager="${PROJECT_ROOT}/scripts/package-release"
  local repository="${BATS_TEST_TMPDIR}/empty-repository"
  local dist_dir="${BATS_TEST_TMPDIR}/empty-dist"

  run "${packager}"
  [ "${status}" -eq 2 ]
  [[ "${output}" == *"Usage: package-release"* ]]

  run "${packager}" latest "${dist_dir}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"invalid release version"* ]]

  mkdir -p "${repository}/scripts"
  cp "${packager}" "${repository}/scripts/package-release"
  git -C "${repository}" init --quiet
  git -C "${repository}" -c user.name=Test -c user.email=test@example.invalid \
    commit --quiet --allow-empty -m empty
  run "${repository}/scripts/package-release" 0.1.0 "${dist_dir}"
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"no repository files found"* ]]
}
