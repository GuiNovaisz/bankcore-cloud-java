\getenv account_password ACCOUNT_DB_PASSWORD
\getenv account_migration_password ACCOUNT_MIGRATION_PASSWORD
CREATE ROLE account_migrator LOGIN PASSWORD :'account_migration_password';
CREATE ROLE account_app LOGIN PASSWORD :'account_password';
CREATE DATABASE account OWNER account_migrator;
REVOKE ALL ON DATABASE account FROM PUBLIC;
GRANT CONNECT ON DATABASE account TO account_app;
\connect account
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO account_app;
ALTER DEFAULT PRIVILEGES FOR ROLE account_migrator IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO account_app;
ALTER DEFAULT PRIVILEGES FOR ROLE account_migrator IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO account_app;
\connect postgres
\getenv ledger_password LEDGER_DB_PASSWORD
\getenv ledger_migration_password LEDGER_MIGRATION_PASSWORD
CREATE ROLE ledger_migrator LOGIN PASSWORD :'ledger_migration_password';
CREATE ROLE ledger_app LOGIN PASSWORD :'ledger_password';
CREATE DATABASE ledger OWNER ledger_migrator;
REVOKE ALL ON DATABASE ledger FROM PUBLIC;
GRANT CONNECT ON DATABASE ledger TO ledger_app;
\connect ledger
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO ledger_app;
ALTER DEFAULT PRIVILEGES FOR ROLE ledger_migrator IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO ledger_app;
ALTER DEFAULT PRIVILEGES FOR ROLE ledger_migrator IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO ledger_app;
\connect postgres
\getenv transfer_password TRANSFER_DB_PASSWORD
\getenv transfer_migration_password TRANSFER_MIGRATION_PASSWORD
CREATE ROLE transfer_migrator LOGIN PASSWORD :'transfer_migration_password';
CREATE ROLE transfer_app LOGIN PASSWORD :'transfer_password';
CREATE DATABASE transfer OWNER transfer_migrator;
REVOKE ALL ON DATABASE transfer FROM PUBLIC;
GRANT CONNECT ON DATABASE transfer TO transfer_app;
\connect transfer
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO transfer_app;
ALTER DEFAULT PRIVILEGES FOR ROLE transfer_migrator IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO transfer_app;
ALTER DEFAULT PRIVILEGES FOR ROLE transfer_migrator IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO transfer_app;
\connect postgres
\getenv projection_password PROJECTION_DB_PASSWORD
\getenv projection_migration_password PROJECTION_MIGRATION_PASSWORD
CREATE ROLE projection_migrator LOGIN PASSWORD :'projection_migration_password';
CREATE ROLE projection_app LOGIN PASSWORD :'projection_password';
CREATE DATABASE projection OWNER projection_migrator;
REVOKE ALL ON DATABASE projection FROM PUBLIC;
GRANT CONNECT ON DATABASE projection TO projection_app;
\connect projection
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO projection_app;
ALTER DEFAULT PRIVILEGES FOR ROLE projection_migrator IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO projection_app;
ALTER DEFAULT PRIVILEGES FOR ROLE projection_migrator IN SCHEMA public GRANT USAGE,SELECT ON SEQUENCES TO projection_app;
\connect postgres

