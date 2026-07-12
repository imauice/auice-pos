export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[4-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export const CURRENCY = ['THB'] as const;
export const DEVICE_PLATFORMS = ['android', 'windows', 'ios', 'macos', 'linux', 'unknown'] as const;
export const UNIT_CATEGORIES = ['count', 'weight', 'volume', 'length', 'service', 'other'] as const;
export const SALE_STATUSES = ['completed', 'voided', 'refunded'] as const;
export const SHIFT_STATUSES = ['open', 'closed', 'cancelled'] as const;
export const PAYMENT_METHODS = ['cash', 'qr', 'card', 'bank_transfer', 'other'] as const;
export const STOCK_MOVEMENT_TYPES = ['opening', 'purchase', 'sale', 'sale_void', 'return', 'adjustment_in', 'adjustment_out', 'transfer_in', 'transfer_out', 'waste'] as const;
export const POSITIVE_MOVEMENTS = new Set(['opening', 'purchase', 'sale_void', 'return', 'adjustment_in', 'transfer_in']);
export const NEGATIVE_MOVEMENTS = new Set(['sale', 'adjustment_out', 'transfer_out', 'waste']);

