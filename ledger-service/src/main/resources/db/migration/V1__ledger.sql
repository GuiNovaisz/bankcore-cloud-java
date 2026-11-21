CREATE TABLE ledger_account (
 id uuid PRIMARY KEY,
 currency text NOT NULL DEFAULT 'BRL' CHECK(currency='BRL'),
 kind text NOT NULL DEFAULT 'CUSTOMER' CHECK(kind IN ('CUSTOMER','TREASURY')),
 enabled boolean NOT NULL DEFAULT true,
 balance numeric(19,2) NOT NULL DEFAULT 0,
 CHECK(kind='TREASURY' OR balance>=0)
);
INSERT INTO ledger_account(id,kind) VALUES ('00000000-0000-0000-0000-000000000001','TREASURY');
CREATE TABLE journal (
 id uuid PRIMARY KEY, source uuid NOT NULL REFERENCES ledger_account(id),
 destination uuid NOT NULL REFERENCES ledger_account(id),
 amount numeric(19,2) NOT NULL CHECK(amount>0), currency text NOT NULL CHECK(currency='BRL'),
 created_at timestamptz NOT NULL DEFAULT now(), CHECK(source<>destination)
);
CREATE TABLE posting (
 journal_id uuid NOT NULL REFERENCES journal(id), account_id uuid NOT NULL REFERENCES ledger_account(id),
 side text NOT NULL CHECK(side IN ('DEBIT','CREDIT')), amount numeric(19,2) NOT NULL CHECK(amount>0),
 PRIMARY KEY(journal_id,side), UNIQUE(journal_id,account_id)
);
CREATE INDEX posting_account_idx ON posting(account_id,journal_id);
CREATE FUNCTION immutable_history() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'IMMUTABLE_FINANCIAL_HISTORY' USING ERRCODE='23514'; END $$;
CREATE TRIGGER immutable_journal BEFORE UPDATE OR DELETE ON journal FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE TRIGGER immutable_posting BEFORE UPDATE OR DELETE ON posting FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE FUNCTION apply_posting() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 UPDATE ledger_account SET balance=balance + CASE WHEN NEW.side='DEBIT' THEN -NEW.amount ELSE NEW.amount END WHERE id=NEW.account_id;
 RETURN NEW;
END $$;
CREATE TRIGGER apply_posting AFTER INSERT ON posting FOR EACH ROW EXECUTE FUNCTION apply_posting();
CREATE FUNCTION balanced_journal() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE j journal; n integer; d numeric; c numeric;
BEGIN
 SELECT * INTO j FROM journal WHERE id=NEW.id;
 SELECT count(*),coalesce(sum(amount) FILTER(WHERE side='DEBIT' AND account_id=j.source),0),coalesce(sum(amount) FILTER(WHERE side='CREDIT' AND account_id=j.destination),0)
 INTO n,d,c FROM posting WHERE journal_id=j.id;
 IF n<>2 OR d<>j.amount OR c<>j.amount THEN RAISE EXCEPTION 'UNBALANCED_JOURNAL' USING ERRCODE='23514'; END IF;
 RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER balanced_journal AFTER INSERT ON journal DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION balanced_journal();
CREATE FUNCTION no_late_posting() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM posting WHERE journal_id=NEW.journal_id AND side=NEW.side) THEN
  RAISE EXCEPTION 'POSTING_ALREADY_EXISTS' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER no_late_posting BEFORE INSERT ON posting FOR EACH ROW EXECUTE FUNCTION no_late_posting();
CREATE TABLE outbox (
 id uuid PRIMARY KEY REFERENCES journal(id), payload text NOT NULL, traceparent text,
 correlation_id text, created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz,
 attempts integer NOT NULL DEFAULT 0, next_attempt_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX pending_outbox ON outbox(next_attempt_at) WHERE published_at IS NULL;

