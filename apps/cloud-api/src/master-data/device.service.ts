import { BadRequestException, Injectable } from "@nestjs/common";
import { InjectModel } from "@nestjs/mongoose";
import { Model } from "mongoose";
import { RegisterDeviceDto } from "./dto/register-device.dto";
interface BranchRecord {
  id: string;
  code: string;
  version: number;
  currentCatalogVersion: number;
  active: boolean;
}
interface DeviceRecord {
  id: string;
  branchId: string;
  active: boolean;
  name: string;
  platform: string;
  appVersion: string;
  version: number;
}
@Injectable()
export class DeviceService {
  constructor(
    @InjectModel("Branch") private readonly branches: Model<BranchRecord>,
    @InjectModel("Device") private readonly devices: Model<DeviceRecord>,
  ) {}
  async register(dto: RegisterDeviceDto) {
    const branch = await this.branches
      .findOne({ code: dto.branchCode, active: true, deletedAt: null })
      .lean()
      .exec();
    if (!branch) throw new BadRequestException("UNKNOWN_OR_INACTIVE_BRANCH");
    const existing = await this.devices
      .findOne({ id: dto.deviceId, deletedAt: null })
      .lean()
      .exec();
    if (existing && !existing.active)
      throw new BadRequestException("DEVICE_INACTIVE");
    if (existing && existing.branchId !== branch.id)
      throw new BadRequestException("DEVICE_BRANCH_CONFLICT");
    const metadataChanged =
      !existing ||
      existing.name !== dto.deviceName ||
      existing.platform !== dto.platform ||
      existing.appVersion !== dto.appVersion;
    const now = new Date();
    await this.devices
      .findOneAndUpdate(
        { id: dto.deviceId },
        {
          $set: {
            branchId: branch.id,
            name: dto.deviceName,
            platform: dto.platform,
            appVersion: dto.appVersion,
            lastSeenAt: now,
            active: true,
            updatedAt: now,
          },
          $setOnInsert: {
            id: dto.deviceId,
            code: dto.deviceId,
            createdAt: now,
            deletedAt: null,
          },
          ...(metadataChanged ? { $inc: { version: 1 } } : {}),
        },
        { upsert: !existing, new: true, setDefaultsOnInsert: true },
      )
      .exec();
    return {
      deviceId: dto.deviceId,
      branchId: branch.id,
      branchVersion: branch.version,
      catalogVersion: branch.currentCatalogVersion,
      registered: true,
    };
  }
  async list() {
    const rows = await this.devices
      .find({ deletedAt: null })
      .sort({ updatedAt: -1 })
      .lean()
      .exec();
    return rows.map((row) => ({
      id: row.id,
      branchId: row.branchId,
      name: row.name,
      platform: row.platform,
      appVersion: row.appVersion,
      active: row.active,
      version: row.version,
    }));
  }
}
