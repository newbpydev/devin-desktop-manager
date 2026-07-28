#!/usr/bin/env bats

set -e

load helpers/portable

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CHECKER="${PROJECT_ROOT}/scripts/check-coverage"
  RUNNER="${PROJECT_ROOT}/scripts/run-coverage"
  COVERAGE_LIBRARY="${PROJECT_ROOT}/scripts/lib/coverage-output.bash"
  RESULTSET="${BATS_TEST_TMPDIR}/.resultset.json"
  resolve_harness_tools bash chmod cp env find flock jq make mkdir mv readlink rm sha256sum sleep stat true
  cat >"${RESULTSET}" <<'JSON'
{
  "bats-suite": {
    "coverage": {
      "/project/bin/tool": {
        "lines": [null, 1, 2, 0, 1, 1, 1, 1, 1, 1, 0]
      }
    },
    "timestamp": 0
  }
}
JSON
}

classify_coverage() {
  local root="$1"
  run bash -c 'source "$1"; exec 3>"$3"; coverage_classify "$2" >&3; status=$?; exec 3>&-; mapfile -d "" -t fields <"$3"; printf "%s|%s\n" "${fields[0]:-}" "${fields[1]:-}"; exit "$status"' \
    _ "${COVERAGE_LIBRARY}" "${root}" "${BATS_TEST_TMPDIR}/classification"
}

make_coverage_checkout() {
  local root="$1"
  mkdir -p "${root}/scripts/lib" "${root}/test-bin"
  cp "${PROJECT_ROOT}/scripts/output-lock" "${PROJECT_ROOT}/scripts/preflight" \
    "${PROJECT_ROOT}/scripts/run-coverage" "${PROJECT_ROOT}/scripts/run-coverage-suite" \
    "${PROJECT_ROOT}/scripts/check-coverage" \
    "${root}/scripts/"
  cp "${COVERAGE_LIBRARY}" "${root}/scripts/lib/coverage-output.bash"
  cat >"${root}/test-bin/ruby" <<EOF
#!${HARNESS_TOOLS[bash]}
printf 'ruby 3.2.0\n'
EOF
  cat >"${root}/test-bin/bundle" <<EOF
#!${HARNESS_TOOLS[bash]}
if [[ "\${1:-}" == --version ]]; then printf 'Bundler version 2.4.20\n'; exit 0; fi
[[ "\${1:-}" == exec ]] || exit 2
shift
exec "\$@"
EOF
  chmod 0755 "${root}/test-bin/ruby" "${root}/test-bin/bundle"
  chmod 0755 "${root}/scripts/"*
}

make_bashcov_stub() {
  local path="$1" mode="$2"
  cat >"${path}" <<EOF
#!${HARNESS_TOOLS[bash]}
set -u
if [[ "\${1:-}" == --version ]]; then printf 'bashcov 3.3.0\n'; exit 0; fi
[[ ${mode@Q} != runner-fail ]] || exit 23
[[ "\${1:-}" == -- ]] || exit 2
[[ "\${BASHCOV_COMMAND_NAME:-}" == bats-suite ]] || exit 2
shift
"\$@" || exit
mkdir -p -- "\${COVERAGE_DIR}/assets"
printf '<html>coverage</html>\n' >"\${COVERAGE_DIR}/index.html"
printf '{}\n' >"\${COVERAGE_DIR}/.last_run.json"
printf '{}\n' >"\${COVERAGE_DIR}/.resultset.json.lock"
if [[ ${mode@Q} == malformed ]]; then printf '{\n' >"\${COVERAGE_DIR}/.resultset.json"; exit 0; fi
if [[ ${mode@Q} == below ]]; then lines='[1,0]'; else lines='[1,1]'; fi
printf '{"%s":{"coverage":{"/project/bin/tool":{"lines":%s}},"timestamp":%s}}\n' \
  "\${BASHCOV_COMMAND_NAME}" "\${lines}" "\$(date +%s)" >"\${COVERAGE_DIR}/.resultset.json"
EOF
  chmod 0755 "${path}"
}

