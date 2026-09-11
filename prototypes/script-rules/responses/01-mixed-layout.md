Here's a sample response you can point the plugin at — it packs prose, a fenced code block, a table, and both list flavors into one message.

---

## Adding retry with exponential backoff

The core idea is simple: when a request fails with a transient error, wait a bit and try again — doubling the wait each time so you stop hammering a struggling server. Add a little random jitter so a thundering herd of clients doesn't retry in lockstep.

Here's a compact implementation in `src/lib/retry.ts`:

```typescript
type RetryOptions = {
  maxAttempts?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
};

export async function withRetry<T>(
  fn: () => Promise<T>,
  { maxAttempts = 5, baseDelayMs = 250, maxDelayMs = 30_000 }: RetryOptions = {},
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (!isRetryable(error) || attempt === maxAttempts - 1) throw error;

      const backoff = Math.min(baseDelayMs * 2 ** attempt, maxDelayMs);
      const jitter = Math.random() * backoff * 0.3;
      await new Promise((resolve) => setTimeout(resolve, backoff + jitter));
    }
  }

  throw lastError;
}

const isRetryable = (error: unknown): boolean =>
  error instanceof Response
    ? error.status === 429 || error.status >= 500
    : true;
```

With the defaults above, the delay schedule works out to:

| Attempt | Base delay | With jitter (max) | Cumulative wait |
|--------:|-----------:|------------------:|----------------:|
| 1       | 250 ms     | 325 ms            | 0 ms            |
| 2       | 500 ms     | 650 ms            | 325 ms          |
| 3       | 1,000 ms   | 1,300 ms          | 975 ms          |
| 4       | 2,000 ms   | 2,600 ms          | 2,275 ms        |
| 5       | 4,000 ms   | 5,200 ms          | 4,875 ms        |

A few things worth calling out before you ship this:

- **Don't retry non-idempotent writes** unless the endpoint supports an idempotency key. A retried `POST /charges` can double-bill someone.
- **Respect `Retry-After`.** If the server tells you how long to wait, that header beats your computed backoff every time.
- **Cap total elapsed time, not just attempt count.** Five attempts with a 30-second ceiling can block a request for over a minute.
- **Log the attempt number** so retry storms are visible in your traces rather than hidden inside a single span.

To wire it up, do these in order:

1. Install the helper and export it from your HTTP client module.
2. Wrap only the read paths first — `GET` and `HEAD` — and deploy.
3. Watch your p99 latency and error-rate dashboards for a day.
4. Then extend it to idempotent writes, one endpoint at a time.

If retries still aren't enough, the next step up is a circuit breaker: after a threshold of consecutive failures, stop calling the dependency entirely for a cooldown window and fail fast instead.

---

That fixture should exercise most of the paths your plugin needs to handle: headings, bold, inline code, a file path, a long code block, a right-aligned numeric table, an unordered list, and an ordered list. If you want a harder test, say the word and I'll add nested lists, blockquotes, LaTeX, and an ASCII diagram.
