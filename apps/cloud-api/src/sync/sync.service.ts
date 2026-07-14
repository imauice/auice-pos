import { BadRequestException, Injectable } from "@nestjs/common";
import { InjectModel } from "@nestjs/mongoose";
import { Model } from "mongoose";
import {
  SyncEventDto,
  SyncPushRequestDto,
  SyncPushResponse,
} from "./dto/sync-push.dto";
import { SYNC_ENTITY_TYPES, SYNC_PROTOCOL_VERSION } from "./sync.constants";

interface StoredSyncEvent {
  id: string;
  branchId: string;
  deviceId: string;
  entityType: string;
  entityId: string;
  operation: string;
  entityVersion: number;
  occurredAt: Date | string;
  payload: unknown;
  serverVersion: number;
}
function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value !== null && typeof value === "object")
    return `{${Object.entries(value as Record<string, unknown>)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, item]) => `${JSON.stringify(key)}:${canonicalJson(item)}`)
      .join(",")}}`;
  return JSON.stringify(value) ?? "null";
}
function immutableContentMatches(
  stored: StoredSyncEvent,
  request: SyncPushRequestDto,
  event: SyncEventDto,
): boolean {
  return (
    stored.branchId === request.branchId &&
    stored.deviceId === request.deviceId &&
    stored.entityType === event.entityType &&
    stored.entityId === event.entityId &&
    stored.operation === event.operation &&
    stored.entityVersion === event.entityVersion &&
    new Date(stored.occurredAt).toISOString() === event.occurredAt &&
    canonicalJson(stored.payload) === canonicalJson(event.payload)
  );
}
function asStoredEvent(value: unknown): StoredSyncEvent | null {
  return value === null ? null : (value as StoredSyncEvent);
}
@Injectable()
export class SyncService {
  constructor(
    @InjectModel("SyncEvent") private readonly events: Model<StoredSyncEvent>,
  ) {}
  async push(request: SyncPushRequestDto): Promise<SyncPushResponse> {
    if (request.protocolVersion !== SYNC_PROTOCOL_VERSION)
      throw new BadRequestException("UNSUPPORTED_PROTOCOL_VERSION");
    const accepted: SyncPushResponse["accepted"] = [];
    const rejected: SyncPushResponse["rejected"] = [];
    for (const event of request.events) {
      if (
        !(SYNC_ENTITY_TYPES as readonly string[]).includes(event.entityType)
      ) {
        rejected.push({
          eventId: event.id,
          code: "UNKNOWN_ENTITY_TYPE",
          message: `Unsupported entity type: ${event.entityType}`,
          retryable: false,
        });
        continue;
      }
      let stored = asStoredEvent(
        await this.events.findOne({ id: event.id }).lean().exec(),
      );
      if (!stored) {
        try {
          stored = asStoredEvent(
            (
              await this.events.create({
                ...event,
                branchId: request.branchId,
                deviceId: request.deviceId,
                occurredAt: new Date(event.occurredAt),
                createdAt: new Date(),
                status: "synced",
                retryCount: 0,
                syncedAt: new Date(),
                serverVersion: event.entityVersion,
              })
            ).toObject(),
          );
        } catch (error: unknown) {
          if ((error as { code?: number }).code === 11000)
            stored = asStoredEvent(
              await this.events.findOne({ id: event.id }).lean().exec(),
            );
          else {
            rejected.push({
              eventId: event.id,
              code: "INTERNAL_ERROR",
              message: "Event could not be persisted",
              retryable: true,
            });
            continue;
          }
        }
      }
      if (!stored) {
        rejected.push({
          eventId: event.id,
          code: "INTERNAL_ERROR",
          message: "Event could not be read after persistence",
          retryable: true,
        });
        continue;
      }
      if (!immutableContentMatches(stored, request, event)) {
        rejected.push({
          eventId: event.id,
          code: "IDEMPOTENCY_CONFLICT",
          message:
            "Event ID was previously used with different immutable content",
          retryable: false,
        });
        continue;
      }
      accepted.push({
        eventId: event.id,
        entityId: stored.entityId,
        serverVersion: stored.serverVersion,
        status: "accepted",
      });
    }
    return {
      protocolVersion: 1,
      accepted,
      rejected,
      serverTime: new Date().toISOString(),
    };
  }
}
