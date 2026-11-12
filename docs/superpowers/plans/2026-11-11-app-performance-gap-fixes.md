# App Performance Gap Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close every gap and bug found in the REQUIREMENTS.md review so the skill, plugin, scripts, CI config and docs match the spec and each other.

**Architecture:** Bash scripts wrap `lhci collect` and `jq`. A shared `summarize.sh` turns a directory of Lighthouse reports into the `perf-scores.json` schema using per-metric medians. A shared `settings.sh` holds the one Lighthouse throttling profile. Plugin packaging sits at the repo root, and the existing `plugin/scripts/` stays where it is. Tests are a bash harness with stub `lhci` and `curl` binaries on `PATH`, so no new dependencies are added.

**Tech Stack:** bash, jq, bc, `@lhci/cli`, Lighthouse JSON reports, Claude Code plugin manifests (JSON) and slash-command markdown.

**Spec:** `REQUIREMENTS.md` (repo root). Where this plan decides something the spec leaves open, the decision is recorded under "Decisions" below and the spec is updated in Task 10.

## Global Constraints

- Budgets, verbatim from spec: LCP ≤ 2500ms (p75 field); INP ≤ 200ms (p75 field); CLS ≤ 0.1 (p75 field); compressed JS ≤ 300 KB per page; above-fold images ≤ 500 KB per page; API p95 ≤ 500ms per endpoint; TTFT ≤ 1000ms per LLM call.
- Regression gate: a drop of more than 10 points on any of the four Lighthouse category scores fails.
- Throttling profile: Lighthouse Slow 4G with CPU 4× slowdown, mobile 375×812 at 3× DPR. Values are identical everywhere they appear.
- `perf-scores.json` schema is additive only. Existing baseline files must still load.
- No new runtime dependencies. Scripts need only bash, jq, bc, curl and `lhci`.
- Each task ends with a commit. Commit messages follow the existing `feat:`/`fix:`/`docs:` style.

## Decisions

- **D1 Plugin root.** The repo root is the plugin root. Manifests live in `.claude-plugin/` at the root. Slash commands live in `commands/` at the root. Scripts stay in `plugin/scripts/` and are referenced as `${CLAUDE_PLUGIN_ROOT}/plugin/scripts/...`.
- **D2 Plugin name.** The plugin and marketplace are both named `cogumi-app-performance`, matching the skill directory. The README install command changes to match.
- **D3 Throttling.** Slow 4G everywhere. The "Slow 3G" wording in SKILL.md and README is changed to match.
- **D4 CI gate.** Regression is enforced by running `compare.sh` against the committed `perf-scores.json`. `lighthouserc.json` keeps absolute assertions as a floor and does not try to express a relative drop.
- **D5 INP.** Lab navigation runs do not produce INP. INP is documented as a field-only budget. TBT stays in CI as the lab proxy for responsiveness.
- **D6 API p95.** Lighthouse cannot measure API latency. A new `api-p95.sh` measures it directly against listed endpoints. It is documented in the skill and wired into `perf.budget.json`'s companion docs, not into the Lighthouse budget format.
- **D7 Field data.** CrUX p75 is documented with how to fetch it (PageSpeed Insights API or the CrUX dashboard). No script is added for it.

## File Structure

