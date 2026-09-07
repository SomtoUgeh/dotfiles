import { runCommand } from "./shared-hooks.js";
import { fileURLToPath } from "node:url";

const AGENTS_ROOT = fileURLToPath(new URL("../../..", import.meta.url));
const GIT_GUARD = fileURLToPath(new URL("../git_guard.py", import.meta.url));
const SHELL_TOOLS = new Set(["bash", "shell", "exec_command"]);

function inspectCommand(command) {
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

function commandFromInput(input) {
  if (!input || typeof input !== "object") {
    return "";
  }
  const command = input.command ?? input.cmd;
  return typeof command === "string" ? command : "";
}

function blockedShellMessage(tool, input) {
  if (!SHELL_TOOLS.has(tool)) {
    return "";
  }
  const command = commandFromInput(input);
  if (!command) {
    return "";
  }
  return inspectCommand(command);
}

export default {
  id: "git-guard",
  async setup(ctx) {
    await ctx.tool.hook("execute.before", async (event) => {
      const message = blockedShellMessage(event.tool, event.input);
      if (message) {
        throw new Error(message);
      }
    });
  },
};
