test_docs_install_command_matches_plugin() {
  sandbox
  assert_contains "$(cat "$REPO/README.md")" "/plugin install cogumi-app-performance@cogumi-app-performance" "install"
  assert_not_contains "$(cat "$REPO/README.md")" "install app-performance@" "old install"
}

test_docs_save_example_has_url() {
  sandbox
  assert_not_contains "$(cat "$REPO/README.md")" "compare.sh --save" "save example"
  assert_contains "$(cat "$REPO/README.md")" "compare.sh http://localhost:3000 --save" "save example with URL"
}

test_docs_no_slow_3g() {
  sandbox
  assert_not_contains "$(cat "$REPO/README.md")" "Slow 3G" "README"
  assert_not_contains "$(cat "$REPO/plugin/SKILL.md")" "Slow 3G" "plugin"
}

test_docs_requirements_name() {
  sandbox
  assert_not_contains "$(cat "$REPO/REQUIREMENTS.md")" '## Skill: `app-performance`' "spec name"
}

test_docs_agents_gate_covers_all_categories() {
  sandbox
  assert_not_contains "$(cat "$REPO/AGENTS.md")" "performance score drops" "AGENTS.md gate wording"
  assert_contains "$(cat "$REPO/AGENTS.md")" "any category score drops" "AGENTS.md gate wording"
}

test_docs_plugin_doc_uses_skill_name() {
  sandbox
  assert_not_contains "$(cat "$REPO/plugin/SKILL.md")" "\`app-performance\` skill" "plugin doc skill name"
}

test_docs_readme_documents_api_p95() {
  sandbox
  assert_contains "$(cat "$REPO/README.md")" "api-p95.sh" "api-p95 documented"
}
