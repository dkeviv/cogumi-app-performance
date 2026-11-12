#!/usr/bin/env bash
# Runs Lighthouse and diffs against the saved baseline in perf-scores.json.
# Usage: bash compare.sh [url] [--save]
#   Exits 1 if any category score drops by more than 10 points.
set -euo pipefail

SCRIPTS="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPTS/lib/settings.sh"

URL="http://localhost:3000"
SAVE=0
for arg in "$@"; do
  case "$arg" in
    --save) SAVE=1 ;;
    --*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) URL="$arg" ;;
  esac
done

BASELINE="perf-scores.json"
WORK="$(mktemp -d)"
CURRENT="$WORK/current.json"
REPORT_DIR="$WORK/reports"
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$BASELINE" ]; then
  echo "Error: $BASELINE not found. Run /perf-baseline first." >&2
  exit 1
fi

echo "Running Lighthouse against: $URL"
echo "Comparing against baseline in $BASELINE"
echo ""

mkdir -p "$REPORT_DIR"
if ! lhci collect "${LH_COLLECT_FLAGS[@]}" --url="$URL" --outputDir="$REPORT_DIR"; then
  echo "Error: lhci collect failed. Check that the URL is reachable and Chrome is installed." >&2
  exit 1
fi

bash "$SCRIPTS/summarize.sh" "$REPORT_DIR" > "$CURRENT"

extract() {
  jq -r '[
    .scores.performance, .scores.accessibility, .scores.seo, .scores.best_practices,
    .metrics.lcp_ms, (.metrics.cls * 1000 | round), .metrics.tbt_ms, .metrics.fcp_ms, .metrics.speed_index,
    .budgets.js_kb, .budgets.image_kb
  ] | @tsv' "$1"
}

IFS=$'\t' read -r B_PERF B_A11Y B_SEO B_BP B_LCP B_CLS B_TBT B_FCP B_SI B_JS B_IMG <<< "$(extract "$BASELINE")"
IFS=$'\t' read -r C_PERF C_A11Y C_SEO C_BP C_LCP C_CLS C_TBT C_FCP C_SI C_JS C_IMG <<< "$(extract "$CURRENT")"

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

REGRESSED=0
check_drop() {
  local label="$1"
  local baseline="$2"
  local current="$3"
  local drop
  drop=$(echo "$baseline - $current" | bc -l)
  if [ "$(echo "$drop > 10" | bc -l)" -eq 1 ]; then
    echo "⚠️  $label dropped $(printf '%.0f' "$drop") points (threshold: 10). Investigate before merging."
    REGRESSED=1
  fi
}

delta_row "Performance score"  "$B_PERF" "$C_PERF" "false"
delta_row "Accessibility score" "$B_A11Y" "$C_A11Y" "false"
delta_row "SEO score"          "$B_SEO"  "$C_SEO"  "false"
delta_row "Best practices score" "$B_BP" "$C_BP"   "false"
delta_row "LCP (ms)"           "$B_LCP"  "$C_LCP"
delta_row "CLS (×1000)"        "$B_CLS"  "$C_CLS"
delta_row "TBT (ms)"           "$B_TBT"  "$C_TBT"
delta_row "FCP (ms)"           "$B_FCP"  "$C_FCP"
delta_row "Speed Index"        "$B_SI"   "$C_SI"
delta_row "JS bundle (KB)"     "$B_JS"   "$C_JS"
delta_row "Image weight (KB)"  "$B_IMG"  "$C_IMG"

echo ""

if [ "$SAVE" -eq 1 ]; then
  cp "$CURRENT" "$BASELINE"
  echo "Baseline updated from current run."
fi

check_drop "Performance score"   "$B_PERF" "$C_PERF"
check_drop "Accessibility score" "$B_A11Y" "$C_A11Y"
check_drop "SEO score"           "$B_SEO"  "$C_SEO"
check_drop "Best practices score" "$B_BP"  "$C_BP"

if [ "$REGRESSED" -eq 1 ]; then
  exit 1
fi
echo "✓ No regression detected."
