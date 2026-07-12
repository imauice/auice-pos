# 0003: sale embed strategy

## Status

Accepted

## Context

A receipt is an immutable aggregate read as one unit.

## Decision

Embed explicit SaleItem and Payment subdocuments in Sale. Domain UUIDs remain on every item/payment.

## Consequences

Receipt snapshots are atomic and efficient; independent line mutation is intentionally discouraged.

## Alternatives Considered

Separate collections were rejected for the MVP because they add consistency and query overhead.

