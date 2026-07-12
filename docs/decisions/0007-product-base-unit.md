# 0007: product base unit

## Status

Accepted

## Context

Multiple packaging units need one authoritative inventory measure.

## Decision

Every stock-tracked product has exactly one active base ProductUnit referenced by Product; it is 1/1.

## Consequences

Inventory remains comparable and barcode/package choices do not fragment stock.

## Alternatives Considered

Balances per package and no explicit base unit were rejected.

