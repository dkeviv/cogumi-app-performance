#!/usr/bin/env bash
# Runs Lighthouse against a URL and saves scores to perf-scores.json.
# Usage: bash baseline.sh [url]
#   url defaults to http://localhost:3000
set -euo pipefail

URL="${1:-http://localhost:3000}"
OUT="perf-scores.json"
REPORT_DIR="$(mktemp -d)"
trap "rm -rf '$REPORT_DIR'" EXIT

echo "Running Lighthouse baseline against: $URL"
echo "Throttling: mobile, CPU 4×, Slow 4G"
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

# Extract median scores from the three runs
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
}' "$REPORT" > "$OUT"

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
LCP=$(jq '.metrics.lcp_ms' "$OUT")
CLS=$(jq '.metrics.cls' "$OUT")
INP=$(jq '.metrics.inp_ms // "n/a"' "$OUT")
JS=$(jq '.budgets.js_kb' "$OUT")

[ "$LCP" -le 2500 ] && echo "  ✓ LCP ${LCP}ms ≤ 2500ms" || echo "  ✗ LCP ${LCP}ms > 2500ms (budget: 2500ms)"
[ "$(echo "$CLS <= 0.1" | bc -l)" -eq 1 ] && echo "  ✓ CLS $CLS ≤ 0.1" || echo "  ✗ CLS $CLS > 0.1 (budget: 0.1)"
if [ "$INP" != '"n/a"' ] && [ "$INP" != "null" ]; then
  [ "$INP" -le 200 ] && echo "  ✓ INP ${INP}ms ≤ 200ms" || echo "  ✗ INP ${INP}ms > 200ms (budget: 200ms)"
else
  echo "  — INP not available in this Lighthouse run (requires field data or Chrome UX report)"
fi
[ "$JS" -le 300 ] && echo "  ✓ JS ${JS}KB ≤ 300KB" || echo "  ✗ JS ${JS}KB > 300KB (budget: 300KB)"
