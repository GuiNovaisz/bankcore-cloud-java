# AWS target (not deployed)

~~~mermaid
flowchart TB
 Internet[Approved operator CIDRs] --> TLS[HTTPS ALB / ACM]
 subgraph VPC
  subgraph Public[Two public subnets]
   TLS
  end
  subgraph Private[Two private subnets, no NAT]
   TLS --> A[ECS Fargate Account]
   TLS --> T[ECS Fargate Transfer]
   TLS --> L[ECS Fargate Ledger]
   TLS --> P[ECS Fargate Projection]
   T --> A & L
   A --> L
   A & T & L & P --> DB[(RDS PostgreSQL)]
   A --> Cache[(ElastiCache TLS)]
   L --> SQS[SQS standard + DLQ]
   SQS --> P
   A & T & L & P --> Collector[OTel Collector Fargate]
   Collector --> XRay[X-Ray]
   Endpoints[PrivateLink + S3 gateway] --> ECR[ECR / Logs / Secrets]
  end
 end
 GitHub[Future GitHub OIDC deployment] --> ECR
 Terraform --> VPC
~~~

Choose ECS Fargate for four small independent workloads with no instance-management requirement. Managed Instances supplies broader EC2 instance types and managed host capacity, useful for specialized hardware or more sustained workloads; ECS on EC2 adds explicit fleet/patch/capacity ownership. There is no workload evidence justifying those operational responsibilities here. This is a workload-specific choice, not a claim that AWS universally recommends Fargate over the newer Managed Instances option.

One cluster; separate task definitions, SGs, task/execution roles, Cloud Map DNS records, log groups, target groups and scaling policies. Each application starts at 0.25 vCPU/0.5 GiB, max two replicas, CPU target 60%. Collector is a separate 0.25 vCPU/0.5 GiB service. Bootstrap is a one-off task. ECR repositories are immutable; input image URIs must contain verified SHA256 digests, with git-SHA tags for provenance. There is no latest application image tag.

The ALB exposes unprefixed /transfers, /accounts, /accounts/*/balance, /journals and /projections/* routes. Balance rule has higher priority than Account wildcard. It never routes /internal, /admin or actuator paths externally. Local edge service prefixes differ to make service ownership explicit. API Gateway is omitted because ALB routing already solves entry/health needs and another managed hop would add cost without a demonstrated requirement.

Networking has two explicitly selected AZ names; private subnet route table has no Internet default route. Interface endpoints for ecr.api, ecr.dkr, logs, secretsmanager, sqs and xray plus S3 gateway let tasks pull private ECR images and access required APIs without NAT. Images for Collector and bootstrap PostgreSQL must be mirrored into their own ECR repositories before execution. Endpoints cost money even when application desired_count is zero. Dedicated SG rules constrain ALB/workload/DB/cache/API flows. Default VPC SG has no rules.

RDS is a single managed PostgreSQL instance containing four owned databases with separate credentials. Sandbox is db.t4g.micro, gp3 20–40 GiB, seven-day backups and deletion protection; multi_az changes the reference design. ElastiCache is a single cache.t4g.micro metadata cache with TLS/CMK; multi_az enables two nodes/failover. The local PG18 / RDS PG17 difference is documented and not presented as tested RDS compatibility. Full AWS runtime validation awaits authorization.

## Authorized deployment procedure (not executed)
1. Approve region, price estimate, Budget/alerts, access CIDRs, ACM certificate, state access and destroy/data-retention plan. No apply before approval.
2. Bootstrap encrypted versioned S3 state with use_lockfile=true, restrict state access, init the backend. Never commit credentials/state.
3. Review a credential-safe Terraform plan. Initial desired_count=0. Applying still creates billable RDS/cache/ALB/endpoints/KMS.
4. Build/test/scan service images; mirror pinned Collector and PostgreSQL bootstrap image into ECR; use git-SHA immutable tags and actual digest inputs. OIDC assume-role, no long-lived access keys.
5. Run the bootstrap ECS task with private subnets and bootstrap SG from outputs; wait for successful exit. It creates role/database/default grants without logging secrets. Bootstrap reads the RDS-managed master password; ordinary services never do.
6. Start application/Collector desired counts after bootstrap; Flyway performs per-service migrations. Verify readiness, ALB health, TLS, SQS and traces. No cloud funding endpoint exists; use an audited future settlement mechanism before meaningful money tests.
7. Smoke test, inspect alarms/logs and verify least privilege in AWS. Attach alarm notification targets and cost alarms appropriate to the operator; Terraform currently creates detection rules without a notification destination.

No authenticated plan, apply, ECR push, ECS execution, RDS bootstrap, AWS DR drill or AWS cost measurement was performed. A foundation can validate code and configuration locally without buying cloud resources.

