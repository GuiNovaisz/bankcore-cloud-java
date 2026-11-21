# ADR-012: OIDC and workload roles

Status: accepted for foundation. Date: 2026-11-21.

Future GitHub deployment uses OIDC short-lived role credentials; tasks use independent IAM roles. Execution roles pull own ECR images/inject scoped secrets/write own logs, task roles get only queue actions they need. No AWS long-lived access keys are committed or provisioned.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
