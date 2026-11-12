test_compare_passes_when_unchanged() {
  sandbox
  bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES" > perf-scores.json
  bash "$REPO/plugin/scripts/compare.sh" >/dev/null
}

test_compare_fails_on_performance_drop_over_10() {
  sandbox
  cp "$REPO/tests/baselines/baseline-high.json" perf-scores.json
  assert_exit 1 bash "$REPO/plugin/scripts/compare.sh"
}

test_compare_fails_on_seo_drop_over_10() {
  sandbox
  bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES" > perf-scores.json
  mkdir low && for i in 1 2 3; do
    jq '.categories.seo.score = 0.75' "$FIXTURES/lhr-$i.json" > "low/lhr-$i.json"
  done
  export FAKE_LHCI_FIXTURES="$PWD/low"
  assert_exit 1 bash "$REPO/plugin/scripts/compare.sh"
}

test_compare_save_after_url() {
  sandbox
  cp "$REPO/tests/baselines/baseline-high.json" perf-scores.json
  bash "$REPO/plugin/scripts/compare.sh" http://localhost:3000 --save >/dev/null || true
  assert_eq "$(jq -r .scores.performance perf-scores.json)" "70" "baseline replaced by current run"
}

test_compare_save_without_url() {
  sandbox
  cp "$REPO/tests/baselines/baseline-high.json" perf-scores.json
  bash "$REPO/plugin/scripts/compare.sh" --save >/dev/null || true
  assert_eq "$(jq -r .scores.performance perf-scores.json)" "70" "saved with default URL"
}

test_compare_requires_baseline() {
  sandbox
  assert_exit 1 bash "$REPO/plugin/scripts/compare.sh"
}
