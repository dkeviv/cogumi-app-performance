# cogumi-app-performance

A Claude Code **skill** and **plugin** for comprehensive app performance optimization — covering perceived speed, frontend assets, rendering, API efficiency, backend/database, caching, and AI streaming, with automated Lighthouse measurement and CI enforcement.

---

## What's included

| Component | Path | Purpose |
|-----------|------|---------|
| **Skill** | `skills/app-performance/SKILL.md` | Coding rules and patterns loaded into Claude's context when working on performance |
| **Plugin** | `plugin/SKILL.md` | Three slash commands for automated Lighthouse measurement |
| `baseline.sh` | `plugin/scripts/baseline.sh` | Run Lighthouse, save scores to `perf-scores.json` |
| `compare.sh` | `plugin/scripts/compare.sh` | Re-run Lighthouse, diff against baseline |
| `budget.sh` | `plugin/scripts/budget.sh` | Generate `lighthouserc.json` and `perf.budget.json` for CI |
| `install-check.sh` | `plugin/scripts/install-check.sh` | Verify all prerequisites are installed |

---

## Performance budgets enforced

| Metric | Budget |
|--------|--------|
| LCP | ≤ 2.5s (p75 field data) |
| INP | ≤ 200ms (p75 field data) |
| CLS | ≤ 0.1 (p75 field data) |
| Compressed JS | ≤ 300 KB per page |
| Above-fold images | ≤ 500 KB per page |
| API response p95 | ≤ 500ms per endpoint |
| Time-to-first-token | ≤ 1s per LLM call |

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Node.js | ≥ 18 | https://nodejs.org |
| Lighthouse CI | latest | `npm install -g @lhci/cli` |
| jq | any | `brew install jq` / `apt install jq` |
| Chrome or Chromium | any | https://google.com/chrome |

Verify everything is in place:

```bash
bash plugin/scripts/install-check.sh
```

---

## Installing the skill

### Option A — Claude Code marketplace (recommended)

```bash
/plugin marketplace add dkeviv/cogumi-app-performance
/plugin install app-performance@cogumi-app-performance
```

### Option B — npx

```bash
npx skills add dkeviv/cogumi-app-performance
```

### Option C — manual

Clone this repo and copy the skill file into your Claude skills directory:

```bash
git clone https://github.com/dkeviv/cogumi-app-performance.git
cp cogumi-app-performance/skills/app-performance/SKILL.md ~/.claude/skills/app-performance.md
```

Once installed, the skill loads automatically when your task involves: `performance`, `slow`, `loading`, `LCP`, `INP`, `CLS`, `bundle`, `skeleton`, `caching`, `N+1`, `streaming`, `lazy`, `debounce`, `waterfall`, `prefetch`, `Redis`, or `timeout`.

---

## Installing the plugin

Clone the repo into your project (or anywhere accessible):

```bash
git clone https://github.com/dkeviv/cogumi-app-performance.git
```

Make scripts executable if they aren't already:

```bash
chmod +x cogumi-app-performance/plugin/scripts/*.sh
```

---

## Using the plugin — slash commands

### `/perf-baseline` — capture a baseline

Run this **before making any performance changes**. It runs Lighthouse against your local dev server and saves scores to `perf-scores.json`.

```bash
# Default: targets http://localhost:3000
bash plugin/scripts/baseline.sh

# Custom URL
bash plugin/scripts/baseline.sh http://localhost:8080
```

**What it does:**
- Runs Lighthouse 3 times with mobile throttling (CPU 4×, Slow 4G)
- Saves scores, Core Web Vitals, and resource weights to `perf-scores.json`
- Prints a budget check (LCP, INP, CLS, JS bundle size)

**Example output:**
```
Running Lighthouse baseline against: http://localhost:3000
Throttling: mobile, CPU 4×, Slow 4G

Baseline saved to perf-scores.json

{
  "Performance score": 62,
  "LCP (ms)": 3100,
  "CLS": 0.12,
  "TBT (ms)": 420,
  "JS (KB)": 380
}

Budgets:
  ✗ LCP 3100ms > 2500ms (budget: 2500ms)
  ✗ CLS 0.12 > 0.1 (budget: 0.1)
  ✗ JS 380KB > 300KB (budget: 300KB)
```

---

### `/perf-compare` — measure improvement after changes

Run this **after applying optimizations**. Requires `perf-scores.json` from a previous baseline run.

```bash
# Default: targets http://localhost:3000
bash plugin/scripts/compare.sh

# Custom URL
bash plugin/scripts/compare.sh http://localhost:8080

# Custom URL + save current run as the new baseline
bash plugin/scripts/compare.sh http://localhost:3000 --save
```

