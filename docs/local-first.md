# Local-first operation

A store must be able to complete sales through internet outages. Cloud latency or availability therefore cannot be part of the critical sale path. The local SQLite database will be the source of truth for an active transaction and will eventually hold durable business records plus a sync outbox.

The cloud is responsible for consolidated data, coordination between devices, administration, and reporting. It does not authorize the basic ability to record a local sale. After connectivity returns, a future worker will retry queued operations, using stable client-generated UUIDs and idempotency so interrupted or repeated requests do not duplicate effects. Failures must remain visible and retryable.

POS-001 proves only that SQLite opens and stores application metadata. No sales or synchronization implementation exists yet.

