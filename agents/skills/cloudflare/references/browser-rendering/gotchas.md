# Browser Rendering Gotchas

## Tier Limits

| Limit | Free | Paid |
|-------|------|------|
| Daily browser time | 10 min | Metered, no fixed hour cap |
| Concurrent sessions | 3 | 200 |
| Quick Actions requests | 1 every 10 seconds | 30 per second |
| Session keep-alive | 10 min max | 10 min max |

Account defaults and usage charges: [current limits](https://developers.cloudflare.com/browser-run/limits/) and [pricing](https://developers.cloudflare.com/browser-run/pricing/).

**Check quota:**
```typescript
const limits = await puppeteer.limits(env.MYBROWSER);
// Acquisition/concurrency state, not a remaining-browser-milliseconds balance.
```

## Release the Browser Resources You Own

```typescript
const browser = await puppeteer.launch(env.MYBROWSER);
try {
  const page = await browser.newPage();
  await page.goto("https://example.com");
  return new Response(await page.content());
} finally {
  await browser.close(); // ALWAYS in finally
}
```

Close one-shot browsers in `finally`, including error paths. When borrowing an owned reusable session, close the per-task context and disconnect the client instead; the session owner closes the browser when retiring it. See [session reuse](patterns.md#session-reuse). REST requests manage their own browser lifecycle.

## Optimize Concurrency

```typescript
// ❌ 3 sessions (hits free tier limit)
const browser1 = await puppeteer.launch(env.MYBROWSER);
const browser2 = await puppeteer.launch(env.MYBROWSER);

// ✅ 1 session, multiple pages
const browser = await puppeteer.launch(env.MYBROWSER);
const page1 = await browser.newPage();
const page2 = await browser.newPage();
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Session limit exceeded | Too many concurrent | Close unused browsers, use pages not browsers |
| Page navigation timeout | Slow page or `networkidle` on busy page | Increase timeout, use `waitUntil: "load"` |
| Session not found | Expired session | Catch error, launch new session |
| Evaluation failed | DOM element missing | Use `?.` optional chaining |
| Protocol error: Target closed | Page closed during operation | Await all ops before closing |

## page.evaluate() Gotchas

```typescript
// ❌ Outer scope not available
const selector = "h1";
await page.evaluate(() => document.querySelector(selector));

// ✅ Pass as argument
await page.evaluate((sel) => document.querySelector(sel)?.textContent, selector);
```

## Performance

**waitUntil options (fastest to slowest):**
1. `domcontentloaded` - DOM ready
2. `load` - load event (default)
3. `networkidle0` - no network for 500ms

**Block unnecessary resources:**
```typescript
await page.setRequestInterception(true);
page.on("request", (req) => {
  if (["image", "stylesheet", "font"].includes(req.resourceType())) {
    req.abort();
  } else {
    req.continue();
  }
});
```

**Session reuse:** Measure startup and reconnect latency for your workload. Use a Durable Object to coordinate exclusive session ownership; KV does not provide a lock.

Current product name: **Browser Run**. The REST path remains `/browser-rendering`. [Official documentation](https://developers.cloudflare.com/browser-run/).
