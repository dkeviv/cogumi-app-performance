test_api_p95_passes_under_budget() {
  sandbox
  export FAKE_CURL_TIME=0.2
  out=$(bash "$REPO/plugin/scripts/api-p95.sh" -n 5 http://x/api)
  assert_contains "$out" "p95=200ms" "p95 value"
  assert_contains "$out" "PASS" "status"
}

test_api_p95_fails_over_budget() {
  sandbox
  export FAKE_CURL_TIME=0.9
  assert_exit 1 bash "$REPO/plugin/scripts/api-p95.sh" -n 5 http://x/api
}

test_api_p95_rejects_no_urls() {
  sandbox
  assert_exit 1 bash "$REPO/plugin/scripts/api-p95.sh"
}
