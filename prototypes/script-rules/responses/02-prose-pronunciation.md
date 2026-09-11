Here's a prose-only fixture, tuned to stress pronunciation rather than layout.

---

The migration landed at 3:47 a.m. UTC on 2026-04-09, roughly 18 months after the original RFC, and it touched about 1,240 files across 7 packages. Throughput went from ~450 req/s to 2.1k req/s, p99 latency dropped 62% (from 890 ms to 338 ms), and our AWS bill fell by $14,500/month — which, honestly, nobody expected. The tricky part wasn't the SQL; it was that PostgreSQL 16.2 changed how `NULLS DISTINCT` behaves in unique indexes, so ~0.3% of rows that had quietly coexisted for years suddenly collided. We caught it in staging (thankfully), rolled back within 11 minutes, added a dedupe pass, and re-ran. If you're doing something similar: read the release notes twice, keep the old read-replica warm for at least 48 hours, and don't schedule a cutover on a Friday. E.g. ours ran Thursday, i.e. we still had a full workday to fix things — vs. the alternative, which is debugging a 500-error storm at 2 a.m. on a Saturday while your on-call engineer's phone is on Do Not Disturb.

---

That one packs in times, dates, a version number, an ISO date, percentages, currency, units, rates (`req/s`), tilde approximations, acronyms (UTC, RFC, AWS, SQL), Latin abbreviations (e.g., i.e., vs.), parentheticals, and an em-dash aside.
