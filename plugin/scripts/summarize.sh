#!/usr/bin/env bash
# Summarizes a directory of Lighthouse JSON reports as per-metric medians.
# Usage: bash summarize.sh REPORT_DIR   (prints perf-scores.json schema to stdout)
set -euo pipefail

DIR="${1:?usage: summarize.sh REPORT_DIR}"

shopt -s nullglob
reports=("$DIR"/*.json)
if [ "${#reports[@]}" -lt 3 ]; then
  echo "Error: expected at least 3 Lighthouse reports in $DIR, found ${#reports[@]}" >&2
  exit 1
fi

jq -s '
  def med: sort | .[(length / 2 | floor)];
  def run: {
    performance: (.categories.performance.score * 100 | round),
    accessibility: (.categories.accessibility.score * 100 | round),
    seo: (.categories.seo.score * 100 | round),
    best_practices: (.categories["best-practices"].score * 100 | round),
    lcp_ms: (.audits["largest-contentful-paint"].numericValue | round),
    inp_ms: (.audits["interaction-to-next-paint"].numericValue // .audits["experimental-interaction-to-next-paint"].numericValue // null | if . then round else null end),
    cls: (.audits["cumulative-layout-shift"].numericValue * 1000 | round | . / 1000),
    fcp_ms: (.audits["first-contentful-paint"].numericValue | round),
    tbt_ms: (.audits["total-blocking-time"].numericValue | round),
    speed_index: (.audits["speed-index"].numericValue | round),
    js_kb: ((.audits["total-byte-weight"].details.items // []) | map(select(.url | test("\\.m?js([?#]|$)"))) | map(.totalBytes) | add // 0 | . / 1024 | round),
    image_kb: ((.audits["total-byte-weight"].details.items // []) | map(select(.url | test("\\.(png|jpg|jpeg|webp|avif|gif|svg)([?#]|$)"))) | map(.totalBytes) | add // 0 | . / 1024 | round)
  };
  map(run) as $r
  | {
    url: .[0].finalUrl,
    timestamp: .[0].fetchTime,
    scores: {
      performance: ($r | map(.performance) | med),
      accessibility: ($r | map(.accessibility) | med),
      seo: ($r | map(.seo) | med),
      best_practices: ($r | map(.best_practices) | med)
    },
    metrics: {
      lcp_ms: ($r | map(.lcp_ms) | med),
      inp_ms: ($r | map(.inp_ms) | med),
      cls: ($r | map(.cls) | med),
      fcp_ms: ($r | map(.fcp_ms) | med),
      tbt_ms: ($r | map(.tbt_ms) | med),
      speed_index: ($r | map(.speed_index) | med)
    },
    budgets: {
      js_kb: ($r | map(.js_kb) | med),
      image_kb: ($r | map(.image_kb) | med)
    }
  }
' "${reports[@]}"
