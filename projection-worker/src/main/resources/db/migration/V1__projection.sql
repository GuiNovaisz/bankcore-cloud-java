CREATE TABLE inbox(event_id uuid PRIMARY KEY,payload text NOT NULL,processed_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE account_projection(account_id uuid PRIMARY KEY,balance numeric(19,2) NOT NULL,currency text NOT NULL CHECK(currency='BRL'));
CREATE TABLE reconciliation_audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,account_id uuid NOT NULL,ledger_balance numeric(19,2) NOT NULL,projection_balance numeric(19,2) NOT NULL,mismatch boolean NOT NULL,checked_at timestamptz NOT NULL DEFAULT now());

