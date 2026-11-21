# Cost and deployment guardrails

REAL_AWS_DEPLOYMENT = NOT_EXECUTED

Region planned: us-east-1. No real billable resources created. Official pricing pages were consulted (references.md); no unverified static dollar quote is offered. A complete priced AWS calculator estimate with current account discounts/taxes is a prerequisite for apply. Zero tasks does not mean zero cost.

| Model | Resources | Cost drivers |
|---|---|---|
| Local | Existing Windows/Docker, 4 app containers + local data/telemetry | Local CPU, RAM, disk and electricity; no AWS bill |
| AWS sandbox | 4 × 0.25 vCPU/0.5 GiB apps + 1 Collector when started; 1 ALB, 1 single-AZ db.t4g.micro, 20–40 GiB gp3, 1 cache.t4g.micro, 6 interface endpoints × 2 AZ, S3 gateway, SQS/DLQ, 6 ECR repos, Secrets Manager, CMK, CloudWatch | Task seconds, fixed hourly database/cache/ALB/endpoints, ALB LCU, storage/IO, requests, images, logs/traces, secrets/keys, public ALB IPv4 |
| Reference production | At least 2 app replicas across AZ, multi-AZ DB, 2-node cache, more retention, stronger auth/TLS/monitoring | Higher fixed footprint plus real traffic and operational requirements; not claimed production ready |

Use H=730 hours for a planning month, not an SLA billing guarantee. For rate inputs from the official calculator: task/hour = 1.25 × vCPU-hour-rate + 2.5 × GB-hour-rate for the five minimum tasks. Sandbox hourly estimate = task/hour + ALB-hour + expected LCU-hour + RDS-hour + cache-hour + 12 × endpoint-AZ-hour + IPv4-hour + variable usage. Daily approximate = hourly ×24 + daily variable units; monthly = hourly ×730 + storage/requests/ingestion/secrets/KMS. Replace all rate inputs with a dated exported calculator quote. No fake $0/Free Tier promise. Do not label an unevaluated formula as a validated bill estimate.

PrivateLink avoids NAT Gateway and unrestricted Internet egress, but twelve endpoint-AZ allocations can cost more than tiny workloads. NAT is not a free alternative: per-hour and per-GB charges plus egress exposure. ALB, RDS and Redis charge while idle; CloudWatch ingestion/traces scale with instrumentation volume. A short scheduled demonstration window and local-first development control costs more effectively than leaving an idle sandbox up.

Before apply: review all counts/sizes, current hourly/day/month estimate, Free Tier eligibility, storage/retention, log sampling, data transfer and notification destinations; configure AWS Budget thresholds and billing alerts. Budgets alert and are not a guaranteed spending cap. Tag project/environment/managed-by/owner. Do not run terraform apply automatically from PR CI.

Shutdown scales ECS to zero (including Collector and scaling minimum); RDS/cache/ALB/endpoints still bill. Complete cleanup requires approved terraform destroy. Disable RDS/ALB deletion protection explicitly only in a reviewed destroy change; keep final RDS snapshot and decide retention. ECR repositories containing images intentionally do not force-delete. Retained snapshots, ECR images, logs, state bucket and KMS pending-deletion period can continue costing money. Never destroy financial data just to make cleanup easy.

