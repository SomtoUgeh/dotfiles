import type { Plugin } from "@opencode-ai/plugin";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { runCommand } from "./shared-hooks";

const PLUGIN_DIR = path.dirname(fileURLToPath(import.meta.url));
const DOTFILES_ROOT = path.resolve(PLUGIN_DIR, "..", "..");
const SHAPING_RIPPLE = path.resolve(DOTFILES_ROOT, "agents", "skills", "shaping", "shaping-ripple.sh");

function runShapingRipple(filePath: string): string {
  const payload = JSON.stringify({
    tool_input: {
      file_path: filePath,
    },
  });

  const result = runCommand(SHAPING_RIPPLE, [], payload, DOTFILES_ROOT);
  if (result.status !== 2) {
    return "";
  }

  return result.stderr || "Shaping reminder triggered";
}

export const ShapingRipplePlugin: Plugin = async ({ client }) => {
  await client.app.log({
    body: {
      service: "shared-hooks",
      level: "info",
      message: "OpenCode shaping ripple hooks initialized",
    },
  });

  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "edit" && input.tool !== "write") {
        return;
      }

      const filePath = typeof input.args?.filePath === "string" ? input.args.filePath : "";
      if (!filePath.endsWith(".md")) {
        return;
      }

      const message = runShapingRipple(filePath);
      if (!message) {
        return;
      }

      output.output = [output.output, message].filter(Boolean).join("\n\n");
      await client.app.log({
        body: {
          service: "shared-hooks",
          level: "info",
          message: `Shaping ripple reminder emitted for ${filePath}`,
        },
      });
    },
  };
};
