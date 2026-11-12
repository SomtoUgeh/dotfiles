import { ALL_FORMATS, Input, UrlSource } from "mediabunny";
import { type CalculateMetadataFunction, staticFile } from "remotion";
import {
  type ClipMeta,
  type Playback,
  planPlayback,
  resolveSegment,
  trimTrailingNavigation,
} from "../lib/clip";
import { scripts, type ScriptId } from "../script";
import type { Scene, ScriptTiming, VideoScript } from "../script/types";

export type ResolvedApp = {
  readonly clip: ClipMeta;
  readonly src: string;
  readonly segment: { readonly start: number; readonly end: number };
  readonly playback: Playback;
};

export type ResolvedScene = {
  readonly scene: Scene;
  readonly durationInFrames: number;
  /** Frames at the end overlapped by the next scene's transition. */
  readonly transitionOutFrames: number;
  /** Frames at the start overlapped by the previous scene's transition. */
  readonly transitionInFrames: number;
  readonly voice: { readonly src: string; readonly startFrame: number; readonly seconds: number } | null;
  readonly app: ResolvedApp | null;
};

export type ResolvedVideo = {
  readonly transitionFrames: number;
  readonly scenes: readonly ResolvedScene[];
};

export type ScriptVideoProps = {
  readonly scriptId: ScriptId;
  /** "" for the script's own voice, or a variant folder suffix such as "daniel". */
  readonly voiceVariant: string;
  /** Filled in by calculateMetadata. */
  readonly resolved: ResolvedVideo | null;
};

// Footage leads: a scene lasts as long as its recording needs at `maxPlaybackRate`, and at least
// as long as its narration. Nothing is trimmed, and by default nothing runs faster than it was
// recorded.
const DEFAULT_TIMING: ScriptTiming = {
  voiceLeadIn: 0.55,
  voiceTail: 0.7,
  transitionSeconds: 0.6,
  maxPlaybackRate: 1,
};

const DEFAULT_MIN_SECONDS: Record<Scene["kind"], number> = {
  intro: 4.5,
  chapter: 3.4,
  app: 4,
  outro: 5,
};

type Manifest = { scenes: Record<string, { text: string; file: string } | undefined> };

const fetchJson = async <T,>(path: string, signal: AbortSignal): Promise<T | null> => {
  const res = await fetch(staticFile(path), { signal });
  if (!res.ok) return null;
  return (await res.json()) as T;
};

const audioSeconds = async (src: string) => {
  const input = new Input({ formats: ALL_FORMATS, source: new UrlSource(src) });
  try {
    return await input.computeDuration();
  } finally {
    input.dispose();
  }
};

const voiceFolder = (script: VideoScript, variant: string) =>
  variant ? `voiceover/${script.id}--${variant}` : `voiceover/${script.id}`;

