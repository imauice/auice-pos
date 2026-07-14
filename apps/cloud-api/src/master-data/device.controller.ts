import { Body, Controller, Get, Post, Query } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { DeviceService } from "./device.service";
import { RegisterDeviceDto } from "./dto/register-device.dto";
import { ReadOnlyQueryDto } from "./dto/read-only-query.dto";
@ApiTags("devices")
@Controller("device")
export class DeviceController {
  constructor(private readonly devices: DeviceService) {}
  @Post("register") register(@Body() dto: RegisterDeviceDto) {
    return this.devices.register(dto);
  }
  @Get() list(@Query() query: ReadOnlyQueryDto) {
    return this.devices.list(query);
  }
}