make_bats_stub() {
  local path="$1" log="$2"
  cat >"${path}" <<EOF
#!${HARNESS_TOOLS[bash]}
if [[ "\${1:-}" == --version ]]; then printf 'Bats 1.14.0\n'; exit 0; fi
printf 'suite\n' >>${log@Q}
EOF
  chmod 0755 "${path}"
}

@test "coverage checker accepts a result at the configured threshold" {
  run "${CHECKER}" "${RESULTSET}" 80

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"80.00% (8/10)"* ]]
}

@test "coverage checker accepts legacy line-array entries" {
  jq '."bats-suite".coverage["/project/bin/tool"] |= .lines' \
    "${RESULTSET}" >"${RESULTSET}.legacy"

  run "${CHECKER}" "${RESULTSET}.legacy" 80

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"80.00% (8/10)"* ]]
}

@test "coverage checker rejects a result below the configured threshold" {
  run "${CHECKER}" "${RESULTSET}" 90

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"80.00% is below required 90.00%"* ]]
}

@test "coverage checker compares exact counts before rounding for display" {
  jq -n '{
    "bats-suite": {
      coverage: {
        "/project/bin/tool": {
          lines: [
            range(0; 20000) | if . < 17999 then 1 else 0 end
          ]
        }
      }
    }
  }' >"${RESULTSET}"

  run "${CHECKER}" "${RESULTSET}" 90

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"90.00% is below required 90.00% (17999/20000)"* ]]
}

@test "coverage checker rejects malformed or empty result data" {
  printf '{}\n' >"${RESULTSET}"

  run "${CHECKER}" "${RESULTSET}" 90

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"contains no relevant lines"* ]]
}

@test "coverage checker rejects a missing result set" {
  run "${CHECKER}" "${BATS_TEST_TMPDIR}/missing.json" 90

  [ "${status}" -ne 0 ]
  [[ "${output}" == *"result set is missing"* ]]
}

@test "coverage checker rejects an invalid minimum" {
  run "${CHECKER}" "${RESULTSET}" 101

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"minimum must be between 0 and 100"* ]]
}

@test "coverage checker requires both public arguments" {
  run "${CHECKER}"

  [ "${status}" -eq 2 ]
  [ "${output}" = "Usage: check-coverage RESULTSET MINIMUM_PERCENT" ]
}

@test "[PMC-U5-C01] stale results and duplicate threshold ownership remain rejected" {
  run env COVERAGE_COMMAND_NAME=bats-suite COVERAGE_STARTED_AT=1 \
    "${CHECKER}" "${RESULTSET}" 80
  [ "${status}" -ne 0 ]
  [[ "${output}" == *"stale"* ]]

  run grep -F 'minimum_coverage' "${PROJECT_ROOT}/.simplecov"
  [ "${status}" -ne 0 ]
  grep -Fq 'COVERAGE_MINIMUM ?= 90' "${PROJECT_ROOT}/Makefile"
  grep -Fq 'BASHCOV_COMMAND_NAME=bats-suite' "${RUNNER}"
}

@test "[PMC-U5-R02] checker requires one fresh intended command result" {
  local now
  now="$(date +%s)"
  jq --argjson timestamp "${now}" '."bats-suite".timestamp = $timestamp' \
    "${RESULTSET}" >"${RESULTSET}.fresh"

  run env COVERAGE_COMMAND_NAME=bats-suite COVERAGE_STARTED_AT="${now}" \
    "${CHECKER}" "${RESULTSET}.fresh" 80
  [ "${status}" -eq 0 ]

  jq '.wrong = ."bats-suite" | del(."bats-suite")' "${RESULTSET}.fresh" >"${RESULTSET}.wrong"
  run env COVERAGE_COMMAND_NAME=bats-suite COVERAGE_STARTED_AT="${now}" \
    "${CHECKER}" "${RESULTSET}.wrong" 80
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"command identity"* ]]
}

