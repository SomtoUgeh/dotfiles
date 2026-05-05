import { getSessionID, runCommand } from "./shared-hooks.js";

const AGENTS_ROOT = new URL("../../..", import.meta.url).pathname.replace(/\/$/, "");
const PLANNOTATOR = `${process.env.HOME ?? ""}/.local/bin/plannotator`;
const STOP_SESSION_IDS = new Set();

function runPlannotator(sessionID) {
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

export const PlannotatorPlugin = async ({ client }) => {
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
