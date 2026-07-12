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
