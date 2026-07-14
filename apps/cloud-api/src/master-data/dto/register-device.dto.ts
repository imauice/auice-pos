import { IsIn, IsNotEmpty, IsString, IsUUID } from "class-validator";
import { DEVICE_PLATFORMS } from "../../domain/domain.constants";
export class RegisterDeviceDto {
  @IsUUID() deviceId!: string;
  @IsString() @IsNotEmpty() branchCode!: string;
  @IsString() @IsNotEmpty() deviceName!: string;
  @IsIn(DEVICE_PLATFORMS) platform!: string;
  @IsString() @IsNotEmpty() appVersion!: string;
}