- Create: `tests/run.sh` — test runner; runs every `test_*` function and reports pass/fail.
- Create: `tests/lib.sh` — assertion helpers and a temp-dir sandbox per test.
- Create: `tests/bin/lhci`, `tests/bin/curl` — stubs that replay fixtures or fixed timings.
- Create: `tests/fixtures/lhr-1.json`, `lhr-2.json`, `lhr-3.json` — three Lighthouse reports with different scores.
- Create: `plugin/scripts/lib/settings.sh` — the one throttling profile, as a bash array.
- Create: `plugin/scripts/summarize.sh` — reports directory → `perf-scores.json` schema, per-metric medians.
- Create: `plugin/scripts/api-p95.sh` — measures p95 latency for listed URLs against the 500ms budget.
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`.
- Create: `commands/perf-baseline.md`, `commands/perf-compare.md`, `commands/perf-budget.md`.
- Modify: `plugin/scripts/baseline.sh`, `compare.sh`, `budget.sh`, `install-check.sh`.
- Modify: `skills/cogumi-app-performance/SKILL.md`.
- Modify: `README.md`, `plugin/SKILL.md`, `AGENTS.md`, `REQUIREMENTS.md`.

---

### Task 1: Test harness and fixtures

**Files:**
- Create: `tests/run.sh`, `tests/lib.sh`, `tests/bin/lhci`, `tests/bin/curl`
- Create: `tests/fixtures/lhr-1.json`, `tests/fixtures/lhr-2.json`, `tests/fixtures/lhr-3.json`

**Interfaces:**
- Consumes: nothing.
- Produces: `tests/lib.sh` provides `sandbox` (creates a temp dir, copies `tests/bin` onto `PATH` for the test, `cd`s into it), `assert_eq ACTUAL EXPECTED MSG`, `assert_contains HAYSTACK NEEDLE MSG`, `assert_exit CODE CMD...`. Stub `lhci` reads `FAKE_LHCI_FIXTURES` (default `tests/fixtures`) and copies `lhr-1..3.json` into the `--outputDir=` argument; exits 1 if `FAKE_LHCI_FAIL=1`. Stub `curl` prints `FAKE_CURL_TIME` (default `0.2`) for `-w '%{time_total}'` calls.

- [ ] **Step 1: Write the harness**

`tests/run.sh` sources `tests/lib.sh`, then runs each function named `test_*` defined in files under `tests/`, printing `PASS`/`FAIL` per test and exiting 1 if any failed. An optional argument filters by name substring.

- [ ] **Step 2: Write the fixtures**

Each fixture has `finalUrl`, `fetchTime`, `categories` (`performance`, `accessibility`, `seo`, `best-practices` with `score` 0–1), and `audits` for `largest-contentful-paint`, `cumulative-layout-shift`, `total-blocking-time`, `first-contentful-paint`, `speed-index`, and `total-byte-weight` (with `details.items` containing one `.js` and one `.webp` URL). Performance scores are 0.60, 0.70, 0.80 across `lhr-1..3`; the other categories are 0.90 in all three. Median performance is 70.

- [ ] **Step 3: Verify the harness runs with zero tests**

Run: `bash tests/run.sh`
Expected: `0 passed, 0 failed` and exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests
git commit -m "test: add bash test harness with stub lhci and curl"
```

---

### Task 2: Shared throttling profile and summarize.sh

**Files:**
- Create: `plugin/scripts/lib/settings.sh`, `plugin/scripts/summarize.sh`
- Test: `tests/test_summarize.sh`

**Interfaces:**
- Consumes: Task 1 harness and fixtures.
- Produces: `settings.sh` defines array `LH_COLLECT_FLAGS` containing the Slow 4G profile flags (throttlingMethod simulate, cpuSlowdownMultiplier 4, rttMs 150, throughputKbps 1638.4, requestLatencyMs 562.5, downloadThroughputKbps 1474.56, uploadThroughputKbps 675, formFactor mobile, screenEmulation mobile 375×812 DPR 3, `--numberOfRuns=3`). `summarize.sh REPORT_DIR` prints one JSON object on stdout with the existing `perf-scores.json` schema (`url`, `timestamp`, `scores`, `metrics`, `budgets`), where every numeric field is the median across the reports in the directory. Exits 1 with a message if fewer than 3 reports are found.

- [ ] **Step 1: Write the failing tests**

