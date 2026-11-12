SKILL="$REPO/skills/cogumi-app-performance/SKILL.md"

test_skill_has_frontmatter() {
  sandbox
  head -1 "$SKILL" | grep -qx -- '---'
  assert_contains "$(sed -n '2,8p' "$SKILL")" "name: cogumi-app-performance" "frontmatter name"
  assert_contains "$(sed -n '2,8p' "$SKILL")" "description:" "frontmatter description"
}

test_skill_has_compression_section() {
  sandbox
  assert_contains "$(cat "$SKILL")" "P1 — Compression, CDN, Service Workers" "section"
}

test_skill_has_multilayer_cache() {
  sandbox
  assert_contains "$(cat "$SKILL")" "memory → Redis → DB" "multi-layer"
}

test_skill_has_partial_fallback() {
  sandbox
  assert_contains "$(cat "$SKILL")" "Partial-response fallback" "partial-response fallback"
}

test_skill_has_p2_infra() {
  sandbox
  assert_contains "$(cat "$SKILL")" "P2 — Infrastructure" "P2 section"
}

test_skill_no_slow_3g() {
  sandbox
  assert_not_contains "$(cat "$SKILL")" "Slow 3G" "throttling wording"
}

test_skill_debounce_encodes_query() {
  sandbox
  assert_contains "$(cat "$SKILL")" "encodeURIComponent(query)" "debounce encodes"
}

test_skill_no_select_star_in_index_audit() {
  sandbox
  assert_not_contains "$(cat "$SKILL")" "EXPLAIN (ANALYZE, BUFFERS) SELECT * " "index audit"
}

test_skill_font_display_consistent() {
  sandbox
  assert_not_contains "$(cat "$SKILL")" "display: 'swap'" "font display"
}

test_skill_dynamic_options_labeled() {
  sandbox
  assert_contains "$(cat "$SKILL")" "choose one per route" "dynamic options"
}

test_skill_has_lab_field_note() {
  sandbox
  assert_contains "$(cat "$SKILL")" "INP is field-only" "lab vs field note"
}
