# 0004: quantity representation

## Status

Accepted

## Context

Measured and packaged quantities require exact fractional representation.

## Decision

Use integer `quantityMinor` plus positive integer `quantityScale`; store base quantities similarly. Unit conversions use positive rational integers.

## Consequences

No floating-point drift; unrepresentable conversions are explicitly rejected.

## Alternatives Considered

Integer-only pieces cannot handle measured goods; floating point was rejected.