@test "[PMC-U5-R03] classifier and repair implement the bounded sidecar matrix" {
  local root="${BATS_TEST_TMPDIR}/coverage" backup="${BATS_TEST_TMPDIR}/.coverage.backup"
  classify_coverage "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "absent|" ]

  make_coverage_tree "${backup}"
  classify_coverage "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "repair-backup|" ]

  local checkout="${BATS_TEST_TMPDIR}/checkout"
  mkdir -p "${checkout}/scripts/lib"
  cp "${PROJECT_ROOT}/scripts/output-lock" "${PROJECT_ROOT}/scripts/preflight" \
    "${PROJECT_ROOT}/scripts/run-coverage" "${PROJECT_ROOT}/scripts/run-coverage-suite" \
    "${checkout}/scripts/"
  cp "${COVERAGE_LIBRARY}" "${checkout}/scripts/lib/coverage-output.bash"
  chmod 0755 "${checkout}/scripts/"*
  mv "${backup}" "${checkout}/.coverage.backup"
  run env MAKE_COVERAGE_DIR=coverage MAKE_DIST_DIR=dist MAKE_BATS=true MAKE_BASHCOV=true \
    "${checkout}/scripts/output-lock" "${checkout}" -- \
    "${checkout}/scripts/run-coverage" --project-root "${checkout}"
  [ "${status}" -ne 2 ]
  [ -d "${checkout}/coverage" ]

  mkdir -p "${checkout}/.coverage.stage.1.abcdef" "${checkout}/.coverage.stage.2.abcdef"
  classify_coverage "${checkout}/coverage"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|multiple-stage" ]
}

@test "[PMC-U5-R04] legacy shape is valid and unknown coverage entries fail closed" {
  local root="${BATS_TEST_TMPDIR}/coverage"
  make_coverage_tree "${root}"
  classify_coverage "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "public-valid|" ]

  printf 'foreign\n' >"${root}/unknown"
  classify_coverage "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|unknown-coverage-entry" ]
  [ -f "${root}/unknown" ]
}

@test "[PMC-U5-R04] assets must be a directory while nested asset files remain valid" {
  local root="${BATS_TEST_TMPDIR}/coverage"
  make_coverage_tree "${root}"
  printf 'nested\n' >"${root}/assets/report.css"
  classify_coverage "${root}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "public-valid|" ]

  rm -rf "${root}/assets"
  printf 'not a directory\n' >"${root}/assets"
  classify_coverage "${root}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|invalid-public" ]
}

@test "[PMC-U5-R04] traversal producer failure cannot validate a partial NUL list" {
  local root="${BATS_TEST_TMPDIR}/coverage" shim_bin="${BATS_TEST_TMPDIR}/find-bin"
  local result="${BATS_TEST_TMPDIR}/classification"
  make_coverage_tree "${root}"
  mkdir -p "${shim_bin}"
  cat >"${shim_bin}/find" <<EOF
#!${HARNESS_TOOLS[bash]}
if [[ "\${1:-}" == ${root@Q} ]]; then
  printf '%s\0%s\0' ${root@Q} ${root@Q}/.resultset.json
  exit 23
fi
exec ${HARNESS_TOOLS[find]@Q} "\$@"
EOF
  chmod 0755 "${shim_bin}/find"

  run env PATH="${shim_bin}:${PATH}" bash -c \
    'source "$1"; coverage_classify "$2" >"$3"; status=$?; mapfile -d "" -t fields <"$3"; printf "%s|%s\n" "${fields[0]:-}" "${fields[1]:-}"; exit "$status"' \
    _ "${COVERAGE_LIBRARY}" "${root}" "${result}"
  [ "${status}" -eq 1 ]
  [ "${output}" = "unsafe|invalid-public" ]
}

