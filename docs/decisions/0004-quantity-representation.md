# 0004: quantity representation

## Status

Accepted

## Context

Measured and packaged quantities require exact fractional representation.

## Decision

Use integer `quantityMinor` plus positive integer `quantityScale`; store base quantities similarly. Unit conversions use positive rational integers. Each Product owns one positive `baseQuantityScale` (default `1` for existing count-based products), and every SaleItem and StockMovement for that product uses that canonical scale rather than the cashier-entered quantity scale.

## Consequences

No floating-point drift; unrepresentable conversions are explicitly rejected. Stock quantities for one product are directly summable because their denominators are identical.

## Alternatives Considered

Integer-only pieces cannot handle measured goods; floating point was rejected.
