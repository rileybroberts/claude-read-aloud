Here's a third fixture, exercising the structures the first two skipped: blockquote, nested lists, an ASCII diagram, and math-ish notation.

---

Short answer: no, you can't safely share one connection pool across forked workers. Here's why that bites.

> A pool is a set of live TCP sockets. `fork()` duplicates the file descriptors, not the protocol state — so two workers end up interleaving bytes on the same wire.

What actually goes wrong, in order of how often I've seen it:

- **Interleaved protocol frames.** Worker A sends a query, worker B sends another, and both read whichever response arrives first. You get worker A's rows returned to worker B.
  - Symptom: "column does not exist" on a query that definitely has that column.
  - Symptom: occasional `unexpected message type 0x44` from the driver.
- **Double-close.** Whichever worker exits first tears down the socket; the others see `ECONNRESET`.
- **Silent pool starvation.** The parent thinks it holds *n* connections. In reality the OS sees *n × workers* descriptors pointing at *n* sockets, and the server's `max_connections` accounting disagrees with everyone.

The fix is to create the pool *after* the fork, sized so the total stays under budget:

```
                  ┌──────────────┐
                  │    parent    │   pool: none
                  └──────┬───────┘
             ┌───────────┼───────────┐
             ▼           ▼           ▼
        ┌────────┐  ┌────────┐  ┌────────┐
        │worker 1│  │worker 2│  │worker 3│
        │ pool:5 │  │ pool:5 │  │ pool:5 │
        └────────┘  └────────┘  └────────┘
                          │
                          ▼
                  max_connections ≥ 15 + overhead
```

Sizing rule of thumb: `per_worker_pool = floor((max_connections × 0.8) / worker_count)`, then leave ≥ 5 connections free for superuser access and migrations. With `max_connections = 100` and 4 workers, that's 20 each — round down to 18 so you have headroom when a worker is mid-restart and its old sockets haven't timed out yet.

One caveat: if you're behind PgBouncer in transaction mode, none of the above applies the same way — the bouncer owns the real connections and your "pool" is just a set of cheap client-side handles. In that setup, oversizing the app pool is nearly free, and `max_connections` on Postgres itself can stay small (~20–30).
