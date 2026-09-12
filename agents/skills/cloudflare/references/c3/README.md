# C3 (create-cloudflare)

Official CLI for scaffolding Cloudflare Workers and Pages projects with templates, TypeScript, and instant deployment.

## Quick Start

```bash
# Interactive (recommended for first-time)
npm create cloudflare@latest my-app

# Worker (API/WebSocket/Cron)
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts

# Pages (static/SSG/full-stack)
npm create cloudflare@latest my-site -- --framework=astro --platform=pages
```

## Platform Selection

- New API, WebSocket, scheduled, or email Worker: use Workers (C3 default).
- New static or full-stack site: check the framework's supported Workers setup, including Static Assets. Use Pages when the user or existing deployment targets Pages and the framework supports it; specify `--platform=pages`.
- Git builds and branch previews alone do not require Pages: [Workers Builds](https://developers.cloudflare.com/workers/ci-cd/builds/) also supports Git integration.
- Download a deployed Worker into a new local directory: use `--existing-script=my-existing-worker`. This downloads deployed code; it does not convert local source.
- Adapt an existing local app: inspect its current framework/configuration and use the matching [Workers framework guide](https://developers.cloudflare.com/workers/framework-guides/). Do not scaffold over an existing application as a generic migration step.

Verify flags against the selected C3 version's help. See [C3 documentation](https://developers.cloudflare.com/pages/get-started/c3/) for platform selection and deployed-script cloning.

## Interactive Flow

When run without flags, C3 prompts in this order:

1. **Project name** - Directory to create (defaults to current dir with `.`)
2. **Application type** - `hello-world`, `web-app`, `demo`, `pre-existing`, `remote-template`
3. **Platform** - `workers` (default) or `pages` (for web apps only)
4. **Framework** - If web-app: `next`, `tanstack-start`, `astro`, `react-router`, `solid`, `svelte`, etc.
5. **TypeScript** - `yes` (recommended) or `no`
6. **Git** - Initialize repository? `yes` or `no`
7. **Deploy** - Deploy now? `yes` or `no` (requires `wrangler login`)

## Installation Methods

```bash
# NPM
npm create cloudflare@latest

# Yarn
yarn create cloudflare

# PNPM
pnpm create cloudflare@latest
```

## In This Reference

| File | Purpose | Use When |
|------|---------|----------|
| **api.md** | Complete CLI flag reference | Scripting, CI/CD, advanced usage |
| **configuration.md** | Generated files, bindings, types | Understanding output, customization |
| **patterns.md** | Workflows, CI/CD, monorepos | Real-world integration |
| **gotchas.md** | Troubleshooting failures | Deployment blocked, errors |

## Reading Order

| Task | Read |
|------|------|
| Create first project | README only |
| Set up CI/CD | README → api → patterns |
| Debug failed deploy | gotchas |
| Understand generated files | configuration |
| Full CLI reference | api |
| Create custom template | patterns → configuration |
| Download deployed Worker or adapt local app | Platform Selection above → patterns |

## Post-Creation

Inspect generated package scripts; the commands below illustrate a Worker project and vary by framework.

```bash
cd my-app

# Local dev with hot reload
npm run dev

# Generate TypeScript types for bindings
npm run cf-typegen

# Deploy to Cloudflare
npm run deploy
```

## See Also

- **workers/README.md** - Workers runtime, bindings, APIs
- **workers-ai/README.md** - AI/ML models
- **pages/README.md** - Pages-specific features
- **wrangler/README.md** - Wrangler CLI beyond initial setup
- **d1/README.md** - SQLite database
- **r2/README.md** - Object storage
