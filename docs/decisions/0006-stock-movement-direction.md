# 0006: stock movement direction

## Status

Accepted

## Context

Inventory must derive from append-only movements with unambiguous signs.

## Decision

Store signed `baseQuantityMinor`; inbound types must be positive and outbound types negative.

## Consequences

Balances can later be summed and invalid type/sign pairs are rejected.

## Alternatives Considered

Direction derived only at query time was rejected as less auditable.

