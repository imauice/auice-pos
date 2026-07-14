import { Injectable } from "@nestjs/common";
import { InjectConnection, InjectModel } from "@nestjs/mongoose";
import { ClientSession, Connection, Model } from "mongoose";
type EntityType = "category" | "product" | "product_unit" | "product_price";
interface Versioned {
  id: string;
  catalogVersion: number;
  deletedAt?: Date | null;
}
@Injectable()
export class MasterDataWriteService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel("Branch") private readonly branches: Model<unknown>,
    @InjectModel("Category") private readonly categories: Model<Versioned>,
    @InjectModel("Product") private readonly products: Model<Versioned>,
    @InjectModel("ProductUnit") private readonly units: Model<Versioned>,
    @InjectModel("ProductPrice") private readonly prices: Model<Versioned>,
  ) {}
  async mutate(
    type: EntityType,
    branchId: string,
    id: string,
    changes: Record<string, unknown>,
    deleted = false,
  ): Promise<Versioned> {
    const session = await this.connection.startSession();
    try {
      let result: Versioned | undefined;
      await session.withTransaction(async () => {
        result = await this.apply(
          type,
          branchId,
          id,
          changes,
          deleted,
          session,
        );
      });
      if (!result) throw new Error("Mutation transaction produced no record");
      return result;
    } catch (error: unknown) {
      if (!this.transactionUnsupported(error)) throw error;
      return this.apply(type, branchId, id, changes, deleted);
    } finally {
      await session.endSession();
    }
  }
  private async apply(
    type: EntityType,
    branchId: string,
    id: string,
    changes: Record<string, unknown>,
    deleted: boolean,
    session?: ClientSession,
  ) {
    const branchQuery = this.branches.findOneAndUpdate(
      { id: branchId },
      { $inc: { currentCatalogVersion: 1 } },
      { new: true, session },
    );
    const branch = await branchQuery
      .lean<{ currentCatalogVersion: number }>()
      .exec();
    if (!branch) throw new Error("Branch not found");
    const now = new Date();
    const model = this.model(type);
    const record = await model
      .findOneAndUpdate(
        { id, branchId },
        {
          $set: {
            ...changes,
            catalogVersion: branch.currentCatalogVersion,
            updatedAt: now,
            deletedAt: deleted ? now : null,
          },
        },
        { new: true, upsert: true, session, setDefaultsOnInsert: true },
      )
      .lean<Versioned>()
      .exec();
    if (!record) throw new Error("Master-data mutation failed");
    return record;
  }
  private model(type: EntityType) {
    return {
      category: this.categories,
      product: this.products,
      product_unit: this.units,
      product_price: this.prices,
    }[type];
  }
  private transactionUnsupported(error: unknown) {
    const message = error instanceof Error ? error.message : "";
    return (
      message.includes("Transaction numbers are only allowed") ||
      message.includes("replica set")
    );
  }
}
