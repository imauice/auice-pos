import { Transform } from "class-transformer";
import { IsInt, IsOptional, IsString, IsUUID, Max, Min } from "class-validator";

export class ReadOnlyQueryDto {
  @IsUUID() branchId!: string;
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(100)
  limit = 25;
  @IsOptional() @IsString() cursor?: string;
}
