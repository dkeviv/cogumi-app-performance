# cogumi-app-performance

App performance rules for AI coding agents (Claude Code, Codex, Cursor, etc.).

## Setup (one-time)

```bash
npm install -g @lhci/cli   # requires Node ≥ 18 and Chrome
brew install jq
```

## Workflow

Before optimizing anything, run the baseline:

```bash
bash path/to/cogumi-app-performance/plugin/scripts/baseline.sh [url]
# default url: http://localhost:3000
# writes: perf-scores.json
```

After changes, measure the delta:

```bash
bash path/to/cogumi-app-performance/plugin/scripts/compare.sh [url]
# compares against perf-scores.json
# exit 1 if performance score drops > 10 points
```

## Performance budgets

| Metric | Budget |
|--------|--------|
| LCP | ≤ 2500ms |
| INP | ≤ 200ms |
| CLS | ≤ 0.1 |
| JS (compressed) | ≤ 300 KB |
| Images (above fold) | ≤ 500 KB |
| API p95 | ≤ 500ms |
| Time-to-first-token | ≤ 1000ms |

## Rules for the agent

**Always check `perf-scores.json` first** if it exists in the project root. Use its numbers as the baseline when suggesting or applying optimizations. Report before/after metrics for every change.

**Never optimize speculatively.** Only change what a measured bottleneck justifies.

### Critical rules

- `fetchpriority="high"` on the largest above-fold image; never `loading="lazy"` on the first visible image
- Explicit `width` + `height` on every `<img>` and media element (prevents CLS)
- Code-split by route; no barrel imports (`import { x } from '@/components'`)
- Parallel fetches with `Promise.all`; no sequential `await` for independent data
- `AbortController` on every search/autocomplete fetch; debounce 300ms
- Cursor-based pagination; never offset on large tables
- `include`/DataLoader for N+1 queries; `EXPLAIN ANALYZE` before adding indexes
- `SELECT` only needed columns; never `SELECT *` in hot paths
- Redis cache-aside: `EX` TTL + `DEL` on write; key format `resource:id`
- For AI streaming: stream first token immediately; cancel stream on unmount/new query; log TTFT
- `useMemo`/`useCallback`/`memo` only after React Profiler confirms unnecessary re-renders

### Anti-patterns (never do these)

- Add Redis/CDN before confirming the DB is the bottleneck
- `loading="lazy"` on the first visible image
- Skeleton screens with different dimensions than real content (causes CLS)
- Optimistic UI on payments, deletes, or permission changes
- `SELECT *` in any hot path
- Sequential `await` for independent data fetches
