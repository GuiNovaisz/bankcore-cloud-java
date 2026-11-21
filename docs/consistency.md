# Consistency and recovery

The idempotency-key UNIQUE index serializes concurrent creation. A conflict blocks until the other local transaction resolves; the subsequent SELECT compares canonical UUIDs, BRL and exact decimal amount. Same key/request returns the same transfer id; a changed command returns 409. Keys are retained with the transfer without automatic expiry, so replay safety is not silently lost. Archival needs a retention decision.

The orchestration worker claims bounded transfer batches using FOR UPDATE SKIP LOCKED. It checks the journal first on every attempt, including after restart. If Ledger committed but the response or Transfer commit was lost, that lookup resolves completion even if the account is now blocked. It does not reject a previously posted movement based on current metadata. The stable transfer id is the ledger journal id. Different logical transfers have different ids.

Outbox publication is at least once. Send succeeds and delivery-timestamp update fails → event may be resent. Send fails → outbox stays pending with persisted attempts and exponential backoff/jitter. The consumer commits the inbox/event-id and additive deltas atomically before ack. An acknowledgement failure redelivers and hits the inbox unique key. A changed payload using an existing event id is rejected, not silently treated as equivalent.

Projection deltas commute across delivery order and do not drive authorization. A projection may temporarily show a negative amount when debit arrives before an earlier funding credit; this is eventual read state only. Keep inbox deduplication records as long as replay is possible. Clearing inbox while keeping projection duplicates effects; rebuild both together under an explicit maintenance procedure.

~~~mermaid
flowchart TD
 Commit[Journal + postings + outbox committed] --> Send{SQS send}
 Send -->|failure| Pending[Persist pending + retry schedule]
 Pending --> Send
 Send -->|success| Mark[Mark published]
 Send -->|acknowledgement uncertain| Again[Possible duplicate send]
 Again --> Inbox[Inbox UNIQUE event id]
 Mark --> Inbox
 Inbox --> Atomic[Commit projection + inbox]
 Atomic --> Ack[Acknowledge message]
 Ack -->|lost ack| Inbox
~~~

No component claims distributed exactly-once. The logical money effect is unique inside Ledger; messaging remains at least once. Long-running pending transfers require alerting and reconciliation, not an arbitrary timeout that marks unknown money outcomes FAILED.

