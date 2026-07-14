import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { SyncPushRequestDto } from "../src/sync/dto/sync-push.dto";
import { SyncService } from "../src/sync/sync.service";
const id = "018f6f62-4b1d-7000-8000-000000000001";
const branchId = "018f6f62-4b1d-7000-8000-000000000002";
const deviceId = "018f6f62-4b1d-7000-8000-000000000003";
const event = {
  id,
  entityType: "product",
  entityId: "018f6f62-4b1d-7000-8000-000000000004",
  operation: "create",
  entityVersion: 1,
  occurredAt: "2026-07-12T10:30:00.000Z",
  payload: { name: "Beer A" },
};
const request = (
  events: unknown[] = [event],
  protocolVersion = 1,
  branch = branchId,
  device = deviceId,
) => ({ protocolVersion, branchId: branch, deviceId: device, events });
async function errors(value: unknown) {
  return validate(plainToInstance(SyncPushRequestDto, value));
}
function memoryModel(raceOnFirstCreate = false) {
  const records = new Map<string, Record<string, unknown>>();
  let raced = false;
  return {
    records,
    findOne: ({ id: eventId }: { id: string }) => ({
      lean: () => ({
        exec: () => Promise.resolve(records.get(eventId) ?? null),
      }),
    }),
    create: (value: Record<string, unknown>) => {
      records.set(value.id as string, value);
      if (raceOnFirstCreate && !raced) {
        raced = true;
        return Promise.reject(
          Object.assign(new Error("duplicate key"), { code: 11000 }),
        );
      }
      return Promise.resolve({ toObject: () => value });
    },
  };
}
describe("sync contract", () => {
  it("accepts cash movement as a supported entity", async () => {
    const service = new SyncService(memoryModel() as never);
    const cash = {
      ...event,
      id: "018f6f62-4b1d-7000-8000-000000000099",
      entityType: "cash_movement",
    };
    expect(
      (await service.push(request([cash]) as never)).accepted,
    ).toHaveLength(1);
  });
  it("accepts a valid envelope and an empty delete payload", async () => {
    expect(await errors(request())).toHaveLength(0);
    expect(
      await errors(request([{ ...event, operation: "delete", payload: {} }])),
    ).toHaveLength(0);
  });
  it("rejects empty and oversized batches", async () => {
    expect(await errors(request([]))).not.toHaveLength(0);
    expect(await errors(request(Array(101).fill(event)))).not.toHaveLength(0);
  });
  it("rejects invalid UUID and timestamp", async () => {
    expect(await errors({ ...request(), branchId: "bad" })).not.toHaveLength(0);
    expect(
      await errors(request([{ ...event, occurredAt: "2026-07-12 10:30" }])),
    ).not.toHaveLength(0);
  });
  it("allows unknown entity types through envelope validation for per-event rejection", async () =>
    expect(
      await errors(request([{ ...event, entityType: "employee" }])),
    ).toHaveLength(0));
  it("rejects unsupported protocol versions", async () => {
    const model = memoryModel();
    await expect(
      new SyncService(model as never).push(request([event], 2) as never),
    ).rejects.toThrow("UNSUPPORTED_PROTOCOL_VERSION");
  });
  it("accepts the first event and an identical duplicate deterministically", async () => {
    const model = memoryModel();
    const service = new SyncService(model as never);
    const first = await service.push(request() as never);
    const duplicate = await service.push(request() as never);
    expect(first.accepted).toEqual(duplicate.accepted);
    expect(model.records.size).toBe(1);
  });
  it.each([
    ["payload", request([{ ...event, payload: { name: "Different" } }])],
    ["branch", request([event], 1, "018f6f62-4b1d-7000-8000-000000000010")],
    [
      "device",
      request([event], 1, branchId, "018f6f62-4b1d-7000-8000-000000000011"),
    ],
  ])("rejects same ID with different %s", async (_label, conflicting) => {
    const service = new SyncService(memoryModel() as never);
    await service.push(request() as never);
    const result = await service.push(conflicting as never);
    expect(result.rejected[0]).toMatchObject({
      code: "IDEMPOTENCY_CONFLICT",
      retryable: false,
    });
    expect(result.accepted).toHaveLength(0);
  });
  it("partially accepts a mixed supported and unsupported batch", async () => {
    const service = new SyncService(memoryModel() as never);
    const unknown = {
      ...event,
      id: "018f6f62-4b1d-7000-8000-000000000012",
      entityType: "employee",
    };
    const result = await service.push(request([event, unknown]) as never);
    expect(result.accepted).toHaveLength(1);
    expect(result.rejected).toEqual([
      expect.objectContaining({
        eventId: unknown.id,
        code: "UNKNOWN_ENTITY_TYPE",
      }),
    ]);
  });
  it("recovers a duplicate-key race and returns the stored result", async () => {
    const model = memoryModel(true);
    const result = await new SyncService(model as never).push(
      request() as never,
    );
    expect(result.accepted).toHaveLength(1);
    expect(result.rejected).toHaveLength(0);
    expect(model.records.size).toBe(1);
  });
});
