#!/usr/bin/env bats

set -e

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  CHECKER="${PROJECT_ROOT}/scripts/check-coverage"
  RESULTSET="${BATS_TEST_TMPDIR}/.resultset.json"
  cat >"${RESULTSET}" <<'JSON'
{
  "bats-suite": {
    "coverage": {
      "/project/bin/tool": [null, 1, 2, 0, 1, 1, 1, 1, 1, 1, 0]
    },
    "timestamp": 0
  }
}
JSON
}

@test "coverage checker accepts a result at the configured threshold" {
  run "${CHECKER}" "${RESULTSET}" 80

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
        "/project/bin/tool": [
          range(0; 20000) | if . < 17999 then 1 else 0 end
        ]
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
