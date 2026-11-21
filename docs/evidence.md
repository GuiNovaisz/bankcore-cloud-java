# Evidence ledger

Recorded 2026-11-21. Actual executed observations only. REAL_AWS_DEPLOYMENT = NOT_EXECUTED. Raw safe machine-readable records are in [evidence/](evidence/proofs.json); full operational artifacts and trace JSON are generated under ignored artifacts/ and uploaded by CI. [PR checks](https://github.com/GuiNovaisz/bankcore-cloud-java/pull/1/checks) identify exact code revisions and final run results. B18 local readiness is complemented by the CI's new Compose volume; do not equate this to live AWS deployment.

| Proof | Environment | Command/test | Expected | Actual | Status |
|---|---|---|---|---|---|
| B1 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | All journals have equal debits and credits | SQL audit: zero unbalanced or partial journals | PASS |
| B2 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | All movements conserve total money including explicit treasury funding | Sum balances including treasury = 0.00; balances match postings | PASS |
| B3 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Concurrent duplicate requests produce one transfer and one journal | 12 simultaneous HTTP requests; 1 transfer; 1 journal; payload conflict 409 | PASS |
| B4 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Same key with a changed request returns 409 | 409 IDEMPOTENCY_CONFLICT | PASS |
| B5 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | 100 BRL minus two concurrent 80 BRL requests accepts exactly one | Both DB sessions observed waiting on locks; statuses 200/422; source balance 20.00 | PASS |
| B6 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Runtime credentials cannot edit/delete journal or posting or directly change balance | UPDATE/DELETE/TRUNCATE/DDL denied to runtime; owner edits blocked; unbalanced journal commit rejected | PASS |
| B7 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Outbox survives SQS failure after financial commit and publishes on recovery | Committed journal + pending outbox retained; eventual inbox count 1 | PASS |
| B8 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Duplicate SQS deliveries have one projection effect | Two additional receives/acks; isolated projection unchanged at 7.00; inbox count 1 | PASS |
| B9 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Poison event is redriven to DLQ after maxReceiveCount=3 | Unparseable payload reached actual LocalStack DLQ with queue redrive policy 3 | PASS |
| B10 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Redis outage falls back to DB without changing financial correctness | Account read 200 with Redis down; transfer completed; SQL invariants unchanged | PASS |
| B11 | Java21 container + controlled real local HTTP server/latches | mvn verify: Platform ResilienceTest | Bounded real RestClient timeout | {"name":"actualRemoteClientHasBoundedTimeout","className":"io.bankcore.platform.ResilienceTest","seconds":3.12,"status":"PASS"} | PASS |
| B12 | Actual production Resilience4j configuration, Awaitility clock wait | mvn verify: Platform ResilienceTest | CLOSED → OPEN → HALF_OPEN → CLOSED | {"name":"productionBreakerOpensFailsFastAndRecovers","className":"io.bankcore.platform.ResilienceTest","seconds":5.403,"status":"PASS"} | PASS |
| B13 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Transfer state survives process restart | Same transfer id across restart; one journal after recovery | PASS |
| B14 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Injected projection divergence is detected and audited | RECONCILIATION_PROOF mismatchDetected=true; audit row retained | PASS |
| B15 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Cross-service trace contains transfer, account and ledger spans | {"traceId":"7bc7d914638779f561a0345f952d176e","services":["transfer-service","account-service","ledger-service"]} | PASS |
| B16 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Durable async context correlates projection processing to originating trace | {"traceId":"7bc7d914638779f561a0345f952d176e","asyncSpan":"projection.process"} | PASS |
| B17 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | SIGTERM drains services without incomplete financial journals | Graceful stop/start; five durable requests eventually completed; no partial journals | PASS |
| B18 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Full isolated local stack healthy | Four readiness endpoints 200; Docker healthchecks green | PASS |
| B19 | Local Terraform1.17.2, signed pinned providers; no credentials/apply | terraform fmt -check -recursive; init -backend=false; validate; Checkov3.4.6 | Terraform fmt/validate and IaC policy gate pass | {"passed":304,"failed":0,"skipped":34,"parsing_errors":0,"resource_count":136,"checkov_version":"3.4.6"} | PASS |
| B20 | Static source audit; complementary to Checkov and human IAM matrix; no live AWS permission simulation | node scripts/audit.mjs | Least privilege static review | Per-workload roles; main-queue-only producer/consumer; no public DB or task IPs; resource wildcards limited to API-required ECR authorization and X-Ray writes in identity policies | PASS |
| B21 | Git history, including all feature commits | gitleaks git --redact; Git history secret scan CI job | No secrets in Git history | Gitleaks local history scan and GitHub job; see linked CI run | PASS |
| B22 | Local Windows Docker, capped 4 peak active VUs, explicit fixtures | node scripts/load.mjs | Reproducible moderate baseline with p50/p95/p99, throughput and errors | {"httpRequests":{"rate":9.75137116941538,"count":474},"httpLatencyMs":{"p(99)":245.39158342999983,"max":292.703231,"avg":89.75886281434597,"min":54.185569,"med":65.74064,"p(50)":65.74064,"p(95)":196.20730989999998},"processingMs":{"max":2718,"avg":842.0181818181818,"min":111,"med":467,"p(50)":467,"p(95)":2547.2999999999997,"p(99)":2696.2599999999998},"httpErrorRate":0,"logicalErrorRate":0,"iterations":{"count":110,"rate":2.262976431720869}} | PASS |
| B23 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Controlled ledger outage under moderate concurrent traffic preserves invariants | 12 concurrent accepted requests during outage; eventual completion; zero partial/unbalanced journals | PASS |
| B24 | Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI | node tests/e2e.mjs | Logical backup restores ledger and invariants to a separate database | pg_dump restored into isolated DB; journal count and all financial invariants verified; real AWS PITR unexecuted | PASS |

## Additional executed checks

- API-CONTRACT: PASS; Provider JSON consumed by worker; decimal strings, page bounds, invalid inputs and missing idempotency header checked
- API-AUTH: PASS; 401 unauthenticated; 403 operator to internal API
- F1: PASS; Durable PROCESSING during outage; COMPLETED only after ledger recovery
- Observability: 4 Prometheus targets up; 14 Grafana panels; DLQ alert loaded; queue/DLQ/consumer latency metrics; correlated JSON async log; actual DB-work/outbox trace spans.
- Java tests: 3 passing tests; results identify real timeout and breaker integration cases.
- Checkov: 304 passed, 0 failed, 34 reviewed/skipped, no parsing errors. A passing gate with explicit exceptions is not a claim of universal policy compliance.

## Local baseline

474 HTTP requests at 9.751 req/s; 110 logical request/terminal-poll iterations (including duplicate-key replays). HTTP p50 65.741 ms, p95 196.207 ms, p99 245.392 ms. Logical observed processing p50 467.000 ms, p95 2547.300 ms, p99 2696.260 ms. HTTP errors 0; logical errors 0. No production TPS claim.

## Limits

B11/B12 prove real configured client/library behavior, not a live AWS failure. B20 is static review, not AWS IAM simulation. B24 validates local logical backup/restore, not AWS PITR or measured RTO/RPO. RDS/ElastiCache/ECS/S3 backend, cost charges, notification delivery and real cloud recovery remain unexecuted. Sandbox security exceptions and trusted-operator scope are explicit in security.md.