```bash
test_summarize_median_performance() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES")
  assert_eq "$(jq -r .scores.performance <<<"$out")" "70" "median of 60,70,80"
}
test_summarize_requires_three_reports() {
  sandbox; mkdir one; cp "$FIXTURES/lhr-1.json" one/
  assert_exit 1 bash "$REPO/plugin/scripts/summarize.sh" one
}
test_summarize_inp_absent_is_null() {
  sandbox  # fixtures have no INP audit
  out=$(bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES")
  assert_eq "$(jq -r .metrics.inp_ms <<<"$out")" "null" "INP absent in lab run"
}
test_settings_profile_is_slow_4g() {
  source "$REPO/plugin/scripts/lib/settings.sh"
  assert_contains "${LH_COLLECT_FLAGS[*]}" "--settings.throttling.rttMs=150" "rtt"
  assert_contains "${LH_COLLECT_FLAGS[*]}" "--settings.throttling.downloadThroughputKbps=1474.56" "download"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh summarize`
Expected: FAIL — `summarize.sh` and `settings.sh` do not exist.

- [ ] **Step 3: Implement `settings.sh` and `summarize.sh`**

`summarize.sh` runs `ls DIR/*.json`, requires at least 3 files, and uses one `jq -s` pass to compute medians (`sort | .[length/2 | floor]`) for each numeric field. `budgets.js_kb` and `budgets.image_kb` keep the existing `.js` / image URL regex. `inp_ms` is `null` when no run has the audit. Output field order matches the current `baseline.sh` output.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh summarize`
Expected: 4 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add plugin/scripts/lib/settings.sh plugin/scripts/summarize.sh tests/test_summarize.sh
git commit -m "feat: add shared Slow 4G profile and median summarizer"
```

---

### Task 3: baseline.sh uses the shared profile and median

**Files:**
- Modify: `plugin/scripts/baseline.sh` (whole file)
- Test: `tests/test_baseline.sh`

**Interfaces:**
- Consumes: `settings.sh` (`LH_COLLECT_FLAGS`), `summarize.sh REPORT_DIR`.
- Produces: `perf-scores.json` in the current directory; prints the summary table and budget checks. Budget lines print `—` (not failure) for INP when `null`.

- [ ] **Step 1: Write the failing tests**

```bash
test_baseline_writes_median_scores() {
  sandbox
  bash "$REPO/plugin/scripts/baseline.sh" http://localhost:3000 >/dev/null
  assert_eq "$(jq -r .scores.performance perf-scores.json)" "70" "median"
}
test_baseline_fails_when_lhci_fails() {
  sandbox; export FAKE_LHCI_FAIL=1
  assert_exit 1 bash "$REPO/plugin/scripts/baseline.sh"
}
test_baseline_prints_inp_na_when_absent() {
  sandbox
  out=$(bash "$REPO/plugin/scripts/baseline.sh" 2>&1)
  assert_contains "$out" "INP not available" "INP line"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh baseline`
Expected: FAIL — current script takes only the first report, so `scores.performance` is `60`, not `70`.

- [ ] **Step 3: Rewrite `baseline.sh`**

Source `settings.sh`. Run `lhci collect "${LH_COLLECT_FLAGS[@]}" --url="$URL" --outputDir="$REPORT_DIR"`. On non-zero exit, print the error and exit 1. Call `summarize.sh "$REPORT_DIR" > perf-scores.json`. Keep the existing budget printout, and read values with one `jq -r '[...] | @tsv'` call.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh baseline`
Expected: 3 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add plugin/scripts/baseline.sh tests/test_baseline.sh
git commit -m "fix: baseline uses median of three runs and shared throttling profile"
```

---

### Task 4: compare.sh gates on any category, fixes argument parsing

**Files:**
- Modify: `plugin/scripts/compare.sh` (whole file)
- Test: `tests/test_compare.sh`

**Interfaces:**
- Consumes: `settings.sh`, `summarize.sh`.
- Produces: `compare.sh [URL] [--save]`. Accepts `--save` before or after the URL, or alone. Exits 1 if any of performance, accessibility, SEO or best-practices drops by more than 10 points. Exits 1 with a message if `perf-scores.json` is missing.

