# App Performance Plugin

Provides three slash commands for Lighthouse measurement and CI enforcement. Use them before and after applying optimizations from the `cogumi-app-performance` skill.

## Commands

### /perf-baseline

Runs Lighthouse against the local dev server (default: http://localhost:3000) three times, takes the median of each metric, and saves scores to `perf-scores.json`. Run this before making any performance changes.

```
/perf-baseline [url]
```

- Default URL: `http://localhost:3000`
- Saves: `perf-scores.json` in the project root
- Simulates: mobile, CPU throttle 4×, Slow 4G

### /perf-compare

Runs Lighthouse again and diffs against the saved baseline. Prints a delta table for all four category scores and the Core Web Vitals.

```
/perf-compare [url] [--save]
```

- Requires `perf-scores.json` (run `/perf-baseline` first).
- Exits 1 if any category score (performance, accessibility, SEO, best practices) drops by more than 10 points.
- `--save` promotes the current run to the baseline. It may appear before or after the URL.

### /perf-budget

Generates `lighthouserc.json` and `perf.budget.json` for CI enforcement, and prints a GitHub Actions snippet. The snippet runs `lhci autorun` and then `compare.sh` against the committed `perf-scores.json`.

```
/perf-budget [url]
```

### API latency

Lighthouse cannot measure API latency. Use the script directly:

```
bash plugin/scripts/api-p95.sh [-n RUNS] URL...
```

It exits 1 if any URL's p95 exceeds 500ms.

## When to use

1. Start of any performance task → `/perf-baseline`
2. After applying optimizations → `/perf-compare`
3. Setting up a new project → `/perf-budget`

## Requirements

- Node.js ≥ 18
- Chrome or Chromium installed
- `@lhci/cli` installed: `npm install -g @lhci/cli`
- `jq` and `bc`

Run `bash plugin/scripts/install-check.sh` to verify.
