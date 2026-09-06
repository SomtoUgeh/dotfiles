---
name: efficient-frontier
description: Coordinate broad work through independent, bounded subagents while keeping decomposition, integration, and final review with the lead agent. Use when delegation reduces a concrete research, implementation, or verification bottleneck.
---

# Efficient Frontier

Keep judgment and integration with the lead agent. Delegate independent work
when the active runtime supports it and useful local work can proceed alongside
it. Use the selected model and available capabilities; this workflow does not
require a provider, model tier, or model switch. Resolve tools through
[runtime equivalents](../RUNTIME_TOOLS.md).

## Workflow

1. Identify the lead's decisions: architecture, prioritization,
   ambiguity resolution, risk, synthesis, and final review.
2. Identify delegable work: research scans, repository inventory, search, docs
   extraction, browser/testing passes, log reduction, test failure clustering,
   narrow coding, and mechanical edits.
3. Assign independent slices with clear file ownership, bounded scope,
   verification, and expected evidence. Tell workers they share the workspace
   and must preserve others' edits. Respect dependencies and concurrency limits.
4. Require compact returns: findings, changed files, commands run, residual
   risk, stop conditions hit, and anything the lead must decide.
5. Integrate and review centrally before presenting the result.

## Handoff Packets

Write delegated prompts as self-contained packets. Assume the receiving agent
has not seen the conversation. Include the repo path, objective, scope,
out-of-scope areas, relevant files or search targets, expected return format,
verification commands, and stop conditions.

Useful stop conditions:

- The live code does not match the assumption in the handoff.
- A verification command fails repeatedly without new evidence; change the
  approach or report the blocker rather than repeating it.
- The work appears to require files outside the assigned scope.
- The agent cannot produce concrete evidence for its claim.

## Review Loop

Treat delegated output as evidence to inspect, not a verdict to forward. Reopen
important cited files, skim high-risk diffs, and rerun or spot-check the
verification that matters before claiming completion. If delegated agents
disagree, inspect the conflicting evidence and resolve it with the lead. Keep
one lead reviewer; do not recursively delegate another full review tree.

## Common Scenarios

Use these as soft suggestions:

- Research: delegate broad repo scans, docs extraction, and source comparison;
  the lead keeps the judgment about what matters.
- Coding: delegate bounded patches, refactors, or mechanical edits when file
  ownership is clear; integrate and review centrally.
- Testing: let the lead choose the validation strategy and scripts,
  then use suitably capable agents to run unit checks, browser flows,
  screenshots, and log reduction. Ask for exact commands, failures, likely causes, and
  whether the signal looks flaky, environmental, or product-relevant.
- Debugging: send independent agents after separate theories, logs, or repro
  paths; keep the final diagnosis with the lead.

## Guardrails

- Do not delegate the immediate blocker if your next step depends on it.
- Do not ask multiple agents to edit the same files at the same time.
- Do not trust subagent conclusions blindly when the risk is high; inspect the
  important evidence yourself.
- Keep tiny or highly coupled tasks local. If delegation is unavailable, do
  the work locally and disclose when a requested independent check was not possible.
- Report savings only when measured. Parallelism can reduce elapsed time;
  coordination and repeated context also cost time and tokens.
