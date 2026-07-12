# 0010: unit snapshot history

## Status

Accepted

## Context

Current unit names, barcodes, conversions, and prices can change.

## Decision

SaleItem and StockMovement snapshot source-unit labels and rational conversion data at creation.

## Consequences

Historical receipts and inventory evidence remain reproducible.

## Alternatives Considered

Joining current ProductUnit data for history was rejected.

