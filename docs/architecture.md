# Architecture

Four independently packaged Spring Boot applications form a monorepo. A shared technical platform contains HTTP security, problem responses, bounded clients, correlation and tracing only. No domain entities or cross-service database adapters are shared.

| Service | Owns | Does not own |
|---|---|---|
| Account | Opaque owner reference, lifecycle, metadata | Money or authoritative balances |
| Ledger | Accounts used for accounting, enabled gates, journals, postings, authoritative balance accumulator, outbox | Transfer orchestration or retail identity |
| Transfer | Idempotency keys, durable transfer state, retry schedule | Money writes or Ledger tables |
| Projection | Inbox, additive derived balances, reconciliation audit | Spending authorization |

## System context
~~~mermaid
flowchart LR
 Operator --> BankCore[BankCore operator backend]
 BankCore --> Accounting[Auditable balanced monetary records]
 BankCore --> AWS[AWS target, not deployed]
~~~

## Local architecture
~~~mermaid
flowchart TB
 Edge[Nginx localhost:28180] --> A[Account]
 Edge --> T[Transfer]
 Edge --> L[Ledger]
 Edge --> P[Projection]
 T --> A
 T --> L
 A --> L
 A --> R[(Redis metadata cache)]
 A --> AD[(Account DB)]
 T --> TD[(Transfer DB)]
 L --> LD[(Ledger DB + outbox)]
 LD --> Pub[Outbox publisher]
 Pub --> Q[LocalStack SQS]
 Q --> DLQ[DLQ]
 Q --> P
 P --> PD[(Projection DB + inbox)]
 P --> L
 A & T & L & P --> O[OpenTelemetry collector]
 O --> Tempo
 Prometheus --> A & T & L & P
 Grafana --> Prometheus & Tempo
~~~

Local PostgreSQL hosts four databases, with separate runtime and migration logins. Roles have no cross-database CONNECT. Migrations belong to the owning service. PostgreSQL 18 is local; RDS target uses managed PostgreSQL 17, a deliberate conservative cloud major. SQL uses features available in both. Cross-major AWS execution remains unvalidated until an authorized deployment.

## Transfer sequence
~~~mermaid
sequenceDiagram
 participant C as Operator/edge
 participant T as Transfer API/worker
 participant A as Account
 participant L as Ledger
 participant D as Ledger PostgreSQL
 participant S as SQS
 participant P as Projection
 C->>T: POST with Idempotency-Key
 T->>T: Commit unique key + canonical request + trace
 T-->>C: 202 REQUESTED (not completion)
 T->>L: GET journal by transfer id
 alt journal exists
  L-->>T: Committed result
 else no journal
  T->>A: Authoritative metadata lookup (no Redis)
  T->>L: POST journal, stable transfer id
  L->>D: Advisory id lock; ordered account locks
  L->>D: Journal + debit + credit + balance deltas + outbox
  D->>D: Deferred balanced-journal constraint at commit
  D-->>L: Commit
 end
 T->>T: Commit COMPLETED
 L->>S: Publish pending outbox with trace context
 S->>P: Delivery, possibly duplicated
 P->>P: Atomic inbox + additive projection
 P->>S: Ack only after commit
~~~

Consistency is strongly transactional within each database, with eventual orchestration and projections across services. There is no 2PC, distributed exactly-once claim or shared balance authority. See consistency.md and ledger.md for uncertain outcomes and account-gating races. Page size is at most 100; background batches are bounded at 5 transfers, 10 outbox events, 5 messages. Offset pagination is adequate for this demonstration; keyset pagination is a future scaling improvement.

