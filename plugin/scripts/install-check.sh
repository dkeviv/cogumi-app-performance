#!/usr/bin/env bash
# Verifies that Lighthouse CI and Chrome are available before running audits.
set -euo pipefail

ERRORS=0

check() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" &>/dev/null; then
    echo "  ✓ $name found: $(command -v "$cmd")"
  else
    echo "  ✗ $name not found — install: $3"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "Checking prerequisites for app-performance plugin..."
echo ""

check "Node.js (≥18)" "node" "https://nodejs.org"
check "lhci" "lhci" "npm install -g @lhci/cli"
check "jq" "jq" "brew install jq  (macOS) or apt install jq  (Linux)"
check "bc" "bc" "brew install bc  (macOS) or apt install bc  (Linux)"

# Check Chrome / Chromium
if command -v google-chrome &>/dev/null || command -v chromium-browser &>/dev/null \
   || command -v chromium &>/dev/null \
   || [ -d "/Applications/Google Chrome.app" ]; then
  echo "  ✓ Chrome/Chromium found"
else
  echo "  ✗ Chrome not found — install Google Chrome or Chromium"
  ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -eq 0 ]; then
  echo "All prerequisites met. Run /perf-baseline to start."
else
  echo "$ERRORS prerequisite(s) missing. Fix above before running audits."
  exit 1
fi
