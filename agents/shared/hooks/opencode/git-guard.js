import { runCommand } from "./shared-hooks.js";

const AGENTS_ROOT = new URL("../../..", import.meta.url).pathname.replace(/\/$/, "");
const GIT_GUARD = new URL("../git_guard.py", import.meta.url).pathname;

function runGitGuard(command) {
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
          message: `Blocked destructive command: ${command.slice(0, 100)}`,
          extra: { message },
        },
      });

      throw new Error(message);
    },
  };
};
