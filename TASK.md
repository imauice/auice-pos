# POS-001 — Foundation

Status: Approved

# POS-002 — Core Domain Model and Sync Contract

Status: In Progress

- [x] Define UUID, UTC timestamp, integer money, quantity, and version rules
- [x] Define all core entities and mandatory ProductUnit addendum
- [x] Add MongoDB schemas, indexes, embedded sale snapshots, and validation utilities
- [x] Add sync protocol v1 DTOs, event persistence, and idempotent duplicate handling
- [x] Add Flutter immutable domain/API models and centralized integer conversion
- [x] Add Drift schema-v2 sync outbox, migration, operations, and index
- [x] Add machine-readable and human-readable API/sync contracts
- [x] Add ADRs 0001–0010
- [x] Add cloud and Flutter unit tests
- [x] Update architecture and local-first documentation
- [x] Complete and record all available verification commands

## POS-002-FIX

- [x] Correct scaled conversion formula and overflow/exactness validation
- [x] Require baseUnitId for stock-tracked products
- [x] Return retryable outbox failures to pending
- [x] Detect immutable idempotency conflicts
- [x] Allow empty delete payload objects
- [x] Support mixed per-event acceptance and rejection
- [x] Run and record final API and Flutter verification
