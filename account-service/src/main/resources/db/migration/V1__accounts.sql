CREATE TABLE account(id uuid PRIMARY KEY, owner_reference varchar(80) NOT NULL,
 status text NOT NULL CHECK(status IN ('PROVISIONING','ACTIVE','BLOCKED','CLOSED')),
 created_at timestamptz NOT NULL DEFAULT now());

