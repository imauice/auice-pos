# 0005: sync idempotency

## Status

Accepted

## Context

Local retries are unavoidable after ambiguous network failures.

## Decision

Use unique SyncEvent UUIDs as idempotency keys. Duplicate pushes return the original accepted entity/version result without another insert.

## Consequences

Clients may retry safely and deterministically.

## Alternatives Considered

Returning DUPLICATE_EVENT was rejected because it complicates recovery.

