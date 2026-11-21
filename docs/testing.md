# Testing

Java: mvn -B -ntp verify on JDK21+ (release21). Windows convenience scripts/verify.ps1 uses a pinned Maven/JDK21 container. Money tests reject fractional cents and unsupported/zero amounts. Platform ResilienceTest starts a real local HTTP server, synchronizes with latches and checks the actual configured client deadline; actual Resilience4j production settings prove OPEN/fail-fast/HALF_OPEN/CLOSED using Awaitility.

Distributed: node tests/e2e.mjs on a running Compose stack. It uses actual HTTP, PostgreSQL roles/transactions, Redis and LocalStack SQS. No mock proves financial invariants. Contract assertions validate 202/idempotency409, status transitions, BRL decimal responses, 401/403 role separation, stored event schema and actual projection consumption. The explicit OpenAPI contract is docs/api/openapi.yml. Contracts are verified by consumers against running providers instead of adding a separate Pact broker or Spring Cloud dependency.

B5 uses a PostgreSQL row-lock barrier and pg_stat_activity observation of two blocked sessions. B3 sends 12 simultaneous HTTP duplicates and checks the resulting journal id. Failure injection uses only task-owned docker compose stop/start/restart and SQL fixtures. No Thread.sleep or unbounded random fault behavior. Node polling sleeps are deadline-bounded observations, not concurrency synchronization. Retry jitter is production backoff, not a random fault hook.

Tests are isolated by random fixture UUIDs and operate safely on this portfolio's local databases. They intentionally alter test-derived data, stop services and create/drop only a uniquely named temporary restore database. Never point them at a real banking environment. The top-level finally restores services if an assertion fails. Artifacts contain results, trace JSON and load summary; credentials are never uploaded.

CI runs Java21, Compose distributed proofs/load, Terraform fmt/init(validate-only)/validate, Checkov, Gitleaks history and dependency review. No AWS credentials, apply or real AWS calls are required. SQS emulator tests are not a claim of AWS deployment equivalence. The local installed JDK25 compilation is additional validation; Docker and CI target Java21. Exact CI run IDs and results are recorded in evidence/report after execution.

