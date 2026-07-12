import { ProductUnitSchema } from '../src/domain/schemas/domain.schemas';
describe('ProductUnit persistence constraints', () => {
  it('defines a unique partial branch barcode index', () => {
    const barcode = ProductUnitSchema.indexes().find(([fields]) => fields.branchId === 1 && fields.barcode === 1);
    expect(barcode?.[1]).toMatchObject({ unique: true, partialFilterExpression: { barcode: { $type: 'string' } } });
  });
  it('defines one active base-unit index per product', () => {
    const base = ProductUnitSchema.indexes().find(([fields]) => fields.productId === 1 && fields.isBaseUnit === 1);
    expect(base?.[1]).toMatchObject({ unique: true, partialFilterExpression: { isBaseUnit: true, deletedAt: null } });
  });
});
