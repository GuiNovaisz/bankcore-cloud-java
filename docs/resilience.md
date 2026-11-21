# Resilience

All remote clients have explicit limits. Service HTTP: 400 ms connection and 900 ms read deadline. AWS SDK: 400 ms connect, 3 s socket/attempt, 4 s total API budget, zero SDK retries. PostgreSQL: 3 s connect, 10 s socket and 2 s pool acquisition. Redis: 200 ms connect/operation. Edge: 1 s connect and 5 s read/write. SQS long poll is one second, inside the API budget; message visibility is 10 s locally and 30 s in AWS.

Account dependency circuit breaker: count window four, minimum four, failure threshold 50%, open wait five seconds, two half-open permits. Expected 4xx business rejections do not trip it. Unit proof exercises the actual production configuration, waits for the open deadline with Awaitility, observes HALF_OPEN and closes after two successful probes. A controlled local HTTP server and latch prove the actual configured RestClient times out rather than hanging. These are library/client integration proofs; not a simulated AWS fault-injection experiment.

| Operation | Retry owner | Policy |
|---|---|---|
| Transfer acceptance | Client | Only with same idempotency key and payload |
| Transfer worker HTTP lookup/post | Durable worker | Retry transport/5xx/circuit-open with same journal id; first reconcile GET |
| Business 404/409/422 during orchestration | Worker | Terminal rejection after missing-journal confirmation |
| Outbox publish | Outbox | Persisted exponential 1–60 s + up to 500 ms jitter |
| Message processing | SQS redrive | No nested immediate retry; visibility then max receives 3 → DLQ |
| Cache access | Account | No retry; degrade to metadata DB |
| Administrative account command | Operator | Reissue same desired state after reconciliation |

Only one layer owns each retry. No request-layer retry × SDK retry × consumer retry multiplication. Scheduled batch sizes, per-service pools (six connections), ECS scaling max two and container resource limits bound concurrency. A separate bulkhead library adds no justified isolation at this scale. HTTP transport is bounded but requests waiting for PostgreSQL row locks are bounded by the ten-second JDBC socket timeout; high contention becomes a retryable dependency outcome.

Redis failure does not block financial authorization because Transfer uses the uncached internal account lookup and Ledger gates. Ledger failure keeps transfers pending. PostgreSQL failure prevents successful durable acceptance/commit and affects readiness, not liveness. SQS failure grows outbox and does not roll back already committed money.

