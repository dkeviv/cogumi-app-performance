# App Performance

## When to use this skill

Load this skill when the task involves any of: performance, slow, loading, optimization, LCP, INP,
CLS, bundle size, skeleton screens, caching, N+1 queries, streaming, lazy loading, debouncing,
request waterfalls, prefetching, Redis, timeouts, or stale data.

**Always measure before changing anything.** An optimization without a before/after metric is
speculation. If you cannot measure, say so explicitly rather than claiming improvement.

---

## Performance Budgets

Check these first. If the app already meets all of them, no optimization is needed.

| Metric | Budget | When |
|--------|--------|------|
| LCP | ≤ 2.5s | p75 field data |
| INP | ≤ 200ms | p75 field data |
| CLS | ≤ 0.1 | p75 field data |
| Compressed JS | ≤ 300 KB | per page load |
| Above-fold images | ≤ 500 KB | per page load |
| API response p95 | ≤ 500ms | per endpoint |
| Time-to-first-token | ≤ 1s | per LLM call |

---

## P0 — Perceived Performance

These make the app feel fast. Apply before any load-time optimization.

### Skeleton screens

Show a layout-matched placeholder that mirrors the shape of real content while data loads.
Never show a generic spinner for content that has a predictable layout.

```tsx
// Bad
if (loading) return <Spinner />;

// Good
if (loading) return <ArticleSkeleton />;  // matches article card dimensions exactly

function ArticleSkeleton() {
  return (
    <div className="skeleton-card" aria-busy="true" aria-label="Loading article">
      <div className="skeleton-img" style={{ width: '100%', height: 180 }} />
      <div className="skeleton-title" style={{ width: '70%', height: 20, marginTop: 12 }} />
      <div className="skeleton-body" style={{ width: '90%', height: 14, marginTop: 8 }} />
    </div>
  );
}
```

**Rule:** Skeleton dimensions must match real content dimensions exactly — any mismatch causes
CLS when real content renders.

### Stale-while-revalidate

On repeat visits, show the previously cached result immediately and refresh in the background.
Do not show a skeleton on repeat visits to the same route.

```ts
// TanStack Query
const { data } = useQuery({
  queryKey: ['articles'],
  queryFn: fetchArticles,
  staleTime: 30_000,      // show cached for 30s before marking stale
  gcTime: 5 * 60_000,     // keep in memory 5 min
});

// SWR equivalent
const { data } = useSWR('/api/articles', fetcher, {
  revalidateOnMount: true,
  revalidateOnFocus: false,
  dedupingInterval: 30_000,
});
```

**Rule:** Set `staleTime` / `dedupingInterval` per resource type. Static config: 10 min.
User feed: 30s. Real-time data: 0s.

### Optimistic UI

Apply only to safe, reversible actions (likes, bookmarks, toggles). Never apply to payments,
deletes, publishes, or permission changes.

```ts
// Bad — wait for server to show result
async function toggleBookmark(id: string) {
  await api.post('/bookmarks', { id });
  refetch();
}

// Good — update immediately, rollback on failure
const mutation = useMutation({
  mutationFn: (id: string) => api.post('/bookmarks', { id }),
  onMutate: async (id) => {
    await queryClient.cancelQueries({ queryKey: ['article', id] });
    const prev = queryClient.getQueryData(['article', id]);
    queryClient.setQueryData(['article', id], (old) => ({ ...old, bookmarked: !old.bookmarked }));
    return { prev };
  },
  onError: (_err, id, ctx) => {
    queryClient.setQueryData(['article', id], ctx.prev);
  },
});
```

### Prefetching

Prefetch only when confidence of navigation is high (hover, visible in viewport). Be conservative
on mobile data connections.

```ts
// On link hover
onMouseEnter={() => queryClient.prefetchQuery({ queryKey: ['article', id], queryFn: ... })}

// On viewport entry (IntersectionObserver)
// Prefetch next page when last item is 80% scrolled into view
```

---

## P0 — Frontend / Assets

### LCP (Largest Contentful Paint)

The single most impactful change for LCP is prioritizing the largest above-fold image.

```html
<!-- Bad: image loads at default priority -->
<img src="/hero.jpg" alt="Hero" />

<!-- Good: fetchpriority=high + correct size hints -->
<img
  src="/hero.webp"
  srcset="/hero-640.webp 640w, /hero-1280.webp 1280w"
  sizes="(max-width: 640px) 640px, 1280px"
  alt="Hero"
  fetchpriority="high"
  decoding="async"
  width="1280"
  height="720"
/>
```

Preload critical fonts before the browser discovers them:
```html
<link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin />
```

### Images

```
Above-fold images  → fetchpriority="high", no loading="lazy", explicit width/height
Below-fold images  → loading="lazy", explicit width/height (prevents CLS)
Format             → WebP or AVIF (serve via <picture> with fallback)
Size               → srcset with at least 3 breakpoints; never serve >2× display size
```

