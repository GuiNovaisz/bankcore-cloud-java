# Ledger and financial correctness

BRL only, two decimal places, BigDecimal in Java and numeric(19,2) in PostgreSQL. Rounding policy is UNNECESSARY: fractional cents are rejected. The application conservatively bounds input precision. Monetary responses are strings so consumers do not need binary floating point. No exchange, overdraft, interest or fees are implemented.

Each journal has two postings: source DEBIT and destination CREDIT. Here debit decreases a customer available-money account and credit increases it; these are wallet subledger conventions, not a complete bank general ledger classification. Deferred PostgreSQL triggers require exactly the two expected amounts/accounts before COMMIT. Source and destination cannot be equal. Journal id is unique; posting side and journal/account combinations are unique.

An account balance is a transactional accumulator of signed immutable postings, maintained by the posting trigger, within the same transaction. It is audited against SUM(postings). Runtime SQL cannot update the balance column directly. The trigger executes under the migration owner with a fixed search_path and nested trigger guard. Negative CUSTOMER balances fail a database CHECK; the explicit TREASURY account may be negative to represent the offset to local fixture funding. Total balances including treasury remain zero.

Before inserting a journal, Ledger takes an advisory transaction lock derived from its UUID. A pre-existing id must match source, destination, currency and amount. Accounts are locked in UUID order. Sufficiency and enabled gates are checked under those locks. Posting application, journal, outbox and balance updates share one local commit. A process crash causes the whole transaction to commit or roll back, never half a movement.

Journals and postings reject UPDATE/DELETE even under the migration owner. Runtime roles have SELECT/INSERT only and cannot ALTER/DROP/TRUNCATE. Owners/superusers can deliberately remove protections, as with any database; administrative compromise is not prevented by triggers. Normal API/runtime flows cannot mutate committed history. Outbox financial payload is immutable and cannot be deleted by runtime credentials. Operational delivery timestamps are mutable.

Corrections are compensating journals: submit a new transfer with the original destination as source, original source as destination, and a new idempotency key. The original journal stays unchanged. Compensation is subject to available funds and enabled-account checks; it is not guaranteed if the recipient has spent funds. There is no automatic destructive reversal or arbitrary history editing API.

Funding exists only under Spring's local profile, protected by operator credentials: explicit treasury debit + customer credit with a caller-supplied journal UUID. Production/AWS has no funding endpoint or external settlement rail. Account metadata creation provisions a zero-balance ledger account idempotently; an interrupted acknowledgement is safe to retry with the same account UUID and owner.

Proofs use real PostgreSQL, role permission failures, a deferred unbalanced-commit attempt and a lock barrier. In B5 an external transaction holds the source row; both HTTP requests are observed waiting on PostgreSQL locks before release. This establishes overlapping financial attempts rather than relying on scheduler timing.

