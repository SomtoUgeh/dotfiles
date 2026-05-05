import { runCommand } from "./shared-hooks.js";

const AGENTS_ROOT = new URL("../../..", import.meta.url).pathname.replace(/\/$/, "");
const SHAPING_RIPPLE = new URL("../../../skills/shaping/shaping-ripple.sh", import.meta.url).pathname;

function runShapingRipple(filePath) {
  const payload = JSON.stringify({
    tool_input: {
      file_path: filePath,
    },
  });

  const result = runCommand(SHAPING_RIPPLE, [], payload, AGENTS_ROOT);
  if (result.status !== 2) {
    return "";
  }

  return result.stderr || "Shaping reminder triggered";
}

export const ShapingRipplePlugin = async ({ client }) => {
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
