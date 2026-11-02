#!/usr/bin/env bash
# Runs Lighthouse and diffs against the saved baseline in perf-scores.json.
# Usage: bash compare.sh [url]
set -euo pipefail

URL="${1:-http://localhost:3000}"
BASELINE="perf-scores.json"
CURRENT="perf-scores-current.json"
REPORT_DIR="$(mktemp -d)"
trap "rm -rf '$REPORT_DIR'" EXIT

if [ ! -f "$BASELINE" ]; then
  echo "Error: $BASELINE not found. Run /perf-baseline first."
  exit 1
fi

echo "Running Lighthouse against: $URL"
echo "Comparing against baseline in $BASELINE"
echo ""

lhci collect \
  --url="$URL" \
  --settings.throttlingMethod=simulate \
  --settings.throttling.cpuSlowdownMultiplier=4 \
  --settings.throttling.downloadThroughputKbps=1638.4 \
  --settings.throttling.uploadThroughputKbps=675 \
  --settings.throttling.rttMs=150 \
  --settings.formFactor=mobile \
  --settings.screenEmulation.mobile=true \
  --settings.screenEmulation.width=375 \
  --settings.screenEmulation.height=812 \
  --settings.screenEmulation.deviceScaleFactor=3 \
  --numberOfRuns=3 \
  --outputDir="$REPORT_DIR"

REPORT=$(ls "$REPORT_DIR"/*.json 2>/dev/null | head -1)
if [ -z "$REPORT" ]; then
  echo "Error: lhci produced no report. Check that the URL is reachable and Chrome is installed."
  exit 1
fi

jq '{
  url: .finalUrl,
  timestamp: .fetchTime,
  scores: {
    performance: (.categories.performance.score * 100 | round),
    accessibility: (.categories.accessibility.score * 100 | round),
    seo: (.categories.seo.score * 100 | round),
    best_practices: (.categories["best-practices"].score * 100 | round)
  },
  metrics: {
    lcp_ms: (.audits["largest-contentful-paint"].numericValue | round),
    inp_ms: (.audits["interaction-to-next-paint"].numericValue // .audits["experimental-interaction-to-next-paint"].numericValue // null | if . then round else null end),
    cls: (.audits["cumulative-layout-shift"].numericValue * 1000 | round | . / 1000),
    fcp_ms: (.audits["first-contentful-paint"].numericValue | round),
    tbt_ms: (.audits["total-blocking-time"].numericValue | round),
    speed_index: (.audits["speed-index"].numericValue | round)
  },
  budgets: {
    js_kb: (.audits["total-byte-weight"].details.items // [] | map(select(.url | test("\\.js"))) | map(.totalBytes) | add // 0 | . / 1024 | round),
    image_kb: (.audits["total-byte-weight"].details.items // [] | map(select(.url | test("\\.(png|jpg|jpeg|webp|avif|gif|svg)"))) | map(.totalBytes) | add // 0 | . / 1024 | round)
  }
}' "$REPORT" > "$CURRENT"

rm -rf "$REPORT_DIR"

# Print comparison table
echo "=== Performance Delta ==="
echo ""
printf "%-30s %10s %10s %10s %s\n" "Metric" "Baseline" "Current" "Delta" "Status"
printf "%-30s %10s %10s %10s %s\n" "------" "--------" "-------" "-----" "------"

delta_row() {
  local label="$1"
  local baseline="$2"
  local current="$3"
  local lower_is_better="${4:-true}"

  if [ -z "$baseline" ] || [ -z "$current" ] || [ "$baseline" = "null" ] || [ "$current" = "null" ]; then
    printf "%-30s %10s %10s %10s %s\n" "$label" "n/a" "n/a" "n/a" "—"
    return
  fi

  local delta
  delta=$(echo "$current - $baseline" | bc -l | xargs printf "%.0f")

  local status="✓"
  if [ "$lower_is_better" = "true" ]; then
    [ "$delta" -gt 0 ] && status="↑ worse"
    [ "$delta" -lt 0 ] && status="↓ better"
  else
    [ "$delta" -lt 0 ] && status="↓ worse"
    [ "$delta" -gt 0 ] && status="↑ better"
  fi

  printf "%-30s %10s %10s %10s %s\n" "$label" "$baseline" "$current" "$delta" "$status"
}

# Extract all values in two jq calls (one per file) to avoid 18 subprocess forks
read B_PERF B_LCP B_CLS B_TBT B_FCP B_SI B_JS B_IMG <<< "$(jq -r '[
  .scores.performance,
  .metrics.lcp_ms,
  (.metrics.cls * 1000 | round),
  .metrics.tbt_ms,
  .metrics.fcp_ms,
  .metrics.speed_index,
  .budgets.js_kb,
  .budgets.image_kb
] | @tsv' "$BASELINE")"

read C_PERF C_LCP C_CLS C_TBT C_FCP C_SI C_JS C_IMG <<< "$(jq -r '[
  .scores.performance,
  .metrics.lcp_ms,
  (.metrics.cls * 1000 | round),
  .metrics.tbt_ms,
  .metrics.fcp_ms,
  .metrics.speed_index,
  .budgets.js_kb,
  .budgets.image_kb
] | @tsv' "$CURRENT")"

delta_row "Performance score" "$B_PERF" "$C_PERF" "false"
delta_row "LCP (ms)"          "$B_LCP"  "$C_LCP"
delta_row "CLS (×1000)"       "$B_CLS"  "$C_CLS"
delta_row "TBT (ms)"          "$B_TBT"  "$C_TBT"
delta_row "FCP (ms)"          "$B_FCP"  "$C_FCP"
delta_row "Speed Index"       "$B_SI"   "$C_SI"
delta_row "JS bundle (KB)"    "$B_JS"   "$C_JS"
delta_row "Image weight (KB)" "$B_IMG"  "$C_IMG"

echo ""

# Handle --save before regression exit so it is always reachable
if [ "${2:-}" = "--save" ]; then
  cp "$CURRENT" "$BASELINE"
  echo "Baseline updated from current run."
fi

# Budget check
REGRESSION=$(echo "${B_PERF} - ${C_PERF}" | bc -l | xargs printf "%.0f")

if [ "$REGRESSION" -gt 10 ]; then
  echo "⚠️  Performance score dropped $REGRESSION points (threshold: 10). Investigate before merging."
  exit 1
else
  echo "✓ No regression detected (delta: ${REGRESSION} points)."
fi
