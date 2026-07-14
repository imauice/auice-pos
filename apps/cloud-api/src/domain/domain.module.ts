import { Module } from "@nestjs/common";
import { MongooseModule } from "@nestjs/mongoose";
import {
  BranchSchema,
  CashMovementSchema,
  CategorySchema,
  DeviceSchema,
  ProductPriceSchema,
  ProductSchema,
  ProductUnitSchema,
  SaleSchema,
  ShiftSchema,
  StockMovementSchema,
} from "./schemas/domain.schemas";
import { ProductRulesService } from "./product-rules.service";
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: "Branch", schema: BranchSchema },
      { name: "Device", schema: DeviceSchema },
      { name: "Category", schema: CategorySchema },
      { name: "Product", schema: ProductSchema },
      { name: "ProductUnit", schema: ProductUnitSchema },
      { name: "ProductPrice", schema: ProductPriceSchema },
      { name: "Shift", schema: ShiftSchema },
      { name: "CashMovement", schema: CashMovementSchema },
      { name: "Sale", schema: SaleSchema },
      { name: "StockMovement", schema: StockMovementSchema },
    ]),
  ],
  providers: [ProductRulesService],
  exports: [ProductRulesService, MongooseModule],
})
export class DomainModule {}
