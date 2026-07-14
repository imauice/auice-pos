# API Contracts

The canonical machine-readable contract is [`openapi.yaml`](openapi.yaml). Runtime Swagger is generated from NestJS decorators at `/api/docs`. TypeScript and Dart models intentionally remain separate so neither runtime is coupled to the other’s generator.

Catalog Product records include positive integer `baseQuantityScale`. Stock-tracked products require it, and catalog pull responses carry it unchanged so every client represents that product's base-unit movements at one canonical scale. Existing count-based products migrate to `1`.
