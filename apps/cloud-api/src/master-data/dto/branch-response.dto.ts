import { ApiProperty } from "@nestjs/swagger";
export class BranchResponseDto {
  @ApiProperty() id!: string;
  @ApiProperty() code!: string;
  @ApiProperty() name!: string;
  @ApiProperty() timezone!: string;
  @ApiProperty({ example: "THB" }) currency!: string;
  @ApiProperty() active!: boolean;
  @ApiProperty() version!: number;
  @ApiProperty() updatedAt!: Date;
}
