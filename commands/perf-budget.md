---
description: Generate lighthouserc.json and perf.budget.json for CI and print the GitHub Actions snippet
argument-hint: "[url]"
---

Run the budget script, then tell the user which files were created and what to commit.

!`bash "${CLAUDE_PLUGIN_ROOT}/plugin/scripts/budget.sh" $ARGUMENTS`

Remind the user to commit lighthouserc.json, perf.budget.json and perf-scores.json.
