# Demonstration SLIs and SLOs

These are proposed learning targets, not objectives derived from production measurements. Rolling window: 30 days (43,200 minutes). Exclude malformed/unauthorized requests from availability; do not exclude dependency failures. Business insufficient-funds rejections are valid outcomes, not platform failures.

| SLI | Demo SLO | Budget in 30 days |
|---|---|---|
| Durable API availability (non-5xx / eligible requests) | 99.9% | 0.1% requests; time analogue 43.2 minutes |
| Valid accepted transfers reach correct terminal outcome within 60 s | 99.5% | 0.5% accepted valid transfers, 500 per 100,000 |
| Transfer creation API latency <1 s | 99% | 1% eligible requests, 1,000 per 100,000 |
| Ledger events projected within 30 s | 99% | 1% committed events, 1,000 per 100,000 |

Error budget = eligible events × (1 − objective). Time conversion is only an availability analogue, not a substitute for a request-based denominator. Never treat wrong financial effects as an acceptable budget: money conservation, no overspend and unique journal effects are hard invariants requiring incident response on any violation.

Use HTTP histograms for API latency/availability, created_at/completed_at SQL cohorts for processing deadlines, and outbox/inbox timestamps for event lag. Proposed cohort SQL must account for missing terminal events (count as violations after their deadline), not only completed samples. Current dashboards provide raw counters/latency; full 30-day recording rules and burn-rate paging have not been production validated.

Page in a real on-call environment for any invariant violation, sustained API availability loss or DLQ involving unresolved committed money projections. Ticket for short-lived cache outages, low-rate poison schema fixtures and moderate backlog with intact durable data. Escalate aged pending transfers rather than assuming financial rejection.

