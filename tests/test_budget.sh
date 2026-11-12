test_budget_throttling_matches_settings() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r .ci.collect.settings.throttling.downloadThroughputKbps lighthouserc.json)" "1474.56" "download"
  assert_eq "$(jq -r .ci.collect.settings.throttling.throughputKbps lighthouserc.json)" "1638.4" "throughput"
  assert_eq "$(jq -r .ci.collect.settings.throttling.rttMs lighthouserc.json)" "150" "rtt"
}

test_budget_references_budget_file() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r .ci.assert.budgetsFile lighthouserc.json)" "perf.budget.json" "budgetsFile"
}

test_budget_snippet_runs_compare_gate() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/budget.sh")
  assert_contains "$out" "compare.sh" "regression gate in CI snippet"
}

test_budget_outputs_are_valid_json() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  jq empty lighthouserc.json && jq empty perf.budget.json
}
