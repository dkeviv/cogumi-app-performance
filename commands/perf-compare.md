---
description: Re-run Lighthouse and diff against perf-scores.json; fails if any category drops more than 10 points
argument-hint: "[url] [--save]"
---

Run the compare script and report the delta table. The default URL is http://localhost:3000. Pass --save to promote the current run to the baseline.

!`bash "${CLAUDE_PLUGIN_ROOT}/plugin/scripts/compare.sh" $ARGUMENTS`

Report before and after numbers for every metric that changed, and state clearly if the regression gate failed.
