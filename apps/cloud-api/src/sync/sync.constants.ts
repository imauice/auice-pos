export const SYNC_PROTOCOL_VERSION = 1;
export const MAX_SYNC_BATCH_SIZE = 100;
export const SYNC_ENTITY_TYPES = [
  "branch",
  "device",
  "category",
  "product",
  "product_unit",
  "product_price",
  "shift",
  "sale",
  "stock_movement",
  "cash_movement",
] as const;
export const SYNC_OPERATIONS = [
  "create",
  "update",
  "delete",
  "append",
] as const;
export const SYNC_ERROR_CODES = [
  "VALIDATION_ERROR",
  "UNSUPPORTED_PROTOCOL_VERSION",
  "UNKNOWN_ENTITY_TYPE",
  "VERSION_CONFLICT",
  "BRANCH_MISMATCH",
  "DEVICE_INACTIVE",
  "DUPLICATE_EVENT",
  "IDEMPOTENCY_CONFLICT",
  "INTERNAL_ERROR",
] as const;
