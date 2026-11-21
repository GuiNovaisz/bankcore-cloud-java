# Failure matrix

| Dependency | Failure | Impact | Detection | Response | Retry? | Recovery | Evidence |
|---|---|---|---|---|---|---|---|
| PostgreSQL | Disconnect/lock timeout | Owner cannot commit; DB readiness down | Hikari/health; API 503 | Roll back local transaction; never acknowledge uncertain work | Durable workers retry | Restore connection; journal lookup | B1/B5/B6/B13/B24; DB outage not separately benchmarked |
| Redis | Unavailable/timeout | Metadata read cost increases | cache failure counters | Bypass cache to metadata DB | No | Automatic TTL refill | B10 |
| SQS | Unavailable after commit | Async lag/outbox backlog | publish failures and pending gauge | Retain outbox, backoff | Outbox only | Send with same event id | B7 |
| SQS | Duplicate delivery | No additional read-model effect | Inbox id, processing counter | Commit deduplication before ack | Safe | Re-ack | B8 |
| SQS | Poison message | One payload repeatedly fails | consumer failures; DLQ alarm | Leave unacked, three receives | Bounded redrive | Inspect, fix schema/consumer, explicitly redrive | B9 |
| Account | Timeout/5xx | New transfers cannot authorize metadata | client latency/circuit state | Leave pending; fail fast when circuit open | Durable worker | Half-open probes | B11/B12 client/library integration |
| Ledger | Unavailable/lost response | Outcome may be unknown | pending transfer, client error | Never claim completion; lookup same journal id | Idempotent worker | Reconcile, then post if missing | F1/B13/B23 |
| Transfer | Restart during orchestration | Acceptance/worker paused | readiness + logs | State remains durable | On restart | Claim pending rows; journal-first lookup | B13/B17 |
| Projection | Restart after commit before ack | Redelivery | inbox/event id | Duplicate no-op | SQS | Restart and ack | B8/B17 |

Failure hooks are external Compose operations and SQL test fixtures only. There are no production failure-toggle endpoints. See tests/e2e.mjs for exact commands and synchronization.

