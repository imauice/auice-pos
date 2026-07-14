import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectModel } from "@nestjs/mongoose";
import { Model } from "mongoose";
import { BranchResponseDto } from "./dto/branch-response.dto";
interface BranchRecord {
  id: string;
  code: string;
  name: string;
  timezone: string;
  currency: string;
  active: boolean;
  version: number;
  updatedAt: Date;
  currentCatalogVersion: number;
}
@Injectable()
export class BranchService {
  constructor(
    @InjectModel("Branch") private readonly branches: Model<BranchRecord>,
  ) {}
  async list(): Promise<BranchResponseDto[]> {
    const records = await this.branches
      .find({ deletedAt: null })
      .sort({ code: 1 })
      .lean()
      .exec();
    return records.map((record) => this.publicDto(record));
  }
  async get(id: string): Promise<BranchResponseDto> {
    const branch = await this.branches
      .findOne({ id, deletedAt: null })
      .lean()
      .exec();
    if (!branch) throw new NotFoundException("Branch not found");
    return this.publicDto(branch);
  }
  private publicDto(branch: BranchRecord): BranchResponseDto {
    return {
      id: branch.id,
      code: branch.code,
      name: branch.name,
      timezone: branch.timezone,
      currency: branch.currency,
      active: branch.active,
      version: branch.version,
      updatedAt: branch.updatedAt,
    };
  }
}
