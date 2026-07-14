import { Body, Controller, Get, Post } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { DeviceService } from "./device.service";
import { RegisterDeviceDto } from "./dto/register-device.dto";
@ApiTags("devices")
@Controller("device")
export class DeviceController {
  constructor(private readonly devices: DeviceService) {}
  @Post("register") register(@Body() dto: RegisterDeviceDto) {
    return this.devices.register(dto);
  }
  @Get() list() {
    return this.devices.list();
  }
}
