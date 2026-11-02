# cogumi-app-performance — Requirements

## Purpose

A Claude Code skill + plugin that covers the full app performance stack: from perceived speed
(what users feel) through frontend assets, rendering, API efficiency, backend/database, caching,
AI/streaming, and automated measurement with CI enforcement.

No existing skill covers all of these. This skill borrows the best parts from:
- Addy Osmani / web-quality-skills — Core Web Vitals, page-weight budgets, before/after metrics
- Vercel / react-best-practices — async waterfall elimination, bundle optimization, re-render rules
- LEO0331 / lighthouse-skill-pack — Lighthouse CI assertions, framework-specific audits
- Community Redis + DB skills — caching patterns, N+1 detection, index auditing

## Performance Budgets (enforced)

| Metric | Budget | Percentile |
|--------|--------|-----------|
| LCP | ≤ 2.5s | p75 field |
| INP | ≤ 200ms | p75 field |
| CLS | ≤ 0.1 | p75 field |
| Compressed JS | ≤ 300 KB | per page |
| Above-fold images | ≤ 500 KB | per page |
| API response (p95) | ≤ 500ms | per endpoint |
| TTFT (AI streaming) | ≤ 1s | per LLM call |

## Skill: `app-performance` (SKILL.md)

**Trigger keywords:** performance, slow, loading, optimization, LCP, INP, CLS, bundle, skeleton,
caching, N+1, streaming, lazy, debounce, waterfall, prefetch, Redis, timeout, stale

### Categories covered (items 1–33 from design table)

#### P0 — Perceived Performance
- Skeleton screens: layout-matched, no CLS (NEW — not in any existing skill)
- Stale-while-revalidate: show cached content immediately, refresh in background (NEW)
- Optimistic UI: only for safe reversible actions with rollback (NEW)

#### P0 — Frontend / Assets
- LCP: fetchpriority=high on hero image, preload fonts, eliminate render-blocking
- Images: WebP/AVIF + responsive srcset; lazy-load below-fold only; never lazy first image
- CLS: explicit dimensions on all media; stable font loading
- Bundle: code-split by route; remove barrel imports; target < 300 KB compressed JS

#### P0 — Rendering
- Async waterfall elimination: parallel independent fetches, Promise.all (from Vercel)
- Re-render optimization: memo/useMemo/useCallback only where profiler shows waste (from Vercel)

#### P0 — API / Network
- Request deduplication: share in-flight; block identical concurrent calls
- Request cancellation: AbortController; debounce search ≥ 300ms (NEW)
- Pagination: cursor-based; progressive load on scroll (NEW)

#### P0 — Backend / Database
- N+1 detection: batch with DataLoader / include / joinedload
- Index audit: cover query predicates and sort columns; explain-plan review
- Column selection: no SELECT * in hot paths (NEW)

#### P1 — Compression, CDN, Service Workers
- Brotli/gzip; verify Content-Encoding header
- CDN + cache headers: immutable for hashed assets, no-cache for HTML
- Critical CSS inline or preload; defer non-critical
- Service workers: cache-first static, network-first API with offline fallback

#### P1 — Caching Architecture
- Client: TanStack Query / SWR staleTime + cacheTime; per-resource TTL
- Server: Redis cache-aside pattern; TTL + invalidation; key naming conventions
- Multi-layer: memory → Redis → DB; promotion and eviction rules

#### P1 — AI / Streaming (NEW — no existing skill covers this)
- Show first token immediately; stream UI updates incrementally
- TTFT budget: < 1s; surface latency in dev logs
- Abort stream on user navigation or new query
- Partial-response fallback; exponential backoff on errors

#### P2 — Infrastructure (scale-justified only)
- Edge/multi-region: only when observed high TTFB globally
- Load balancing: only when single instance is saturated

## Plugin: measurement loop (items 34–40)

**Slash commands:**
- `/perf-baseline` — runs Lighthouse, saves `perf-scores.json`
- `/perf-compare` — runs Lighthouse again, diffs against baseline, prints delta table
- `/perf-budget` — writes `lighthouserc.json` + `perf.budget.json` for CI enforcement

**Scripts:**
- `scripts/baseline.sh` — Lighthouse CLI run with mobile throttling; saves JSON
- `scripts/compare.sh` — second run + diff against baseline
- `scripts/budget.sh` — generates config files for CI
- `scripts/install-check.sh` — verifies Lighthouse and Chrome are available

**CI integration:**
- `lighthouserc.json` blocks PR if any score drops > 10 points
- `perf.budget.json` enforces JS bundle, image, and API budgets

## Non-goals

- No infrastructure provisioning
- No framework migrations
- No speculative optimizations without measurement evidence
- No changes to auth, payments, or data-destructive operations
- Never claim performance improvement without before/after numbers

## Anti-goals (what makes this a failure)

- Skill that adds optimizations speculatively without checking profiler/metrics first
- Skill that adds Redis/CDN/load balancing before confirming they are the bottleneck
- Plugin that breaks CI on false positives (unstable Lighthouse scores)
- Rules that conflict with framework defaults (e.g., fighting Next.js Image optimizer)
