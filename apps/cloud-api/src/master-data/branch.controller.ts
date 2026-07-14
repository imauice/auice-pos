import { Controller, Get, Param, ParseUUIDPipe } from "@nestjs/common";
import { ApiOkResponse, ApiTags } from "@nestjs/swagger";
import { BranchService } from "./branch.service";
import { BranchResponseDto } from "./dto/branch-response.dto";
@ApiTags("branches")
@Controller("branches")
export class BranchController {
  constructor(private readonly branches: BranchService) {}
  @Get() @ApiOkResponse({ type: [BranchResponseDto] }) list() {
    return this.branches.list();
  }
  @Get(":id") @ApiOkResponse({ type: BranchResponseDto }) get(
    @Param("id", new ParseUUIDPipe()) id: string,
  ) {
    return this.branches.get(id);
  }
}
