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

function shouldInspect(tool, args) {
  if (!args || typeof args !== "object") {
    return false;
  }
  if (tool === "apply_patch") {
    return typeof (args.patchText ?? args.command ?? args.patch) === "string";
  }
  if (tool === "edit" || tool === "write") {
    const path = args.filePath ?? args.file_path;
    return typeof path === "string" && path.endsWith(".md");
  }
  return false;
}

function rippleMessage(tool, args, directory) {
  if (!shouldInspect(tool, args)) {
    return "";
  }
  return runShapingRipple(tool, args, directory);
}

function appendReminder(value, message) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    if (typeof value.output === "string") {
      value.output = [value.output, message].filter(Boolean).join("\n\n");
      return value;
    }
    if (typeof value.content === "string") {
      value.content = [value.content, message].filter(Boolean).join("\n\n");
      return value;
    }
    if (Array.isArray(value.content)) {
      value.content = [...value.content, { type: "text", text: message }];
      return value;
    }
    value.content = message;
    return value;
  }
  if (typeof value === "string") {
    return [value, message].filter(Boolean).join("\n\n");
  }
  return message;
}

export default {
  id: "shaping-ripple",
  async setup(ctx) {
    const directory = ctx.location?.directory;
    if (!directory) {
      return;
    }
    await ctx.tool.hook("execute.after", async (event) => {
      if (event.status === "error") {
        return;
      }
      const message = rippleMessage(event.tool, event.input, directory);
      if (!message) {
        return;
      }
      event.result = appendReminder(event.result, message);
    });
  },
};
