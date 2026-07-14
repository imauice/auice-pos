import { Body, Controller, Post } from "@nestjs/common";
import { ApiBody, ApiOkResponse, ApiTags } from "@nestjs/swagger";
import { SyncPushRequestDto, SyncPushResponse } from "./dto/sync-push.dto";
import { SyncService } from "./sync.service";
@ApiTags("sync")
@Controller("sync")
export class SyncController {
  constructor(private readonly sync: SyncService) {}
  @Post("push")
  @ApiBody({ type: SyncPushRequestDto })
  @ApiOkResponse({
    description: "Per-event deterministic acceptance and rejection results",
  })
  push(@Body() request: SyncPushRequestDto): Promise<SyncPushResponse> {
    return this.sync.push(request);
  }
}
