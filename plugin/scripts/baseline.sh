#!/usr/bin/env bash
# Runs Lighthouse three times against a URL and saves median scores to perf-scores.json.
# Usage: bash baseline.sh [url]
#   url defaults to http://localhost:3000
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS/lib/settings.sh"

URL="${1:-http://localhost:3000}"
OUT="perf-scores.json"
REPORT_DIR="$(mktemp -d)"
trap 'rm -rf "$REPORT_DIR"' EXIT

echo "Running Lighthouse baseline against: $URL"
echo "Throttling: mobile, CPU 4×, Slow 4G"
echo ""

if ! lhci collect "${LH_COLLECT_FLAGS[@]}" --url="$URL" --outputDir="$REPORT_DIR"; then
  echo "Error: lhci collect failed. Check that the URL is reachable and Chrome is installed." >&2
  exit 1
fi

summary="$(bash "$SCRIPTS/summarize.sh" "$REPORT_DIR")"
printf '%s\n' "$summary" > "$OUT"

echo "Baseline saved to $OUT"
echo ""
jq '{
  "Performance score": .scores.performance,
  "LCP (ms)": .metrics.lcp_ms,
  "CLS": .metrics.cls,
  "TBT (ms)": .metrics.tbt_ms,
  "JS (KB)": .budgets.js_kb
}' "$OUT"

echo ""
echo "Budgets:"
read -r LCP CLS INP JS <<< "$(jq -r '[.metrics.lcp_ms, .metrics.cls, (.metrics.inp_ms // "null"), .budgets.js_kb] | @tsv' "$OUT")"

[ "$LCP" -le 2500 ] && echo "  ✓ LCP ${LCP}ms ≤ 2500ms" || echo "  ✗ LCP ${LCP}ms > 2500ms (budget: 2500ms)"
[ "$(echo "$CLS <= 0.1" | bc -l)" -eq 1 ] && echo "  ✓ CLS $CLS ≤ 0.1" || echo "  ✗ CLS $CLS > 0.1 (budget: 0.1)"
if [ "$INP" != "null" ]; then
  [ "$INP" -le 200 ] && echo "  ✓ INP ${INP}ms ≤ 200ms" || echo "  ✗ INP ${INP}ms > 200ms (budget: 200ms)"
else
  echo "  — INP not available in this Lighthouse run (field-only budget; see SKILL.md)"
fi
[ "$JS" -le 300 ] && echo "  ✓ JS ${JS}KB ≤ 300KB" || echo "  ✗ JS ${JS}KB > 300KB (budget: 300KB)"
