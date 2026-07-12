import { Transform } from 'class-transformer'; import { IsInt, IsOptional, IsString, IsUUID, Max, Min } from 'class-validator';
export class CatalogQueryDto {
  @IsUUID() branchId!: string;
  @Transform(({ value }) => Number(value)) @IsInt() @Min(0) catalogVersion!: number;
  @IsOptional() @Transform(({ value }) => Number(value)) @IsInt() @Min(1) @Max(500) limit = 100;
  @IsOptional() @IsString() cursor?: string;
}
