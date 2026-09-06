import { runCommand } from "./shared-hooks.js";
import { fileURLToPath } from "node:url";

const SHAPING_RIPPLE = fileURLToPath(new URL("../../../skills/shaping/shaping-ripple.sh", import.meta.url));

function runShapingRipple(tool, args, directory) {
  const payload = JSON.stringify({
    tool_name: tool,
    tool_input: args,
    cwd: directory,
  });

  const result = runCommand(SHAPING_RIPPLE, [], payload, directory);
  if (result.status === 0) {
    return "";
  }
  if (result.status !== 2) {
    return `Shaping ripple check failed: ${result.stderr || "unknown process failure"}`;
  }

  return result.stderr || "Shaping reminder triggered";
}

export const ShapingRipplePlugin = async ({ client, directory }) => {
  await client.app.log({
    body: {
      service: "shared-hooks",
      level: "info",
      message: "OpenCode shaping ripple hooks initialized",
    },
  });

  return {
    "tool.execute.after": async (input, output) => {
      const isPatch = input.tool === "apply_patch" && typeof input.args?.patchText === "string";
      const isMarkdownEdit = (input.tool === "edit" || input.tool === "write")
        && typeof input.args?.filePath === "string" && input.args.filePath.endsWith(".md");
      if (!isPatch && !isMarkdownEdit) {
        return;
      }

      const message = runShapingRipple(input.tool, input.args, directory);
      if (!message) {
        return;
      }

      output.output = [output.output, message].filter(Boolean).join("\n\n");
      await client.app.log({
        body: {
          service: "shared-hooks",
          level: "info",
          message: `Shaping ripple result emitted for ${input.tool}`,
        },
      });
    },
  };
};
