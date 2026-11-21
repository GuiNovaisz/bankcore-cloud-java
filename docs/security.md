# Security model and reviewed limits

This foundation has a **trusted operator API**, not retail customer authentication. Random operator/service passwords are separate, at least 24 characters, BCrypt hashed for HTTP verification and generated outside Git. Operator cannot call /internal; service cannot call public/operator APIs. No arbitrary client ownership header is trusted. Basic authentication is over localhost HTTP only in development, with HTTPS at the AWS ALB. Production customer access needs an external identity provider (for example Cognito/JWT), tenant ownership authorization, credentials rotation and a dedicated review. No home-built authorization server.

Cloud trust boundary: CIDR-restricted TLS1.2+/TLS1.3 ALB, no HTTP listener, private task ENIs, no public RDS/Redis, SG-to-SG internal allowlists. Internal service HTTP trusts this VPC boundary plus service credentials. It is **not end-to-end TLS or zero-trust service identity**. Before handling real customer/financial data, add private TLS/mTLS and credential/key rotation, remove shared service credential scope, and implement customer authorization. ElastiCache uses TLS in AWS; the cache is disposable metadata only.

Runtime DB connections have separate per-service logins and no DDL ownership. Ledger runtime cannot update/delete journals/postings, alter tables or directly write balances. Migration logins own schema and Flyway runs at startup with separate secrets. Application task definitions still receive migration credentials for startup; a production migration pipeline should use one-off migration tasks and remove owner secrets from application task execution roles. This prototype does not pretend that a compromised process with startup migration secrets is contained as tightly as its ordinary JDBC role.

## IAM matrix
| Workload role | Allowed resource/action | Implicitly denied examples |
|---|---|---|
| Account task | No AWS API grant | SQS publish/receive/delete; DB master secrets |
| Transfer task | No AWS API grant | SQS receive; ECR write; IAM |
| Ledger task | Main queue sqs:SendMessage | Queue purge/delete, DLQ consume, IAM |
| Projection task | Main queue receive/delete/change visibility; main/DLQ read-only attributes | Publish, purge/delete, DLQ receive/delete/redrive |
| Collector task | xray:PutTraceSegments, PutTelemetryRecords | IAM, SQS, secrets |
| Each execution role | Its ECR repository read; its log stream write; only its required startup secrets | Other repositories/secrets, ECR write, cloud mutation |
| Bootstrap execution | DB master secret plus app/migrator password secrets | General account administration |

Identity-policy Resource=* exists only for ECR GetAuthorizationToken and X-Ray write APIs which do not support a resource ARN. Log/ECR object suffix wildcards restrict an owned group/repository. SQS TLS Deny uses wildcard Principal/Action to deny all insecure queue operations, not grant broad identity permissions. Endpoint policy is an account boundary layered with these workload policies; it does not replace IAM. KMS key-policy root kms:* / Resource=* delegates management of that specific key to its owning account; application task roles do not get KMS administration. Flow-log role can write only its own log group.

## IaC scanner exceptions
Checkov configuration and inline skips are reviewed sandbox choices, not evidence that every security control is implemented. Global exceptions: CKV_AWS_332 (fixed Fargate 1.4.0 versus mutable platform LATEST); CKV_AWS_378 (private HTTP targets after TLS termination); CKV2_AWS_50 (single-AZ disposable cache); CKV2_AWS_30 (avoid SQL parameter logging of financial data); CKV2_AWS_5 (cross-module attachment graph false positives; every referenced SG is attached to ALB, ECS, RDS, cache or endpoints). Inline exceptions cover service-managed Secrets Manager/ECR/CloudWatch encryption, bounded 30-day retention, explicit single-AZ DB, omitted enhanced-monitoring agent, disposable cache snapshots, no sandbox WAF/ALB S3 access logs, and coordinated rotation deferred to deployment. RDS storage/Performance Insights and Redis use a rotating CMK.

No real PII fixtures or CPF. .env, state, plans, generated credentials and operational artifacts are ignored. Terraform random_password values live in state; use encrypted access-controlled remote S3 state with locking before real deployment. Never publish state or plans as general CI artifacts. Gitleaks scans Git history. Dependency review checks PR changes for high/critical vulnerable dependencies. These do not prove absence of unknown vulnerabilities or production compliance.


Secret-scan false-positive review: one historical synthetic k6 duplicateKey UUID was flagged by generic-api-key. Its exact commit/path/rule/line fingerprint is recorded in .gitleaksignore; no rule or directory is broadly exempted. Current published load summaries remove setup fixture identifiers while preserving every metric. This is not a credential exception.
