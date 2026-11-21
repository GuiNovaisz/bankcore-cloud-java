# ADR-002: Double-entry immutable ledger

Status: accepted for foundation. Date: 2026-11-21.

Use one atomic PostgreSQL journal/posting boundary for both sides of each movement. Deferred constraints validate exact debit/credit amounts; immutable triggers and runtime grants prevent destructive edits. Balances are transactional accumulators audited against postings. This avoids cross-service debit/credit sagas and makes conservation provable.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
