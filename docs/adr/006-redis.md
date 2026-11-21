# ADR-006: Disposable cache-aside metadata

Status: accepted for foundation. Date: 2026-11-21.

Cache only Account public metadata for15seconds. Miss/failure reads DB, mutations best-effort invalidate, authorization bypasses Redis. Read staleness is explicit and cannot authorize funds. No cache balance authority or distributed lock.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