@test "[PMC-U5-R05] invalid coverage roots fail before output lock creation" {
  local checkout="${BATS_TEST_TMPDIR}/checkout" value
  mkdir -p "${checkout}/scripts/lib"
  cp "${PROJECT_ROOT}/scripts/output-lock" "${PROJECT_ROOT}/scripts/preflight" \
    "${PROJECT_ROOT}/scripts/run-coverage" "${PROJECT_ROOT}/scripts/run-coverage-suite" \
    "${checkout}/scripts/"
  cp "${COVERAGE_LIBRARY}" "${checkout}/scripts/lib/coverage-output.bash"
  chmod 0755 "${checkout}/scripts/"*

  for value in /absolute ../escape . dist $'bad\tpath'; do
    rm -f "${checkout}/.devin-desktop-manager.outputs.lock"
    run env MAKE_COVERAGE_DIR="${value}" MAKE_DIST_DIR=dist MAKE_BATS=true MAKE_BASHCOV=true \
      "${checkout}/scripts/run-coverage" --project-root "${checkout}"
    [ "${status}" -ne 0 ]
    [ ! -e "${checkout}/.devin-desktop-manager.outputs.lock" ]
  done

  mkdir -p "${checkout}/real"
  ln -s real "${checkout}/symbolic"
  run env MAKE_COVERAGE_DIR=symbolic/coverage MAKE_DIST_DIR=dist MAKE_BATS=true MAKE_BASHCOV=true \
    "${checkout}/scripts/run-coverage" --project-root "${checkout}"
  [ "${status}" -eq 1 ]
  [ ! -e "${checkout}/.devin-desktop-manager.outputs.lock" ]
}

@test "[PMC-U5-R06] direct runner rejects an unowned descriptor" {
  local lock="${BATS_TEST_TMPDIR}/lock"
  : >"${lock}"
  run bash -c 'exec 6<>"$1"; flock -n 6; MAKE_COVERAGE_DIR=coverage MAKE_DIST_DIR=dist MAKE_BATS=true MAKE_BASHCOV=true "$2" --output-lock-fd 6 --project-root "$3"' \
    _ "${lock}" "${RUNNER}" "${PROJECT_ROOT}"
  [ "${status}" -eq 2 ]
}

@test "[PMC-U5-R01] runner parser and threshold failures preserve prior coverage" {
  local checkout="${BATS_TEST_TMPDIR}/checkout" prior="${BATS_TEST_TMPDIR}/prior"
  local bats="${BATS_TEST_TMPDIR}/bats" bashcov mode
  make_coverage_checkout "${checkout}"
  make_coverage_tree "${checkout}/coverage"
  make_bats_stub "${bats}" "${BATS_TEST_TMPDIR}/suite-log"
  snapshot_tree "${checkout}/coverage" "${prior}"

  for mode in runner-fail malformed below; do
    bashcov="${BATS_TEST_TMPDIR}/bashcov-${mode}"
    make_bashcov_stub "${bashcov}" "${mode}"
    run env PATH="${checkout}/test-bin:${PATH}" MAKE_COVERAGE_DIR=coverage MAKE_DIST_DIR=dist MAKE_COVERAGE_MINIMUM=90 \
      MAKE_BATS="${bats}" MAKE_BASHCOV="${bashcov}" \
      "${checkout}/scripts/run-coverage" --project-root "${checkout}"
    [ "${status}" -eq 1 ]
    snapshot_tree "${checkout}/coverage" "${BATS_TEST_TMPDIR}/after-${mode}"
    cmp -s "${prior}" "${BATS_TEST_TMPDIR}/after-${mode}"
    run find "${checkout}" -maxdepth 1 -name '.coverage.stage.*' -print
    [ -z "${output}" ]
  done
}

