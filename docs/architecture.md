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

The sync outbox, worker, business records, and synchronization contracts will be implemented in later tasks. Future synchronization must use client-generated UUIDs and idempotent operations. Sales, payments, and stock movements will be append-only; inventory will be derived from movements instead of synchronized by overwriting quantities.

