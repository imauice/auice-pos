import { plainToInstance } from 'class-transformer'; import { validate } from 'class-validator';
import { SyncPushRequestDto } from '../src/sync/dto/sync-push.dto'; import { SyncService } from '../src/sync/sync.service';
const id = '018f6f62-4b1d-7000-8000-000000000001'; const branchId = '018f6f62-4b1d-7000-8000-000000000002'; const deviceId = '018f6f62-4b1d-7000-8000-000000000003';
const event = { id, entityType: 'product', entityId: '018f6f62-4b1d-7000-8000-000000000004', operation: 'create', entityVersion: 1, occurredAt: '2026-07-12T10:30:00.000Z', payload: { name: 'Beer A' } };
const request = (events: unknown[] = [event], protocolVersion = 1) => ({ protocolVersion, branchId, deviceId, events });
async function errors(value: unknown) { return validate(plainToInstance(SyncPushRequestDto, value)); }
function memoryModel() {
  const records = new Map<string, Record<string, unknown>>();
  return { records, findOne: ({ id: eventId }: { id: string }) => ({ lean: () => ({ exec: () => Promise.resolve(records.get(eventId) ?? null) }) }), create: (value: Record<string, unknown>) => { records.set(value.id as string, value); return Promise.resolve({ toObject: () => value }); } };
}
describe('sync contract', () => {
  it('accepts a valid envelope', async () => expect(await errors(request())).toHaveLength(0));
  it('rejects empty and oversized batches', async () => { expect(await errors(request([]))).not.toHaveLength(0); expect(await errors(request(Array(101).fill(event)))).not.toHaveLength(0); });
  it('rejects invalid UUID and timestamp', async () => { expect(await errors({ ...request(), branchId: 'bad' })).not.toHaveLength(0); expect(await errors(request([{ ...event, occurredAt: '2026-07-12 10:30' }]))).not.toHaveLength(0); });
  it('rejects unsupported entity types in validation', async () => expect(await errors(request([{ ...event, entityType: 'employee' }]))).not.toHaveLength(0));
  it('rejects unsupported protocol versions', async () => { const model = memoryModel(); await expect(new SyncService(model as never).push(request([event], 2) as never)).rejects.toThrow('UNSUPPORTED_PROTOCOL_VERSION'); });
  it('accepts the first event and treats a duplicate deterministically', async () => {
    const model = memoryModel(); const service = new SyncService(model as never);
    const first = await service.push(request() as never); const duplicate = await service.push(request() as never);
    expect(first.accepted).toEqual(duplicate.accepted); expect(first.accepted[0].status).toBe('accepted'); expect(model.records.size).toBe(1);
  });
});
