/**
 * Scene-list format. One file per video in this folder (e.g. example.ts)
 * holds every scene, its copy and its voice line. `scripts/voiceover.mjs` reads the
 * same file, so keep script files data-only: no runtime imports (type imports only).
 */

/** A CSS-pixel rectangle in the recorded 1440x900 viewport. */
export type Box = {
  readonly x: number;
  readonly y: number;
  readonly width: number;
  readonly height: number;
};

/** A beat id from the clip's events JSON, or an explicit time in seconds. */
export type ClipTimeRef = string | number;

/**
 * Camera behaviour for an app scene.
 * - "auto": zoom toward clusters of click/type/hover events, release on navigation or long gaps.
 * - "off": always full frame.
 * - { region }: hold a fixed region (CSS px) for the whole scene. `zoom` overrides the fitted level.
 */
export type ZoomMode =
  | "auto"
  | "off"
  | { readonly region: Box; readonly zoom?: number };

export type CaptionPlacement = "auto" | "bottom-left" | "bottom-right";

type SceneBase = {
  /** Stable id; also the voiceover file name (public/voiceover/<video>/<id>.wav). */
  readonly id: string;
  /** Voiceover line. Omit for a silent scene. */
  readonly voice?: string;
  /** Minimum on-screen seconds, used when the voice is short or absent. */
  readonly minSeconds?: number;
};

export type IntroScene = SceneBase & {
  readonly kind: "intro";
  readonly title: string;
  readonly subtitle?: string;
};

export type ChapterScene = SceneBase & {
  readonly kind: "chapter";
  /** Small label above the title, e.g. "Chapter 1". */
  readonly eyebrow?: string;
  readonly title: string;
};

export type OutroScene = SceneBase & {
  readonly kind: "outro";
  readonly tagline: string;
  readonly url: string;
};

export type AppScene = SceneBase & {
  readonly kind: "app";
  /** Clip name: public/clips/<clip>.mp4 + <clip>.json. */
  readonly clip: string;
  /** Segment start: beat id or seconds. */
  readonly from: ClipTimeRef;
  /** Segment end: beat id or seconds. Defaults to the beat after `from`. */
  readonly to?: ClipTimeRef;
  /** Short on-screen phrase that interprets the screen (2–4 words). */
  readonly caption?: string;
  /** Optional small label above the caption. */
  readonly eyebrow?: string;
  readonly captionPlacement?: CaptionPlacement;
  readonly zoom?: ZoomMode;
  /** Fastest allowed speed-up before trimming (default from script timing). */
  readonly maxPlaybackRate?: number;
  /**
   * Keep the navigation into the next page when it falls in the last ~1.2 s of the segment.
   * Default false: the segment stops just before it and the cross-fade carries the change.
   */
  readonly keepNavigation?: boolean;
  /** Seconds the last frame stays on screen after the recording ends (default 0.8). */
  readonly holdSeconds?: number;
  /** Which end to cut when the segment is still too long at max speed. */
  readonly trim?: "end" | "start";
};

export type Scene = IntroScene | ChapterScene | OutroScene | AppScene;

export type VoiceSettings = {
  readonly stability: number;
  readonly similarity_boost: number;
  readonly style: number;
  readonly use_speaker_boost: boolean;
};

export type ScriptTiming = {
  /** Seconds of silence before the voice starts in each scene. */
  readonly voiceLeadIn: number;
  /** Seconds of breathing room after the voice ends. */
  readonly voiceTail: number;
  /** Cross-fade length between scenes, in seconds. */
  readonly transitionSeconds: number;
  /** Default speed-up ceiling for footage. */
  readonly maxPlaybackRate: number;
};

export type VideoScript = {
  /** Composition id and voiceover folder name. */
  readonly id: string;
  readonly voice?: {
    /** ElevenLabs voice id. Default: voiceId in voice.config.json. */
    readonly voiceId?: string;
    /** ElevenLabs model id. Default: model in voice.config.json. */
    readonly model?: string;
    readonly settings?: Partial<VoiceSettings>;
  };
  readonly timing?: Partial<ScriptTiming>;
  readonly scenes: readonly Scene[];
};
