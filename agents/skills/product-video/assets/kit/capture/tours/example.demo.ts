/**
 * Example tour: records one clip of the bundled example site. Copy this file for your
 * product. One test records one clip; put a beat at each point where the narration
 * changes subject.
 */
import { test } from "@playwright/test";

import { Recorder } from "../recorder";

test.describe.configure({ mode: "serial" });

test("01 sign up", async ({ page }) => {
  // Open the page and wait until it is ready before the recording starts.
  await page.goto("/");
  await page.getByLabel("Full name").waitFor();

  const rec = await Recorder.start(page, "example-01-signup");
  rec.beat("form");
  await rec.pause(1200);
  await rec.type(page.getByLabel("Full name"), "Maya Okafor");
  await rec.type(page.getByLabel("Work email"), "maya@studio.example");
  await rec.select(page.getByLabel("Plan"), { label: "Team" });

  rec.beat("submit");
  await rec.pause(800);
  await rec.click(page.getByRole("button", { name: "Create workspace" }));
  // The site takes 3 s to set up the workspace. The viewer does not watch that.
  await rec.offAir(async () => {
    await page.waitForURL(/\/welcome/u);
    await page.getByRole("heading", { name: /Welcome/u }).waitFor();
  });

  rec.beat("dashboard");
  await rec.pause(1500);
  await rec.hover(page.getByTestId("next-steps"), { after: 1500 });
  await rec.scroll(160);
  await rec.stop();
});
