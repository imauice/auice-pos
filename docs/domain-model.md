# Core domain model

Syncable entities use a public domain UUID, branch UUID, UTC creation/update timestamps, integer version, and nullable soft-delete timestamp. Transactional records also retain their originating device. Money is integer satang in THB. Quantities and rational conversions are integers only.

The model includes Branch, Device, Category, Product, ProductUnit, ProductPrice, Shift, Sale with embedded SaleItem and Payment snapshots, append-only StockMovement, and SyncEvent. Products never store a current stock quantity.

## Multi-unit examples

Beer A has Bottle as its 1/1 base unit with its own barcode and 65 THB price. Case converts directly at 12/1, has a separate barcode, and costs 720 THB. Receiving 10 cases records +120 bottles; selling 3 bottles records −3; selling 2 cases records −24. The derived remaining stock would be `120 - 3 - 24 = 93 bottles`, although balance aggregation is not implemented.

Snack A uses Small bag as base. Large bag is 6/1 and Box is 24/1. Receiving 5 boxes records +120 small bags; selling 2 large bags records −12; selling 3 small bags records −3.

Product service validation must verify Product.baseUnitId belongs to the same product, exactly one active base exists, and its conversion is 1/1. ProductPrice must reference a unit of the same product. MongoDB’s partial unique base-unit and branch-barcode indexes provide additional enforcement. Historical sale and movement snapshots never consult mutable current unit data.