```html
<!-- Correct pattern -->
<picture>
  <source type="image/avif" srcset="/img-640.avif 640w, /img-1280.avif 1280w" sizes="..." />
  <source type="image/webp" srcset="/img-640.webp 640w, /img-1280.webp 1280w" sizes="..." />
  <img src="/img-1280.jpg" alt="..." width="1280" height="720" loading="lazy" />
</picture>
```

### CLS (Cumulative Layout Shift)

Every media element must have explicit `width` + `height` (or `aspect-ratio`) before it loads.

```css
/* Prevent image layout shift */
img { width: 100%; height: auto; aspect-ratio: 16/9; }

/* Prevent font FOUT shift */
@font-face {
  font-display: optional;  /* use fallback if font not cached */
}
```

Never inject content above existing content after load. Reserve space for ads and embeds.

### Bundle size

```
Target: < 300 KB compressed JS per page

Check:  npx bundlesize --config bundlesize.config.json
        npx webpack-bundle-analyzer stats.json
```

```ts
// Bad: barrel import loads entire library
import { Button, Input, Modal, Table, ... } from '@/components';

// Good: direct imports — tree-shakeable
import { Button } from '@/components/Button';
import { Input } from '@/components/Input';

// Bad: load all at once
import HeavyChart from 'recharts';

// Good: code-split by route
const HeavyChart = lazy(() => import('recharts'));
```

---

## P0 — Rendering

### Eliminate async waterfalls

Sequential awaits in a component = waterfall. Fetch independent data in parallel.

```ts
// Bad — waterfall: 600ms total
const user = await getUser(id);
const posts = await getPosts(id);
const followers = await getFollowers(id);

// Good — parallel: 200ms total (slowest of the three)
const [user, posts, followers] = await Promise.all([
  getUser(id),
  getPosts(id),
  getFollowers(id),
]);
```

In React Server Components, start fetches at the top of the component tree, not inside children.

### Re-render optimization

Profile before optimizing. Open React DevTools Profiler, record an interaction, then fix only
the components that show unnecessary renders.

```tsx
// Bad: new object on every render triggers child re-render
<Child config={{ theme: 'dark', size: 'lg' }} />

// Good: stable reference
const config = useMemo(() => ({ theme: 'dark', size: 'lg' }), []);
<Child config={config} />

// Bad: inline callback recreated every render
<Button onClick={() => handleClick(id)} />

// Good: stable callback bound to the specific id
const handleClick = useCallback(() => { doSomething(id); }, [id]);
<Button onClick={handleClick} />
```

**Rule:** Do not add memo/useMemo/useCallback speculatively. Add only after profiler confirms
the re-render is causing measurable lag.

---

## P0 — API / Network

### Request deduplication

Never fire the same request twice simultaneously. Use a query library or manual deduplication.

```ts
// TanStack Query deduplicates automatically when queryKey matches
// For manual deduplication:
const inFlight = new Map<string, Promise<Response>>();

function dedupedFetch(url: string) {
  if (inFlight.has(url)) return inFlight.get(url)!;
  const p = fetch(url).finally(() => inFlight.delete(url));
  inFlight.set(url, p);
  return p;
}
```

### Request cancellation

Abort superseded requests. A stale response arriving after a newer one corrupts UI state.

```ts
// Search: debounce + cancel on new input
const controllerRef = useRef<AbortController | null>(null);

async function search(query: string) {
  controllerRef.current?.abort();
  controllerRef.current = new AbortController();
  
  try {
    const results = await fetch(`/api/search?q=${query}`, {
      signal: controllerRef.current.signal,
    }).then(r => r.json());
    setResults(results);
  } catch (e) {
    if (e.name !== 'AbortError') throw e;
  }
}

// Debounce: fire at most once per 300ms.
// Include search in deps so the debounced fn sees current state/props.
// eslint-disable-next-line react-hooks/exhaustive-deps
const debouncedSearch = useMemo(() => debounce(search, 300), [search]);
```

### Pagination

Use cursor-based pagination. Never fetch all records for display.

```ts
// Bad: offset pagination degrades at scale
GET /api/articles?page=100&limit=20  // DB must scan 2000 rows

// Good: cursor-based
GET /api/articles?after=cursor_xyz&limit=20  // O(1) with indexed cursor column

// Infinite scroll: prefetch next page when 80% through current page
const observer = new IntersectionObserver(([entry]) => {
  if (entry.isIntersecting) fetchNextPage();
}, { threshold: 0.8 });
```

### Timeouts + circuit breakers

Never await external services without a timeout. Surface partial data rather than blocking.

```ts
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 5_000);  // 5s timeout

try {
  const data = await fetch(externalUrl, { signal: controller.signal });
} catch (e) {
  if (e.name === 'AbortError') return fallbackData;
  throw e;
} finally {
  clearTimeout(timeout);
}
```

---

## P0 — Backend / Database

### N+1 queries

An N+1 query fires one query per row instead of one query for all rows.

