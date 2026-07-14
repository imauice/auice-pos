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
  branchId: string;
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
    if (cursor && cursor.branchId !== query.branchId)
      throw new BadRequestException("Cursor does not match requested branchId");
    if (cursor && cursor.fromVersion !== query.catalogVersion)
      throw new BadRequestException(
        "Cursor does not match requested catalogVersion",
      );
    const fromVersion = cursor?.fromVersion ?? query.catalogVersion;
    const targetVersion = cursor?.targetVersion ?? branch.currentCatalogVersion;
    const groups = await Promise.all([
      this.candidates(
        this.categories,
        "categories",
        query,
        targetVersion,
        cursor,
      ),
      this.candidates(this.products, "products", query, targetVersion, cursor),
      this.candidates(this.units, "productUnits", query, targetVersion, cursor),
      this.candidates(
        this.prices,
        "productPrices",
        query,
        targetVersion,
        cursor,
      ),
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
    const page = combined.slice(0, query.limit);
    // Each collection is capped at the requested page size. A completely full
    // merged page may conservatively produce one final empty page, but never an
    // unbounded query.
    const hasMore =
      combined.length > page.length || page.length === query.limit;
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
          branchId: query.branchId,
          fromVersion,
          targetVersion,
          lastCatalogVersion: last.record.catalogVersion,
          lastEntityType: last.kind,
          lastId: last.record.id,
        });
    }
    return response;
  }
  private candidates(
    model: Model<CatalogRecord>,
    kind: Kind,
    query: CatalogQueryDto,
    targetVersion: number,
    cursor?: Cursor,
  ): Promise<CatalogRecord[]> {
    const catalogVersion: Record<string, number> = {
      $gt: query.catalogVersion,
      $lte: targetVersion,
    };
    const filter: Record<string, unknown> = {
      branchId: query.branchId,
      catalogVersion,
    };
    if (cursor) {
      const equalVersionPosition =
        kind > cursor.lastEntityType
          ? { catalogVersion: cursor.lastCatalogVersion }
          : kind === cursor.lastEntityType
            ? {
                catalogVersion: cursor.lastCatalogVersion,
                id: { $gt: cursor.lastId },
              }
            : undefined;
      filter.$or = [
        {
          catalogVersion: {
            $gt: cursor.lastCatalogVersion,
            $lte: targetVersion,
          },
        },
        ...(equalVersionPosition ? [equalVersionPosition] : []),
      ];
      delete filter.catalogVersion;
    }
    return model
      .find(filter)
      .sort({ catalogVersion: 1, id: 1 })
      .limit(query.limit)
      .select("-_id -__v")
      .lean()
      .exec();
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
        (cursor.fromVersion ?? -1) < 0 ||
        (cursor.targetVersion ?? -1) < (cursor.fromVersion ?? 0) ||
        (cursor.lastCatalogVersion ?? -1) <= (cursor.fromVersion ?? 0) ||
        (cursor.lastCatalogVersion ?? 0) > (cursor.targetVersion ?? -1) ||
        !kinds.includes(cursor.lastEntityType as Kind) ||
        typeof cursor.branchId !== "string" ||
        cursor.branchId.length === 0 ||
        typeof cursor.lastId !== "string"
      )
        throw new Error();
      return cursor as Cursor;
    } catch {
      throw new BadRequestException("Invalid cursor");
    }
  }
}
