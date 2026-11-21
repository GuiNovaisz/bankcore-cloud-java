-- A posting set is closed once committed: its two sides are unique and immutable.
-- Protect journal-linked event payloads as the immutable source for explicit replay.
CREATE FUNCTION outbox_payload_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF NEW.id<>OLD.id OR NEW.payload<>OLD.payload OR NEW.created_at<>OLD.created_at THEN
  RAISE EXCEPTION 'IMMUTABLE_EVENT_PAYLOAD' USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER outbox_payload_guard BEFORE UPDATE ON outbox FOR EACH ROW EXECUTE FUNCTION outbox_payload_guard();
REVOKE DELETE ON outbox FROM ledger_app;
CREATE TABLE replay_audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,event_id uuid NOT NULL REFERENCES outbox(id),requested_at timestamptz NOT NULL DEFAULT now());
