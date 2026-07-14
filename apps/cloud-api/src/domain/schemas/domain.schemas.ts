import { Schema } from "mongoose";
import {
  CURRENCY,
  CASH_MOVEMENT_TYPES,
  CASH_REASON_CODES,
  DEVICE_PLATFORMS,
  PAYMENT_METHODS,
  SALE_STATUSES,
  SHIFT_STATUSES,
  STOCK_MOVEMENT_TYPES,
  UNIT_CATEGORIES,
  UUID_PATTERN,
} from "../domain.constants";
import { hideInternal, syncableFields } from "./base.schema";
import { assertMovementDirection } from "../domain.validation";

const optionalUuid = { type: String, default: null, match: UUID_PATTERN };
const integer = (min?: number) => ({
  type: Number,
  required: true,
  min,
  validate: Number.isInteger,
});
const money = integer(0);
const options = { versionKey: false as const, toJSON: hideInternal };

export const BranchSchema = new Schema(
  {
    ...syncableFields,
    code: { type: String, required: true },
    name: { type: String, required: true },
    timezone: { type: String, default: "Asia/Bangkok" },
    currency: { type: String, enum: CURRENCY, default: "THB" },
    active: { type: Boolean, required: true },
    currentCatalogVersion: {
      type: Number,
      required: true,
      default: 0,
      min: 0,
      validate: Number.isInteger,
    },
  },
  options,
);
BranchSchema.index({ code: 1 }, { unique: true });

export const DeviceSchema = new Schema(
  {
    ...syncableFields,
    code: { type: String, required: true },
    name: { type: String, required: true },
    platform: { type: String, enum: DEVICE_PLATFORMS, required: true },
    appVersion: { type: String, required: true },
    lastSeenAt: Date,
    active: { type: Boolean, required: true },
  },
  options,
);
DeviceSchema.index({ branchId: 1, code: 1 }, { unique: true });

export const CategorySchema = new Schema(
  {
    ...syncableFields,
    name: { type: String, required: true },
    description: String,
    sortOrder: integer(0),
    active: { type: Boolean, required: true },
    catalogVersion: integer(1),
  },
  options,
);
CategorySchema.index({ branchId: 1, active: 1 });
CategorySchema.index({ branchId: 1, catalogVersion: 1, id: 1 });

export const ProductSchema = new Schema(
  {
    ...syncableFields,
    categoryId: optionalUuid,
    sku: String,
    name: { type: String, required: true },
    description: String,
    baseUnitId: optionalUuid,
    trackStock: { type: Boolean, required: true },
    baseQuantityScale: {
      type: Number,
      required: true,
      default: 1,
      min: 1,
      validate: Number.isInteger,
    },
    active: { type: Boolean, required: true },
    catalogVersion: integer(1),
  },
  options,
);
ProductSchema.index(
  { branchId: 1, sku: 1 },
  { unique: true, partialFilterExpression: { sku: { $type: "string" } } },
);
ProductSchema.index({ branchId: 1, catalogVersion: 1, id: 1 });
ProductSchema.pre(
  "validate",
  function (this: {
    trackStock: boolean;
    baseUnitId?: string | null;
    baseQuantityScale?: number;
  }) {
    if (this.trackStock && !this.baseUnitId)
      throw new Error("Stock-tracked products require baseUnitId");
    if (
      this.trackStock &&
      (!Number.isInteger(this.baseQuantityScale) ||
        this.baseQuantityScale! <= 0)
    )
      throw new Error(
        "Stock-tracked products require a positive baseQuantityScale",
      );
  },
);

export const ProductUnitSchema = new Schema(
  {
    ...syncableFields,
    productId: { type: String, required: true, match: UUID_PATTERN },
    code: { type: String, required: true },
    name: { type: String, required: true },
    unitCategory: { type: String, enum: UNIT_CATEGORIES, required: true },
    isBaseUnit: { type: Boolean, required: true },
    conversionNumerator: integer(1),
    conversionDenominator: integer(1),
    barcode: String,
    allowSale: { type: Boolean, required: true },
    allowPurchase: { type: Boolean, required: true },
    active: { type: Boolean, required: true },
    catalogVersion: integer(1),
  },
  options,
);
ProductUnitSchema.index(
  { branchId: 1, barcode: 1 },
  { unique: true, partialFilterExpression: { barcode: { $type: "string" } } },
);
ProductUnitSchema.index({ productId: 1 });
ProductUnitSchema.index({ productId: 1, active: 1 });
ProductUnitSchema.index({ branchId: 1, catalogVersion: 1, id: 1 });
ProductUnitSchema.index(
  { productId: 1, isBaseUnit: 1 },
  {
    unique: true,
    partialFilterExpression: { isBaseUnit: true, deletedAt: null },
  },
);
ProductUnitSchema.pre(
  "validate",
  function (this: {
    isBaseUnit: boolean;
    conversionNumerator: number;
    conversionDenominator: number;
  }) {
    if (
      this.isBaseUnit &&
      (this.conversionNumerator !== 1 || this.conversionDenominator !== 1)
    )
      throw new Error("Base unit conversion must be 1 / 1");
  },
);

export const ProductPriceSchema = new Schema(
  {
    ...syncableFields,
    productId: { type: String, required: true, match: UUID_PATTERN },
    productUnitId: { type: String, required: true, match: UUID_PATTERN },
    priceMinor: money,
    currency: { type: String, enum: CURRENCY, required: true },
    effectiveFrom: { type: Date, required: true },
    effectiveTo: Date,
    active: { type: Boolean, required: true },
    catalogVersion: integer(1),
  },
  options,
);
ProductPriceSchema.index({ productId: 1, productUnitId: 1 });
ProductPriceSchema.index({ branchId: 1, productUnitId: 1, effectiveFrom: 1 });
ProductPriceSchema.index({ branchId: 1, catalogVersion: 1, id: 1 });