**What it does:**
- Runs Lighthouse 3 times with the same mobile throttling as baseline
- Diffs every metric against `perf-scores.json`
- Exits with code 1 if the performance score dropped more than 10 points
- Optionally updates the baseline with `--save`

**Example output:**
```
=== Performance Delta ===

Metric                          Baseline    Current      Delta  Status
------                          --------    -------      -----  ------
Performance score                     62         78         16  ↑ better
LCP (ms)                            3100       2200        900  ↓ better
CLS (×1000)                          120         60         60  ↓ better
TBT (ms)                             420        180        240  ↓ better
FCP (ms)                            1800       1200        600  ↓ better
Speed Index                         3400       2100       1300  ↓ better
JS bundle (KB)                       380        280        100  ↓ better
Image weight (KB)                    620        310        310  ↓ better

✓ No regression detected (delta: -16 points).
```

---

### `/perf-budget` — set up CI enforcement

Run this once when setting up a new project. Generates config files that block PRs when performance regresses.

```bash
# Default: targets http://localhost:3000
bash plugin/scripts/budget.sh

# Custom URL (used in generated lighthouserc.json)
bash plugin/scripts/budget.sh https://staging.myapp.com
```

**What it generates:**

`lighthouserc.json` — used by `lhci autorun` in CI. Asserts:
- Performance score ≥ 70
- Accessibility score ≥ 90
- LCP ≤ 2500ms
- CLS ≤ 0.1
- TBT ≤ 300ms
- Text compression enabled

`perf.budget.json` — resource budgets:
- JS ≤ 300 KB
- Images ≤ 500 KB
- Fonts ≤ 100 KB
- Total page weight ≤ 1 MB
- ≤ 50 total requests

The script also prints a ready-to-use **GitHub Actions workflow** snippet.

**Commit both files to your repository:**
```bash
git add lighthouserc.json perf.budget.json
git commit -m "chore: add Lighthouse CI performance budgets"
```

---

## Recommended workflow

```
1. Start feature or performance task
   └─ bash plugin/scripts/baseline.sh        # capture current state

2. Apply optimizations
   └─ (Claude uses the app-performance skill to guide changes)

3. Measure improvement
   └─ bash plugin/scripts/compare.sh         # verify delta

4. If improved, update baseline
   └─ bash plugin/scripts/compare.sh --save  # promote to new baseline

5. Set up CI (once per project)
   └─ bash plugin/scripts/budget.sh          # generate CI config
   └─ git add lighthouserc.json perf.budget.json && git commit
```

---

## What the skill covers

The skill loads coding rules across these categories when triggered:

| Category | Examples |
|----------|---------|
| **Perceived performance** | Skeleton screens, stale-while-revalidate, optimistic UI, prefetching |
| **Frontend / assets** | LCP image priority, WebP/AVIF, CLS prevention, bundle splitting |
| **Rendering** | Async waterfall elimination, re-render optimization (React) |
| **API / network** | Request deduplication, cancellation (AbortController), cursor pagination, timeouts |
| **Backend / database** | N+1 detection, index auditing, column selection |
| **Caching** | TanStack Query staleTime, Redis cache-aside pattern, TTL strategy |
| **AI / streaming** | Stream-first token, TTFT budget, stream cancellation, retry backoff |

Full rules with bad/good code examples are in [`skills/app-performance/SKILL.md`](skills/app-performance/SKILL.md).

---

## Key rules (summary)

- **Always measure before changing anything.** Run `/perf-baseline` first.
- **Report before/after metrics** for every optimization.
- **Do not add Redis, CDN, or load balancing** before confirming they solve an observed bottleneck.
- **Do not add `memo`/`useMemo`/`useCallback`** without profiler evidence.
- **Never `loading="lazy"` the first visible image** — it delays LCP.
- **Never optimistic UI on payments, deletes, or permission changes.**
- **Test on low-end mobile**: CPU throttle 4×, Slow 3G network.

---

## Files

```
cogumi-app-performance/
├── README.md
├── REQUIREMENTS.md              # Full design spec and rationale
├── skills/
│   └── app-performance/
│       └── SKILL.md             # The skill — loaded into Claude's context
└── plugin/
    ├── SKILL.md                 # Plugin docs and slash command definitions
    └── scripts/
        ├── install-check.sh     # Verify prerequisites
        ├── baseline.sh          # /perf-baseline
        ├── compare.sh           # /perf-compare
        └── budget.sh            # /perf-budget
```

---

## License

MIT
