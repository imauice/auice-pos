# Auice POS Roadmap

- **M0 Foundation** — Monorepo, development services, health checks, and local database startup.
- **M1 Product and Device Sync** — POS-003 implements branch/device registration and snapshot-paginated cloud-to-local catalog synchronization; operational CRUD and background polling remain future work.
- **M2 Offline Sale** — POS-004 implements the local cart, cash payment, atomic sale/stock/outbox transaction, and offline receipts; refunds and advanced tenders remain future work.
- **M3 Cloud Synchronization** — Idempotent outbox processing, retries, conflict rules, and observability.
- **M4 Shift and Cash Management** — POS-005 implements offline shift opening, cash movements, expected-cash reconciliation, closing snapshots, and history; cloud event application remains future work.
- **M5 Stock Movement** — Append-only inventory movements and derived stock balances.
- **M6 Reports and Operations** — Operational reports, monitoring, support tools, and hardening.
