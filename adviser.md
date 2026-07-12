# Auice POS Engineering Rules

## Architecture

- The POS is local-first.
- A sale must never depend on cloud availability.
- SQLite is the source of truth for an active local transaction.
- MongoDB is the consolidated cloud data store.
- Every sync operation must be idempotent.
- Every locally created record must use a client-generated UUID.
- Sales, payments, and stock movements are append-only.
- Never synchronize inventory by overwriting stock quantity.
- Deletion must use soft delete unless explicitly approved.
- Do not change the approved architecture without review.

## Development

- Do not add dependencies without explaining their purpose.
- Every database structure change requires a migration or documented migration strategy.
- Every business rule must have automated tests.
- Keep tasks focused and avoid unrelated refactoring.
- Never silently ignore synchronization errors.
- Never commit credentials or real environment files.
- Validate all API input.
- Use UTC timestamps internally.
- Monetary values must not use floating-point arithmetic in future POS modules.

## Delivery

After completing a task, report:

1. Summary
2. Files changed
3. Dependencies added
4. Configuration changes
5. Tests performed
6. Test results
7. Known limitations
8. Risks
9. Manual verification steps