export const calculateScriptMetadata: CalculateMetadataFunction<ScriptVideoProps> = async ({
  props,
  abortSignal,
}) => {
  const script: VideoScript = scripts[props.scriptId];
  const fps = 30;
  const timing = { ...DEFAULT_TIMING, ...script.timing };
  const transitionFrames = Math.round(timing.transitionSeconds * fps);
  const folder = voiceFolder(script, props.voiceVariant);

  const manifest = (await fetchJson<Manifest>(`${folder}/manifest.json`, abortSignal)) ?? {
    scenes: {},
  };

  const clipNames = [
    ...new Set(script.scenes.flatMap((s) => (s.kind === "app" ? [s.clip] : []))),
  ];
  const clips = new Map<string, ClipMeta>();
  await Promise.all(
    clipNames.map(async (name) => {
      const meta = await fetchJson<ClipMeta>(`clips/${name}.json`, abortSignal);
      if (!meta) throw new Error(`Missing public/clips/${name}.json — run npm run clips`);
      clips.set(name, meta);
    }),
  );

  const voices = await Promise.all(
    script.scenes.map(async (scene) => {
      const text = scene.voice?.trim();
      if (!text) return null;
      const entry = manifest.scenes[scene.id];
      if (!entry || entry.text !== text) {
        console.warn(
          `[voiceover] ${script.id}/${scene.id}: no fresh audio for current text — run npm run voiceover -- ${script.id}`,
        );
        return null;
      }
      const src = staticFile(`${folder}/${entry.file}`);
      return { src, seconds: await audioSeconds(src) };
    }),
  );

  const n = script.scenes.length;
  const scenes = script.scenes.map((scene, i): ResolvedScene => {
    const voice = voices[i];
    const transitionOutFrames = i < n - 1 ? transitionFrames : 0;
    const transitionInFrames = i > 0 ? transitionFrames : 0;
    const minSeconds = scene.minSeconds ?? DEFAULT_MIN_SECONDS[scene.kind];
    const voiceSeconds = voice ? timing.voiceLeadIn + voice.seconds + timing.voiceTail : 0;

    let segment: { start: number; end: number } | null = null;
    let clip: ClipMeta | null = null;
    let maxRate = timing.maxPlaybackRate;
    if (scene.kind === "app") {
      clip = clips.get(scene.clip) ?? null;
      if (!clip) throw new Error(`Clip ${scene.clip} not loaded`);
      const resolved = resolveSegment(clip, scene.from, scene.to);
      segment = scene.keepNavigation === true ? resolved : trimTrailingNavigation(clip, resolved);
      maxRate = scene.maxPlaybackRate ?? timing.maxPlaybackRate;
    }
    // Room for the whole recording at its allowed speed, plus a beat to read the final screen.
    const footageSeconds = segment
      ? (segment.end - segment.start) / maxRate + (scene.kind === "app" ? (scene.holdSeconds ?? 0.8) : 0)
      : 0;
    const coreSeconds = Math.max(minSeconds, voiceSeconds, footageSeconds);
    // The outgoing transition overlaps the next scene, so add it on top of the core length.
    const durationInFrames = Math.ceil(coreSeconds * fps) + transitionOutFrames;

    let app: ResolvedApp | null = null;
    if (scene.kind === "app" && clip && segment) {
      app = {
        clip,
        src: staticFile(`clips/${scene.clip}.mp4`),
        segment,
        playback: planPlayback({
          ...segment,
          sceneFrames: durationInFrames,
          fps,
          maxRate,
          trim: scene.trim ?? "end",
        }),
      };
    }

    return {
      scene,
      durationInFrames,
      transitionOutFrames,
      transitionInFrames,
      voice: voice
        ? { src: voice.src, seconds: voice.seconds, startFrame: Math.round(timing.voiceLeadIn * fps) }
        : null,
      app,
    };
  });

  const total =
    scenes.reduce((sum, s) => sum + s.durationInFrames, 0) - transitionFrames * Math.max(0, n - 1);

  // Scene map for stills and review: start frame, length and footage speed.
  let start = 0;
  const map = scenes.map((s) => {
    const sceneSeconds = (s.durationInFrames - s.transitionOutFrames) / fps;
    const spare = s.voice ? sceneSeconds - timing.voiceLeadIn - s.voice.seconds : sceneSeconds;
    const row = `${s.scene.id}@${start}+${s.durationInFrames} ${sceneSeconds.toFixed(1)}s voice=${
      s.voice ? s.voice.seconds.toFixed(1) : "none"
    } spare=${spare.toFixed(1)}${
      s.app ? ` footage=${(s.app.segment.end - s.app.segment.start).toFixed(1)}` : ""
    }`;
    start += s.durationInFrames - s.transitionOutFrames;
    return row;
  });
  console.log(`[timeline] ${script.id}: ${map.join(" | ")}`);

  return {
    fps,
    durationInFrames: total,
    defaultOutName: script.id,
    props: { ...props, resolved: { transitionFrames, scenes } },
  };
};
