---
description: Capture a Lighthouse baseline (median of 3 runs, Slow 4G) into perf-scores.json
argument-hint: "[url]"
---

Run the baseline script and report the output. The default URL is http://localhost:3000.

!`bash "${CLAUDE_PLUGIN_ROOT}/plugin/scripts/baseline.sh" $ARGUMENTS`

Report the performance score, LCP, CLS, TBT, JS size and budget lines. Do not claim any improvement from this run.
