# Lighthouse Slow 4G profile, shared by baseline.sh and compare.sh.
# budget.sh writes the same values into lighthouserc.json; tests/test_budget.sh enforces that.
LH_COLLECT_FLAGS=(
  --settings.throttlingMethod=simulate
  --settings.throttling.cpuSlowdownMultiplier=4
  --settings.throttling.rttMs=150
  --settings.throttling.throughputKbps=1638.4
  --settings.throttling.requestLatencyMs=562.5
  --settings.throttling.downloadThroughputKbps=1474.56
  --settings.throttling.uploadThroughputKbps=675
  --settings.formFactor=mobile
  --settings.screenEmulation.mobile=true
  --settings.screenEmulation.width=375
  --settings.screenEmulation.height=812
  --settings.screenEmulation.deviceScaleFactor=3
  --numberOfRuns=3
)
