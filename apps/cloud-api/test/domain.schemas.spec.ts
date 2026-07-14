import {
  ProductSchema,
  ProductUnitSchema,
  CashMovementSchema,
  ShiftSchema,
} from "../src/domain/schemas/domain.schemas";
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
  });
  it("constrains cash movement type, reason, and amount", () => {
    expect(CashMovementSchema.path("type").options.enum).toEqual([
      "cash_in",
      "cash_out",
    ]);
    expect(CashMovementSchema.path("amountMinor").options.min).toBe(0);
    expect(CashMovementSchema.path("reasonCode").options.required).toBe(true);
  });
});
describe("Product canonical stock scale", () => {
  it("defaults baseQuantityScale to one and rejects non-positive scales", () => {
    const path = ProductSchema.path("baseQuantityScale");
    expect(path.options).toMatchObject({ required: true, default: 1, min: 1 });
  });
});