```ts
// Bad: fires 1 + N queries
const articles = await db.article.findMany();
for (const article of articles) {
  article.author = await db.user.findUnique({ where: { id: article.authorId } });
}

// Good: one query with join
const articles = await db.article.findMany({
  include: { author: true },
});

// For DataLoader pattern (GraphQL or batching)
const authorLoader = new DataLoader(async (ids) => {
  const users = await db.user.findMany({ where: { id: { in: ids } } });
  return ids.map(id => users.find(u => u.id === id));
});
```

### Index audit

Before changing schema, run EXPLAIN ANALYZE on slow queries. Add indexes only where confirmed.

```sql
-- Check slow queries (PostgreSQL)
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Explain a slow query
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM articles WHERE author_id = $1 ORDER BY created_at DESC;
-- If "Seq Scan" on a large table → add index
CREATE INDEX CONCURRENTLY idx_articles_author_created ON articles(author_id, created_at DESC);
```

### Column selection

```ts
// Bad: fetches all columns including large blobs
const articles = await db.article.findMany();

// Good: select only what the view needs
const articles = await db.article.findMany({
  select: { id: true, title: true, authorId: true, createdAt: true },
});
```

---

## P1 — Caching Architecture

Apply in this order: client cache → server Redis → DB. Do not add Redis until client caching
is in place and DB is confirmed to be the bottleneck.

### Client-side caching

```ts
// Define per-resource staleTime
const STALE = {
  static: 10 * 60_000,   // config, enums: 10 min
  feed: 30_000,           // user feed: 30s
  realtime: 0,            // live data: always revalidate
};

useQuery({ queryKey: ['articles'], queryFn: fetch, staleTime: STALE.feed });
```

### Redis cache-aside

```ts
async function getCachedArticle(id: string) {
  const cached = await redis.get(`article:${id}`);
  if (cached) return JSON.parse(cached);

  const article = await db.article.findUnique({ where: { id } });
  await redis.set(`article:${id}`, JSON.stringify(article), 'EX', 300);  // 5 min TTL
  return article;
}

// Invalidation on write
async function updateArticle(id: string, data: Partial<Article>) {
  const updated = await db.article.update({ where: { id }, data });
  await redis.del(`article:${id}`);
  return updated;
}
```

**Key naming:** `resource:id` (e.g. `article:abc123`), `list:resource:filter` (e.g. `list:articles:user:456`)

---

## P1 — AI / Streaming Performance

### Stream first token immediately

```ts
// Bad: wait for complete response
const response = await llm.complete(prompt);
setAnswer(response.text);

// Good: stream incrementally
const stream = await llm.stream(prompt);
let text = '';
for await (const chunk of stream) {
  text += chunk.delta;
  setAnswer(text);  // update UI on each chunk
}
```

### Time-to-first-token budget: < 1s

```ts
const startTime = performance.now();
const stream = await llm.stream(prompt);
let firstTokenLogged = false;

for await (const chunk of stream) {
  if (!firstTokenLogged && chunk.delta) {
    console.debug(`TTFT: ${(performance.now() - startTime).toFixed(0)}ms`);
    firstTokenLogged = true;
  }
  // update UI
}
```

### Cancel stream on navigation or new query

```ts
const abortRef = useRef<AbortController | null>(null);

async function askQuestion(prompt: string) {
  abortRef.current?.abort();
  abortRef.current = new AbortController();

  try {
    const stream = await llm.stream(prompt, { signal: abortRef.current.signal });
    for await (const chunk of stream) {
      // update UI
    }
  } catch (e) {
    if (e.name !== 'AbortError') throw e;
  }
}

// Cancel on component unmount
useEffect(() => () => abortRef.current?.abort(), []);
```

### Streaming error recovery

```ts
async function streamWithRetry(prompt: string, maxRetries = 2) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await llm.stream(prompt);
    } catch (e) {
      if (attempt === maxRetries) throw e;
      await new Promise(r => setTimeout(r, 1000 * 2 ** attempt));  // 1s, 2s backoff
    }
  }
}
```

---

## Measurement rules

1. **Always capture baseline first** — run `/perf-baseline` (plugin) before any change.
2. **Report before/after** — every optimization must include metric delta.
3. **Field data over lab** — CrUX p75 is truth; Lighthouse score is a lab proxy.
4. **Test on low-end mobile** — CPU throttle 4×, Slow 3G network.
5. **Do not claim improvement without numbers.**

---

## Anti-patterns (never do these)

- Add Redis/CDN/load balancing before confirming they solve an observed bottleneck
- Add `memo` / `useMemo` without profiler evidence
- `fetchpriority="high"` on below-fold images (hurts LCP)
- `loading="lazy"` on the first visible image (delays LCP)
- Skeleton screens with different dimensions than real content (causes CLS)
- Optimistic UI on payments, deletes, or permission changes
- Debounce delays longer than 500ms (feels unresponsive)
- Prefetch on mobile without checking `navigator.connection.saveData`
- `SELECT *` in any hot-path query
- Waterfalls disguised as sequential `await` in Server Components