export const ShiftSchema = new Schema(
  {
    ...syncableFields,
    deviceId: { type: String, required: true, match: UUID_PATTERN },
    openedByEmployeeId: String,
    closedByEmployeeId: String,
    status: { type: String, enum: SHIFT_STATUSES, required: true },
    openedAt: { type: Date, required: true },
    closedAt: Date,
    openingCashMinor: money,
    cashSalesMinor: money,
    cashInMinor: money,
    cashOutMinor: money,
    closingCashMinor: money,
    expectedCashMinor: money,
    cashDifferenceMinor: integer(),
    currency: { type: String, enum: CURRENCY, required: true },
  },
  options,
);

export const CashMovementSchema = new Schema(
  {
    id: { type: String, required: true, unique: true, match: UUID_PATTERN },
    branchId: { type: String, required: true, match: UUID_PATTERN },
    deviceId: { type: String, required: true, match: UUID_PATTERN },
    shiftId: { type: String, required: true, match: UUID_PATTERN },
    type: { type: String, enum: CASH_MOVEMENT_TYPES, required: true },
    amountMinor: money,
    currency: { type: String, enum: CURRENCY, required: true },
    reasonCode: { type: String, enum: CASH_REASON_CODES, required: true },
    note: String,
    occurredAt: { type: Date, required: true },
    createdAt: { type: Date, required: true },
    version: integer(1),
  },
  options,
);
CashMovementSchema.index({ branchId: 1, deviceId: 1 });
CashMovementSchema.index({ shiftId: 1, occurredAt: 1 });

export const SaleItemSchema = new Schema(
  {
    id: { type: String, required: true, match: UUID_PATTERN },
    saleId: { type: String, required: true, match: UUID_PATTERN },
    productId: { type: String, required: true, match: UUID_PATTERN },
    productUnitId: { type: String, required: true, match: UUID_PATTERN },
    productNameSnapshot: { type: String, required: true },
    skuSnapshot: String,
    unitCodeSnapshot: { type: String, required: true },
    unitNameSnapshot: { type: String, required: true },
    barcodeSnapshot: String,
    quantityMinor: integer(1),
    quantityScale: integer(1),
    conversionNumeratorSnapshot: integer(1),
    conversionDenominatorSnapshot: integer(1),
    baseQuantityMinor: integer(1),
    baseQuantityScale: integer(1),
    unitPriceMinor: money,
    subtotalMinor: money,
    discountMinor: money,
    taxMinor: money,
    totalMinor: money,
    createdAt: { type: Date, required: true },
  },
  { _id: false, versionKey: false },
);
export const PaymentSchema = new Schema(
  {
    id: { type: String, required: true, match: UUID_PATTERN },
    saleId: { type: String, required: true, match: UUID_PATTERN },
    branchId: { type: String, required: true, match: UUID_PATTERN },
    deviceId: { type: String, required: true, match: UUID_PATTERN },
    method: { type: String, enum: PAYMENT_METHODS, required: true },
    amountMinor: money,
    currency: { type: String, enum: CURRENCY, required: true },
    reference: String,
    paidAt: { type: Date, required: true },
    createdAt: { type: Date, required: true },
  },
  { _id: false, versionKey: false },
);
export const SaleSchema = new Schema(
  {
    ...syncableFields,
    deviceId: { type: String, required: true, match: UUID_PATTERN },
    shiftId: { type: String, required: true, match: UUID_PATTERN },
    receiptNumber: { type: String, required: true },
    status: { type: String, enum: SALE_STATUSES, required: true },
    currency: { type: String, enum: CURRENCY, required: true },
    subtotalMinor: money,
    discountMinor: money,
    taxMinor: money,
    totalMinor: money,
    paidMinor: money,
    changeMinor: money,
    itemCount: integer(0),
    soldAt: { type: Date, required: true },
    voidedAt: Date,
    voidReason: String,
    items: { type: [SaleItemSchema], required: true },
    payments: { type: [PaymentSchema], required: true },
  },
  options,
);
SaleSchema.index({ branchId: 1, receiptNumber: 1 }, { unique: true });

export const StockMovementSchema = new Schema(
  {
    id: { type: String, required: true, unique: true, match: UUID_PATTERN },
    branchId: { type: String, required: true, match: UUID_PATTERN },
    deviceId: { type: String, required: true, match: UUID_PATTERN },
    productId: { type: String, required: true, match: UUID_PATTERN },
    type: { type: String, enum: STOCK_MOVEMENT_TYPES, required: true },
    sourceUnitId: { type: String, required: true, match: UUID_PATTERN },
    sourceUnitCodeSnapshot: { type: String, required: true },
    sourceUnitNameSnapshot: { type: String, required: true },
    sourceQuantityMinor: integer(1),
    sourceQuantityScale: integer(1),
    conversionNumeratorSnapshot: integer(1),
    conversionDenominatorSnapshot: integer(1),
    baseQuantityMinor: integer(),
    baseQuantityScale: integer(1),
    referenceType: { type: String, required: true },
    referenceId: { type: String, required: true },
    occurredAt: { type: Date, required: true },
    note: String,
    createdAt: { type: Date, required: true },
    version: integer(1),
  },
  options,
);
StockMovementSchema.index({ branchId: 1, productId: 1, occurredAt: 1 });
StockMovementSchema.pre(
  "validate",
  function (this: { type: string; baseQuantityMinor: number }) {
    assertMovementDirection(this.type, this.baseQuantityMinor);
  },
);
