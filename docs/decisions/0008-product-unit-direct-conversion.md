# 0008: product unit direct conversion

## Status

Accepted

## Context

Conversion chains can become ambiguous and mutable.

## Decision

Every ProductUnit stores a positive rational conversion directly to its product base unit.

## Consequences

Runtime conversion is one exact integer formula.

## Alternatives Considered

Chained unit-to-unit conversion was rejected.

