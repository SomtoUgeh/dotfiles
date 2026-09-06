import { runCommand } from "./shared-hooks.js";
import { fileURLToPath } from "node:url";

const AGENTS_ROOT = fileURLToPath(new URL("../../..", import.meta.url));
const GIT_GUARD = fileURLToPath(new URL("../git_guard.py", import.meta.url));

function runGitGuard(command) {
  const payload = JSON.stringify({
    tool: "bash",
    tool_input: {
      command,
    },
  });

  const result = runCommand("uv", ["run", "--script", GIT_GUARD], payload, AGENTS_ROOT);
  if (result.status === 0) {
    return "";
  }

  return result.stderr || "Git guard could not inspect the command";
}

export const GitGuardPlugin = async ({ client }) => {
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
          message: "Git guard blocked a shell command",
          extra: { message },
        },
      });

      throw new Error(message);
    },
  };
};
