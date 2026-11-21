# ADR-011: Four shallow Terraform modules

Status: accepted for foundation. Date: 2026-11-21.

Networking, messaging, data and runtime have clear inputs/outputs under a sandbox root. Pin CLI/providers with lockfile, fmt/validate/Checkov in CI. No auto-apply, credential-free validation first. Sensitive random credentials reside in state; real deployments need encrypted remotely locked state.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
