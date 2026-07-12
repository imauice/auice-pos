import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { SyncPushRequestDto, SyncPushResponse } from './dto/sync-push.dto';
import { SYNC_ENTITY_TYPES, SYNC_PROTOCOL_VERSION } from './sync.constants';
interface StoredSyncEvent { id: string; entityId: string; entityVersion: number; serverVersion: number }
@Injectable()
export class SyncService {
  constructor(@InjectModel('SyncEvent') private readonly events: Model<StoredSyncEvent>) {}
  async push(request: SyncPushRequestDto): Promise<SyncPushResponse> {
    if (request.protocolVersion !== SYNC_PROTOCOL_VERSION) throw new BadRequestException('UNSUPPORTED_PROTOCOL_VERSION');
    const accepted: SyncPushResponse['accepted'] = []; const rejected: SyncPushResponse['rejected'] = [];
    for (const event of request.events) {
      if (!(SYNC_ENTITY_TYPES as readonly string[]).includes(event.entityType)) { rejected.push({ eventId: event.id, code: 'UNKNOWN_ENTITY_TYPE', message: `Unsupported entity type: ${event.entityType}`, retryable: false }); continue; }
      let stored = await this.events.findOne({ id: event.id }).lean().exec();
      if (!stored) {
        try { stored = (await this.events.create({ ...event, branchId: request.branchId, deviceId: request.deviceId, occurredAt: new Date(event.occurredAt), createdAt: new Date(), status: 'synced', retryCount: 0, syncedAt: new Date(), serverVersion: event.entityVersion })).toObject(); }
        catch (error: unknown) { if ((error as { code?: number }).code === 11000) stored = await this.events.findOne({ id: event.id }).lean().exec(); else { rejected.push({ eventId: event.id, code: 'INTERNAL_ERROR', message: 'Event could not be persisted', retryable: true }); continue; } }
      }
      if (stored) accepted.push({ eventId: event.id, entityId: stored.entityId, serverVersion: stored.serverVersion, status: 'accepted' });
    }
    return { protocolVersion: 1, accepted, rejected, serverTime: new Date().toISOString() };
  }
}
