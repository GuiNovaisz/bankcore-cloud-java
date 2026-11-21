# ADR-001: Four services and monorepo

Status: accepted for foundation. Date: 2026-11-21.

Account metadata, durable Transfer orchestration, authoritative Ledger and derived Projection have distinct invariants and failure domains. Independent databases and images demonstrate network consistency. Keep atomic repository review/CI and a stable technical platform module; no shared domain jar. More services would multiply operational work without new ownership.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
