// Checks the julds-wake Worker's scheduled wake against a fake boat API and T3 Connect page
// (services/julds-wake/src/index.js). Run: node --test tests/test_julds_wake_scheduled.mjs
import assert from "node:assert/strict";
import { beforeEach, test } from "node:test";
import worker from "../services/julds-wake/src/index.js";

const RELAY = "https://relay.test/.well-known/t3/environment";
const BRIEF_TICK = Date.parse("2026-11-26T07:50:00Z"); // 07:50 London: the morning brief wake
let calls, alerts, fake;

// Every timer fires at once and moves a fake clock by its delay, so 10 minutes of polls take no time.
let clock = 0;
Date.now = () => clock;
globalThis.setTimeout = (fn, ms = 0) => { clock += ms; queueMicrotask(fn); return 0; };
globalThis.fetch = async (url, init = {}) => {
  const u = String(url);
  calls.push(`${init.method || "GET"} ${u}`);
  if (u === RELAY) return new Response("{}", { status: fake.t3After-- <= 0 ? 200 : 503 });
  if (u.endsWith("/resume")) {
    fake.resumes++;
    if (fake.resumeStatus === 200) fake.state = "running";
    return new Response(JSON.stringify({ message: "nope" }), { status: fake.resumeStatus });
  }
  if (fake.statusThrows) throw new Error("network down");
  return new Response(JSON.stringify(fake.statusCode === 200 ? { sandbox: { state: fake.state } } : { message: "boat is down" }), { status: fake.statusCode });
};

const env = (sleeps = "1") => ({
  JULDS_SLEEPS: sleeps, SANDBOX_ID: "bx_julds", VMS: "julds:bx_julds,icb:bx_icb", T3_RELAY_URL: RELAY,
  BOAT_KEY: "k", BOAT_KEY_VMS: "k2", ALERT_TO: "to@test", ALERT_FROM: "from@test",
  EMAIL: { send: async (m) => { alerts.push(m.subject); } },
});
async function tick(e, at = BRIEF_TICK) {
  let job;
  await worker.scheduled({ cron: "5,50 * * * *", scheduledTime: at }, e, { waitUntil: (p) => { job = p; } });
  await job;
}

beforeEach(() => {
  calls = []; alerts = []; clock = BRIEF_TICK;
  fake = { state: "archived", statusCode: 200, statusThrows: false, resumeStatus: 200, resumes: 0, t3After: 2 };
});

test("JULDS_SLEEPS not 1: no wake", async () => {
  await tick(env("0"));
  assert.deepEqual(calls, []);
});

test("a cron tick with no scheduled work: no wake", async () => {
  await tick(env(), Date.parse("2026-11-26T12:50:00Z"));
  assert.deepEqual(calls, []);
});

test("asleep: one resume, then it waits until T3 answers", async () => {
  await tick(env());
  assert.equal(fake.resumes, 1);
  assert.equal(calls.filter((c) => c === `GET ${RELAY}`).length, 3);
  assert.deepEqual(alerts, []);
});

test("already awake with T3: no resume", async () => {
  fake.state = "running"; fake.t3After = 0;
  await tick(env());
  assert.equal(fake.resumes, 0);
  assert.deepEqual(alerts, []);
});

test("boat does not report the state: an alert", async () => {
  fake.statusCode = 500;
  await tick(env());
  assert.equal(fake.resumes, 0);
  assert.deepEqual(alerts, ["[julds] scheduled wake failed"]);
});

test("a fetch that throws: an alert", async () => {
  fake.statusThrows = true;
  await tick(env());
  assert.deepEqual(alerts, ["[julds] scheduled wake failed"]);
});

test("a failed resume: one alert, from the resume", async () => {
  fake.resumeStatus = 500;
  await tick(env());
  assert.deepEqual(alerts, ["[julds] wake failed: julds"]);
});

test("T3 never answers: an alert after 10 minutes, under 50 subrequests", async () => {
  fake.t3After = Infinity;
  await tick(env());
  assert.ok(clock - BRIEF_TICK > 10 * 60_000 && clock - BRIEF_TICK < 12 * 60_000);
  assert.deepEqual(alerts, ["[julds] T3 not answering after a scheduled wake"]);
  assert.ok(calls.length < 50, `${calls.length} subrequests`);
});
