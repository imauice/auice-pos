# Architecture

Auice POS has three applications. The **Local Flutter POS** owns the active checkout experience and persists locally in SQLite. The **NestJS Cloud API** exposes validated HTTP endpoints and consolidates synchronized data in MongoDB. The **Vue Cloud Website** consumes that API for cloud operations. Valkey is provisioned for future transient coordination and caching; it is not in the sale path and is unused by POS-001.

```text
Flutter UI
   ↓
Local Application Service
   ↓
SQLite Transaction
   ├── Business Record
   └── Future Sync Outbox
             ↓
       Sync Worker
             ↓
        NestJS API
             ↓
          MongoDB
```

POS-002 defines synchronization contracts and implements the standalone outbox/event-log persistence foundations. Business tables, transaction-to-outbox integration, and the worker remain for later tasks. Synchronization uses client-generated UUIDs and idempotent operations. Sales, payments, and stock movements are append-only; inventory will be derived from movements instead of synchronized by overwriting quantities.

POS-002 implements the outbox and cloud event-log foundations plus protocol contracts, but not transaction integration or a worker:

```text
Business Transaction
   ↓
SQLite Transaction
   ├── Domain Record
   └── Sync Outbox Event
             ↓
      Future Sync Worker
             ↓
       POST /api/sync/push
             ↓
      Cloud Sync Event Log
             ↓
 Future Domain Event Application
```

Products have exactly one inventory base unit. Configurable ProductUnits convert directly to it using positive integer rationals. Unit prices are independent, and sale/movement history snapshots unit and conversion data.

POS-003 master-data flow:

```text
Cloud Master Data
   ↓
Snapshot Catalog API
   ↓
Transactional SQLite Import
   ↓
Local Search and Barcode Lookup
   ↓
Ready for Sale (sale workflow remains future work)
```

The first pull freezes `targetVersion`; keyset cursors carry the from/target versions and last `(catalogVersion, entityType, id)`. Later cloud mutations wait for the next pull. A master-data mutation normally increments the branch and writes the record in one MongoDB session transaction. Standalone MongoDB cannot transact: the documented fallback increments then writes, and any gap is recovered by reissuing the mutation with a new catalog version; production should use a replica set.

Branch endpoints intentionally omit `currentCatalogVersion`; registration and catalog responses expose the synchronization versions. Device metadata changes increment Device.version, while heartbeat-only repeat registration does not. Devices cannot move branches through registration.

POS-004 offline sale flow:

```text
Search Local Catalog
      ↓
Build Cart
      ↓
Validate Cash Payment
      ↓
Single SQLite Transaction
      ├── Sale
      ├── SaleItems
      ├── Payment
      ├── StockMovements
      └── SyncOutbox
      ↓
Receipt Available Immediately
      ↓
Future Cloud Sync
```

Cart prices and names are snapshots: later catalog imports cannot rewrite a completed receipt or silently change an existing cart line. `itemCount` is the number of distinct cart lines, not a sum of units or base quantity. Stock is represented only by signed append-only movements; a sale creates one negative-base movement for each stock-tracked line.

POS-005 shift flow:

```text
Open Shift
    ↓
Offline Sales and Cash Movements
    ↓
Calculate Expected Cash
    ↓
Count Actual Cash
    ↓
Close Shift Atomically
    ↓
Future Cloud Sync
```

SQLite enforces one open shift per device with a partial unique index in addition to the service guard. Opening, cash movement, and closing each pair their domain write with an outbox event in one transaction. SQLite serializes writes on the connection; closing calculates its summary and conditionally changes `status = open` within the same transaction, so a competing sale or close cannot leave a partially reconciled shift.

Open summaries are derived from completed local sales, cash payments, and append-only cash movements. A cash sale contributes tender minus change. Closing persists sales count, cash-sales count, gross sales, `cashSalesMinor`, `cashInMinor`, `cashOutMinor`, `expectedCashMinor`, closing cash, and difference; closed summaries return only these reconciliation snapshots. A shift is pending sync when its shift event or any related sale, cash movement, or sale stock-movement event is pending or processing. Cancellation, refunds, Cloud event application, and background synchronization remain deferred.
