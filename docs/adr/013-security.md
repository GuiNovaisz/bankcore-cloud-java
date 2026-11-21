# ADR-013: Operator-scoped foundation trust

Status: accepted for foundation. Date: 2026-11-21.

Use separate random Basic-auth operator/service roles, loopback local ports, HTTPS at CIDR-limited ALB and private SG-based internal trust. This intentionally excludes retail authentication, mTLS and production compliance. Real customer data requires dedicated identity/authorization, rotation, private TLS and migration-credential isolation before use.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
