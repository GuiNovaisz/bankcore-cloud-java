# Well-Architected review

An internal learning review against AWS's six pillars and Financial Services Industry Lens, not certification or banking compliance.

| Pillar | Foundation decision/evidence | Remaining production work |
|---|---|---|
| Operational Excellence | IaC, CI, immutable images, runbooks, trace/evidence, replay audit | Real on-call, deployment/PITR game day and alarm notifications |
| Security | Operator/service roles, private DB/cache, per-workload IAM/SG, secret injection, KMS, history scan | Retail auth/ownership, end-to-end service TLS, coordinated rotation, separate migration workload |
| Reliability | Double-entry constraints, locks, idempotency, outbox/inbox, DLQ, restart/restore proofs | Real AWS failure domain tests, approved Multi-AZ, production recovery measurements |
| Performance Efficiency | Bounded queries/pools/batches, metadata cache, measured moderate load | Capacity model using realistic workload; keyset pagination as scale requires |
| Cost Optimization | Local-first, no apply, desired_count=0, tagged resources, bounded logs | Approved current calculator export, Budget, actual utilization data |
| Sustainability | Small independent tasks, no idle cloud resources deployed, bounded retention | Measured utilization, region/workload choices under real demand |

Financial Services Lens themes: integrity and traceability of money, segregation of duties/ownership, evidence, recoverability, security and operational risk. Ledger postings are the immutable financial audit; logs are supporting diagnostics. This does not implement KYC/AML/PCI/LGPD governance, regulatory reporting, real settlement or production controls. Treat service/region outages, privileged database compromise, partial restores and credential rotation as explicit risks.

