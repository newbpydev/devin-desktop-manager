#!/usr/bin/env bash

set -Eeuo pipefail

[[ $# -ge 2 && "$1" == /* && -f "$1" && -x "$1" ]] || exit 2
unset COVERAGE_DIR
exec "$@"
