---
name: wrangler
description: Cloudflare Workers CLI for deploying, developing, and managing Workers, KV, R2, D1, Vectorize, Hyperdrive, Workers AI, Containers, Queues, Workflows, Pipelines, and Secrets Store. Load before running wrangler commands to ensure correct syntax and best practices. Biases towards retrieval from Cloudflare docs over pre-trained knowledge.
---

# Wrangler CLI

Your knowledge of Wrangler CLI flags, config fields, and subcommands may be outdated. **Prefer retrieval over pre-training** for any Wrangler task.

## Retrieval Sources

Fetch the **latest** information before writing or reviewing Wrangler commands and config. Do not rely on baked-in knowledge for CLI flags, config fields, or binding shapes.

| Source | How to retrieve | Use for |
|--------|----------------|---------|
| Wrangler docs | `https://developers.cloudflare.com/workers/wrangler/` | CLI commands, flags, config reference |
| Wrangler config schema | `node_modules/wrangler/config-schema.json` | Config fields, binding shapes, allowed values |
| Cloudflare docs | Search tool or `https://developers.cloudflare.com/workers/` | API reference, compatibility dates/flags |

## Check the project toolchain first

Inspect the package manifest, lockfile, scripts, and installed Wrangler version.
Use the project's installed executable or package script; a bare `wrangler`
command below is shorthand for that verified invocation. Do not run an `npx`
command that downloads a package merely to answer a question.

Install or update Wrangler only when required by authorized implementation,
using the project's package manager and compatible version. Prefer existing
Wrangler commands over custom API wrappers when they meet the task safely.

## Key Guidelines

- **Use `wrangler.jsonc`**: Prefer JSON config over TOML. Newer features are JSON-only.
- **Set `compatibility_date`**: Preserve an existing tested date; choose the current date for a new project and verify compatibility changes before updating. Check https://developers.cloudflare.com/workers/configuration/compatibility-dates/
- **Generate types after config changes**: Run `wrangler types` to update TypeScript bindings.
- **Local dev defaults to local storage**: Bindings use local simulation unless `remote: true`.
- **Profile Worker startup**: Run `wrangler check startup` to measure startup time and detect scripts that exceed the startup time limit.
- **Use environments for staging/prod**: Define `env.staging` and `env.production` in config.

## Quick Start: New Worker

```bash
# Initialize new project
npx wrangler init my-worker

# Or with a framework
npx create-cloudflare@latest my-app
```

## Quick Reference: Core Commands

| Task | Command |
|------|---------|
| Start local dev server | `wrangler dev` |
| Deploy to Cloudflare | `wrangler deploy` |
| Deploy dry run | `wrangler deploy --dry-run` |
| Generate TypeScript types | `wrangler types` |
| Profile Worker startup time | `wrangler check startup` |
| View live logs | `wrangler tail` |
| Delete Worker | `wrangler delete` |
| Auth status | `wrangler whoami` |

---

## Task-specific command reference

Load only the relevant section in [commands.md](references/commands.md):
configuration and types; local development; deployment and secrets; KV; R2; D1;
Vectorize; Hyperdrive; Workers AI; Queues; Containers; Workflows; Pipelines;
Secrets Store; Pages; observability; testing; or troubleshooting.

Check the account, environment, and local/remote target before a mutation.
Never put secret values in command arguments, logs, or committed config.
Hyperdrive credential setup uses the dashboard or an approved API integration;
its CLI password flags are not a protected secret-input channel.
