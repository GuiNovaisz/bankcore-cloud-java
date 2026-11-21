# Domain

Account lifecycle is PROVISIONING → ACTIVE ↔ BLOCKED → CLOSED. CLOSED cannot reopen. Administrative state changes acknowledge the Ledger gate before committing metadata. Ledger gates are checked under the same row locks as monetary writes, giving blocking a definite financial ordering. Failed cross-service lifecycle acknowledgement can temporarily be conservative (metadata active, Ledger disabled). Retry the same status command and inspect both stores; there is no false promise of atomic metadata/ledger lifecycle changes. Closing currently disables financial movement and preserves any historical balance; operators must settle funds before closure as an operating policy. Automatic zero-balance close enforcement is outside this prototype.

Transfer transitions: REQUESTED → PROCESSING → COMPLETED or FAILED. REQUESTED can complete on its first background attempt. PROCESSING means durable work and uncertain/retryable outcome, never confirmed money movement. COMPLETED means Ledger acknowledged an existing or new committed journal. FAILED is reserved for authoritative business rejection such as insufficient funds, missing/inactive accounts or conflicting journal command. Transport failures never become a false financial rejection/completion.

Opaque fixture owner references contain no CPF or real customer data. The API is for a trusted operator, not a multi-tenant retail customer application. Idempotency namespace is the single operator environment. Adding retail tenants requires authenticated tenant scoping, authorization and migration of that uniqueness contract.

