import {
  ProductSchema,
  ProductUnitSchema,
  CashMovementSchema,
  ShiftSchema,
  StockMovementSchema,
} from "../src/domain/schemas/domain.schemas";
import { model } from "mongoose";

const CashMovementModel = model(
  "CashMovementSchemaSpec",
  CashMovementSchema.clone(),
);
const ProductModel = model("InventoryProductSchemaSpec", ProductSchema.clone());
describe("ProductUnit persistence constraints", () => {
  it("defines a unique partial branch barcode index", () => {
    const barcode = ProductUnitSchema.indexes().find(
      ([fields]) => fields.branchId === 1 && fields.barcode === 1,
    );
    expect(barcode?.[1]).toMatchObject({
      unique: true,
      partialFilterExpression: { barcode: { $type: "string" } },
    });
  });
  it("defines one active base-unit index per product", () => {
    const base = ProductUnitSchema.indexes().find(
      ([fields]) => fields.productId === 1 && fields.isBaseUnit === 1,
    );
    expect(base?.[1]).toMatchObject({
      unique: true,
      partialFilterExpression: { isBaseUnit: true, deletedAt: null },
    });
  });
});
describe("Shift and cash movement persistence", () => {
  it("defines persisted shift cash snapshots", () => {
    expect(ShiftSchema.path("cashSalesMinor")).toBeDefined();
    expect(ShiftSchema.path("cashInMinor")).toBeDefined();
    expect(ShiftSchema.path("cashOutMinor")).toBeDefined();
    expect(ShiftSchema.path("salesCount")).toBeDefined();
    expect(ShiftSchema.path("cashSalesCount")).toBeDefined();
    expect(ShiftSchema.path("grossSalesMinor")).toBeDefined();
  });
  it("constrains cash movement type, reason, and amount", () => {
    expect(CashMovementSchema.path("type").options.enum).toEqual([
      "cash_in",
      "cash_out",
    ]);
    expect(CashMovementSchema.path("amountMinor").options.min).toBe(1);
    expect(CashMovementSchema.path("reasonCode").options.required).toBe(true);
  });
  it.each([
    [0, false],
    [-1, false],
    [1.5, false],
    [1, true],
  ])("validates amountMinor %s", (amountMinor, valid) => {
    const document = new CashMovementModel({
      id: "018f4c3a-7a11-7abc-8abc-1234567890ab",
      branchId: "018f4c3a-7a11-7abc-8abc-1234567890ac",
      deviceId: "018f4c3a-7a11-7abc-8abc-1234567890ad",
      shiftId: "018f4c3a-7a11-7abc-8abc-1234567890ae",
      type: "cash_in",
      amountMinor,
      currency: "THB",
      reasonCode: "other",
      occurredAt: new Date(),
      createdAt: new Date(),
      version: 1,
    });
    expect(document.validateSync() == null).toBe(valid);
  });
});
describe("Product canonical stock scale", () => {
  it("defaults baseQuantityScale to one and rejects non-positive scales", () => {
    const path = ProductSchema.path("baseQuantityScale");
    expect(path.options).toMatchObject({ required: true, default: 1, min: 1 });
  });
  it("defines optional integer low-stock thresholds", () => {
    expect(ProductSchema.path("lowStockThresholdMinor").options.min).toBe(0);
    expect(ProductSchema.path("lowStockThresholdScale").options.min).toBe(1);
  });
  it("requires low-stock threshold to use the canonical scale", async () => {
    const document = new ProductModel({
      id: "018f4c3a-7a11-7abc-8abc-1234567890ab",
      branchId: "018f4c3a-7a11-7abc-8abc-1234567890ac",
      name: "Fabric",
      baseUnitId: "018f4c3a-7a11-7abc-8abc-1234567890ad",
      trackStock: true,
      baseQuantityScale: 1000,
      lowStockThresholdMinor: 5000,
      lowStockThresholdScale: 1,
      active: true,
      catalogVersion: 1,
      createdAt: new Date(),
      updatedAt: new Date(),
      version: 1,
    });
    await expect(document.validate()).rejects.toThrow(
      "Low-stock threshold must use the canonical scale",
    );
  });
  it("defines inventory adjustment reasons on stock movements", () => {
    expect(StockMovementSchema.path("reasonCode").options.enum).toContain(
      "physical_count",
    );
  });
});
