# 0009: unit specific pricing

## Status

Accepted

## Context

Package pricing is commercial policy, not simple multiplication.

## Decision

ProductPrice references ProductUnit; every unit may have an independent effective-dated price.

## Consequences

A 12-bottle case may cost 720 THB while bottles cost 65 THB each.

## Alternatives Considered

Automatically deriving package price was rejected.

