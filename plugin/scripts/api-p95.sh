#!/usr/bin/env bash
# Measures p95 response time for API URLs against the 500ms budget.
# Usage: bash api-p95.sh [-n RUNS] URL...   (RUNS defaults to 20)
# Exits 1 if any URL's p95 exceeds the budget.
set -euo pipefail

BUDGET_MS=500
RUNS=20

while getopts "n:" opt; do
  case "$opt" in
    n) RUNS="$OPTARG" ;;
    *) echo "usage: api-p95.sh [-n RUNS] URL..." >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [ "$#" -eq 0 ]; then
  echo "usage: api-p95.sh [-n RUNS] URL..." >&2
  exit 1
fi

failed=0
for url in "$@"; do
  p95=$(
    for _ in $(seq "$RUNS"); do
      curl -o /dev/null -s -w '%{time_total}\n' "$url"
    done | awk '{ print $1 * 1000 }' | sort -n | awk '
      { v[NR] = $1 }
      END {
        i = int(NR * 0.95); if (i < NR * 0.95) i++
        if (i < 1) i = 1
        printf "%d", v[i]
      }'
  )
  if [ "$p95" -gt "$BUDGET_MS" ]; then
    status=FAIL
    failed=1
  else
    status=PASS
  fi
  echo "$url p95=${p95}ms budget=${BUDGET_MS}ms $status"
done

exit "$failed"
