import type { Plugin } from "@opencode-ai/plugin";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { getSessionID, runCommand } from "./shared-hooks";

const PLUGIN_DIR = path.dirname(fileURLToPath(import.meta.url));
const AGENTS_ROOT = path.resolve(PLUGIN_DIR, "..", "..", "..");
const PLANNOTATOR = path.resolve(process.env.HOME ?? "", ".local", "bin", "plannotator");
const STOP_SESSION_IDS = new Set<string>();

function runPlannotator(sessionID: string): string {
  if (!PLANNOTATOR) {
    return "plannotator path is not configured";
  }

  if (STOP_SESSION_IDS.has(sessionID)) {
    return "";
  }

  const result = runCommand(PLANNOTATOR, [], undefined, AGENTS_ROOT);
  if (result.status !== 0) {
    return result.stderr || "plannotator returned a non-zero status";
  }

  STOP_SESSION_IDS.add(sessionID);
  return "";
}

export const PlannotatorPlugin: Plugin = async ({ client }) => {
  await client.app.log({
    body: {
      service: "shared-hooks",
      level: "info",
      message: "OpenCode plannotator hooks initialized",
    },
  });

  return {
    event: async ({ event }) => {
      const sessionID = getSessionID(event);

      if (event.type === "session.created") {
        STOP_SESSION_IDS.delete(sessionID);
        return;
      }

      if (event.type === "session.deleted") {
        STOP_SESSION_IDS.delete(sessionID);
        return;
      }

      if (event.type === "session.idle" && sessionID) {
        const message = runPlannotator(sessionID);
        if (!message) {
          return;
        }

        await client.app.log({
          body: {
            service: "shared-hooks",
            level: "warn",
            message: `Plannotator invocation failed for ${sessionID}: ${message}`,
          },
        });
      }
    },
  };
};