- [ ] **Step 1: Write the failing tests**

```bash
test_compare_passes_when_unchanged() {
  sandbox
  bash "$REPO/plugin/scripts/summarize.sh" "$FIXTURES" > perf-scores.json   # same fixtures as current run
  bash "$REPO/plugin/scripts/compare.sh" >/dev/null
}
test_compare_fails_on_performance_drop_over_10() {
  sandbox; cp "$REPO/tests/fixtures/baseline-high.json" perf-scores.json  # performance 90
  assert_exit 1 bash "$REPO/plugin/scripts/compare.sh"                    # current 70
}
test_compare_fails_on_seo_drop_over_10() {
  sandbox; cp "$REPO/tests/fixtures/baseline-seo-high.json" perf-scores.json  # seo 100
  assert_exit 1 bash "$REPO/plugin/scripts/compare.sh"                       # current 90
}
test_compare_save_after_url() {
  sandbox
  bash "$REPO/plugin/scripts/compare.sh" http://localhost:3000 --save >/dev/null
  assert_eq "$(jq -r .scores.performance perf-scores.json)" "70" "saved"
}
test_compare_save_without_url() {
  sandbox; cp "$REPO/tests/fixtures/baseline-high.json" perf-scores.json
  bash "$REPO/plugin/scripts/compare.sh" --save >/dev/null || true
  assert_eq "$(jq -r .scores.performance perf-scores.json)" "70" "saved with default URL"
}
test_compare_requires_baseline() {
  sandbox
  assert_exit 1 bash "$REPO/plugin/scripts/compare.sh"
}
```