@test "[PMC-U5-R06] successful publication invokes the full suite once" {
  local checkout="${BATS_TEST_TMPDIR}/checkout" bats="${BATS_TEST_TMPDIR}/bats"
  local bashcov="${BATS_TEST_TMPDIR}/bashcov" log="${BATS_TEST_TMPDIR}/suite-log"
  make_coverage_checkout "${checkout}"
  make_bats_stub "${bats}" "${log}"
  make_bashcov_stub "${bashcov}" success

  run env PATH="${checkout}/test-bin:${PATH}" MAKE_COVERAGE_DIR=coverage MAKE_DIST_DIR=dist MAKE_COVERAGE_MINIMUM=90 \
    MAKE_BATS="${bats}" MAKE_BASHCOV="${bashcov}" \
    "${checkout}/scripts/run-coverage" --project-root "${checkout}"
  [ "${status}" -eq 0 ]
  [ "$(wc -l <"${log}")" -eq 1 ]
  [ -f "${checkout}/coverage/.resultset.json" ]
  [ ! -e "${checkout}/.coverage.backup" ]
}

@test "[PMC-U7-R04] both domains classify before repair or removal" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout"
  local backup="${root}/.coverage.backup"
  make_clean_checkout "${root}"
  make_coverage_tree "${backup}"
  make_package_pair "${root}/dist" devin-desktop-manager-1.2.3.tar.gz
  printf 'corrupt\n' >>"${root}/dist/devin-desktop-manager-1.2.3.tar.gz"
  snapshot_tree "${backup}" "${BATS_TEST_TMPDIR}/coverage-before"
  snapshot_tree "${root}/dist" "${BATS_TEST_TMPDIR}/dist-before"

  run "${root}/scripts/clean-generated" --project-root "${root}"
  [ "${status}" -eq 1 ]
  [ -d "${backup}" ]
  [ ! -e "${root}/coverage" ]
  snapshot_tree "${backup}" "${BATS_TEST_TMPDIR}/coverage-after"
  snapshot_tree "${root}/dist" "${BATS_TEST_TMPDIR}/dist-after"
  cmp "${BATS_TEST_TMPDIR}/coverage-before" "${BATS_TEST_TMPDIR}/coverage-after"
  cmp "${BATS_TEST_TMPDIR}/dist-before" "${BATS_TEST_TMPDIR}/dist-after"

  rm -rf "${root}/dist"
  make_package_pair "${root}/dist/.devin-desktop-manager.package.backup" \
    devin-desktop-manager-1.2.3.tar.gz
  chmod 0700 "${root}/dist/.devin-desktop-manager.package.backup"
  run "${root}/scripts/clean-generated" --project-root "${root}"
  [ "${status}" -eq 0 ]
  [ ! -e "${backup}" ]
  [ ! -e "${root}/coverage" ]
  [ ! -e "${root}/dist" ]
}

@test "[PMC-U7-R02] invalid clean roots fail before lock creation" {
  local root="${BATS_TEST_TMPDIR}/clean-checkout" outside="${BATS_TEST_TMPDIR}/outside"
  local value
  make_clean_checkout "${root}"
  printf 'sentinel\n' >"${outside}"

  for value in /absolute ../outside . dist $'bad\tpath'; do
    rm -f "${root}/.devin-desktop-manager.outputs.lock"
    run env MAKE_COVERAGE_DIR="${value}" MAKE_DIST_DIR=dist \
      "${root}/scripts/clean-generated" --project-root "${root}"
    [ "${status}" -eq 1 ]
    [ ! -e "${root}/.devin-desktop-manager.outputs.lock" ]
    [ "$(<"${outside}")" = sentinel ]
  done

  mkdir -p "${root}/real"
  ln -s real "${root}/symbolic"
  run env MAKE_COVERAGE_DIR=symbolic/coverage MAKE_DIST_DIR=dist \
    "${root}/scripts/clean-generated" --project-root "${root}"
  [ "${status}" -eq 1 ]
  [ ! -e "${root}/.devin-desktop-manager.outputs.lock" ]
}
