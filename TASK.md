# POS-001 — Foundation

Status: Approved

# POS-002 — Core Domain Model and Sync Contract

Status: Approved

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

# POS-003 — Branch, Device Registration, Product Catalog and Initial Pull Sync

Status: Approved

- [x] Add explicit Branch list/get APIs
- [x] Add conflict-safe idempotent device registration
- [x] Add transactional catalog mutation/version boundary
- [x] Add stable snapshot keyset catalog pull
- [x] Add Drift schema-v3 master-data tables and indexes
- [x] Add resumable transactional catalog page import
- [x] Add SKU, name, unit, barcode, and current-price lookup
- [x] Add non-blocking online/offline startup coordinator
- [x] Add Cloud Web read-only master-data routes
- [x] Add cloud and Flutter coverage for POS-003 behavior
- [x] Complete and record final verification

## POS-003-FIX

- [x] Bound catalog keyset queries per entity collection
- [x] Bind catalog cursors to branch and starting version
- [x] Complete paginated Cloud Web read-only pages and APIs
- [x] Persist only the pending catalog cursor for interrupted pulls
- [x] Wire catalog startup and dependencies through Riverpod
- [x] Verify Cloud API, Cloud Web, and Flutter commands

# POS-004 — Offline Sale Transaction, Cart and Receipt Foundation

Status: Submitted for Review

- [x] Add Drift v4 shift, sale, line, payment, movement, and receipt-sequence tables
- [x] Implement local cart, exact integer calculations, and multi-unit behavior
- [x] Implement cash payment, change, and atomic sale/outbox completion
- [x] Add automatic development shift and per-device receipt sequences
- [x] Add local receipt repository, history, and snapshot reconstruction
- [x] Add sale, payment, receipt, history, and receipt-detail screens
- [x] Add scenario, rollback, migration, repository, and offline UI tests
- [x] Complete and record final verification

## POS-004-FIX

- [x] Add canonical Product base quantity scale and v5 migration
- [x] Centralize cart-option and checkout catalog integrity validation
- [x] Persist canonical scale through sale, movement, and sync snapshots
- [x] Replace floating-point UI money formatting with integer formatting
- [x] Add weighted, relationship, effective-price, formatting, and rollback tests
- [x] Complete final verification and submit for review
