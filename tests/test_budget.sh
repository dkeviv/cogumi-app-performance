test_budget_throttling_matches_settings() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r .ci.collect.settings.throttling.downloadThroughputKbps lighthouserc.json)" "1474.56" "download"
  assert_eq "$(jq -r .ci.collect.settings.throttling.throughputKbps lighthouserc.json)" "1638.4" "throughput"
  assert_eq "$(jq -r .ci.collect.settings.throttling.rttMs lighthouserc.json)" "150" "rtt"
}

test_budget_does_not_mix_budgets_and_assertions() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r '.ci.assert.budgetsFile // "absent"' lighthouserc.json)" "absent" "budgetsFile must not sit beside assertions"
}

test_budget_snippet_asserts_budget_file_separately() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/budget.sh")
  assert_contains "$out" "lhci assert --no-lighthouserc --budgetsFile=perf.budget.json" "budget file step"
}

test_budget_snippet_runs_compare_gate() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/budget.sh")
  assert_contains "$out" "compare.sh" "regression gate in CI snippet"
}

test_budget_assertions_use_current_audits() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r '.ci.assert.assertions | has("uses-webp-images")' lighthouserc.json)" "false" "unknown audit"
  assert_eq "$(jq -r '.ci.assert.assertions | has("uses-optimized-images")' lighthouserc.json)" "false" "deprecated audit"
}

test_budget_no_external_upload() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r '.ci.upload // "absent"' lighthouserc.json)" "absent" "no implicit upload to public storage"
}

test_budget_outputs_are_valid_json() {
  sandbox
  bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  jq empty lighthouserc.json && jq empty perf.budget.json
}
