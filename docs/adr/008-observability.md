# ADR-008: OpenTelemetry and bounded metrics

Status: accepted for foundation. Date: 2026-11-21.

Micrometer/OTel propagates HTTP context and persists async parents in durable records. Collector/Tempo and Prometheus/Grafana form a small local stack. AWS uses Collector X-Ray and native CloudWatch telemetry. No sensitive/high-cardinality metric labels or claim of automatic JDBC query spans.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
