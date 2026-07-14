import { BadRequestException } from "@nestjs/common";
import { NEGATIVE_MOVEMENTS, POSITIVE_MOVEMENTS } from "./domain.constants";

export function assertPositiveInteger(value: number, field: string): void {
  if (!Number.isInteger(value) || value <= 0)
    throw new BadRequestException(`${field} must be a positive integer`);
}
export function assertNonNegativeMoney(value: number, field: string): void {
  if (!Number.isInteger(value) || value < 0)
    throw new BadRequestException(
      `${field} must be a non-negative integer minor-unit value`,
    );
}
export function convertToBaseMinor(
  quantityMinor: number,
  quantityScale: number,
  conversionNumerator: number,
  conversionDenominator: number,
  baseQuantityScale: number,
): number {
  assertPositiveInteger(quantityMinor, "quantityMinor");
  assertPositiveInteger(quantityScale, "quantityScale");
  assertPositiveInteger(conversionNumerator, "conversionNumerator");
  assertPositiveInteger(conversionDenominator, "conversionDenominator");
  assertPositiveInteger(baseQuantityScale, "baseQuantityScale");
  const quantityAndConversion = quantityMinor * conversionNumerator;
  const dividend = quantityAndConversion * baseQuantityScale;
  const divisor = quantityScale * conversionDenominator;
  if (
    !Number.isSafeInteger(quantityAndConversion) ||
    !Number.isSafeInteger(dividend) ||
    !Number.isSafeInteger(divisor)
  )
    throw new BadRequestException("Conversion exceeds the safe integer range");
  if (dividend % divisor !== 0)
    throw new BadRequestException(
      "Conversion result cannot be represented exactly",
    );
  return dividend / divisor;
}
export function assertMovementDirection(
  type: string,
  baseQuantityMinor: number,
): void {
  if (!Number.isInteger(baseQuantityMinor) || baseQuantityMinor === 0)
    throw new BadRequestException(
      "baseQuantityMinor must be a non-zero integer",
    );
  if (
    (POSITIVE_MOVEMENTS.has(type) && baseQuantityMinor < 0) ||
    (NEGATIVE_MOVEMENTS.has(type) && baseQuantityMinor > 0)
  )
    throw new BadRequestException(`Invalid direction for ${type}`);
}
export function assertExactlyOneBaseUnit(
  units: ReadonlyArray<{
    isBaseUnit: boolean;
    conversionNumerator: number;
    conversionDenominator: number;
  }>,
): void {
  const bases = units.filter((unit) => unit.isBaseUnit);
  if (bases.length !== 1)
    throw new BadRequestException("A product must have exactly one base unit");
  if (
    bases[0].conversionNumerator !== 1 ||
    bases[0].conversionDenominator !== 1
  )
    throw new BadRequestException("The base unit conversion must be 1 / 1");
}
export function assertProductUnitBelongsToProduct(
  productId: string,
  unit: { productId: string },
): void {
  if (unit.productId !== productId)
    throw new BadRequestException("ProductUnit must belong to Product");
}
export function assertPriceUnitRelationship(
  productId: string,
  unit: { productId: string },
): void {
  if (unit.productId !== productId)
    throw new BadRequestException(
      "ProductPrice ProductUnit belongs to another product",
    );
}
