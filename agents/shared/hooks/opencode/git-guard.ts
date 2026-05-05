import type { Plugin } from "@opencode-ai/plugin";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { runCommand } from "./shared-hooks";

const PLUGIN_DIR = path.dirname(fileURLToPath(import.meta.url));
const AGENTS_ROOT = path.resolve(PLUGIN_DIR, "..", "..", "..");
const SHARED_HOOKS_DIR = path.resolve(AGENTS_ROOT, "shared", "hooks");
const GIT_GUARD = path.resolve(SHARED_HOOKS_DIR, "git_guard.py");

function runGitGuard(command: string): string {
  const payload = JSON.stringify({
    tool: "bash",
    tool_input: {
      command,
    },
  });

  const result = runCommand("python3", [GIT_GUARD], payload, AGENTS_ROOT);
  if (result.status !== 2) {
    return "";
  }

  return result.stderr || "Blocked by git guard";
}

export const GitGuardPlugin: Plugin = async ({ client }) => {
  await client.app.log({
    body: {
      service: "shared-hooks",
      level: "info",
      message: "OpenCode Git guard hooks initialized",
    },
  });

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") {
        return;
      }

      const command = typeof output.args?.command === "string" ? output.args.command : "";
      if (!command) {
        return;
      }

      const message = runGitGuard(command);
      if (!message) {
        return;
      }

      await client.app.log({
        body: {
          service: "shared-hooks",
          level: "warn",
          message: `Blocked destructive command: ${command.slice(0, 100)}`,
          extra: { message },
        },
      });

      throw new Error(message);
    },
  };
};
