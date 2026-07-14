import { BadRequestException, Injectable } from "@nestjs/common";
import { InjectModel } from "@nestjs/mongoose";
import { Model } from "mongoose";
import { CatalogQueryDto } from "./dto/catalog-query.dto";
export interface CatalogRecord {
  id: string;
  catalogVersion: number;
  [key: string]: unknown;
}
interface BranchRecord {
  id: string;
  currentCatalogVersion: number;
}
type Kind = "categories" | "products" | "productUnits" | "productPrices";
interface Cursor {
  fromVersion: number;
  targetVersion: number;
  lastCatalogVersion: number;
  lastEntityType: Kind;
  lastId: string;
}
const kinds: Kind[] = [
  "categories",
  "products",
  "productUnits",
  "productPrices",
];
@Injectable()
export class CatalogService {
  constructor(
    @InjectModel("Branch") private readonly branches: Model<BranchRecord>,
    @InjectModel("Category") private readonly categories: Model<CatalogRecord>,
    @InjectModel("Product") private readonly products: Model<CatalogRecord>,
    @InjectModel("ProductUnit") private readonly units: Model<CatalogRecord>,
    @InjectModel("ProductPrice") private readonly prices: Model<CatalogRecord>,
  ) {}
  async pull(query: CatalogQueryDto) {
    const branch = await this.branches
      .findOne({ id: query.branchId, deletedAt: null })
      .lean()
      .exec();
    if (!branch) throw new BadRequestException("Unknown branch");
    const cursor = query.cursor ? this.decodeCursor(query.cursor) : undefined;
    if (cursor && cursor.fromVersion !== query.catalogVersion)
      throw new BadRequestException(
        "Cursor does not match requested catalogVersion",
      );
    const fromVersion = cursor?.fromVersion ?? query.catalogVersion;
    const targetVersion = cursor?.targetVersion ?? branch.currentCatalogVersion;
    const filter = {
      branchId: query.branchId,
      catalogVersion: { $gt: fromVersion, $lte: targetVersion },
    };
    const groups = await Promise.all([
      this.categories.find(filter).select("-_id -__v").lean().exec(),
      this.products.find(filter).select("-_id -__v").lean().exec(),
      this.units.find(filter).select("-_id -__v").lean().exec(),
      this.prices.find(filter).select("-_id -__v").lean().exec(),
    ]);
    const combined = groups
      .flatMap((records, index) =>
        records.map((record) => ({ kind: kinds[index], record })),
      )
      .sort(
        (a, b) =>
          a.record.catalogVersion - b.record.catalogVersion ||
          a.kind.localeCompare(b.kind) ||
          a.record.id.localeCompare(b.record.id),
      );
    const remaining = cursor
      ? combined.filter((item) =>
          this.afterCursor(item.kind, item.record, cursor),
        )
      : combined;
    const page = remaining.slice(0, query.limit);
    const hasMore = remaining.length > page.length;
    const response: {
      fromVersion: number;
      targetVersion: number;
      hasMore: boolean;
      nextCursor?: string;
      categories: CatalogRecord[];
      products: CatalogRecord[];
      productUnits: CatalogRecord[];
      productPrices: CatalogRecord[];
    } = {
      fromVersion,
      targetVersion,
      hasMore,
      categories: [],
      products: [],
      productUnits: [],
      productPrices: [],
    };
    for (const item of page) response[item.kind].push(item.record);
    if (hasMore) {
      const last = page.at(-1);
      if (last)
        response.nextCursor = this.encodeCursor({
          fromVersion,
          targetVersion,
          lastCatalogVersion: last.record.catalogVersion,
          lastEntityType: last.kind,
          lastId: last.record.id,
        });
    }
    return response;
  }
  private afterCursor(kind: Kind, record: CatalogRecord, cursor: Cursor) {
    return (
      record.catalogVersion > cursor.lastCatalogVersion ||
      (record.catalogVersion === cursor.lastCatalogVersion &&
        (kind > cursor.lastEntityType ||
          (kind === cursor.lastEntityType && record.id > cursor.lastId)))
    );
  }
  private encodeCursor(cursor: Cursor) {
    return Buffer.from(JSON.stringify(cursor)).toString("base64url");
  }
  private decodeCursor(value: string): Cursor {
    try {
      const cursor = JSON.parse(
        Buffer.from(value, "base64url").toString(),
      ) as Partial<Cursor>;
      if (
        !Number.isInteger(cursor.fromVersion) ||
        !Number.isInteger(cursor.targetVersion) ||
        !Number.isInteger(cursor.lastCatalogVersion) ||
        !kinds.includes(cursor.lastEntityType as Kind) ||
        typeof cursor.lastId !== "string"
      )
        throw new Error();
      return cursor as Cursor;
    } catch {
      throw new BadRequestException("Invalid cursor");
    }
  }
}
