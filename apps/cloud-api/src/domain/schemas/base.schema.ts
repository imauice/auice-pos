import { SchemaDefinition } from "mongoose";
import { UUID_PATTERN } from "../domain.constants";
export const syncableFields: SchemaDefinition = {
  id: { type: String, required: true, unique: true, match: UUID_PATTERN },
  branchId: { type: String, required: true, match: UUID_PATTERN },
  createdAt: { type: Date, required: true },
  updatedAt: { type: Date, required: true },
  version: { type: Number, required: true, min: 1, validate: Number.isInteger },
  deletedAt: { type: Date, default: null },
};
export const hideInternal = {
  transform: (_doc: unknown, ret: Record<string, unknown>) => {
    delete ret._id;
    delete ret.__v;
    return ret;
  },
};
