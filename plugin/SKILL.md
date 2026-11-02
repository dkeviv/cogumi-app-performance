# App Performance Plugin

Provides three slash commands for automated Lighthouse measurement and CI enforcement.
Use these before and after applying optimizations from the `app-performance` skill.

## Commands

### /perf-baseline

Runs Lighthouse against the local dev server (default: http://localhost:3000) and saves scores
to `perf-scores.json`. Run this before making any performance changes.

```
/perf-baseline [url]
```

- Default URL: `http://localhost:3000`
- Saves: `perf-scores.json` in the project root
- Simulates: mobile, CPU throttle 4×, Slow 4G

### /perf-compare

Runs Lighthouse again and diffs against the saved baseline. Prints a delta table showing
improvement or regression per metric.

```
/perf-compare [url]
```

Requires `perf-scores.json` to exist (run `/perf-baseline` first).

### /perf-budget

Generates `lighthouserc.json` and `perf.budget.json` for CI enforcement. Blocks PRs if any
score drops more than 10 points from baseline.

```
/perf-budget
```

## When to use

1. Start of any performance task → `/perf-baseline`
2. After applying optimizations → `/perf-compare`
3. Setting up a new project → `/perf-budget`

## Requirements

- Node.js ≥ 18
- Chrome or Chromium installed
- `@lhci/cli` installed: `npm install -g @lhci/cli`

Run `bash plugin/scripts/install-check.sh` to verify.
