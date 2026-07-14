import { BranchService } from "../src/master-data/branch.service";
import { CatalogService } from "../src/master-data/catalog.service";
import { DeviceService } from "../src/master-data/device.service";
import { MasterDataWriteService } from "../src/master-data/master-data-write.service";
import { ReadOnlyCatalogService } from "../src/master-data/read-only-catalog.service";
const branch = {
  id: "018f6f62-4b1d-7000-8000-000000000001",
  code: "BKK01",
  name: "Bangkok",
  timezone: "Asia/Bangkok",
  currency: "THB",
  active: true,
  version: 2,
  updatedAt: new Date("2026-01-01"),
  currentCatalogVersion: 4,
};
const dto = {
  deviceId: "018f6f62-4b1d-7000-8000-000000000002",
  branchCode: "BKK01",
  deviceName: "POS-01",
  platform: "windows",
  appVersion: "0.1.0",
};
const singleQuery = (value: unknown) => ({
  lean: () => ({ exec: () => Promise.resolve(value) }),
});
describe("branch and device master data", () => {
  it("returns explicit branch list/get DTOs", async () => {
    const model = {
      find: () => ({ sort: () => singleQuery([branch]) }),
      findOne: () => singleQuery(branch),
    };
    const service = new BranchService(model as never);
    expect(await service.list()).toEqual([
      {
        id: branch.id,
        code: "BKK01",
        name: "Bangkok",
        timezone: "Asia/Bangkok",
        currency: "THB",
        active: true,
        version: 2,
        updatedAt: branch.updatedAt,
      },
    ]);
    expect((await service.get(branch.id)).id).toBe(branch.id);
  });
  it("registers new and repeatedly updates same-branch device", async () => {
    let device: Record<string, unknown> | null = null;
    const branches = { findOne: () => singleQuery(branch) };
    const devices = {
      findOne: () => singleQuery(device),
      findOneAndUpdate: (
        _filter: unknown,
        update: {
          $set: Record<string, unknown>;
          $setOnInsert: Record<string, unknown>;
          $inc?: { version: number };
        },
      ) => ({
        exec: () => {
          device = {
            ...(device ?? update.$setOnInsert),
            ...update.$set,
            version: Number(device?.version ?? 0) + (update.$inc?.version ?? 0),
          };
          return Promise.resolve(device);
        },
      }),
    };
    const service = new DeviceService(branches as never, devices as never);
    expect((await service.register(dto)).registered).toBe(true);
    await service.register({ ...dto, appVersion: "0.2.0" });
    expect((device as unknown as Record<string, unknown>).appVersion).toBe(
      "0.2.0",
    );
    expect((device as unknown as Record<string, unknown>).version).toBe(2);
  });
  it("rejects branch conflict and inactive device", async () => {
    const branches = { findOne: () => singleQuery(branch) };
    const model = (device: unknown) => ({ findOne: () => singleQuery(device) });
    await expect(
      new DeviceService(
        branches as never,
        model({ branchId: "other", active: true }) as never,
      ).register(dto),
    ).rejects.toThrow("DEVICE_BRANCH_CONFLICT");
    await expect(
      new DeviceService(
        branches as never,
        model({ branchId: branch.id, active: false }) as never,
      ).register(dto),
    ).rejects.toThrow("DEVICE_INACTIVE");
  });
  it("rejects unknown or inactive branch", async () =>
    await expect(
      new DeviceService(
        { findOne: () => singleQuery(null) } as never,
        {} as never,
      ).register(dto),
    ).rejects.toThrow("UNKNOWN_OR_INACTIVE_BRANCH"));
});
describe("catalog snapshot keyset pull", () => {
  type Range = { $gt: number; $lte: number };
  type CandidateClause = {
    catalogVersion: number | Range;
    id?: { $gt: string };
  };
  type CandidateFilter = {
    branchId: string;
    catalogVersion?: Range;
    $or?: CandidateClause[];
  };
  const records = [
    {
      id: "c2",
      branchId: branch.id,
      catalogVersion: 2,
      name: "C2",
      deletedAt: null,
    },
    {
      id: "c4",
      branchId: branch.id,
      catalogVersion: 4,
      name: "C4",
      deletedAt: new Date("2026-02-01"),
    },
    {
      id: "c5",
      branchId: branch.id,
      catalogVersion: 5,
      name: "late",
      deletedAt: null,
    },
  ];
  const model = (items: typeof records) => {
    const limits: number[] = [];
    return {
      limits,
      find: (filter: CandidateFilter) => {
        let result = items.filter((item) => {
          if (item.branchId !== filter.branchId) return false;
          if (filter.catalogVersion) {
            return (
              item.catalogVersion > filter.catalogVersion.$gt &&
              item.catalogVersion <= filter.catalogVersion.$lte
            );
          }
          return (filter.$or ?? []).some((clause) => {
            const version = clause.catalogVersion;
            if (typeof version === "number") {
              return (
                item.catalogVersion === version &&
                (!clause.id || item.id > clause.id.$gt)
              );
            }
            return (
              item.catalogVersion > version.$gt &&
              item.catalogVersion <= version.$lte
            );
          });
        });
        const query = {
          sort: () => query,
          limit: (limit: number) => {
            limits.push(limit);
            result = result.slice(0, limit);
            return query;
          },
          select: () => query,
          lean: () => query,
          exec: () => Promise.resolve(result),
        };
        return query;
      },
    };
  };
  const service = (current = 4, branchId = branch.id) => {
    const models = [model(records), model([]), model([]), model([])];
    return {
      models,
      catalog: new CatalogService(
        {
          findOne: () =>
            singleQuery({
              ...branch,
              id: branchId,
              currentCatalogVersion: current,
            }),
        } as never,
        ...(models.map((entry) => entry as never) as [
          never,
          never,
          never,
          never,
        ]),
      ),
    };
  };
  it("supports full and incremental pulls with tombstones", async () => {
    const full = await service().catalog.pull({
      branchId: branch.id,
      catalogVersion: 0,
      limit: 100,
    });
    expect(full.categories.map((x) => x.id)).toEqual(["c2", "c4"]);
    const incremental = await service().catalog.pull({
      branchId: branch.id,
      catalogVersion: 2,
      limit: 100,
    });
    expect(incremental.categories.map((x) => x.id)).toEqual(["c4"]);
    expect(incremental.categories[0].deletedAt).toBeInstanceOf(Date);
  });
  it("keeps stable target and excludes mutations between pages", async () => {
    const first = await service(4).catalog.pull({
      branchId: branch.id,
      catalogVersion: 0,
      limit: 1,
    });
    expect(first.targetVersion).toBe(4);
    expect(first.hasMore).toBe(true);
    const second = await service(5).catalog.pull({
      branchId: branch.id,
      catalogVersion: 0,
      limit: 1,
      cursor: first.nextCursor,
    });
    expect(second.targetVersion).toBe(4);
    expect(second.categories.map((x) => x.id)).toEqual(["c4"]);
    expect(second.categories.some((x) => x.id === "c5")).toBe(false);
  });
  it("rejects invalid cursor", async () =>
    await expect(
      service().catalog.pull({
        branchId: branch.id,
        catalogVersion: 0,
        limit: 10,
        cursor: "bad",
      }),
    ).rejects.toThrow("Invalid cursor"));
  it("binds cursors to branch and starting catalog version", async () => {
    const first = await service().catalog.pull({
      branchId: branch.id,
      catalogVersion: 0,
      limit: 1,
    });
    await expect(
      service(4, "018f6f62-4b1d-7000-8000-000000000099").catalog.pull({
        branchId: "018f6f62-4b1d-7000-8000-000000000099",
        catalogVersion: 0,
        limit: 1,
        cursor: first.nextCursor,
      }),
    ).rejects.toThrow("Cursor does not match requested branchId");
    await expect(
      service().catalog.pull({
        branchId: branch.id,
        catalogVersion: 1,
        limit: 1,
        cursor: first.nextCursor,
      }),
    ).rejects.toThrow("Cursor does not match requested catalogVersion");
    await expect(
      service().catalog.pull({
        branchId: branch.id,
        catalogVersion: 0,
        limit: 1,
        cursor: first.nextCursor,
      }),
    ).resolves.toMatchObject({ targetVersion: 4 });
  });
  it("bounds every collection query for a large catalog", async () => {
    const large = Array.from({ length: 10_000 }, (_, index) => ({
      ...records[0],
      id: `record-${index.toString().padStart(5, "0")}`,
      catalogVersion: index + 1,
    }));
    const models = [model(large), model(large), model(large), model(large)];
    const catalog = new CatalogService(
      {
        findOne: () =>
          singleQuery({ ...branch, currentCatalogVersion: 10_000 }),
      } as never,
      ...(models.map((entry) => entry as never) as [
        never,
        never,
        never,
        never,
      ]),
    );
    const page = await catalog.pull({
      branchId: branch.id,
      catalogVersion: 0,
      limit: 25,
    });
    expect(models.flatMap((entry) => entry.limits)).toEqual([25, 25, 25, 25]);
    expect(
      page.categories.length +
        page.products.length +
        page.productUnits.length +
        page.productPrices.length,
    ).toBe(25);
  });
});
describe("catalog mutation boundary", () => {
  it("increments once, assigns the same version, and preserves deletion tombstones", async () => {
    let version = 0;
    const saved: Array<Record<string, unknown>> = [];
    const branches = {
      findOneAndUpdate: () => ({
        lean: () => ({
          exec: () => Promise.resolve({ currentCatalogVersion: ++version }),
        }),
      }),
    };
    const entity = {
      findOneAndUpdate: (
        _f: unknown,
        u: { $set: Record<string, unknown> },
      ) => ({
        lean: () => ({
          exec: () => {
            saved.push(u.$set);
            return Promise.resolve({ id: "x", ...u.$set });
          },
        }),
      }),
    };
    const session = {
      withTransaction: async (fn: () => Promise<void>) => fn(),
      endSession: () => Promise.resolve(),
    };
    const connection = { startSession: () => Promise.resolve(session) };
    const service = new MasterDataWriteService(
      connection as never,
      branches as never,
      entity as never,
      entity as never,
      entity as never,
      entity as never,
    );
    const first = await service.mutate("product", branch.id, "x", {
      name: "A",
    });
    const second = await service.mutate(
      "product",
      branch.id,
      "x",
      { name: "A" },
      true,
    );
    expect(first.catalogVersion).toBe(1);
    expect(second.catalogVersion).toBe(2);
    expect(saved[1].catalogVersion).toBe(2);
    expect(saved[1].deletedAt).toBeInstanceOf(Date);
  });
});

