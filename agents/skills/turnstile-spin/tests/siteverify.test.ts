import { afterEach, expect, test } from "bun:test";
import { verifyTurnstile } from "../templates/verify-turnstile";

const originalFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = originalFetch; });
const input = { token: "fixture-token", secret: "fixture-secret", hostnames: "example.com", action: "signup" };

test("validates body and accepts only the correct action and hostname", async () => {
  let calls = 0;
  globalThis.fetch = Object.assign(async (url: RequestInfo | URL, options?: RequestInit) => {
    calls++;
    expect(url).toBe("https://challenges.cloudflare.com/turnstile/v0/siteverify");
    expect(options?.method).toBe("POST");
    expect(options?.signal).toBeInstanceOf(AbortSignal);
    expect(String(options?.body)).toBe("secret=fixture-secret&response=fixture-token");
    return Response.json({ success: true, action: "signup", hostname: "example.com" });
  }, { preconnect: originalFetch.preconnect });
  expect(await verifyTurnstile(input)).toBe(true);
  expect(calls).toBe(1);
});

test("invalid input never calls Siteverify", async () => {
  let calls = 0;
  globalThis.fetch = Object.assign(async () => {
    calls++;
    return Response.json({ success: true, action: "signup", hostname: "example.com" });
  }, { preconnect: originalFetch.preconnect });
  for (const token of [null, undefined, {}, [], 42, "", "x".repeat(2049)]) {
    expect(await verifyTurnstile({ ...input, token })).toBe(false);
  }
  for (const secret of [null, undefined, {}, "", " "]) {
    expect(await verifyTurnstile({ ...input, secret })).toBe(false);
  }
  for (const hostnames of [undefined, "", " , "]) {
    expect(await verifyTurnstile({ ...input, hostnames })).toBe(false);
  }
  for (const action of ["", "space here", "x".repeat(33)]) {
    expect(await verifyTurnstile({ ...input, action })).toBe(false);
  }
  expect(calls).toBe(0);
});

test("all unsuccessful or malformed responses fail closed", async () => {
  for (const value of [null, [], {}, { success: "true", action: "signup", hostname: "example.com" },
    { success: false, "error-codes": ["timeout-or-duplicate"] },
    { success: true, action: "login", hostname: "example.com" },
    { success: true, action: "signup", hostname: "evil.example" }]) {
    globalThis.fetch = Object.assign(async () => Response.json(value), { preconnect: originalFetch.preconnect });
    expect(await verifyTurnstile(input)).toBe(false);
  }
  globalThis.fetch = Object.assign(async () => new Response("invalid json"), { preconnect: originalFetch.preconnect });
  expect(await verifyTurnstile(input)).toBe(false);
  globalThis.fetch = Object.assign(async () => Response.json({ success: true, action: "signup", hostname: "example.com" }, { status: 500 }), { preconnect: originalFetch.preconnect });
  expect(await verifyTurnstile(input)).toBe(false);
  globalThis.fetch = Object.assign(async () => { throw new Error("network or timeout"); }, { preconnect: originalFetch.preconnect });
  expect(await verifyTurnstile(input)).toBe(false);
});
