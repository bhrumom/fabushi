# 06 运维可观测性与 SLO

## Lifecycle states

`discovered -> tested -> captured -> scanned -> packaged -> approved -> queued -> published -> reconciled -> measured` with explicit terminal failure states.

## SLIs

- package generation success rate
- media validation success rate
- publish queue latency
- publisher success/retry rate
- duplicate prevention rate
- analytics reconciliation delay
- daily eligible-content count

## Initial SLOs

- 99% successful processing for valid eligible packages excluding external platform outages.
- 100% product-claim provenance retention.
- 0 secret/privacy publish incidents.
- 100% publisher attempts have an audit record.

Alerts should prioritize privacy/security, duplicate publishing, queue runaway, credential failures and sustained adapter failures.
