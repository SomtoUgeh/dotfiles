# DO Storage Testing

Testing Durable Objects with storage using `vitest-plugin`.

## Setup

**vitest.config.ts:**
```typescript
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })],
  test: { setupFiles: ["./test/setup.ts"] }
});
```

**package.json:** The tested plugin 1.1.4 requires Vitest `^4.1.0`. Check peer dependencies on upgrade. Use ESM (`"type": "module"`) or `vitest.config.mts`. For complete setup and generated Env types see [shared DO testing](../../../durable-objects/references/testing.md).

Create `test/setup.ts` with the shared guide's `afterEach(reset)` hook; storage is
not reset automatically. These examples need concrete exported classes and
bindings for `COUNTER`, `USER_MANAGER`, `BATCH_PROCESSOR`, `MY_DO`, and `BANK`.
`USER_MANAGER` must provide the shown methods and `_meta` schema; the batch
processor must schedule an alarm and move queued rows into `processed_items`.
Each snippet below is a test-file fragment; retain the imports from Basic
Testing, plus any imports shown in the later snippet.

## Basic Testing

```typescript
import { env, runInDurableObject } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("Counter DO", () => {
  it("increments counter", async () => {
    const id = env.COUNTER.idFromName("test");
    const result = await runInDurableObject(env.COUNTER.get(id), async (instance, state) => {
      const val1 = await instance.increment();
      const val2 = await instance.increment();
      return { val1, val2 };
    });
    expect(result.val1).toBe(1);
    expect(result.val2).toBe(2);
  });
});
```

## Testing SQL Storage

```typescript
it("creates and queries users", async () => {
  const id = env.USER_MANAGER.idFromName("test");
  await runInDurableObject(env.USER_MANAGER.get(id), async (instance, state) => {
    await instance.createUser("alice@example.com", "Alice");
    const user = await instance.getUser("alice@example.com");
    expect(user).toEqual({ email: "alice@example.com", name: "Alice" });
  });
});

it("handles schema migrations", async () => {
  const id = env.USER_MANAGER.idFromName("migration-test");
  await runInDurableObject(env.USER_MANAGER.get(id), async (instance, state) => {
    const version = state.storage.sql.exec(
      "SELECT value FROM _meta WHERE key = 'schema_version'"
    ).one()?.value;
    expect(version).toBe("1");
  });
});
```

## Testing Alarms

```typescript
import { runDurableObjectAlarm } from "cloudflare:test";

it("processes batch on alarm", async () => {
  const id = env.BATCH_PROCESSOR.idFromName("test");
  
  // Add items
  await runInDurableObject(env.BATCH_PROCESSOR.get(id), async (instance) => {
    await instance.addItem("item1");
    await instance.addItem("item2");
  });
  
  // Trigger alarm
  await runDurableObjectAlarm(env.BATCH_PROCESSOR.get(id));
  
  // Verify processed
  await runInDurableObject(env.BATCH_PROCESSOR.get(id), async (instance, state) => {
    const count = state.storage.sql.exec(
      "SELECT COUNT(*) as count FROM processed_items"
    ).one().count;
    expect(count).toBe(2);
  });
});
```

## Testing Concurrency

```typescript
it("handles concurrent increments safely", async () => {
  const id = env.COUNTER.idFromName("concurrent-test");
  
  // Parallel increments
  const results = await Promise.all([
    runInDurableObject(env.COUNTER.get(id), (i) => i.increment()),
    runInDurableObject(env.COUNTER.get(id), (i) => i.increment()),
    runInDurableObject(env.COUNTER.get(id), (i) => i.increment())
  ]);
  
  // All should get unique values
  expect(new Set(results).size).toBe(3);
  expect(Math.max(...results)).toBe(3);
});
```

## Test Isolation

```typescript
import { beforeEach } from "vitest";

// Per-test unique IDs
let testId: string;
beforeEach(() => { testId = crypto.randomUUID(); });

it("isolated test", async () => {
  const id = env.MY_DO.idFromName(testId);
  await runInDurableObject(env.MY_DO.get(id), async (instance, state) => {
    expect(await state.storage.get("marker")).toBeUndefined();
    await state.storage.put("marker", testId);
    expect(await state.storage.get("marker")).toBe(testId);
  });
});

// Cleanup pattern
it("with cleanup", async () => {
  const id = env.MY_DO.idFromName("cleanup-test");
  try {
    await runInDurableObject(env.MY_DO.get(id), async (instance, state) => {
      expect(await state.storage.get("marker")).toBeUndefined();
      await state.storage.put("marker", "temporary");
      expect(await state.storage.get("marker")).toBe("temporary");
    });
  } finally {
    await runInDurableObject(env.MY_DO.get(id), async (instance, state) => {
      await state.storage.deleteAll();
    });
  }
  await runInDurableObject(env.MY_DO.get(id), async (instance, state) => {
    expect(await state.storage.get("marker")).toBeUndefined();
  });
});
```

## Testing PITR

Point-in-time recovery needs a separate authorized integration test against a disposable deployed SQLite DO. Local Miniflare does not establish production bookmark/restore behavior. Do not mark recovery verified from an in-process storage rollback test. See the [PITR API](https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/#point-in-time-recovery-api).

## Testing Transactions

```typescript
it("rolls back on error", async () => {
  const id = env.BANK.idFromName("transaction-test");
  
  await runInDurableObject(env.BANK.get(id), async (instance, state) => {
    await state.storage.put("balance", 100);
    
    await expect(
      state.storage.transaction(async () => {
        await state.storage.put("balance", 50);
        throw new Error("Cancel");
      })
    ).rejects.toThrow("Cancel");
    
    const balance = await state.storage.get("balance");
    expect(balance).toBe(100); // Rolled back
  });
});
```
