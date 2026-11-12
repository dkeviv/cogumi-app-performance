#!/usr/bin/env bash
# Generates lighthouserc.json and perf.budget.json for CI enforcement.
# Usage: bash budget.sh [url]
set -euo pipefail

URL="${1:-http://localhost:3000}"
LHCI_CONFIG="lighthouserc.json"
BUDGET_FILE="perf.budget.json"

echo "Generating CI performance config for: $URL"

# lighthouserc.json — used by lhci autorun in CI
cat > "$LHCI_CONFIG" <<EOF
{
  "ci": {
    "collect": {
      "url": ["$URL"],
      "numberOfRuns": 3,
      "settings": {
        "throttlingMethod": "simulate",
        "formFactor": "mobile",
        "screenEmulation": {
          "mobile": true,
          "width": 375,
          "height": 812,
          "deviceScaleFactor": 3
        },
        "throttling": {
          "rttMs": 150,
          "throughputKbps": 1638.4,
          "cpuSlowdownMultiplier": 4,
          "requestLatencyMs": 562.5,
          "downloadThroughputKbps": 1474.56,
          "uploadThroughputKbps": 675
        }
      }
    },
    "assert": {
      "preset": "lighthouse:no-pwa",
      "assertions": {
        "categories:performance": ["error", {"minScore": 0.7}],
        "categories:accessibility": ["warn", {"minScore": 0.9}],
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}],
        "cumulative-layout-shift": ["error", {"maxNumericValue": 0.1}],
        "total-blocking-time": ["warn", {"maxNumericValue": 300}],
        "interactive": ["warn", {"maxNumericValue": 5000}]
      }
    }
  }
}
EOF

echo "Created $LHCI_CONFIG"

# perf.budget.json — resource budgets checked separately
cat > "$BUDGET_FILE" <<EOF
[
  {
    "path": "/*",
    "timings": [
      { "metric": "interactive", "budget": 5000 },
      { "metric": "first-contentful-paint", "budget": 2000 },
      { "metric": "largest-contentful-paint", "budget": 2500 },
      { "metric": "cumulative-layout-shift", "budget": 0.1 },
      { "metric": "total-blocking-time", "budget": 300 }
    ],
    "resourceSizes": [
      { "resourceType": "script", "budget": 300 },
      { "resourceType": "image", "budget": 500 },
      { "resourceType": "stylesheet", "budget": 50 },
      { "resourceType": "font", "budget": 100 },
      { "resourceType": "total", "budget": 1000 }
    ],
    "resourceCounts": [
      { "resourceType": "third-party", "budget": 10 },
      { "resourceType": "total", "budget": 50 }
    ]
  }
]
EOF

echo "Created $BUDGET_FILE"

# GitHub Actions workflow snippet
echo ""
echo "=== GitHub Actions CI snippet ==="
cat <<'EOF'
# .github/workflows/perf.yml
name: Lighthouse CI
on: [push, pull_request]
jobs:
  lhci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run build
      - run: npm run start &
      - run: npx wait-on http://localhost:3000
      - run: npm install -g @lhci/cli
      - run: lhci collect
      - run: lhci assert
      - run: lhci assert --no-lighthouserc --budgetsFile=perf.budget.json
      # Regression gate: fails if any category drops > 10 points vs the committed perf-scores.json.
      # Requires the plugin scripts in the repo (clone or vendor cogumi-app-performance/plugin/scripts).
      - run: bash cogumi-app-performance/plugin/scripts/compare.sh http://localhost:3000
EOF

echo ""
echo "Add the GitHub Actions snippet above to .github/workflows/perf.yml"
echo "Commit $LHCI_CONFIG, $BUDGET_FILE and perf-scores.json (from baseline.sh) to your repository."
