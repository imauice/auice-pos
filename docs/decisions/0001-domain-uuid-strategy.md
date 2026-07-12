# 0001: domain uuid strategy

## Status

Accepted

## Context

Devices must create identifiers before cloud access.

## Decision

Use standards-based UUID v7 for new domain and event IDs. Current Dart UUID support provides v7. Accept valid RFC UUIDs at API boundaries for interoperability; never expose MongoDB `_id`.

## Consequences

IDs are locally available, time-sortable, and stable across retries.

## Alternatives Considered

UUID v4 was acceptable but loses ordering locality. Custom algorithms were rejected.

