const textDecoder = new TextDecoder();
const textEncoder = new TextEncoder();

export function runCommand(command, args = [], input, cwd) {
  try {
    if (typeof Bun === "undefined") {
      return {
        status: null,
        stderr: "OpenCode shared hooks require the Bun runtime",
      };
    }

    const result = Bun.spawnSync([command, ...args], {
      stdin: input ? textEncoder.encode(input) : undefined,
      cwd,
    });

    return {
      status: result.exitCode,
      stderr: result.stderr ? textDecoder.decode(result.stderr).trim() : "",
    };
  } catch (error) {
    return {
      status: null,
      stderr: error instanceof Error ? error.message : "Unknown command error",
    };
  }
}

export function getSessionID(eventData) {
  return eventData.sessionID ?? eventData.properties?.sessionID ?? "";
}
