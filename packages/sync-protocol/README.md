# Auice Sync Protocol v1

`POST /api/sync/push` accepts 1–100 events. The envelope contains `protocolVersion`, branch/device UUIDs, and ordered events. Supported entity types are `branch`, `device`, `category`, `product`, `product_unit`, `product_price`, `shift`, `sale`, and `stock_movement`.

Events use client-generated UUID v7 IDs, entity UUIDs, integer versions, UTC timestamps, and JSON payloads. The cloud event log intentionally uses a flexible JSON payload because one versioned log carries several domain shapes; envelope metadata remains strictly validated. Nest's default JSON body limit (100 KB) protects payload size, batches are limited to 100 events, and unknown properties are rejected.

## Idempotency and retries

Event ID is the idempotency key. A repeated ID with identical immutable envelope and payload content does not create another record and returns the original `accepted` result. Reusing an ID with different branch, device, entity metadata, timestamp, or payload returns non-retryable `IDEMPOTENCY_CONFLICT`. Events are sent oldest-first, but v1 does not guarantee cross-device ordering.

The local outbox uses `pending`, `processing`, `synced`, and `dead_letter`. A retryable failure returns to `pending`, increments `retryCount`, and records `lastError` plus `lastAttemptAt`, so it remains discoverable. A future worker will apply a configured retry limit and move exhausted events to `dead_letter`; that worker is not implemented here.

## Errors

- `VALIDATION_ERROR`: malformed contract; fix before retrying.
- `UNSUPPORTED_PROTOCOL_VERSION`: client protocol is not supported.
- `UNKNOWN_ENTITY_TYPE`: event type is unavailable in this version.
- `VERSION_CONFLICT`: server version disagrees; resolution is deferred.
- `BRANCH_MISMATCH`: envelope and entity branches differ.
- `DEVICE_INACTIVE`: originating device is disabled.
- `DUPLICATE_EVENT`: reserved; v1 duplicates normally return accepted.
- `IDEMPOTENCY_CONFLICT`: an existing event ID has different immutable content; never retry under that ID.
- `INTERNAL_ERROR`: transient server persistence failure; retryable.

## Multi-unit payload examples

```json
{"entityType":"product","payload":{"id":"uuid","name":"Beer A","baseUnitId":"bottle-unit-id","trackStock":true}}
{"entityType":"product_unit","payload":{"id":"case-unit-id","productId":"uuid","code":"case","name":"ลัง","conversionNumerator":12,"conversionDenominator":1,"barcode":"case-barcode","allowSale":true,"allowPurchase":true}}
{"entityType":"product_price","payload":{"productId":"uuid","productUnitId":"case-unit-id","priceMinor":72000,"currency":"THB"}}
{"entityType":"sale","payload":{"items":[{"productUnitId":"case-unit-id","unitNameSnapshot":"ลัง","quantityMinor":2,"quantityScale":1,"conversionNumeratorSnapshot":12,"conversionDenominatorSnapshot":1,"baseQuantityMinor":24,"baseQuantityScale":1,"unitPriceMinor":72000}]}}
{"entityType":"stock_movement","payload":{"type":"sale","sourceUnitId":"case-unit-id","sourceQuantityMinor":2,"sourceQuantityScale":1,"conversionNumeratorSnapshot":12,"conversionDenominatorSnapshot":1,"baseQuantityMinor":-24,"baseQuantityScale":1}}
```
