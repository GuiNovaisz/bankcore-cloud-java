# Reproducible load baseline

Run scripts/load-test.ps1 or node scripts/load.mjs after healthy startup. Pinned k6 executes sequential moderate scenarios: steady 2 VU/15s; burst 4 VU/10s; concurrent 2 VU/10s; duplicate-key 2 VU/10s. The fixture starts two fictional accounts and an explicit treasury funding journal. No real money. It polls logical terminal outcomes rather than equating accepted HTTP202 with a completed movement.

Metrics: http_reqs rate, HTTP p50/p95/p99, http_req_failed, logical_transfer_error_rate and transfer_processing_ms p50/p95/p99. Detailed actual numbers are copied from artifacts/load-summary.json into evidence.md after execution. Thresholds require logical failures zero and HTTP failure rate <1%; they are demonstration checks, not a production performance promise. The duplicate scenario intentionally returns the same logical transfer, so raw request count is not unique financial throughput.

Record hardware/OS, container limits, dataset, duration and scenario with each baseline. All service containers are capped at 1 CPU/384 MiB; k6 0.5 CPU/192 MiB. Sharing a developer workstation and Windows Docker virtualization affects timing. No extrapolation to production TPS. B23 separately proves 12 accepted concurrent requests during a controlled Ledger outage, recovery and SQL invariants. It is a bounded failure-under-traffic proof, not a saturation/chaos benchmark.

