# Local-first operation

A store must be able to complete sales through internet outages. Cloud latency or availability therefore cannot be part of the critical sale path. The local SQLite database will be the source of truth for an active transaction and will eventually hold durable business records plus a sync outbox.

The cloud is responsible for consolidated data, coordination between devices, administration, and reporting. It does not authorize the basic ability to record a local sale. After connectivity returns, a future worker will retry queued operations, using stable client-generated UUIDs and idempotency so interrupted or repeated requests do not duplicate effects. Failures must remain visible and retryable.

POS-002 adds a durable `sync_outbox` with pending, processing, synced, and future dead-letter states. A retryable failure returns to pending with incremented retry metadata, keeping it selectable. It is intentionally not connected to sales and no periodic worker exists yet. Future business writes must insert their domain record and outbox event in one SQLite transaction; retry uses the stable SyncEvent UUID and identical immutable content.

POS-003 loads SQLite catalog data before contacting the cloud. Existing catalog data remains usable through outages. Online startup registers the stable local device ID, resumes any persisted catalog cursor, imports every page transactionally, and advances `lastCatalogVersion` only after the final page. With no local catalog and no network, startup reports `firstRunNeedsConnection`.

POS-004 connects business writes to the outbox without adding any network dependency. Cash checkout validates local snapshots and commits Sale, SaleItems, Payment, negative StockMovements, and pending sale/movement events in the same SQLite transaction. A failure at any insertion rolls back the receipt sequence and every business/outbox row. Receipt history is reconstructed from stored snapshots and remains available offline.

POS-005 requires an explicitly opened local shift before sale. Opening a shift, recording an append-only cash movement, and closing a shift each commit their pending outbox event in the same SQLite transaction, without an HTTP request. Expected cash is opening cash plus net cash retained by completed cash payments plus cash-in minus cash-out. Closing stores final cash snapshots so later synchronization cannot rewrite the reconciliation. Receipt sequences remain scoped by device and UTC date inside SQLite.
