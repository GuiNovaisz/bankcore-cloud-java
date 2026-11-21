ALTER FUNCTION apply_posting() SECURITY DEFINER;
ALTER FUNCTION apply_posting() SET search_path=pg_catalog,public;
REVOKE ALL ON journal,posting,ledger_account FROM ledger_app;
GRANT SELECT,INSERT ON journal,posting TO ledger_app;
GRANT SELECT ON ledger_account TO ledger_app;
GRANT INSERT(id) ON ledger_account TO ledger_app;
GRANT UPDATE(enabled) ON ledger_account TO ledger_app;
REVOKE ALL ON flyway_schema_history FROM ledger_app;

