test_summarize_median_performance() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES")
  assert_eq "$(jq -r .scores.performance <<<"$out")" "70" "median of 60,70,80"
}

test_summarize_requires_three_reports() {
  sandbox
  mkdir one && cp "$FIXTURES/lhr-1.json" one/
  assert_exit 1 bash "$REPO/plugin/scripts/summarize.sh" one
}

test_summarize_inp_absent_is_null() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES")
  assert_eq "$(jq -r .metrics.inp_ms <<<"$out")" "null" "INP absent in lab run"
}

test_settings_profile_is_slow_4g() {
  sandbox
  source "$REPO/plugin/scripts/lib/settings.sh"
  assert_contains "${LH_COLLECT_FLAGS[*]}" "--settings.throttling.rttMs=150" "rtt"
  assert_contains "${LH_COLLECT_FLAGS[*]}" "--settings.throttling.downloadThroughputKbps=1474.56" "download"
}

test_summarize_js_excludes_json_responses() {
  sandbox
  mkdir reports
  for i in 1 2 3; do
    jq '.audits["total-byte-weight"].details.items += [{"url":"http://x/api.json","totalBytes":900000}]' \
      "$FIXTURES/lhr-$i.json" > "reports/lhr-$i.json"
  done
  out=$(bash "$REPO/plugin/scripts/summarize.sh" reports)
  assert_eq "$(jq -r .budgets.js_kb <<<"$out")" "195" "api.json not counted as JS"
}
