# Access And Docs

Use this at the start of an Erivault investigation.

## Contents

- Read local authority first
- Access checklist
- Environment checklist
- Local, dev, and prod access
- Secret handling
- When access is missing

## Read Local Authority First

Before using live systems, read the local files that define intent:
- `AGENTS.md` in the repo root and any nested package instructions
- nearby `README.md` files for the app, worker, or package
- `docs/adr/` for ownership and boundary decisions
- product `spec.md`, implementation notes, or docs for the feature area
- Alchemy infrastructure code for worker, queue, R2, Durable Object, and binding topology
- tests near the feature, especially contract tests and e2e coverage

For Erivault, do not infer ownership from whichever worker received the request. Product/domain code owns product truth; workers and transports should be narrow services.

## Access Checklist

Confirm only the access needed for the investigation:

| Surface | What To Check | Evidence |
|---------|---------------|----------|
| GitHub | branch, commit, PR, deployment SHA | `git status`, `git log`, `gh` if available |
| Cloudflare account | correct account and environment | `wrangler whoami`, dashboard, or Cloudflare MCP |
| Alchemy | stage and resource graph | deploy scripts and Alchemy files |
| Worker logs | web app, capture, assets, agent orchestration | tail logs with request IDs and timestamps |
| Queues | pending, retry, dead-letter or terminal state | Cloudflare queue dashboard or logs |
| Workflows | instance status and step output | Cloudflare workflow instances |
| Durable Objects | live handoff or websocket state | request logs and DO-specific errors |
| R2 | object exists, metadata, checksum, content type | R2 dashboard, worker route, or signed internal read |
| AI Gateway | request count, model response, gateway IDs | AI Gateway logs with safe metadata |
| Neon Postgres | product rows and migrations | Neon MCP or approved local database URL |
| Browser/mobile | user-visible behavior | screenshot, network requests, refresh/reconnect proof |

## Environment Checklist

Always name the environment:
- local dev
- Cloudflare dev deployment
- production deployment
- mobile simulator or physical device
- desktop authenticated flow
- guest handoff flow

Check whether the URL host and worker name actually match the environment. In Erivault, a production-looking host can still route through a dev worker during testing.

## Local, Dev, And Prod Access

Use the same diagnostic shape in every environment, but gather evidence from the environment-appropriate surface.

| Environment | Primary Evidence | Notes |
|-------------|------------------|-------|
| local | dev server terminal, local worker output, local DB, browser network, local object emulator or bound dev resources | Read repo scripts first. Do not assume deployed Cloudflare dashboards include local-only failures. |
| dev | Cloudflare dev workers, dev queues/workflows/R2, dev Neon branch or configured database, dev deploy commit | Verify the worker script name and route before tailing. |
| prod | production workers, prod queues/workflows/R2, prod Neon, production deploy commit | Minimize data exposure. Prefer safe IDs, counts, statuses, and redacted metadata. |

For Cloudflare-specific evidence in any environment, use `cloudflare-operations.md`.

## Secret Handling

Do not paste or summarize:
- database URLs
- API keys or tokens
- Better Auth secrets
- Cloudflare tokens
- private R2 URLs
- raw evidence bytes
- raw personal data
- full AI provider responses if they contain private media or user data

Use safe identifiers instead: request ID, workflow ID, asset ID, evidence ID, target ID, handoff ID, or redacted object key.

## When Access Is Missing

If a surface cannot be accessed:
1. Say exactly which proof is missing.
2. Continue with repo, DB, browser, or log evidence that is available.
3. Avoid turning inference into fact.
4. Recommend the smallest access or diagnostic addition that would close the gap.
