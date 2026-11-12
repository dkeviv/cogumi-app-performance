#!/usr/bin/env bash
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TESTS_DIR/lib.sh"
shopt -s nullglob

for f in "$TESTS_DIR"/test_*.sh; do
  source "$f"
done

filter="${1:-}"
pass=0
fail=0
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for fn in $(declare -F | awk '{print $3}' | grep '^test_' | sort); do
  if [ -n "$filter" ] && [[ "$fn" != *"$filter"* ]]; then
    continue
  fi
  if ( set -e; "$fn" ) >"$log" 2>&1; then
    echo "PASS $fn"
    pass=$((pass + 1))
  else
    echo "FAIL $fn"
    sed 's/^/    /' "$log"
    fail=$((fail + 1))
  fi
done

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
