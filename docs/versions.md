# Versions and selection record

Researched 2026-11-21 using official docs, Maven Central metadata/artifact HEAD checks, HashiCorp release checksums/registry and published container tags. Versions are explicit reproducibility pins; none is asserted universally latest unless metadata was actually queried.

| Component | Selected / observed | Rationale |
|---|---|---|
| Java language/runtime target | 21 | Explicit mission requirement; containers/CI JDK21; local installed Temurin25.0.5+8 compiles release21 |
| Spring Boot | 3.5.16 | Official 3.5 requirements compatible17–25; metadata POM verified200; stable Spring6/Jackson2 line. Current main docs also advertise4.2.0; intentionally no unnecessary major migration |
| Maven | 3.9.11 | Official Maven Central distribution; Docker build JDK21 |
| AWS SDK Java v2 | 2.59.7 | Release from Maven Central metadata |
| Resilience4j | 2.4.0 | Release from Maven Central metadata; circuitbreaker API + Micrometer adapter |
| Micrometer/OTel/Flyway/PostgreSQL JDBC/security/test libraries | Spring Boot3.5.16 BOM | mvn dependency:tree records exact resolved versions; avoid incompatible overrides |
| PostgreSQL local | 18.7-alpine | Existing verified image; cloud target managed major17 is intentional and not AWS-runtime tested |
| Redis local | 7.4.2-alpine | Explicit known image; cloud Redis OSS7.1 managed target |
| LocalStack | 4.10.0 | SQS-only local emulator without real AWS resources |
| Nginx | 1.28.0-alpine | Dynamic Docker DNS upstream resolution |
| Temurin runtime image | 21.0.9_10-jre-alpine | Nonroot Java21 image tag; no latest |
| Maven build image | 3.9.11-eclipse-temurin-21 | Java21 multistage builds |
| Collector | 0.123.0 contrib | OTLP/Tempo locally; AWS X-Ray exporter configuration prepared |
| Prometheus | v3.2.1 | Metrics + rules |
| Grafana | 11.6.0 | Provisioned dashboards and datasources |
| Tempo | 2.7.2 | Trace-id retrieval proof |
| Terraform | 1.17.2 | Official release index; downloaded binary SHA256 checked against published SHA256SUMS |
| HashiCorp AWS provider | 6.73.0 | Official registry selected; signed install + lockfile |
| HashiCorp random provider | 3.9.1 | Official registry selected; signed install + lockfile |
| Checkov | 3.4.6 | Official GitHub release and Docker image |
| Gitleaks | v8.30.1 | Official GitHub release; history scan |
| k6 | 2.4.0 | Official Grafana release; bounded scenarios |
| ECS Fargate platform | 1.4.0 Linux | Pinned platform; scanner exception versus LATEST reviewed |

Spring Cloud is not used: instrumented RestClient and Resilience4j meet the concrete needs. No Cloud compatibility train is required. Patch-tag containers are fixed names but registry tags can theoretically be retargeted; record RepoDigests with evidence, use immutable ECR digests for cloud deployments, and periodically refresh pins with scans. This is not a claim that old image pins are free of vulnerabilities.

