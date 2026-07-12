import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayNotEmpty, IsArray, IsIn, IsInt, IsNotEmptyObject, IsObject, IsString, IsUUID, Matches, Min, ValidateNested } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { MAX_SYNC_BATCH_SIZE, SYNC_ENTITY_TYPES, SYNC_OPERATIONS } from '../sync.constants';
const utcIso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
export class SyncEventDto {
  @ApiProperty() @IsUUID() id!: string;
  @ApiProperty({ enum: SYNC_ENTITY_TYPES }) @IsString() @IsIn(SYNC_ENTITY_TYPES) entityType!: string;
  @ApiProperty() @IsUUID() entityId!: string;
  @ApiProperty({ enum: SYNC_OPERATIONS }) @IsIn(SYNC_OPERATIONS) operation!: string;
  @ApiProperty() @IsInt() @Min(1) entityVersion!: number;
  @ApiProperty({ example: '2026-07-12T10:30:00.000Z' }) @Matches(utcIso) occurredAt!: string;
  @ApiProperty({ type: Object }) @IsObject() @IsNotEmptyObject({ nullable: false }) payload!: Record<string, unknown>;
}
export class SyncPushRequestDto {
  @ApiProperty({ example: 1 }) @IsInt() protocolVersion!: number;
  @ApiProperty() @IsUUID() branchId!: string;
  @ApiProperty() @IsUUID() deviceId!: string;
  @ApiProperty({ type: [SyncEventDto], maxItems: MAX_SYNC_BATCH_SIZE }) @IsArray() @ArrayNotEmpty() @ArrayMaxSize(MAX_SYNC_BATCH_SIZE) @ValidateNested({ each: true }) @Type(() => SyncEventDto) events!: SyncEventDto[];
}
export interface AcceptedSyncResult { eventId: string; entityId: string; serverVersion: number; status: 'accepted' }
export interface RejectedSyncResult { eventId: string; code: string; message: string; retryable: boolean }
export interface SyncPushResponse { protocolVersion: 1; accepted: AcceptedSyncResult[]; rejected: RejectedSyncResult[]; serverTime: string }

