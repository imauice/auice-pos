import { BadRequestException, Injectable } from "@nestjs/common";
import { InjectModel } from "@nestjs/mongoose";
import { Model } from "mongoose";
import { CatalogRecord } from "./catalog.service";
import { ReadOnlyQueryDto } from "./dto/read-only-query.dto";

export type ReadOnlyKind = "products" | "productUnits" | "productPrices";

interface ReadCursor {
  branchId: string;
  kind: ReadOnlyKind;
  lastId: string;
}

@Injectable()
export class ReadOnlyCatalogService {
  constructor(
    @InjectModel("Product") private readonly products: Model<CatalogRecord>,
    @InjectModel("ProductUnit") private readonly units: Model<CatalogRecord>,
    @InjectModel("ProductPrice") private readonly prices: Model<CatalogRecord>,
  ) {}

  async list(kind: ReadOnlyKind, query: ReadOnlyQueryDto) {
    const cursor = query.cursor ? this.decode(query.cursor) : undefined;
    if (
      cursor &&
      (cursor.branchId !== query.branchId || cursor.kind !== kind)
    ) {
      throw new BadRequestException("Cursor does not match this catalog view");
    }
    const model = {
      products: this.products,
      productUnits: this.units,
      productPrices: this.prices,
    }[kind];
    const rows = await model
      .find({
        branchId: query.branchId,
        deletedAt: null,
        ...(cursor ? { id: { $gt: cursor.lastId } } : {}),
      })
      .sort({ id: 1 })
      .limit(query.limit + 1)
      .select("-_id -__v")
      .lean()
      .exec();
    const hasMore = rows.length > query.limit;
    const items = rows.slice(0, query.limit);
    const last = items.at(-1);
    return {
      items,
      nextCursor:
        hasMore && last
          ? this.encode({ branchId: query.branchId, kind, lastId: last.id })
          : undefined,
    };
  }

  private encode(cursor: ReadCursor) {
    return Buffer.from(JSON.stringify(cursor)).toString("base64url");
  }

  private decode(value: string): ReadCursor {
    try {
      const cursor = JSON.parse(
        Buffer.from(value, "base64url").toString(),
      ) as Partial<ReadCursor>;
      if (
        typeof cursor.branchId !== "string" ||
        !["products", "productUnits", "productPrices"].includes(
          cursor.kind ?? "",
        ) ||
        typeof cursor.lastId !== "string"
      ) {
        throw new Error();
      }
      return cursor as ReadCursor;
    } catch {
      throw new BadRequestException("Invalid cursor");
    }
  }
}
