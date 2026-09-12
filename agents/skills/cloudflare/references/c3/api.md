# C3 CLI Reference

## Invocation

```bash
npm create cloudflare@latest [name] [-- flags]  # NPM requires --
yarn create cloudflare [name] [flags]
pnpm create cloudflare@latest [name] [-- flags]
```

## Core Flags

| Flag | Values | Description |
|------|--------|-------------|
| `--type` | `hello-world`, `hello-world-assets-only`, `hello-world-with-assets`, `scheduled`, `queues`, `pre-existing`, and other values from `--help` | Built-in template |
| `--platform` | `workers` (default), `pages` | Target platform |
| `--framework` | `next`, `tanstack-start`, `astro`, `react-router`, `solid`, `svelte`, `qwik`, `vue`, `angular`, `hono` | Web framework (sets the web-framework category) |
| `--lang` | `ts`, `js`, `python` | Language (for `--type=hello-world`) |
| `--lang=ts` / `--no-ts` | - | TypeScript for web apps |

## Deployment Flags

| Flag | Description |
|------|-------------|
| `--deploy` / `--no-deploy` | Deploy immediately (prompts interactive, skips in CI) |
| `--git` / `--no-git` | Initialize git (default: yes) |
| `--open` | Open browser after deploy |

## Advanced Flags

| Flag | Description |
|------|-------------|
| `--template=https://github.com/user/repo` | A degit-compatible repository URL; optionally pin a ref |
| `--template-mode=git` or `tar` | Template download mechanism |
| `--existing-script=my-worker` | Download an existing deployed Worker by name, not a local file |
| `--category` | `hello-world`, `web-framework`, `demo`, or `remote-template` |
| `--accept-defaults` | Answer unspecified prompts with defaults; pair with `--no-deploy` |
| `--no-agents` | Do not create an AGENTS.md file |
| `--no-auto-update` | Use the selected C3 version |

## Environment Variables

```bash
CLOUDFLARE_API_TOKEN=xxx    # For deployment
CLOUDFLARE_ACCOUNT_ID=xxx   # Account ID
CREATE_CLOUDFLARE_TELEMETRY_DISABLED=1     # Disable telemetry
```

## Exit Codes

Check the process exit status and error output; do not assume every release distinguishes cancellation from failure with these specific codes.

## Examples

```bash
# TypeScript Worker
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --no-deploy

# Next.js on Workers
npm create cloudflare@latest my-app -- --framework=next --platform=workers --lang=ts

# Astro blog
npm create cloudflare@latest my-blog -- --framework=astro --lang=ts --deploy

# CI: non-interactive
npm create cloudflare@latest my-app -- --framework=next --lang=ts --no-git --no-deploy --accept-defaults

# GitHub template
npm create cloudflare@latest -- --template=cloudflare/templates/worker-openapi

# Download deployed Worker into a new directory
npm create cloudflare@latest my-worker-copy -- --existing-script=my-existing-worker
```


For local app adaptation, use the framework migration guidance in [README.md](README.md#platform-selection). Verify flags with the selected CLI help and [C3 docs](https://developers.cloudflare.com/pages/get-started/c3/).
