test_baseline_writes_median_scores() {
  sandbox
  bash "$REPO/plugin/scripts/baseline.sh" http://localhost:3000 >/dev/null
  assert_eq "$(jq -r .scores.performance perf-scores.json)" "70" "median"
}

test_baseline_fails_when_lhci_fails() {
  sandbox
  export FAKE_LHCI_FAIL=1
  assert_exit 1 bash "$REPO/plugin/scripts/baseline.sh"
}

test_baseline_prints_inp_na_when_absent() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/baseline.sh" 2>&1)
  assert_contains "$out" "INP not available" "INP line"
}