describe("read-only catalog pages", () => {
  it("returns a bounded branch-scoped page and cursor", async () => {
    const rows = [
      { id: "a", branchId: branch.id, deletedAt: null },
      { id: "b", branchId: branch.id, deletedAt: null },
    ];
    const limits: number[] = [];
    const model = {
      find: (filter: { branchId: string; id?: { $gt: string } }) => {
        let result = rows.filter(
          (row) =>
            row.branchId === filter.branchId &&
            (!filter.id || row.id > filter.id.$gt),
        );
        const query = {
          sort: () => query,
          limit: (limit: number) => {
            limits.push(limit);
            result = result.slice(0, limit);
            return query;
          },
          select: () => query,
          lean: () => query,
          exec: () => Promise.resolve(result),
        };
        return query;
      },
    };
    const service = new ReadOnlyCatalogService(
      model as never,
      model as never,
      model as never,
    );
    const first = await service.list("products", {
      branchId: branch.id,
      limit: 1,
    });
    expect(first.items.map((row) => row.id)).toEqual(["a"]);
    expect(first.nextCursor).toBeDefined();
    expect(limits).toEqual([2]);
    await expect(
      service.list("products", {
        branchId: branch.id,
        limit: 1,
        cursor: first.nextCursor,
      }),
    ).resolves.toMatchObject({ items: [{ id: "b" }] });
  });
});
