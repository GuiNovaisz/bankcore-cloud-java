# ADR-005: Transactional outbox and inbox

Status: accepted for foundation. Date: 2026-11-21.

The journal and event are one commit; a polling publisher owns retry. Send/update ambiguity may redeliver. Inbox and projection share a transaction, ack follows commit. Retaining ids enables explicit replay; storage retention is a real operational tradeoff.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
