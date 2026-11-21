# Disaster recovery

Demo objectives, not measured production guarantees: target RTO four hours, RPO five minutes for authoritative data using RDS PITR; projection can be rebuilt from retained journal/outbox and should have no independent financial authority. The only executed recovery drill is local logical pg_dump/restore with invariant validation (B24). AWS PITR and these objective times are NOT proven.

Reference backup: encrypted RDS storage, seven-day automated backup retention, copying tags and final snapshot on deletion. Single-AZ sandbox is not high availability. Multi-AZ option covers an AZ failure domain, not region-wide recovery. No multi-region DR is implemented.

Recovery order: preserve incident artifacts and isolate writers; recreate reviewed infrastructure from pinned Terraform/state; restore PostgreSQL to a new private instance; recreate/validate database roles and secrets; redeploy previous known-good image/task revisions; reconcile all pending transfers by journal id before new posting; retain/inspect SQS/DLQ and outbox; rebuild projections/inbox together if needed; validate money conservation, balanced journals, nonnegative customer balances, idempotency and account gates; resume a bounded smoke then traffic. Record actual RTO/RPO when a real drill is authorized.

Retain outbox/inbox history across restores or replay the full relevant range. Restoring DB and queue to mismatched points creates duplicate/lost derived deliveries, resolved with immutable ids, replay and reconciliation, never editing postings. Credential changes must match restored database roles and task secrets. ECR images and remote state have independent recovery/retention policies.

Local B24 creates an isolated restore_<random> database only inside the task's PostgreSQL container, restores a dump without owner/ACL commands, compares journal count and reruns all invariant SQL, then drops only that exact test database. It does not delete a user's database or claim physical backup/PITR equivalence.