Create `tests/fixtures/baseline-high.json` (performance 90, others 90), and `baseline-seo-high.json` (seo 100, others 90). Use the output schema from Task 2.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh compare`
Expected: FAIL — `--save` as first argument is taken as the URL; SEO drop is not gated.

- [ ] **Step 3: Rewrite `compare.sh`**

Parse args: first positional that does not start with `--` is the URL; `--save` sets a flag. Source `settings.sh`, run `lhci collect`, then `summarize.sh` into a temp current file in the workspace directory (not the repo). Print the delta table for all four categories and existing metrics. Compute the drop for each category with `bc`. Any drop over 10 sets a failure flag. Apply `--save` only after the table prints. Exit with the failure flag status.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh compare`
Expected: 6 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add plugin/scripts/compare.sh tests/test_compare.sh tests/fixtures
git commit -m "fix: compare gates on all categories and accepts --save anywhere"
```

---

### Task 5: install-check.sh verifies bc and jq

**Files:**
- Modify: `plugin/scripts/install-check.sh`
- Test: `tests/test_install_check.sh`

**Interfaces:**
- Consumes: none.
- Produces: exit 0 only when `node`, `lhci`, `jq`, `bc` and Chrome are all found.

- [ ] **Step 1: Write the failing test**

```bash
test_install_check_requires_bc() {
  sandbox
  # PATH without bc: stubs dir first, then a dir containing only the other tools
  mkdir -p nobc && for t in node lhci jq; do ln -s "$(command -v $t)" nobc/$t; done
  PATH="$PWD/nobc:/usr/bin:/bin" assert_exit 1 bash "$REPO/plugin/scripts/install-check.sh"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh install_check`
Expected: FAIL — exit is 0 because `bc` is not checked.

- [ ] **Step 3: Add the check**

Add `check "bc" "bc" "brew install bc  (macOS) or apt install bc  (Linux)"`. Keep the rest unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/run.sh install_check`
Expected: 1 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add plugin/scripts/install-check.sh tests/test_install_check.sh
git commit -m "fix: install-check verifies bc, which baseline and compare require"
```

---

### Task 6: budget.sh uses the shared profile, budgetsFile and a CI gate step

**Files:**
- Modify: `plugin/scripts/budget.sh`
- Test: `tests/test_budget.sh`

**Interfaces:**
- Consumes: `settings.sh` values (same numbers, expressed as JSON).
- Produces: `lighthouserc.json` whose `ci.collect.settings.throttling` matches `settings.sh`, whose `ci.assert` includes `budgetsFile: "perf.budget.json"`, and whose `ci.assert.assertions` keeps the absolute floors. `perf.budget.json` is unchanged in shape. The printed GitHub Actions snippet runs `lhci autorun` and then `bash plugin/scripts/compare.sh "$URL"` against the committed `perf-scores.json`.

- [ ] **Step 1: Write the failing tests**

```bash
test_budget_throttling_matches_settings() {
  sandbox; bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r .ci.collect.settings.throttling.downloadThroughputKbps lighthouserc.json)" "1474.56" "download"
  assert_eq "$(jq -r .ci.collect.settings.throttling.throughputKbps lighthouserc.json)" "1638.4" "throughput"
}
test_budget_references_budget_file() {
  sandbox; bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  assert_eq "$(jq -r .ci.assert.budgetsFile lighthouserc.json)" "perf.budget.json" "budgetsFile"
}
test_budget_snippet_runs_compare_gate() {
  sandbox; out=$(bash "$REPO/plugin/scripts/budget.sh")
  assert_contains "$out" "compare.sh" "regression gate in CI snippet"
}
test_budget_outputs_are_valid_json() {
  sandbox; bash "$REPO/plugin/scripts/budget.sh" >/dev/null
  jq empty lighthouserc.json && jq empty perf.budget.json
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh budget`
Expected: FAIL — throttling values differ, `budgetsFile` is absent, snippet has no compare step.

- [ ] **Step 3: Update `budget.sh`**

Replace the throttling block with the Slow 4G values from `settings.sh`. Add `"budgetsFile": "perf.budget.json"` under `ci.assert`. Keep `ci.assert.preset` and the absolute assertions. Add the `compare.sh` step to the workflow heredoc, and note that `perf-scores.json` must be committed.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh budget`
Expected: 4 passed, 0 failed.

- [ ] **Step 5: Verify the budgetsFile key against the installed lhci**

Run: `lhci --version` and check the `assert` help or docs for `budgetsFile`.
Expected: key is accepted. If not verifiable offline, say so in the final report and keep the key.

- [ ] **Step 6: Commit**

```bash
git add plugin/scripts/budget.sh tests/test_budget.sh
git commit -m "fix: budget config matches Slow 4G profile, references budgets, and gates regressions"
```

---

### Task 7: api-p95.sh for the API p95 budget

**Files:**
- Create: `plugin/scripts/api-p95.sh`
- Test: `tests/test_api_p95.sh`

**Interfaces:**
- Consumes: `tests/bin/curl` stub (returns `FAKE_CURL_TIME` for `-w '%{time_total}'`).
- Produces: `api-p95.sh [-n RUNS] URL...`. For each URL it runs `curl -o /dev/null -s -w '%{time_total}' URL` RUNS times (default 20), computes p95 in ms (nearest-rank), prints one line per URL, and exits 1 if any p95 exceeds 500ms.

- [ ] **Step 1: Write the failing tests**

```bash
test_api_p95_passes_under_budget() {
  sandbox; export FAKE_CURL_TIME=0.2
  bash "$REPO/plugin/scripts/api-p95.sh" -n 5 http://x/api >/dev/null
}
test_api_p95_fails_over_budget() {
  sandbox; export FAKE_CURL_TIME=0.9
  assert_exit 1 bash "$REPO/plugin/scripts/api-p95.sh" -n 5 http://x/api
}
test_api_p95_rejects_no_urls() {
  sandbox
  assert_exit 1 bash "$REPO/plugin/scripts/api-p95.sh"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh api_p95`
Expected: FAIL — script does not exist.

- [ ] **Step 3: Implement `api-p95.sh`**

Parse `-n`. Require at least one URL. For each URL collect times, convert to ms with `awk` or `bc`, sort numerically, take index `ceil(0.95 * n)`. Print `URL p95=NNNms budget=500ms PASS|FAIL`. Track failures and exit accordingly.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh api_p95`
Expected: 3 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add plugin/scripts/api-p95.sh tests/test_api_p95.sh
git commit -m "feat: add api-p95 script for the API p95 budget"
```

---

### Task 8: Plugin packaging and slash commands

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Create: `commands/perf-baseline.md`, `commands/perf-compare.md`, `commands/perf-budget.md`
- Test: `tests/test_plugin.sh`

**Interfaces:**
- Consumes: scripts from Tasks 3–7. Skills at `skills/cogumi-app-performance/SKILL.md` (default discovery).
- Produces: `plugin.json` with `name: "cogumi-app-performance"`, a version, and description. `marketplace.json` with `name: "cogumi-app-performance"` and one plugin entry whose `source` is `"./"`. Each command file has frontmatter `description` and a body that runs `bash "${CLAUDE_PLUGIN_ROOT}/plugin/scripts/<script>.sh" $ARGUMENTS`.

- [ ] **Step 1: Write the failing tests**

```bash
test_plugin_manifests_are_valid_json() {
  sandbox
  jq empty "$REPO/.claude-plugin/plugin.json" && jq empty "$REPO/.claude-plugin/marketplace.json"
}
test_plugin_name_matches_marketplace() {
  assert_eq "$(jq -r .name "$REPO/.claude-plugin/plugin.json")" "cogumi-app-performance" "plugin name"
  assert_eq "$(jq -r .plugins[0].name "$REPO/.claude-plugin/marketplace.json")" "cogumi-app-performance" "entry name"
}
test_commands_exist_and_call_scripts() {
  for pair in perf-baseline:baseline perf-compare:compare perf-budget:budget; do
    f="$REPO/commands/${pair%%:*}.md"; s="${pair##*:}"
    assert_contains "$(cat "$f")" "plugin/scripts/$s.sh" "$f calls $s.sh"
  done
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh plugin`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Create the manifests and commands**

Use the Claude Code plugin manifest schema. Before committing, check the current plugin and marketplace docs for required fields. If the docs cannot be reached, state that in the final report and keep the minimal fields above.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh plugin`
Expected: 3 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin commands tests/test_plugin.sh
git commit -m "feat: add plugin manifests and perf slash commands"
```

---

### Task 9: SKILL.md content gaps and snippet bugs

**Files:**
- Modify: `skills/cogumi-app-performance/SKILL.md`
- Test: `tests/test_skill.sh`

**Interfaces:**
- Consumes: none.
- Produces: new sections and corrected snippets as listed below.

Gap sections to add:
- **P1 — Compression, CDN, Service Workers** (after P1 AI/Streaming, before Measurement): Brotli/gzip with verification via `curl -sI -H 'Accept-Encoding: br' URL | grep -i content-encoding`; `Cache-Control: public, max-age=31536000, immutable` for hashed assets and `no-cache` for HTML; critical CSS inlined or preloaded; service worker strategies: cache-first for static assets, network-first with offline fallback for API.
- **Multi-layer caching** (in P1 — Caching Architecture): memory → Redis → DB; promote a Redis hit into memory with a short TTL; evict memory by LRU with a size cap; the DB is read only on a miss in both layers.
- **AI partial-response fallback** (in P1 — AI/Streaming): once tokens have been shown, do not restart the stream. On error, keep the partial text, show a notice, and offer retry. Retry with backoff only before the first token.
- **P2 — Infrastructure (scale-justified only)**: add edge or multi-region only when p75 TTFB is high from several regions in measured data; add load balancing only when one instance shows saturation (CPU or queue depth) in measured data.

Bug fixes:
- Static/dynamic snippet: split into three separate examples labeled "choose one per route", so `export const dynamic` is not declared twice in one block.
- Next.js font example: `display: 'optional'` to match the CLS guidance (or note the trade-off explicitly).
- Debounce example: `encodeURIComponent(query)` in the request URL.
- Index audit example: replace `SELECT *` with explicit columns.
- Measurement rule 4 and any "Slow 3G" text: change to "Slow 4G".
- Measurement section: add "Lab vs field" note — INP is field-only, use CrUX p75 (PageSpeed Insights API or CrUX dashboard) for the budgets, and use `api-p95.sh` for API p95.

- [ ] **Step 1: Write the failing tests**

```bash
test_skill_has_compression_section() {
  assert_contains "$(cat "$SKILL")" "P1 — Compression, CDN, Service Workers" "section"
}
test_skill_has_multilayer_cache() {
  assert_contains "$(cat "$SKILL")" "memory → Redis → DB" "multi-layer"
}
test_skill_has_partial_fallback() {
  assert_contains "$(cat "$SKILL")" "partial" "partial-response fallback"
}
test_skill_has_p2_infra() {
  assert_contains "$(cat "$SKILL")" "P2 — Infrastructure" "P2 section"
}
test_skill_no_slow_3g() {
  assert_not_contains "$(cat "$SKILL")" "Slow 3G" "throttling wording"
}
test_skill_debounce_encodes_query() {
  assert_contains "$(cat "$SKILL")" "encodeURIComponent(query)" "debounce encodes"
}
test_skill_no_select_star_in_index_audit() {
  assert_not_contains "$(cat "$SKILL")" "EXPLAIN (ANALYZE, BUFFERS) SELECT * " "index audit"
}
test_skill_font_display_consistent() {
  assert_not_contains "$(cat "$SKILL")" "display: 'swap'" "font display"
}
```

Add `assert_not_contains` to `tests/lib.sh` in this task.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh skill`
Expected: FAIL on each new section and bug fix.

- [ ] **Step 3: Edit SKILL.md**

Add the sections and fixes listed above. Keep the existing examples. Use the same heading style and bad/good format as the rest of the file.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh skill`
Expected: 8 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add skills/cogumi-app-performance/SKILL.md tests/test_skill.sh tests/lib.sh
git commit -m "docs: add compression, multi-layer cache, AI fallback and P2 guidance; fix snippets"
```

---

### Task 10: README, plugin docs, AGENTS.md and REQUIREMENTS.md

**Files:**
- Modify: `README.md`, `plugin/SKILL.md`, `AGENTS.md`, `REQUIREMENTS.md`
- Test: `tests/test_docs.sh`

**Interfaces:**
- Consumes: the final script names and plugin name from Tasks 2–8.
- Produces: docs that match the code.

Changes:
- README install Option A: `/plugin marketplace add dkeviv/cogumi-app-performance` then `/plugin install cogumi-app-performance@cogumi-app-performance`.
- README step 4: `bash plugin/scripts/compare.sh http://localhost:3000 --save`.
- README rule and plugin doc: "Slow 4G" everywhere; compare gate described as any category dropping more than 10 points.
- README files tree: add `.claude-plugin/`, `commands/`, `plugin/scripts/lib/settings.sh`, `summarize.sh`, `api-p95.sh`, `tests/`.
- README: add a short section on `api-p95.sh` and a CI section explaining that the regression gate runs `compare.sh` against the committed `perf-scores.json`.
- `plugin/SKILL.md`: rename skill reference to `cogumi-app-performance`; list all three commands with their script calls.
- `AGENTS.md`: change "exit 1 if performance score drops > 10 points" to "exit 1 if any category score drops > 10 points".
- `REQUIREMENTS.md`: skill name `cogumi-app-performance`; record decisions D1–D7; update the CI section to match D4 and D5; update the throttling wording to Slow 4G.

- [ ] **Step 1: Write the failing tests**

```bash
test_docs_install_command_matches_plugin() {
  assert_contains "$(cat "$REPO/README.md")" "cogumi-app-performance@cogumi-app-performance" "install"
  assert_not_contains "$(cat "$REPO/README.md")" "app-performance@cogumi-app-performance" "old install"
}
test_docs_save_example_has_url() {
  assert_not_contains "$(cat "$REPO/README.md")" "compare.sh --save" "save example"
}
test_docs_no_slow_3g() {
  assert_not_contains "$(cat "$REPO/README.md")" "Slow 3G" "README"
  assert_not_contains "$(cat "$REPO/plugin/SKILL.md")" "Slow 3G" "plugin"
}
test_docs_requirements_name() {
  assert_not_contains "$(cat "$REPO/REQUIREMENTS.md")" "Skill: \`app-performance\`" "spec name"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run.sh docs`
Expected: FAIL on the old install command, the `--save` example, and Slow 3G.

- [ ] **Step 3: Edit the four docs**

Make the changes listed above. Keep README structure. Do not add new sections beyond the `api-p95` and CI notes.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run.sh docs`
Expected: 4 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add README.md plugin/SKILL.md AGENTS.md REQUIREMENTS.md tests/test_docs.sh
git commit -m "docs: align README, plugin docs, AGENTS.md and spec with implementation"
```

---

### Task 11: Full verification

**Files:** none modified unless a test fails.

- [ ] **Step 1: Run the whole suite**

Run: `bash tests/run.sh`
Expected: all tests pass, 0 failed. Save output to the workspace; do not paste it into the repo.

- [ ] **Step 2: Lint the scripts**

Run: `shellcheck plugin/scripts/*.sh plugin/scripts/lib/*.sh tests/*.sh tests/bin/*` if `shellcheck` is installed.
Expected: no errors. If shellcheck is not installed, say so in the final report.

- [ ] **Step 3: Manual run against a real page (optional, not verified by tests)**

Requires Chrome and `@lhci/cli`. Run `bash plugin/scripts/baseline.sh <url>` against a local page, then `compare.sh <url>`. Report the real numbers or state that this was not run.

- [ ] **Step 4: Confirm the working tree is clean**

Run: `git status`
Expected: no uncommitted changes.

## Self-Review

- **Spec coverage:** P1 compression/CDN/SW/critical CSS → Task 9. Multi-layer caching → Task 9. AI partial fallback → Task 9. P2 infra → Task 9. API p95 → Task 7 and Task 10. perf.budget.json budgetsFile → Task 6. Plugin manifest and slash commands → Task 8. CI 10-point gate → Tasks 4 and 6. INP in CI → D5, documented in Task 9 and Task 10. Throttling consistency → Tasks 2, 3, 6. Median claim → Task 2 and Task 3. `--save` bug → Task 4. Spec name → Task 10. Snippet bugs → Task 9. bc check → Task 5. Debounce encode and SELECT * → Task 9. CrUX → D7, documented in Task 9.
- **Review Focus:**
  - lhci yields fewer than 3 reports → `test_summarize_requires_three_reports` (Task 2).
  - INP absent in lab run → `test_summarize_inp_absent_is_null` and `test_baseline_prints_inp_na_when_absent` (Tasks 2–3).
  - `--save` before or after URL, or alone → `test_compare_save_after_url`, `test_compare_save_without_url` (Task 4).
  - Baseline file missing → `test_compare_requires_baseline` (Task 4).
  - bc missing → `test_install_check_requires_bc` (Task 5).
- **Type consistency:** `summarize.sh REPORT_DIR` output schema is the same one `baseline.sh` writes today. `settings.sh` defines `LH_COLLECT_FLAGS`. `api-p95.sh` flags are `-n` and URL list. Test names match the functions in the tasks.
- **Proportion:** Task bodies name tests and assertions and leave script bodies to the implementer, per the step granularity rule.
