import { spawnSync } from "node:child_process";

export type EventData = {
  sessionID?: string;
  properties?: {
    sessionID?: string;
  };
};

export type GuardResult = {
  status: number | null;
  stderr: string;
};

export function runCommand(command: string, args: string[] = [], input?: string, cwd?: string): GuardResult {
  try {
    const result = spawnSync(command, args, {
      input,
      encoding: "utf8",
      cwd,
      shell: false,
    });

    if (result.error) {
      return {
        status: result.status,
        stderr: result.error.message,
      };
    }

    return {
      status: result.status,
      stderr: result.stderr ? result.stderr.toString().trim() : "",
    };
  } catch (error) {
    return {
      status: null,
      stderr: error instanceof Error ? error.message : "Unknown command error",
    };
  }
}

export function getSessionID(eventData: EventData): string {
  return eventData.sessionID ?? eventData.properties?.sessionID ?? "";
}
