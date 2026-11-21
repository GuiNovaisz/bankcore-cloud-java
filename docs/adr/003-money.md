# ADR-003: Exact BRL decimal representation

Status: accepted for foundation. Date: 2026-11-21.

BigDecimal and PostgreSQL numeric with scale2 and UNNECESSARY rounding reject fractional cents. Decimal-string API responses protect JavaScript consumers. Single currency avoids hidden exchange/rounding assumptions. A future multi-currency design needs explicit currency-specific scales and balanced per-currency journals.

Consequences: implement/test the chosen boundary and retain the documented limitation; re-evaluate with measured workload or an explicit production requirement rather than adding technology for its name.
