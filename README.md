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

The API health endpoint is `GET http://localhost:3000/api/health`; Swagger is at `http://localhost:3000/docs`. The website reads `VITE_API_BASE_URL`, while the API reads the values documented in its `.env.example`.

## Development workflow

Keep work task-focused, add migrations for database changes, validate inputs, use UTC internally, and add automated tests for business rules. Run lint, tests, builds, Flutter analysis, and Compose validation before delivery. Never commit real `.env` files or credentials.

## Known limitations

POS-001 contains no authentication, products, sales, payments, stock, shifts, sync outbox, sync worker, or production deployment configuration. Valkey is provisioned but not used. The health endpoint reports unavailable MongoDB meaningfully while retaining HTTP availability.

