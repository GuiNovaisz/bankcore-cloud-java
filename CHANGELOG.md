# Changelog

## v0.1.0 — Cloud-Native Banking Backend Foundation

Initial stable portfolio release. Four independently deployable Java 21 / Spring Boot services demonstrate financial correctness, durable distributed workflows and an AWS target represented as validated Terraform. No frontend or real-money integration is included.

### Architecture

- **Account Service:** account metadata, ownership references and lifecycle; no duplicate balance authority.
- **Ledger Service:** authoritative double-entry journals, immutable postings, transactional balance accumulation and outbox.
- **Transfer Service:** durable orchestration, idempotency keys, explicit terminal states and journal-first recovery after uncertain outcomes.
- **Projection Worker:** SQS consumption, inbox deduplication, derived read model and auditable reconciliation.

### Financial Correctness

BRL amounts use exact decimal arithmetic with scale two and no silent fractional-cent rounding. A local PostgreSQL transaction commits both sides of a movement; constraints, unique keys and ordered locking protect balanced journals, conserved money and nonnegative customer balances. Concurrent overspend is checked with an observed database lock barrier. Repeated requests have one logical transfer/journal; conflicting payloads return 409. Corrections require new compensating entries, preserving financial history.

### Distributed Systems

Transactional outbox publication and SQS delivery are at least once. Inbox uniqueness prevents repeated projection effects. Stable journal identifiers reconcile lost acknowledgements and service restarts. Projection divergence is detected and audited without silent repair. No distributed exactly-once or cross-service 2PC claim.

### Resilience

Explicit HTTP/SDK/database/cache deadlines, retries with one owner, durable exponential backoff, a real Account dependency circuit breaker, Redis metadata fallback and graceful shutdown. Controlled failure scenarios verify recovery without falsely completing financial work. Redis never authorizes spending.

### Observability

Prometheus metrics, provisioned Grafana dashboards/alerts, structured JSON logs and OpenTelemetry→Collector→Tempo traces. HTTP and durable Transfer/outbox/SQS contexts connect synchronous and asynchronous processing. Custom metric labels exclude account/customer/transfer/idempotency/trace identifiers.

### Cloud Architecture

Validated Terraform describes an ECS Fargate target with private RDS PostgreSQL and ElastiCache, ECR repositories, SQS/DLQ, Secrets Manager, VPC endpoints, scoped workload IAM and CloudWatch/X-Ray targets. Local development uses Docker Compose and LocalStack SQS. Terraform was formatted, initialized with backend disabled, validated and scanned; it was not applied.

### Security

Immutable financial history, separate runtime database privileges, operator/service API roles, secret scanning, dependency review, IaC security and explicit private-workload trust boundaries. Documented sandbox exceptions and production hardening limits remain visible. This is not a production banking compliance or certification claim.

### Verification

B1–B24 cover double-entry/conservation, concurrent request idempotency and overspend, immutable history, outbox recovery, duplicate delivery, poison-message DLQ, cache outage, actual client timeout and circuit-breaker lifecycle, restart recovery, reconciliation, HTTP/async traces, shutdown, clean local startup, Terraform/security, static least privilege, secret scanning, bounded load, failure under traffic and isolated logical PostgreSQL backup/restore. Java tests and distributed proofs run in the official CI; see [evidence](docs/evidence.md), [testing](docs/testing.md) and [security scope](docs/security.md).

### Validation Boundaries

- B20 is a **static IAM review**, not Access Analyzer, IAM simulation or AWS runtime authorization validation.
- B24 is a **local logical PostgreSQL restore**, not RDS PITR or a measured cloud recovery objective.
- Load results are a bounded local/CI baseline, **not production capacity or a financial TPS benchmark**.
- LocalStack is a local emulator, not evidence of real SQS or any AWS deployment.
- No real money, banking certification, production compliance, validated Multi-AZ failover or real ECS/RDS/ElastiCache/Secrets Manager/CloudWatch/X-Ray deployment is claimed.

REAL_AWS_DEPLOYMENT = NOT_EXECUTED

No AWS resources were created. Frontend and v0.2.0 are outside this release.
