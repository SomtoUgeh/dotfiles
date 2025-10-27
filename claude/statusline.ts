#!/usr/bin/env bun

// @ts-ignore - Bun types are available at runtime
import { spawn } from "bun";

// Read JSON input from stdin
// @ts-ignore - Bun global is available at runtime
const input = await Bun.stdin.text();
const data = JSON.parse(input);

// Extract values
// @ts-ignore - Bun global is available at runtime
const currentDir = data.workspace?.current_dir || Bun.cwd();

// Pass original data unchanged to ccusage (don't add defaults)
const originalInput = input;

// Get ccusage status
const ccusageProcess = spawn(["bunx", "ccusage", "statusline"], {
  stdin: "pipe",
  stdout: "pipe",
  stderr: "pipe",
});

ccusageProcess.stdin.write(originalInput);
ccusageProcess.stdin.end();

const [ccusageOutput, ccusageError] = await Promise.all([
  new Response(ccusageProcess.stdout).text(),
  new Response(ccusageProcess.stderr).text()
]);

// Wait for ccusage process to finish
await ccusageProcess.exited;

// Use stdout if available, otherwise try to extract something meaningful from stderr
let ccusage = ccusageOutput.trim();
if (!ccusage && ccusageError) {
  // If ccusage failed, we could show a default message or try to parse the error
  ccusage = "ccusage: error";
}

// Extract just the model name from ccusage output (remove cost info)
// Assuming format like "model-name | $X.XX" or "model-name $X.XX"
let model = ccusage.split(/[|$]/)[0].trim();

// Get Claude Code version
let claudeVersion = "";
try {
  const versionProcess = spawn(["claude", "--version"], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const versionText = await new Response(versionProcess.stdout).text();
  await versionProcess.exited;

  // Extract version number (e.g., "1.0.72" from "1.0.72 (Claude Code)")
  const versionMatch = versionText.trim().match(/^([\d.]+)/);
  if (versionMatch) {
    claudeVersion = versionMatch[1];
  }
} catch {
  // Claude command not available, ignore
}

// Get git branch if in a git repo
let gitBranch = "";
try {
  // Check if we're in a git repo
  const gitCheckProcess = spawn(["git", "rev-parse", "--git-dir"], {
    stdout: "pipe",
    stderr: "pipe",
  });

  await new Response(gitCheckProcess.stdout).text();
  const gitCheckExitCode = await gitCheckProcess.exited;

  if (gitCheckExitCode === 0) {
    // Get current branch
    const branchProcess = spawn(["git", "branch", "--show-current"], {
      stdout: "pipe",
      stderr: "pipe",
    });

    const branchOutput = await new Response(branchProcess.stdout).text();
    await branchProcess.exited;
    gitBranch = branchOutput.trim();
  }
} catch {
  // Not in a git repo, ignore
}

// Get directory name (basename)
const dirName = currentDir.split("/").pop() || currentDir;

// Output the statusline
// Build the output parts
let output = `${model} | 📁 ${dirName}`;
if (gitBranch) {
  output += ` | 🌿 ${gitBranch}`;
}
if (claudeVersion) {
  output += ` | ⚡ v${claudeVersion}`;
}
console.log(output);
