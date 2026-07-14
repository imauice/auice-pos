import { Schema } from "mongoose";
import { UUID_PATTERN } from "../../domain/domain.constants";
import { SYNC_ENTITY_TYPES, SYNC_OPERATIONS } from "../sync.constants";
export const SyncEventSchema = new Schema(
  {
    id: { type: String, required: true, unique: true, match: UUID_PATTERN },
    branchId: { type: String, required: true, match: UUID_PATTERN },
    deviceId: { type: String, required: true, match: UUID_PATTERN },
    entityType: { type: String, enum: SYNC_ENTITY_TYPES, required: true },
    entityId: { type: String, required: true, match: UUID_PATTERN },
    operation: { type: String, enum: SYNC_OPERATIONS, required: true },
    entityVersion: {
      type: Number,
      required: true,
      min: 1,
      validate: Number.isInteger,
    },
    payload: { type: Schema.Types.Mixed, required: true },
    occurredAt: { type: Date, required: true },
    createdAt: { type: Date, required: true },
    status: { type: String, enum: ["synced"], required: true },
    retryCount: { type: Number, required: true, default: 0 },
    lastAttemptAt: Date,
    lastError: String,
    syncedAt: { type: Date, required: true },
    serverVersion: {
      type: Number,
      required: true,
      min: 1,
      validate: Number.isInteger,
    },
  },
  {
    collection: "sync_events",
    versionKey: false,
    toJSON: {
      transform: (_doc, ret: Record<string, unknown>) => {
        delete ret._id;
        return ret;
      },
    },
  },
);
SyncEventSchema.index({ branchId: 1, deviceId: 1, occurredAt: 1 });
// Mixed is intentional: the event log stores versioned JSON payloads for multiple domain entity types. DTO envelope fields remain strictly validated.
