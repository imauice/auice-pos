# Local-first operation

A store must be able to complete sales through internet outages. Cloud latency or availability therefore cannot be part of the critical sale path. The local SQLite database will be the source of truth for an active transaction and will eventually hold durable business records plus a sync outbox.

The cloud is responsible for consolidated data, coordination between devices, administration, and reporting. It does not authorize the basic ability to record a local sale. After connectivity returns, a future worker will retry queued operations, using stable client-generated UUIDs and idempotency so interrupted or repeated requests do not duplicate effects. Failures must remain visible and retryable.

POS-002 adds a durable `sync_outbox` with pending, processing, synced, and future dead-letter states. A retryable failure returns to pending with incremented retry metadata, keeping it selectable. It is intentionally not connected to sales and no periodic worker exists yet. Future business writes must insert their domain record and outbox event in one SQLite transaction; retry uses the stable SyncEvent UUID and identical immutable content.

POS-003 loads SQLite catalog data before contacting the cloud. Existing catalog data remains usable through outages. Online startup registers the stable local device ID, resumes any persisted catalog cursor, imports every page transactionally, and advances `lastCatalogVersion` only after the final page. With no local catalog and no network, startup reports `firstRunNeedsConnection`.
