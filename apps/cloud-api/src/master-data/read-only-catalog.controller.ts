import { Controller, Get, Param, ParseEnumPipe, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { ReadOnlyQueryDto } from "./dto/read-only-query.dto";
import {
  ReadOnlyCatalogService,
  ReadOnlyKind,
} from "./read-only-catalog.service";

enum ReadOnlyKindParam {
  products = "products",
  productUnits = "productUnits",
  productPrices = "productPrices",
}

@ApiTags("catalog views")
@Controller("catalog-view")
export class ReadOnlyCatalogController {
  constructor(private readonly catalog: ReadOnlyCatalogService) {}

  @Get(":kind")
  list(
    @Param("kind", new ParseEnumPipe(ReadOnlyKindParam)) kind: ReadOnlyKind,
    @Query() query: ReadOnlyQueryDto,
  ) {
    return this.catalog.list(kind, query);
  }
}
