// Checks when the julds-wake Worker wakes julds before scheduled work (services/julds-wake/src/schedule.js).
// Run: node --test tests/test_julds_wake_schedule.mjs
import assert from "node:assert/strict";
import { test } from "node:test";
import { dueWakes, SCHEDULED_WAKES } from "../services/julds-wake/src/schedule.js";

const due = (iso) => dueWakes(new Date(iso)).map((w) => w.why);
const BRIEF = SCHEDULED_WAKES[0].why;
const P3 = SCHEDULED_WAKES[1].why;

test("morning brief: 07:50 and 08:05 London, in winter and in summer time", () => {
  assert.deepEqual(due("2026-11-26T07:50:00Z"), [BRIEF]); // GMT
  assert.deepEqual(due("2026-11-26T08:05:00Z"), [BRIEF]);
  assert.deepEqual(due("2027-06-02T06:50:00Z"), [BRIEF]); // BST: 07:50 London is 06:50 UTC
  assert.deepEqual(due("2027-06-02T07:50:00Z"), []); // 08:50 London
});

test("p3-stack sync: Mondays 08:50 and 09:05 UTC only", () => {
  assert.deepEqual(due("2026-11-30T08:50:00Z"), [P3]); // Monday
  assert.deepEqual(due("2026-11-30T09:05:00Z"), [P3]);
  assert.deepEqual(due("2026-12-01T08:50:00Z"), []); // Tuesday
});

test("other cron ticks wake nothing", () => {
  assert.deepEqual(due("2026-11-26T12:50:00Z"), []);
  assert.deepEqual(due("2026-11-26T07:05:00Z"), []);
});

test("every time fits the :05 and :50 cron", () => {
  for (const w of SCHEDULED_WAKES) for (const t of w.times) assert.match(t, /^\d\d:(05|50)$/, w.why);
});
