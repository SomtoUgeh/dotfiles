import { Video } from "@remotion/media";
import { useMemo } from "react";
import { AbsoluteFill, Freeze, useCurrentFrame, useVideoConfig } from "remotion";
import { brand, browser } from "../brand/tokens";
import { type FocusEvent, cameraAt, planCamera } from "../lib/camera";
import {
  type ClipMeta,
  type Playback,
  frameOfSourceTime,
  isPointerEvent,
  sourceTimeAt,
} from "../lib/clip";
import { cursorAt, planCursor } from "../lib/cursor";
import { prettyUrl } from "../lib/url";
import type { CaptionPlacement, ZoomMode } from "../script/types";
import { BrowserFrame, Stage } from "./BrowserFrame";
import { Caption, captionLayout, captionRect, chooseCaptionSide, overlapArea } from "./Caption";
import { Cursor } from "./Cursor";

const { viewport } = browser;
const URL_PAINT_LAG = 0.3;

export type AppShotProps = {
  readonly clip: ClipMeta;
  readonly src: string;
  readonly playback: Playback;
  readonly sceneFrames: number;
  readonly transitionInFrames: number;
  readonly transitionOutFrames: number;
  readonly zoom?: ZoomMode;
  readonly caption?: string;
  readonly eyebrow?: string;
  readonly captionPlacement?: CaptionPlacement;
};

/** Events of the clip that fall inside the played part of the segment, in scene frames. */
const useSceneEvents = (clip: ClipMeta, playback: Playback, fps: number) =>
  useMemo(() => {
    const shownUntil = playback.sourceStart + (playback.playFrames * playback.rate) / fps;
    const inRange = (t: number) => t >= playback.sourceStart - 0.4 && t <= shownUntil;
    const focus: FocusEvent[] = clip.events
      .filter(isPointerEvent)
      .filter((e) => inRange(e.t))
      .map((e) => ({ frame: frameOfSourceTime(playback, e.t, fps), kind: e.type, box: e.box }));
    const urls = clip.events
      .filter((e): e is Extract<typeof e, { type: "url" }> => e.type === "url")
      .sort((a, b) => a.t - b.t);
    const urlChangeFrames = urls
      .filter((u) => u.t > playback.sourceStart && u.t <= shownUntil)
      .map((u) => frameOfSourceTime(playback, u.t, fps));
    return { focus, urls, urlChangeFrames };
  }, [clip, playback, fps]);

/**
 * A segment of recorded app footage in a browser frame, with an auto camera, a synthetic
 * cursor and an optional caption. Footage speed/freeze comes from `playback`.
 */
export const AppShot: React.FC<AppShotProps> = ({
  clip,
  src,
  playback,
  sceneFrames,
  transitionInFrames,
  transitionOutFrames,
  zoom = "auto",
  caption,
  eyebrow,
  captionPlacement = "auto",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { focus, urls, urlChangeFrames } = useSceneEvents(clip, playback, fps);

  const side = useMemo(() => {
    if (!caption) return "left" as const;
    if (captionPlacement === "bottom-left") return "left" as const;
    if (captionPlacement === "bottom-right") return "right" as const;
    return chooseCaptionSide(caption, Boolean(eyebrow), focus.map((f) => f.box));
  }, [caption, captionPlacement, eyebrow, focus]);

  const cameraPlan = useMemo(
    () =>
      planCamera(zoom, focus, urlChangeFrames, {
        fps,
        viewport,
        sceneFrames,
        transitionOutFrames,
        clearBottom: caption
          ? captionLayout(caption, Boolean(eyebrow)).top - browser.contentTop - 24
          : undefined,
      }),
    [zoom, focus, urlChangeFrames, fps, sceneFrames, transitionOutFrames, caption, eyebrow],
  );
  const cursorPlan = useMemo(() => planCursor(focus, fps), [focus, fps]);

  // The caption reads as the scene's title, then steps aside before the action reaches it.
  const captionEnter = transitionInFrames * 0.6;
  const captionExit = useMemo(() => {
    const sceneExit = sceneFrames - transitionOutFrames;
    if (!caption) return sceneExit;
    const rect = captionRect(caption, Boolean(eyebrow), side);
    const lead = 0.8 * fps;
    const conflict = focus.find((e) => {
      if (e.frame < captionEnter) return false;
      const cam = cameraAt(cameraPlan, e.frame, viewport);
      const box = {
        x: (e.box.x - cam.cx) * cam.z + viewport.width / 2,
        y: (e.box.y - cam.cy) * cam.z + viewport.height / 2,
        width: e.box.width * cam.z,
        height: e.box.height * cam.z,
      };
      return overlapArea(rect, box, 16) > 0;
    });
    if (!conflict) return sceneExit;
    return Math.min(sceneExit, Math.max(captionEnter + 1.8 * fps, conflict.frame - lead));
  }, [caption, eyebrow, side, focus, cameraPlan, captionEnter, sceneFrames, transitionOutFrames, fps]);

  const cam = cameraAt(cameraPlan, frame, viewport);
  const cursor = cursorAt(cursorPlan, frame);
  const toScreen = (x: number, y: number) => ({
    x: (x - cam.cx) * cam.z + viewport.width / 2,
    y: (y - cam.cy) * cam.z + viewport.height / 2,
  });

  // URL events fire before the new page paints; lag them so the pill matches the pixels.
  const now = sourceTimeAt(playback, frame, fps) - URL_PAINT_LAG;
  const currentUrl = [...urls].reverse().find((u) => u.t <= now) ?? urls[0];

  return (
    <AbsoluteFill>
      <Stage />
      <BrowserFrame url={currentUrl ? prettyUrl(currentUrl.url) : brand.host}>
        <div
          style={{
            position: "absolute",
            width: viewport.width,
            height: viewport.height,
            transformOrigin: "0 0",
            translate: `${viewport.width / 2 - cam.cx * cam.z}px ${viewport.height / 2 - cam.cy * cam.z}px`,
            scale: cam.z,
          }}
        >
          <Freeze frame={playback.playFrames - 1} active={(f) => f >= playback.playFrames}>
            <Video
              src={src}
              muted
              trimBefore={Math.round(playback.sourceStart * fps)}
              playbackRate={playback.rate}
              style={{ width: viewport.width, height: viewport.height }}
            />
          </Freeze>
        </div>
        {cursor ? <Cursor state={cursor} toScreen={toScreen} zoom={cam.z} /> : null}
      </BrowserFrame>
      {caption ? (
        <Caption
          text={caption}
          eyebrow={eyebrow}
          side={side}
          enterAt={captionEnter}
          exitAt={captionExit}
        />
      ) : null}
    </AbsoluteFill>
  );
};
