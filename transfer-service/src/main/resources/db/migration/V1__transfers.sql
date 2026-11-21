CREATE TABLE transfer(id uuid PRIMARY KEY, idempotency_key varchar(128) NOT NULL UNIQUE,
 source uuid NOT NULL, destination uuid NOT NULL, amount numeric(19,2) NOT NULL CHECK(amount>0),
 currency text NOT NULL CHECK(currency='BRL'), status text NOT NULL CHECK(status IN ('REQUESTED','PROCESSING','COMPLETED','FAILED')),
 failure_code text, attempts integer NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now(),
 created_at timestamptz NOT NULL DEFAULT now(), completed_at timestamptz, CHECK(source<>destination));
CREATE INDEX pending_transfer ON transfer(next_attempt_at) WHERE status IN ('REQUESTED','PROCESSING');

