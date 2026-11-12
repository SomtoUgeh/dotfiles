/**
 * Product-video recorder. Streams 2x JPEG frames from a page over CDP while a tour step
 * runs, and logs what the viewer should notice (clicks, typing, scene beats, URL
 * changes) so the edit can draw a smooth cursor, zoom on the action and place captions.
 * Waits that a viewer should not sit through are wrapped in `offAir`, which marks a
 * range the assembler cuts.
 *
 * Output per clip under $DEMO_OUT/clips/<clip>/ (default: ../out next to this folder):
 *   frames/000001.jpg …  frames.jsonl  {"i":1,"t":12.3}
 *   events.jsonl                       {"t":…,"type":"click",…}
 *
 * Chromium only: the capture uses the Chrome DevTools Protocol.
 */
import { appendFileSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";

import type { CDPSession, Locator, Page } from "@playwright/test";

const FRAME_QUALITY = 85;
const CURSOR_SETTLE_MS = 380;
const CAPTURE_TIMEOUT_MS = 2500;

/**
 * Pace multiplier for every viewer-facing wait and typing delay. 1 is brisk;
 * DEMO_PACE=1.6 gives a slower, more deliberate walkthrough that narration can follow.
 */
const PACE = (() => {
  const value = Number(process.env.DEMO_PACE ?? "1");
  return Number.isFinite(value) && value > 0 ? value : 1;
})();

function paced(ms: number): number {
  return Math.round(ms * PACE);
}

export function demoOutDir(): string {
  return process.env.DEMO_OUT ?? path.resolve(import.meta.dirname, "..", "out");
}

interface Box {
  height: number;
  width: number;
  x: number;
  y: number;
}

type DemoEvent =
  | { t: number; type: "beat"; id: string; note?: string }
  | { t: number; type: "click" | "type" | "hover"; box: Box; label?: string }
  | { t: number; type: "off" | "on" }
  | { t: number; type: "scroll"; dy: number }
  | { t: number; type: "url"; url: string };

type EventInput = DemoEvent extends infer E ? (E extends DemoEvent ? Omit<E, "t"> : never) : never;

export class Recorder {
  private readonly dir: string;
  private readonly page: Page;
  private session: CDPSession | null = null;
  private running = false;
  private loopDone: Promise<void> = Promise.resolve();
  private readonly t0 = Date.now();
  private frame = 0;
  /** Start time of the newest saved frame. */
  private lastFrameAt = -1;
  /** Drops the capture in flight, when there is one. */
  private interrupt: (() => void) | null = null;

  private constructor(page: Page, clip: string) {
    if (!/^[a-z0-9][a-z0-9-]*$/u.test(clip)) {
      throw new Error(`Clip name "${clip}" must use lower-case letters, digits and hyphens`);
    }
    this.page = page;
    this.dir = path.join(demoOutDir(), "clips", clip);
    rmSync(this.dir, { force: true, recursive: true });
    mkdirSync(path.join(this.dir, "frames"), { recursive: true });
    writeFileSync(path.join(this.dir, "frames.jsonl"), "");
    writeFileSync(path.join(this.dir, "events.jsonl"), "");
  }

  /** Starts a clip. Open the page and wait until it is ready before you call this. */
  static async start(page: Page, clip: string): Promise<Recorder> {
    const recorder = new Recorder(page, clip);
    recorder.session = await page.context().newCDPSession(page);
    page.on("framenavigated", (frame) => {
      if (frame === page.mainFrame()) {
        recorder.log({ type: "url", url: frame.url() });
        // A capture in flight during a navigation stalls until it times out, which
        // freezes the picture. Drop it and take a new one from the new page.
        recorder.interrupt?.();
      }
    });
    recorder.log({ type: "url", url: page.url() });
    recorder.running = true;
    recorder.loopDone = recorder.loop();
    return recorder;
  }

  private now(): number {
    return (Date.now() - this.t0) / 1000;
  }

  private log(event: EventInput): void {
    appendFileSync(path.join(this.dir, "events.jsonl"), `${JSON.stringify({ t: this.now(), ...event })}\n`);
  }

  private async loop(): Promise<void> {
    const viewport = this.page.viewportSize();
    const width = viewport?.width ?? 1440;
    const height = viewport?.height ?? 900;
    while (this.running && this.session) {
      const t = this.now();
      // Frames are captured one after another so that each keeps its own timestamp.
      const interrupted = new Promise<null>((resolve) => {
        this.interrupt = () => resolve(null);
      });
      const shot = await Promise.race([
        withTimeout(
          this.session.send("Page.captureScreenshot", {
            clip: { height, scale: 2, width, x: 0, y: 0 },
            format: "jpeg",
            optimizeForSpeed: true,
            quality: FRAME_QUALITY,
          }),
          CAPTURE_TIMEOUT_MS,
        ),
        interrupted,
      ]);
      this.interrupt = null;
      if (shot) {
        this.frame += 1;
        this.lastFrameAt = t;
        const name = String(this.frame).padStart(6, "0");
        writeFileSync(path.join(this.dir, "frames", `${name}.jpg`), Buffer.from(shot.data, "base64"));
        appendFileSync(path.join(this.dir, "frames.jsonl"), `${JSON.stringify({ i: this.frame, t })}\n`);
      } else {
        // The page is navigating; try again shortly.
        await new Promise((resolve) => setTimeout(resolve, 30));
      }
    }
  }

  /** Ends the clip. It logs the final beat `end`, which the assembler requires. */
  async stop(): Promise<void> {
    this.log({ type: "beat", id: "end" });
    this.running = false;
    // A stalled capture must not hang the step; the loop exits on its own.
    await withTimeout(this.loopDone, CAPTURE_TIMEOUT_MS * 2);
    await this.session?.detach().catch(() => null);
    this.session = null;
  }

  /** A named moment the edit can cut a scene at. */
  beat(id: string, note?: string): void {
    this.log(note ? { id, note, type: "beat" } : { id, type: "beat" });
  }

  /** Run something the viewer should not watch (loading, seeding, long waits). */
  async offAir<T>(work: () => Promise<T>): Promise<T> {
    this.log({ type: "off" });
    try {
      return await work();
    } finally {
      // Come back on air only when a frame of the finished state exists, so the cut
      // never opens on the screen from before the wait.
      await this.freshFrame();
      this.log({ type: "on" });
    }
  }

  /** Waits until a frame that started after this call has been saved. */
  private async freshFrame(): Promise<void> {
    const from = this.now();
    const deadline = Date.now() + CAPTURE_TIMEOUT_MS * 2;
    while (this.running && this.lastFrameAt < from && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 15));
    }
  }

  /** Lets the viewer read the screen. */
  async pause(ms: number): Promise<void> {
    await this.page.waitForTimeout(paced(ms));
  }

  private async aim(target: Locator, type: "click" | "type" | "hover", label?: string): Promise<Box> {
    await target.waitFor({ state: "visible", timeout: 30_000 });
    await target.scrollIntoViewIfNeeded();
    const box = await target.boundingBox();
    if (!box) {
      throw new Error(`No bounding box for ${label ?? String(target)}`);
    }
    this.log(label ? { box, label, type } : { box, type });
    await this.page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 10 });
    await this.page.waitForTimeout(paced(CURSOR_SETTLE_MS));
    return box;
  }

  async click(target: Locator, opts: { after?: number; label?: string } = {}): Promise<void> {
    await this.aim(target, "click", opts.label);
    await target.click();
    await this.page.waitForTimeout(paced(opts.after ?? 650));
  }

  async hover(target: Locator, opts: { after?: number; label?: string } = {}): Promise<void> {
    await this.aim(target, "hover", opts.label);
    await this.page.waitForTimeout(paced(opts.after ?? 900));
  }

  /** Types visibly, character by character. */
  async type(
    target: Locator,
    text: string,
    opts: { after?: number; delay?: number; label?: string } = {},
  ): Promise<void> {
    await this.aim(target, "type", opts.label);
    await target.click();
    await target.fill("");
    await target.pressSequentially(text, { delay: paced(opts.delay ?? 38) });
    await this.page.waitForTimeout(paced(opts.after ?? 350));
  }

  /** Fills a long value at once (still drawn as a typing beat). */
  async fill(target: Locator, text: string, opts: { after?: number; label?: string } = {}): Promise<void> {
    await this.aim(target, "type", opts.label);
    await target.fill(text);
    await this.page.waitForTimeout(paced(opts.after ?? 450));
  }

  async select(
    target: Locator,
    value: string | { label: string },
    opts: { after?: number; label?: string } = {},
  ): Promise<void> {
    await this.aim(target, "click", opts.label);
    await target.selectOption(value);
    await this.page.waitForTimeout(paced(opts.after ?? 450));
  }

  /** Smooth wheel scroll the viewer can follow. */
  async scroll(dy: number, opts: { after?: number } = {}): Promise<void> {
    this.log({ dy, type: "scroll" });
    const steps = Math.max(1, Math.round(Math.abs(dy) / 40));
    for (let i = 0; i < steps; i += 1) {
      // Wheel steps run in order so that they read as one scroll.
      await this.page.mouse.wheel(0, dy / steps);
      await this.page.waitForTimeout(16);
    }
    await this.page.waitForTimeout(paced(opts.after ?? 700));
  }
}

/** Resolves to null when the promise rejects or takes longer than `ms`. */
async function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T | null> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<null>((resolve) => {
    timer = setTimeout(() => resolve(null), ms);
  });
  try {
    return await Promise.race([promise.catch(() => null), timeout]);
  } finally {
    clearTimeout(timer);
  }
}
