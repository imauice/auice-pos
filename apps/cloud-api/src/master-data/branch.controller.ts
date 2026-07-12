import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common'; import { ApiTags } from '@nestjs/swagger'; import { BranchService } from './branch.service';
@ApiTags('branches') @Controller('branches') export class BranchController {
  constructor(private readonly branches:BranchService){} @Get() list(){return this.branches.list();} @Get(':id') get(@Param('id',new ParseUUIDPipe()) id:string){return this.branches.get(id);}
}
