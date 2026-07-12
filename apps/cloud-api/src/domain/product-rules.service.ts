import { Injectable } from '@nestjs/common';
import { assertExactlyOneBaseUnit, assertPriceUnitRelationship, assertProductUnitBelongsToProduct } from './domain.validation';
interface ProductUnitRuleView { productId: string; isBaseUnit: boolean; active: boolean; conversionNumerator: number; conversionDenominator: number }
@Injectable()
export class ProductRulesService {
  validateProduct(trackStock: boolean, baseUnitId: string | null | undefined): void {
    if (trackStock && !baseUnitId) throw new Error('Stock-tracked products require baseUnitId');
  }
  validateUnits(productId: string, baseUnitId: string, units: ReadonlyArray<ProductUnitRuleView & { id: string }>): void {
    units.forEach((unit) => assertProductUnitBelongsToProduct(productId, unit));
    assertExactlyOneBaseUnit(units);
    if (!units.some((unit) => unit.id === baseUnitId && unit.isBaseUnit && unit.active)) throw new Error('Product.baseUnitId must reference its active base ProductUnit');
  }
  validatePrice(productId: string, unit: ProductUnitRuleView): void { assertPriceUnitRelationship(productId, unit); }
}
