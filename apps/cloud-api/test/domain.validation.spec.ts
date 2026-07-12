import { assertExactlyOneBaseUnit, assertMovementDirection, assertNonNegativeMoney, assertPriceUnitRelationship, assertProductUnitBelongsToProduct, convertToBaseMinor } from '../src/domain/domain.validation';
describe('integer domain rules', () => {
  it('converts beer and snack packages exactly', () => {
    expect(convertToBaseMinor(10, 12, 1)).toBe(120); expect(convertToBaseMinor(2, 12, 1)).toBe(24);
    expect(convertToBaseMinor(5, 24, 1)).toBe(120); expect(convertToBaseMinor(2, 6, 1)).toBe(12);
  });
  it('rejects non-exact, zero, negative and decimal conversions', () => {
    expect(() => convertToBaseMinor(1, 1, 2)).toThrow('exactly'); expect(() => convertToBaseMinor(1, 1, 0)).toThrow();
    expect(() => convertToBaseMinor(1, -1, 1)).toThrow(); expect(() => convertToBaseMinor(1.5, 1, 1)).toThrow();
  });
  it('validates stock direction', () => {
    expect(() => assertMovementDirection('purchase', 120)).not.toThrow(); expect(() => assertMovementDirection('sale', -3)).not.toThrow();
    expect(() => assertMovementDirection('sale', 3)).toThrow(); expect(() => assertMovementDirection('purchase', -3)).toThrow();
  });
  it('requires exactly one 1/1 base unit', () => {
    expect(() => assertExactlyOneBaseUnit([])).toThrow(); expect(() => assertExactlyOneBaseUnit([{ isBaseUnit: true, conversionNumerator: 1, conversionDenominator: 1 }, { isBaseUnit: true, conversionNumerator: 1, conversionDenominator: 1 }])).toThrow();
    expect(() => assertExactlyOneBaseUnit([{ isBaseUnit: true, conversionNumerator: 12, conversionDenominator: 1 }])).toThrow();
  });
  it('rejects decimal and negative money', () => { expect(() => assertNonNegativeMoney(65.5, 'priceMinor')).toThrow(); expect(() => assertNonNegativeMoney(-1, 'priceMinor')).toThrow(); });
  it('rejects unrelated product units and prices', () => { expect(() => assertProductUnitBelongsToProduct('a', { productId: 'b' })).toThrow(); expect(() => assertPriceUnitRelationship('a', { productId: 'b' })).toThrow(); });
});
