import { example } from "./example";
import type { VideoScript } from "./types";

/**
 * Register each script here. The key is the composition id and must equal the script's
 * `id` and its file name (src/script/<id>.ts). Use letters, digits and hyphens only.
 */
export const scripts = {
  example,
} satisfies Record<string, VideoScript>;

export type ScriptId = keyof typeof scripts;
