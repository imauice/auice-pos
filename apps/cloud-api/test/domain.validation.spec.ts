import {
  assertExactlyOneBaseUnit,
  assertMovementDirection,
  assertNonNegativeMoney,
  assertPriceUnitRelationship,
  assertProductUnitBelongsToProduct,
  convertToBaseMinor,
} from "../src/domain/domain.validation";
import { ProductRulesService } from "../src/domain/product-rules.service";
describe("integer domain rules", () => {
  it("converts scaled weights and packages exactly", () => {
    expect(convertToBaseMinor(1500, 1000, 1000, 1, 1)).toBe(1500);
    expect(convertToBaseMinor(2, 1, 12, 1, 1)).toBe(24);
    expect(convertToBaseMinor(2, 1, 6, 1, 1)).toBe(12);
    expect(convertToBaseMinor(1, 1, 2500, 1000, 1000)).toBe(2500);
  });
  it("rejects non-exact and invalid conversions", () => {
    expect(() => convertToBaseMinor(1, 1, 1, 2, 1)).toThrow("exactly");
    expect(() => convertToBaseMinor(1, 1, 1, 0, 1)).toThrow();
    expect(() => convertToBaseMinor(1, 1, -1, 1, 1)).toThrow();
    expect(() => convertToBaseMinor(1.5, 1, 1, 1, 1)).toThrow();
  });
  it("rejects unsafe integer overflow", () =>
    expect(() =>
      convertToBaseMinor(Number.MAX_SAFE_INTEGER, 1, 2, 1, 1),
    ).toThrow("safe integer"));
  it("validates stock direction", () => {
    expect(() => assertMovementDirection("purchase", 120)).not.toThrow();
    expect(() => assertMovementDirection("sale", -3)).not.toThrow();
    expect(() => assertMovementDirection("sale", 3)).toThrow();
    expect(() => assertMovementDirection("purchase", -3)).toThrow();
  });
  it("requires exactly one 1/1 base unit", () => {
    expect(() => assertExactlyOneBaseUnit([])).toThrow();
    expect(() =>
      assertExactlyOneBaseUnit([
        { isBaseUnit: true, conversionNumerator: 1, conversionDenominator: 1 },
        { isBaseUnit: true, conversionNumerator: 1, conversionDenominator: 1 },
      ]),
    ).toThrow();
    expect(() =>
      assertExactlyOneBaseUnit([
        { isBaseUnit: true, conversionNumerator: 12, conversionDenominator: 1 },
      ]),
    ).toThrow();
  });
  it("rejects decimal and negative money", () => {
    expect(() => assertNonNegativeMoney(65.5, "priceMinor")).toThrow();
    expect(() => assertNonNegativeMoney(-1, "priceMinor")).toThrow();
  });
  it("rejects unrelated product units and prices", () => {
    expect(() =>
      assertProductUnitBelongsToProduct("a", { productId: "b" }),
    ).toThrow();
    expect(() =>
      assertPriceUnitRelationship("a", { productId: "b" }),
    ).toThrow();
  });
  it("requires baseUnitId for stock-tracked products", () => {
    const rules = new ProductRulesService();
    expect(() => rules.validateProduct(true, null)).toThrow("baseUnitId");
    expect(() => rules.validateProduct(false, null)).not.toThrow();
    expect(() => rules.validateProduct(true, "unit-id")).not.toThrow();
  });
  it("requires a positive canonical scale for stock-tracked products", () => {
    const rules = new ProductRulesService();
    expect(() => rules.validateProduct(true, "unit-id", 1000)).not.toThrow();
    expect(() => rules.validateProduct(true, "unit-id", 0)).toThrow(
      "baseQuantityScale",
    );
    expect(() => rules.validateProduct(true, "unit-id", 1.5)).toThrow(
      "baseQuantityScale",
    );
  });
  it("requires baseUnitId to reference the active base unit of the product", () => {
    const rules = new ProductRulesService();
    const unit = {
      id: "base",
      productId: "product",
      isBaseUnit: true,
      active: true,
      conversionNumerator: 1,
      conversionDenominator: 1,
    };
    expect(() => rules.validateUnits("product", "base", [unit])).not.toThrow();
    expect(() => rules.validateUnits("product", "other", [unit])).toThrow(
      "active base",
    );
    expect(() =>
      rules.validateUnits("product", "base", [{ ...unit, active: false }]),
    ).toThrow("active base");
    expect(() => rules.validateUnits("other-product", "base", [unit])).toThrow(
      "belong",
    );
  });
});
