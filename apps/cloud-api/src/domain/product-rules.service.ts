import { Injectable } from '@nestjs/common';
import { assertExactlyOneBaseUnit, assertPriceUnitRelationship, assertProductUnitBelongsToProduct } from './domain.validation';
interface ProductUnitRuleView { productId: string; isBaseUnit: boolean; conversionNumerator: number; conversionDenominator: number }
@Injectable()
export class ProductRulesService {
  validateUnits(productId: string, baseUnitId: string, units: ReadonlyArray<ProductUnitRuleView & { id: string }>): void {
    units.forEach((unit) => assertProductUnitBelongsToProduct(productId, unit));
    assertExactlyOneBaseUnit(units);
    if (!units.some((unit) => unit.id === baseUnitId && unit.isBaseUnit)) throw new Error('Product.baseUnitId must reference its base ProductUnit');
  }
  validatePrice(productId: string, unit: ProductUnitRuleView): void { assertPriceUnitRelationship(productId, unit); }
}
