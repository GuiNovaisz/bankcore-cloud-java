# BankCore Cloud

Cloud-native banking backend built with Java and Spring Boot, designed around financial correctness, distributed systems, resilience, observability and AWS infrastructure as code.

## Português

**Versão estável atual: [v0.1.0](https://github.com/GuiNovaisz/bankcore-cloud-java/releases/tag/v0.1.0).**

BankCore demonstra como movimentar dinheiro sem duplicação, gasto concorrente indevido ou lançamentos parciais, mesmo quando serviços e mensageria falham. O milestone **v0.1.0 — Cloud-Native Banking Backend Foundation** tem quatro serviços, sem frontend. É um laboratório de engenharia e portfólio; não conecta dinheiro real nem declara conformidade bancária de produção.

O Ledger é a única autoridade financeira: journals de dupla entrada, postings imutáveis e locks no PostgreSQL. Transfer possui seu próprio ciclo durável; uma resposta HTTP perdida é reconciliada pelo id do journal. A outbox e o consumidor idempotente aceitam entrega pelo menos uma vez. Redis otimiza somente leitura de metadados, com fallback ao banco.

Microserviços permitem demonstrar ownership, falhas de rede, consistência eventual e deployments independentes. Account, Transfer, Ledger e Projection têm bancos, usuários, migrations e imagens distintos. Não há jar de domínio compartilhado. Terraform prepara ECS Fargate, ECR, RDS privado, ElastiCache privado, SQS/DLQ, Secrets Manager e CloudWatch/X-Ray.

**AWS real não foi implantada. Nenhum apply é executado pela CI.**

`REAL_AWS_DEPLOYMENT = NOT_EXECUTED`
 [Provas e resultados](docs/evidence.md), [arquitetura](docs/architecture.md), [limitações](docs/security.md) e [custos](docs/cost-model.md) são parte da entrega.

### Executar no Windows

Requer Docker Desktop com Linux containers, PowerShell 7 e Node.js 22+. Reserve aproximadamente 4 GiB para esta stack; o Compose limita memória e CPU por serviço. Não reutiliza navegador, cookies ou aplicações pessoais.

~~~powershell
git clone https://github.com/GuiNovaisz/bankcore-cloud-java.git
cd bankcore-cloud-java
git switch --detach v0.1.0
./scripts/dev-up.ps1
./scripts/verify.ps1
./scripts/smoke.ps1
./scripts/load-test.ps1
./scripts/dev-down.ps1
~~~

API local: http://localhost:28180. Grafana: http://localhost:13000 (admin, senha em .env). Prometheus: http://localhost:19090. Tempo: http://localhost:13200. Credenciais locais são geradas, ignoradas pelo Git e nunca incluídas nas imagens. A API é exclusiva para operadores; não implementa autenticação de clientes bancários. [Passo a passo de transferência](docs/operations.md), [OpenAPI](docs/api/openapi.yml), [testes](docs/testing.md).

Para levantar em Linux/CI: node scripts/configure.mjs; docker compose --parallel 1 up -d --build --wait. Para compilar um único serviço: mvn -pl ledger-service -am verify (JDK 21+, bytecode 21). A biblioteca platform contém somente segurança HTTP, erros e propagação de contexto.

~~~mermaid
flowchart LR
 Client[Operator] --> Edge[Edge / ALB]
 Edge --> Account[Account]
 Edge --> Transfer[Transfer]
 Transfer --> Account
 Transfer --> Ledger[Ledger: financial authority]
 Ledger --> DB[(Ledger PostgreSQL)]
 Ledger --> Outbox[Transactional outbox]
 Outbox --> SQS[SQS + DLQ]
 SQS --> Projection[Projection worker]
 Projection --> Read[(Derived read model)]
 Account --> Redis[(Disposable Redis cache)]
~~~

Os testes de falha param e reiniciam **somente serviços deste projeto Compose**. O teste de carga é limitado, reproduzível e não representa capacidade de produção. Para remover containers, execute dev-down; os dados permanecem no volume. Remova o volume somente quando desejar apagar as fixtures.

The complete English version follows below.

## English

**Current stable release: [v0.1.0](https://github.com/GuiNovaisz/bankcore-cloud-java/releases/tag/v0.1.0).**

BankCore demonstrates monetary movement without duplicate effects, concurrent overspending or half-committed transfers, including dependency outages and uncertain HTTP outcomes. **v0.1.0 — Cloud-Native Banking Backend Foundation** contains four services and no frontend. This is an engineering portfolio laboratory, with no real-money rails or production banking compliance claims.

Ledger is the sole financial authority. It commits balanced immutable postings, authoritative balances and the outbox atomically. Transfer owns durable orchestration and reconciles uncertain outcomes using the journal identifier. SQS delivery is at least once, and the inbox prevents duplicate projection effects. Redis caches metadata only and is bypassed for financial authorization.

The service boundaries demonstrate independent ownership/deployment, network failure and distributed consistency. Each service has its own database, role, Flyway migrations and container. The platform module shares stable transport infrastructure only. Terraform targets private ECS Fargate tasks, ECR, RDS PostgreSQL, ElastiCache, SQS/DLQ, Secrets Manager, CloudWatch and OpenTelemetry/X-Ray.

**No real AWS deployment was performed. CI never applies Terraform.**

`REAL_AWS_DEPLOYMENT = NOT_EXECUTED`
 Review [evidence](docs/evidence.md), [architecture](docs/architecture.md), [security limits](docs/security.md) and the [cost model](docs/cost-model.md).

### Run

Requirements: Docker Desktop/Linux containers, PowerShell 7 and Node.js 22+. Run the same PowerShell commands above, or on Linux run node scripts/configure.mjs, docker compose --parallel 1 up -d --build --wait, mvn verify with Java 21+, node tests/e2e.mjs, node scripts/load.mjs, and docker compose down.

The operator API is at localhost:28180; Grafana localhost:13000 (admin and generated password); Prometheus localhost:19090; Tempo localhost:13200. Generated credentials stay in ignored .env. [Operations](docs/operations.md) documents creating accounts, explicit double-entry fixture funding, transfers, polling status, traces and shutdown. [OpenAPI](docs/api/openapi.yml) describes decimal-string monetary contracts. API access is operator-only; retail identity and ownership authorization are outside this foundation.

Failure tests intentionally stop only this project's containers. The bounded load baseline is reproducible evidence, not a production capacity claim. Compose down preserves the database volume. See [testing](docs/testing.md), [failure matrix](docs/failure-matrix.md), [SLOs](docs/slo.md), [ADRs](docs/adr/README.md), and [AWS operations](docs/aws-architecture.md). A possible v0.2.0 BankCore Cloud Experience with React/TypeScript remains documentation only, conditional on backend/cloud validation and separate authorization.

