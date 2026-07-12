import { Injectable, NotFoundException } from '@nestjs/common'; import { InjectModel } from '@nestjs/mongoose'; import { Model } from 'mongoose';
interface BranchRecord { id:string; code:string; name:string; timezone:string; currency:string; active:boolean; version:number; updatedAt:Date; currentCatalogVersion:number }
@Injectable() export class BranchService {
  constructor(@InjectModel('Branch') private readonly branches: Model<BranchRecord>) {}
  list(): Promise<BranchRecord[]> { return this.branches.find({ deletedAt: null }).select('-_id id code name timezone currency active version updatedAt').sort({ code: 1 }).lean().exec(); }
  async get(id: string): Promise<BranchRecord> { const branch=await this.branches.findOne({ id, deletedAt:null }).select('-_id id code name timezone currency active version updatedAt').lean().exec(); if(!branch) throw new NotFoundException('Branch not found'); return branch; }
}
