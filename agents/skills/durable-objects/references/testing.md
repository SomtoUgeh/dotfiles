# Testing Durable Objects

Use `@cloudflare/vitest-plugin` to test DOs inside the Workers runtime.

## Setup

### Install Dependencies

```bash
npm i -D vitest@^4.1.0 @cloudflare/vitest-plugin
```

Check the installed plugin peer dependencies before choosing Vitest. The tested
`@cloudflare/vitest-plugin` 1.1.4 supports Vitest `^4.1.0`, not Vitest 5.
Use an ESM project (`"type": "module"` in package.json) or name the config
`vitest.config.mts`; loading this ESM-only plugin through CommonJS fails.

### vitest.config.ts

```typescript
import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" } })],
  test: { setupFiles: ["./test/setup.ts"] },
});
```

### Storage Reset (test/setup.ts)

The tested plugin does not reset storage between tests automatically. Register
the reset hook for tests that require fresh stored data. It does not remove known
object IDs from namespace listings. Do not run tests concurrently when they share
this reset hook.

```typescript
import { reset } from "cloudflare:test";
import { afterEach } from "vitest";

afterEach(async () => {
  await reset();
});
```

### TypeScript Config (test/tsconfig.json)

```jsonc
{
  "extends": "../tsconfig.json",
  "compilerOptions": {
    "moduleResolution": "bundler",
    "types": ["@cloudflare/vitest-plugin/types"]
  },
  "include": ["./**/*.ts", "../worker-configuration.d.ts"]
}
```

### Environment Types

Generate types after configuring the bindings and exporting their concrete DO
classes. Wrangler generates `Cloudflare.Env` and typed namespaces used by the
tests; augmenting `ProvidedEnv` in `cloudflare:test` no longer supplies these types.

```bash
npx wrangler types
```

The examples assume an exported SQLite-backed `Counter` with
`increment(name = "default")`, `getCount(name = "default")`, a
`counters(name, value)` table, and the alarm handler below. The Worker routes
POST/GET to that counter using the `id` query parameter. Export these classes
from the configured Worker entry point before running the tests.

## Unit Tests (Direct DO Access)

```typescript
import { env } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("Counter DO", () => {
  it("should increment", async () => {
    const stub = env.COUNTER.getByName("test-counter");
    
    expect(await stub.increment()).toBe(1);
    expect(await stub.increment()).toBe(2);
    expect(await stub.getCount()).toBe(2);
  });

  it("isolates different instances", async () => {
    const stub1 = env.COUNTER.getByName("counter-1");
    const stub2 = env.COUNTER.getByName("counter-2");
    
    await stub1.increment();
    await stub1.increment();
    await stub2.increment();
    
    expect(await stub1.getCount()).toBe(2);
    expect(await stub2.getCount()).toBe(1);
  });
});
```

## Integration Tests (HTTP via SELF)

```typescript
import { SELF } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("Worker HTTP", () => {
  it("should increment via POST", async () => {
    const res = await SELF.fetch("http://example.com?id=test", {
      method: "POST",
    });
    
    expect(res.status).toBe(200);
    const data = await res.json<{ count: number }>();
    expect(data.count).toBe(1);
  });

  it("should get count via GET", async () => {
    await SELF.fetch("http://example.com?id=get-test", { method: "POST" });
    await SELF.fetch("http://example.com?id=get-test", { method: "POST" });
    
    const res = await SELF.fetch("http://example.com?id=get-test");
    const data = await res.json<{ count: number }>();
    expect(data.count).toBe(2);
  });
});
```

## Direct Internal Access

Use `runInDurableObject()` to access instance internals and storage:

```typescript
import { env, runInDurableObject } from "cloudflare:test";
import { describe, it, expect } from "vitest";
import { Counter } from "../src";

describe("DO internals", () => {
  it("can verify storage directly", async () => {
    const stub = env.COUNTER.getByName("direct-test");
    await stub.increment();
    await stub.increment();

    await runInDurableObject(stub, async (instance: Counter, state) => {
      expect(instance).toBeInstanceOf(Counter);
      
      const result = state.storage.sql
        .exec<{ value: number }>(
          "SELECT value FROM counters WHERE name = ?",
          "default"
        )
        .one();
      expect(result.value).toBe(2);
    });
  });
});
```

## List DO IDs

```typescript
import { env, listDurableObjectIds } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("DO listing", () => {
  it("can list all IDs in namespace", async () => {
    const id1 = env.COUNTER.idFromName("list-1");
    const id2 = env.COUNTER.idFromName("list-2");
    
    await env.COUNTER.get(id1).increment();
    await env.COUNTER.get(id2).increment();
    
    const ids = await listDurableObjectIds(env.COUNTER);
    expect(ids.some(id => id.equals(id1))).toBe(true);
    expect(ids.some(id => id.equals(id2))).toBe(true);
  });
});
```

## Testing Alarms

Use `runDurableObjectAlarm()` to trigger alarms immediately:

```typescript
import { env, runInDurableObject, runDurableObjectAlarm } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("DO alarms", () => {
  it("can trigger alarms immediately", async () => {
    const stub = env.COUNTER.getByName("alarm-test");
    await stub.increment();
    await stub.increment();
    expect(await stub.getCount()).toBe(2);

    // Schedule alarm
    await runInDurableObject(stub, async (instance, state) => {
      await state.storage.setAlarm(Date.now() + 60_000);
    });

    // Execute immediately without waiting
    const ran = await runDurableObjectAlarm(stub);
    expect(ran).toBe(true);

    // Verify alarm handler ran (if it resets counter)
    expect(await stub.getCount()).toBe(0);

    // No alarm scheduled now
    const ranAgain = await runDurableObjectAlarm(stub);
    expect(ranAgain).toBe(false);
  });
});
```

Example alarm handler:
```typescript
async alarm(): Promise<void> {
  this.ctx.storage.sql.exec("DELETE FROM counters");
}
```

## Test Isolation

With the `test/setup.ts` reset hook configured above, each test starts with fresh
storage. Without that hook, the second test below observes the first test's count.
Known object IDs may still appear in `listDurableObjectIds()` after a reset; test
stored data rather than asserting that the namespace listing is empty.

```typescript
import { env } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("Isolation", () => {
  it("first test creates DO", async () => {
    const stub = env.COUNTER.getByName("isolated");
    await stub.increment();
    expect(await stub.getCount()).toBe(1);
  });

  it("second test has fresh state", async () => {
    const stub = env.COUNTER.getByName("isolated");
    expect(await stub.getCount()).toBe(0); // Stored count was reset
  });
});
```

## SQLite Storage Testing

```typescript
import { env, runInDurableObject } from "cloudflare:test";
import { describe, it, expect } from "vitest";

describe("SQLite", () => {
  it("can verify SQL storage", async () => {
    const stub = env.COUNTER.getByName("sqlite-test");
    await stub.increment("page-views");
    await stub.increment("page-views");
    await stub.increment("api-calls");

    await runInDurableObject(stub, async (instance, state) => {
      const rows = state.storage.sql
        .exec<{ name: string; value: number }>(
          "SELECT name, value FROM counters ORDER BY name"
        )
        .toArray();

      expect(rows).toEqual([
        { name: "api-calls", value: 1 },
        { name: "page-views", value: 2 },
      ]);

      expect(state.storage.sql.databaseSize).toBeGreaterThan(0);
    });
  });
});
```

## Running Tests

```bash
npx vitest        # Watch mode
npx vitest run    # Single run
```

package.json:
```json
{
  "scripts": {
    "test": "vitest"
  }
}
```
