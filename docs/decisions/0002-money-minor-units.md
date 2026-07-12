# 0002: money minor units

## Status

Accepted

## Context

Binary floating point cannot represent money reliably.

## Decision

Represent THB as non-negative integer satang fields ending in `Minor`; contracts use `{ amountMinor, currency: 'THB' }`.

## Consequences

Arithmetic is exact and validation is simple. Multi-currency is deferred.

## Alternatives Considered

Floating point and a complex decimal Money class were rejected.

