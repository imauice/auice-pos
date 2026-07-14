# Auice POS

Auice POS is a local-first point-of-sale platform with a Flutter store application, NestJS cloud API, Vue cloud website, MongoDB consolidation store, and Valkey development service. A local sale must never depend on cloud availability: SQLite will remain authoritative for active local transactions and future synchronization will be idempotent and append-only.

## Repository structure

```text
apps/cloud-api       NestJS API and MongoDB health
apps/cloud-web       Vue cloud status website
apps/local-pos       Flutter local POS foundation
packages/            Reserved API and sync contracts
infrastructure/      Development infrastructure notes
docs/                Architecture and local-first documentation
```

## Prerequisites

- Node.js 24 and npm
- Flutter SDK
- Docker with Compose

## Installation and startup

Install JavaScript dependencies from the root with `npm install`. Install Flutter dependencies with `cd apps/local-pos && flutter pub get`, then generate Drift code using `dart run build_runner build --delete-conflicting-outputs`.

Start services from the root with `docker compose up -d`. Run the API with `cd apps/cloud-api && npm run start:dev`, and the website with `cd apps/cloud-web && npm run dev`. Run the POS with `cd apps/local-pos && flutter run`. Override its API location when needed with `flutter run --dart-define=API_BASE_URL=http://HOST:3000/api` (Android emulators commonly use host `10.0.2.2`).

The API health endpoint is `GET http://localhost:3000/api/health`; Swagger is at `http://localhost:3000/api/docs`. Sync protocol v1 accepts validated, idempotent event batches at `POST http://localhost:3000/api/sync/push`. Nest's default 100 KB JSON body limit and a 100-event batch limit protect the endpoint. The website reads `VITE_API_BASE_URL`, while the API reads the values documented in its `.env.example`.

POS-003 adds `GET /api/branches`, `GET /api/branches/:id`, `POST /api/device/register`, snapshot-paginated `GET /api/catalog`, and branch-scoped paginated read-only views under `GET /api/catalog-view/:kind` and `GET /api/device`. Flutter configuration also supports `BRANCH_CODE`, `DEVICE_NAME`, `DEVICE_PLATFORM`, and `APP_VERSION` through `--dart-define`. Startup makes the local catalog usable first, then registers and resumes catalog synchronization when online. A first run without a catalog and network reports setup-required instead of sale readiness.

## Development workflow

Keep work task-focused, add migrations for database changes, validate inputs, use UTC internally, and add automated tests for business rules. Run lint, tests, builds, Flutter analysis, and Compose validation before delivery. Never commit real `.env` files or credentials.

## Known limitations

POS-002 defines product, sale, payment, shift, stock-movement, multi-unit packaging, and sync persistence contracts but no workflows or UI. The local outbox is not connected to business transactions and has no worker. Sync push records events but does not apply payloads to domain collections. Authentication, pull sync, conflict resolution, stock aggregation, purchasing workflows, and production deployment remain absent.
