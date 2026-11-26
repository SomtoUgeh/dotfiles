// Scheduled wakes: julds sleeps after 90 quiet minutes, so work that starts on julds with no
// person in front of it needs julds awake first. Each entry wakes julds at its times (local to `tz`,
// on `days` if given, 0 = Sunday) and waits until T3 answers through T3 Connect. The cron runs at
// :05 and :50 of every hour, so a time must end in :05 or :50. A request that reaches T3 Connect while
// julds is asleep is held and delivered when julds is back (T3 webhook tasks drop it after their
// maxDeliveryAgeMinutes), so the second time catches a julds that went to sleep just before the run.
// Add an entry here for each new T3 scheduled task or bot routine that runs on julds.
export const SCHEDULED_WAKES = [
  // Chief of Staff (Coworkers) posts the T3 webhook task "Morning brief (Chief of Staff trigger)" at 08:00 London.
  { why: "morning brief (Chief of Staff, 08:00 London)", tz: "Europe/London", times: ["07:50", "08:05"] },
  // T3 fixed_time task "p3-stack weekly upstream sync": Mondays 09:00 in julds's own time zone (UTC).
  { why: "p3-stack weekly upstream sync (T3, Mon 09:00 UTC)", tz: "UTC", times: ["08:50", "09:05"], days: [1] },
];
const WEEKDAY = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };

// The entries due at `at` (a Date), to the minute.
export function dueWakes(at, wakes = SCHEDULED_WAKES) {
  return wakes.filter((w) => {
    const parts = Object.fromEntries(
      new Intl.DateTimeFormat("en-GB", { timeZone: w.tz, weekday: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
        .formatToParts(at)
        .map((p) => [p.type, p.value]),
    );
    if (w.days && !w.days.includes(WEEKDAY[parts.weekday])) return false;
    return w.times.includes(`${parts.hour}:${parts.minute}`);
  });
}
