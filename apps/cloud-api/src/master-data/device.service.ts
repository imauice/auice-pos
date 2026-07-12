import { BadRequestException, Injectable } from '@nestjs/common'; import { InjectModel } from '@nestjs/mongoose'; import { Model } from 'mongoose'; import { RegisterDeviceDto } from './dto/register-device.dto';
interface BranchRecord { id:string; code:string; version:number; currentCatalogVersion:number; active:boolean }
interface DeviceRecord { id:string; branchId:string }
@Injectable() export class DeviceService {
  constructor(@InjectModel('Branch') private readonly branches:Model<BranchRecord>,@InjectModel('Device') private readonly devices:Model<DeviceRecord>){}
  async register(dto:RegisterDeviceDto){ const branch=await this.branches.findOne({code:dto.branchCode,active:true,deletedAt:null}).lean().exec(); if(!branch) throw new BadRequestException('Unknown or inactive branch'); const now=new Date(); await this.devices.findOneAndUpdate({id:dto.deviceId},{ $set:{branchId:branch.id,name:dto.deviceName,platform:dto.platform,appVersion:dto.appVersion,lastSeenAt:now,active:true,updatedAt:now,deletedAt:null},$setOnInsert:{id:dto.deviceId,code:dto.deviceId,createdAt:now,version:1}},{upsert:true,new:true,setDefaultsOnInsert:true}).exec(); return {deviceId:dto.deviceId,branchId:branch.id,branchVersion:branch.version,catalogVersion:branch.currentCatalogVersion,registered:true}; }
}
