import { Module } from "@nestjs/common";
import { DomainModule } from "../domain/domain.module";
import { BranchController } from "./branch.controller";
import { BranchService } from "./branch.service";
import { CatalogController } from "./catalog.controller";
import { CatalogService } from "./catalog.service";
import { DeviceController } from "./device.controller";
import { DeviceService } from "./device.service";
import { MasterDataWriteService } from "./master-data-write.service";
import { ReadOnlyCatalogController } from "./read-only-catalog.controller";
import { ReadOnlyCatalogService } from "./read-only-catalog.service";
@Module({
  imports: [DomainModule],
  controllers: [
    BranchController,
    DeviceController,
    CatalogController,
    ReadOnlyCatalogController,
  ],
  providers: [
    BranchService,
    DeviceService,
    CatalogService,
    MasterDataWriteService,
    ReadOnlyCatalogService,
  ],
  exports: [MasterDataWriteService],
})
export class MasterDataModule {}
