test_plugin_manifests_are_valid_json() {
  sandbox
  jq empty "$REPO/.claude-plugin/plugin.json"
  jq empty "$REPO/.claude-plugin/marketplace.json"
}

test_plugin_name_matches_marketplace() {
  sandbox
  assert_eq "$(jq -r .name "$REPO/.claude-plugin/plugin.json")" "cogumi-app-performance" "plugin name"
  assert_eq "$(jq -r .name "$REPO/.claude-plugin/marketplace.json")" "cogumi-app-performance" "marketplace name"
  assert_eq "$(jq -r '.plugins[0].name' "$REPO/.claude-plugin/marketplace.json")" "cogumi-app-performance" "entry name"
}

test_marketplace_has_owner_and_source() {
  sandbox
  assert_eq "$(jq -r '.owner.name' "$REPO/.claude-plugin/marketplace.json")" "dkeviv" "owner"
  assert_eq "$(jq -r '.plugins[0].source' "$REPO/.claude-plugin/marketplace.json")" "./" "source"
}

test_commands_exist_and_call_scripts() {
  sandbox
  for pair in perf-baseline:baseline perf-compare:compare perf-budget:budget; do
    f="$REPO/commands/${pair%%:*}.md"
    s="${pair##*:}"
    assert_contains "$(cat "$f")" "plugin/scripts/$s.sh" "$f calls $s.sh"
  done
}
