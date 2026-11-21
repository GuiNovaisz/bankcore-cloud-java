# Reconciliation and projection rebuild

POST /internal/reconciliation/{accountId} in Projection requires the service role. It fetches the authoritative Ledger balance, compares the current projection and persists both amounts plus mismatchDetected in reconciliation_audit. It never changes either amount. Since databases are read separately, active traffic/in-flight events can produce a temporary mismatch; stop traffic, drain outbox/queue and retry before classifying a discrepancy as corruption. There is no cross-service snapshot claim.

B14 drains the chosen account, introduces exactly BRL 0.01 in the derived database through test-only SQL, checks mismatchDetected=true and a persisted audit row, then explicitly removes that test delta. The production API has no divergence injection endpoint.

Recovery: snapshot projection/inbox and retain reconciliation audit. In a maintenance window pause consumer and traffic; rebuild a fresh projection database by replaying immutable Ledger outbox payloads in pages with the original event ids. Rebuild inbox and projection together. POST Ledger /internal/outbox/{eventId}/replay resets delivery metadata and inserts replay_audit atomically. It is idempotent at the consumer and requires service credentials. After the replay drains, run reconciliation for every ledger account in bounded pages; record results, switch readers and resume traffic. Do not clear inbox alone or rewrite Ledger.

An intentionally stopped LocalStack may lose ephemeral queue state. It is not proof of AWS queue durability. Replay is the repair mechanism for local emulator loss; real AWS SQS retention and RDS backup policies have different failure domains. B24 proves local logical restore only.

