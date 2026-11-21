# ADR-007: Durable retry ownership

Status: accepted for foundation. Date: 2026-11-21.

Use bounded RestClient, Resilience4j Account breaker and database retry schedule. Workers reconcile journal before retry; SDK immediate retries disabled. SQS owns consumer redelivery. This avoids multiplicative retries and false terminal outcomes after lost responses.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
