# Executor: shared MCP setup

Executor owns the tool catalog, upstream authentication, and per-tool policies.
Codex, Grok Build, Cursor, Claude Code, and OpenCode use `executor_cloud` for internet
services and `executor` for desktop tools. The local stdio adapter discovers the
background service without storing its port or bearer token in client configs.
The cloud stdio adapter connects to the shared Cloudflare URL and handles each
device's sign-in.

Skills, hooks, plugins, language servers, and app-specific tools retain their
existing owners. Executor does not make every managed connector portable.
The AltSchool VM also uses both gateways, with its own Linux-local tools.
All five Mac agents have an `executor_cloud` entry. See the
[Cloudflare guide](cloud.md) for device setup, verified services and pending
migration checks. All fourteen verified internet-service duplicates are removed
locally; only desktop tools and temporary Canva remain in the local catalog.

Start with [Executor on a new computer](new-computer.md) for the onboarding checklist.

## Install and connect

Verified with Executor **1.6.8**, on macOS, 12 September 2026. Check released CLI
help before upgrading: some website examples use obsolete command names.

```sh
bun add --global executor@1.6.8
executor install
executor service status
executor web
```

`executor web` opens an authenticated page and may print a credential-bearing
URL. Do not paste that output into tickets, chat, or tracked logs. Use
`executor server rotate-token` if the local token is exposed.

From the dotfiles repository:

```sh
uv run --script scripts/setup_executor.py --check
uv run --script scripts/setup_executor.py
```

Check mode exits 1 when changes are needed, 0 when current, and 2 on a setup
error. The script requires an installed executable; it does not install
packages, start services, import integrations, or authorize accounts. Use
`--executor-path /absolute/path/to/executor` if Executor is not on PATH.

It writes these host-local files using private backups and atomic replacement:

| Agent | Configuration |
| --- | --- |
| Codex | `~/.codex/config.toml` |
| Grok Build | `~/.grok/config.toml` |
| Claude Code | `~/.claude.json` |
| Cursor | `~/.cursor/mcp.json` |
| OpenCode 2 | `~/.config/opencode/opencode.jsonc`, under `mcp.servers` |

On macOS, the script selects the installed native binary behind the npm shim,
so GUI clients do not need Node on their inherited PATH. It can migrate the
matching shim entry without replacing custom flags or settings. After an
Executor upgrade, rerun the script and the transport checks.

Every entry runs the resolved Executor executable with:

```text
mcp --elicitation-mode browser --no-artifacts
```

Browser elicitation keeps approval decisions in the local Executor UI. Artifact
surfaces are intentionally disabled for this shared tool profile; discovery
currently exposes `execute`, `skills`, and `resume`. No extra per-integration
search tools are needed: search is available inside `execute`.

The script parses every input before writing any file, preserves unrelated
settings, and refuses to replace a differently configured Executor entry.
Existing extra settings and explicitly disabled gateways are preserved. Restart
or open a fresh agent session after configuration changes. Configuration on disk
alone does not prove a client loaded the gateway. Codex subsequently loaded the
shared gateway and successfully called OpenAI Docs through it during cleanup.

## Integration ownership and migration

The initial local service listens on port **4789**. Use `executor service status`
for the current address; do not assume the documentation's default port 4788.
`executor daemon status` reported the default port incorrectly in this setup,
whereas `executor service status` identified the running launchd service.

| Integration | Initial local verification / owner |
| --- | --- |
| Exa | Search through Executor passed |
| Context7 | Library lookup through Executor passed; public connection, not a migrated API-key grant |
| OpenAI Docs | Search through Executor's CLI and MCP code execution passed |
| Cloudflare | OAuth and documentation search passed |
| Granola | OAuth and account-info read passed |
| Postman | OAuth and authenticated-user read passed |
| Playwright | Local stdio server; tab-list read passed |
| 1Password MCP | Local stdio server; desktop authentication passed |
| Figma | Remote MCP registration returned HTTP 403; Figma REST API subsequently connected and verified in Executor Cloud |
| Canva | OAuth through Executor CIMD; 34 tools discovered and design search passed |
| GitHub | Personal token stored in Executor; authenticated `get_me` passed |
| Google Drive, Gmail, Docs, Sheets, Slides | Separate Google Discovery integrations, shared OAuth client; real reads passed for all five |
| PostHog | Personal API key through `posthog-key`; authenticated `projects-get` read passed; direct Codex entry removed |
| Paper | Local HTTP through Executor; file-context read passed after opening Paper and a design |
| Codex app tools, managed connectors, other plugins | Retain native ownership; no general bridge migration performed |

These are the initial local results, not the current local inventory or
continuous health guarantees. The Cloudflare guide tracks cloud verification
and local removals. PostHog briefly
reported healthy authentication despite having zero tools. Validate the catalog
and an actual read before declaring a connection working.

After verifying the relevant gateway tools in a fresh Codex session:

```sh
uv run --script scripts/setup_executor.py --check --retire-codex-direct
uv run --script scripts/setup_executor.py --retire-codex-direct
```

This removes matching standard direct Codex entries for Exa, Context7,
Cloudflare, Granola, OpenAI Docs, Paper, Playwright, PostHog, Postman, and the standard local
1Password command. Executor owns these migrated tools. Custom
endpoints, arguments, headers, and other modified definitions are left alone.
The command is an explicit migration decision, not a live health checker.

Normal `scripts/sync_agent_config.py` skips these direct defaults while an enabled
Executor entry exists, so the main installer will not recreate migrated entries.
Existing custom definitions remain untouched. Fresh machines without an active
gateway retain their direct defaults. Disabling or removing the gateway restores
normal default seeding on the next sync.

After the user logged out, `claude mcp get executor` reported **Connected** in
user scope (all projects), using the configured native binary. No configuration
change was needed. Earlier, the signed-in CLI excluded this server; the exact
cause was not established. A real tool call from a Claude conversation remains
to be checked after the next sign-in. Claude's direct Exa entry and its tracked
inventory definition are removed. The Context7 plugin is disabled in Claude and
Codex; both use Executor's verified Context7 connection.

Grok and Cursor discovered Executor successfully. After verifying Canva, GitHub,
Google, Notion and PostHog through Executor, retire their duplicate Codex tools:

```sh
uv run --script scripts/setup_executor.py --retire-codex-plugins --check
uv run --script scripts/setup_executor.py --retire-codex-plugins
```

This opt-in flag sets `plugins.<id>.mcp_servers.<name>.enabled = false` for
installed matching plugins, and `apps.<connector-id>.enabled = false` for their
managed app equivalents. Plugin enablement, skill settings and plugin caches
remain untouched. It refuses retirement when the gateway is explicitly disabled.
The normal installer preserves these host choices. Re-run after adding a matching
plugin or changing package sources; app IDs and server names were checked against
installed manifests and Codex's configuration schema on 12 September 2026.
Start a new Codex session to load the changed tool inventory. Skill instructions
that name native connector tools should be fulfilled using Executor discovery and
the equivalent tool schema; a retained skill is not proof of identical APIs.

### Remaining connector audit

The installed manifests were inspected during cleanup. These are configuration
findings, not proof that a managed connector can authenticate through Executor.

| Connector | Finding / next requirement |
| --- | --- |
| Granola | Same MCP endpoint as the verified gateway; duplicate Codex plugin disabled |
| Notion | Executor read passed; duplicate plugin MCP disabled independently of its retained skills |
| Linear, Slack | User excluded these from further migration; Linear is absent from the current Executor integration catalog |
| Figma | REST profile and file reads verified through cloud `figma_api`; native MCP capabilities remain separate |
| Canva | Gateway read verified; duplicate MCP/app disabled, skill bundle retained |
| Google apps | All five read checks passed; duplicate Drive-suite and Gmail MCP/apps disabled, Google skill bundle retained |
| GitHub | Gateway authenticated-user read verified; duplicate MCP/app disabled; repository writes not exercised |
| PostHog | Gateway read verified; direct MCP removed and duplicate managed app disabled; skills retained |
| Cursor cached plugins | PostHog, Postman, Granola, Canva and Shopify manifests exist, but CLI discovery reports only Executor; GUI activation remains unverified |

Native app/computer/browser tools remain attached to their host application.
Fresh transport checks passed for Claude, Grok, and Cursor; real reads passed
through Codex's Executor tool. Full conversational checks in the other clients
remain unverified, including Claude after its next sign-in.

### OpenCode 2

The setup script supports OpenCode 2's `mcp.servers` schema with local command
arrays for both Executor adapters. It reads JSONC comments and trailing commas;
changed configuration is rendered as JSON, while all unrelated values and
explicit disabled states are preserved. The initial symlink is materialized as
a private host-local file without editing the shared template. The installer
preserves this file on subsequent runs.

A fresh OpenCode 2.0.2 standalone conversation loaded `executor_cloud`, read its
execute skill, discovered GitHub, and completed `get_me` with the expected login.
`opencode debug config` also confirmed the existing direct MCP definitions. The
background service's `opencode mcp list` had reported no servers even though the
running UI showed connections; that command alone is not acceptance evidence.
Open a fresh session after setup; do not restart an active service merely to
refresh a status check.

All eleven standard direct OpenCode MCP entries have been
removed from this Mac's OpenCode configuration after gateway reads. Cloudflare
Docs was added separately to the hosted gateway and returned documentation for
Workers D1 bindings. Reproduce this cleanup after verifying both gateways:

```sh
uv run --script scripts/setup_executor.py --retire-opencode-direct --check
uv run --script scripts/setup_executor.py --retire-opencode-direct
```

This requires both active gateways already configured (or the cloud setup flags
on the same command). It removes only matching standard definitions, preserves
custom entries and permissions, and does not perform live health checks. The
installer preserves the resulting host-local file. Fresh devices retain direct
defaults until their gateways are configured and this explicit cleanup runs.

DigitalOcean uses four hosted connections: `digitalocean-accounts`,
`digitalocean-droplets`, `digitalocean-networking`, and `digitalocean-docs`.
Account information, droplet listing, VPC peering listing and a docs-page read
passed through Executor Cloud. The existing 1Password token was stored in the
cloud encrypted credential provider. Even the docs endpoint required that token;
the failed no-auth connection was removed.

Cloudflare bindings, builds and observability are connected through Executor
Cloud. D1 database listing, Worker/build listing and observability-key reads
passed on 12 September 2026; their matching OpenCode entries are retired by the
cleanup flag. Bindings uses `org.main`; Builds and Observability use the existing
`user.personalCloudflareBuilds` and `user.personalCloudflareObservability`
connections. Earlier proposed local registrations are superseded.
Agentation and shadcn are connected through local Executor. Session listing and
a project-registry read passed through the gateway. OpenCode's host configuration
now contains only `executor` and `executor_cloud`.
Agentation 1.2.0 and shadcn 4.19.1 are pinned under
`~/.local/share/executor-local-tools` using npm. Agentation's server reuses port
4747 when another instance owns it. After retiring the old OpenCode processes,
Executor relaunched Agentation, owned port 4747, and passed another session read.

shadcn's upstream tool schemas do not accept a project directory; the CLI captures
it at startup with `mcp --cwd`. `scripts/executor_shadcn.mjs` adds a required
absolute `projectDirectory` to each tool and creates a separate upstream process
per call. Concurrent two-project registry reads and invalid-path rejection passed
against shadcn 4.19.1. This preserves project routing without shared mutable cwd.
The adapter also requires `@modelcontextprotocol/sdk@1.30.0` in the local tool
directory. Its arguments are the absolute adapter path and the absolute
`~/.local/share/executor-local-tools/node_modules` path, launched with Node.
Reproduce the pinned dependencies on another Mac before registering these local
tools:

```sh
npm install --prefix "$HOME/.local/share/executor-local-tools" --save-exact \
  agentation-mcp@1.2.0 shadcn@4.19.1 @modelcontextprotocol/sdk@1.30.0
```

Register Agentation with the resolved Node executable and arguments
`<modules>/agentation-mcp/dist/cli.js server`. Register shadcn with Node and
arguments `<dotfiles>/scripts/executor_shadcn.mjs <modules>`. Expand all paths to
absolute paths. Complete the local Executor approvals and real reads before
running client retirement on that device.

## Add and use integrations

Use Executor's Integrations UI to add a server and connect its account. OAuth
must be authorized for Executor; another agent's existing grant is not
necessarily reusable. Enter secrets in the UI/provider flow, never in chat.
For a public MCP server, the released CLI sequence is:

```sh
executor call executor mcp addServer --help
executor call executor coreTools connections create --help
```

Register the remote endpoint using `addServer`, then create a `template: "none"`
connection if the service truly requires no authentication. Stdio registration
already creates a default connection in this release; do not create a second
connection for the same local process unnecessarily.

```sh
executor tools integrations
executor tools search "documentation"
executor tools describe openai-docs.user.main.search_openai_docs
executor call tools openai-docs user main search_openai_docs '{"query":"MCP","limit":1}'
```

CLI invocation paths start with `tools`; discovery paths omit that prefix.
Inside `execute`, call the discovered path through `tools[path](input)`. Inspect
its schema first. Results use `{ ok, data }` or `{ ok: false, error }`; check the
envelope before accessing upstream `content`. Keep output small.

## Policies and verification

MCP metadata is a starting point, not a complete permission policy. This release
uses `destructiveHint` for its imported default; missing annotations do not prove
that a tool is read-only. Mixed tools such as Cloudflare `execute` and Playwright
`browser_tabs` can perform writes even when some invocations only read.

The local profile requires approval for mixed/sensitive integration calls and
has explicit automatic rules for the reviewed Cloudflare docs/search, Granola
read tools, and Postman's account-info tool. Public documentation/search tools
run without approval. New integrations need their own policy review.

```sh
executor call executor coreTools policies list '{}'
grok mcp doctor executor
cursor agent mcp list-tools executor
codex mcp get executor
claude mcp get executor
```

`get` checks configuration; discovery checks transport. Complete verification
with a real read in each client. Test approval using a harmless read temporarily
marked `require_approval`, then cancel it and remove the temporary policy.
Cancellation was verified to stop execution; Executor's CLI returns nonzero for
that expected cancellation. Never automatically accept arbitrary paused calls.

## Known connection issues

- **Google apps:** `google-drive`, `google-gmail`, `google-docs`, `google-sheets`,
  and `google-slides` use `org.personal` connections and the shared
  `google-workspace` OAuth client. The Google Cloud web client is named
  `Executor local`, with callback `http://localhost:4789/api/oauth/callback`.
  Its credentials were entered directly into Executor, not tracked files.
  Enable each corresponding API in the OAuth client's Cloud project as well as
  approving account consent. Drive initially returned HTTP 403 `SERVICE_DISABLED`;
  enabling its API fixed the read without reauthorization. Executor's generic
  credential-error wrapper can obscure this cause: inspect the upstream error.
  All five APIs were enabled and read checks passed on 12 September 2026.
  These checks did not send email or modify files. Each additional account needs
  its own consent. Review requested scopes in Google's consent page.
- **Figma:** `https://mcp.figma.com/mcp` is correct. Figma restricts its remote
  MCP server to approved clients; Executor's dynamic registration returned 403.
  The UI's generic registration guidance does not grant access. A normal Figma
  REST OAuth app is not a replacement for an approved MCP client. Keep native
  Figma rather than impersonating another client.
  The separate REST integration `figma_api.user.personalFigma` is now connected
  in Executor Cloud using a personal access token. `users.getMe({})` and
  `files.getFile({file_key, depth: 1})` both returned HTTP 200 on 12 September
  2026, using an existing synthetic verification design. This does not verify
  writes or replace native MCP design-editing tools. See the cloud guide for
  token setup and maintenance.
- **1Password credential provider:** separate from the 1Password Environment MCP.
  The account domain must match `op account list`; the account on this machine
  uses `my.1password.eu`, not `eu.1password.com`. Choose Desktop App authentication
  and only the intended vaults. The provider uses the desktop app/CLI to resolve
  credentials outside agent-authored code.
- **PostHog:** `posthog-key.org.personal.exec` uses a personal API key stored by
  Executor, with the MCP Server preset. Tool discovery and an authenticated
  `projects-get` read passed. After the user's policy update, a fresh read ran
  without another approval prompt. The `exec` tool can also write; inspect current
  policies rather than assuming a fixed approval mode. Some tools are scope-gated;
  expand scopes only for a needed task.
  The direct Codex entry is removed and the installer will not recreate it.
  Failed OAuth integrations and local client registrations were removed. OAuth
  returned tokens rejected with HTTP 401 `Invalid API key`, including a direct
  initialize outside Executor; its underlying cause remains unestablished.
  For verification, inspect `exec`, then run `search project`, `info projects-get`,
  and `call --json projects-get {}`. Supply the required `context` and `llm_model`
  fields. Project responses include ingestion tokens: report counts or selected
  safe fields rather than dumping the full response.
- **Paper:** the desktop app must be running with a design open. Executor uses
  `http://127.0.0.1:29979/mcp`; `paper.user.main.get_basic_info` passed for an open
  file. The direct Codex definition is removed. Paper calls require approval.
  The MCP-only `paper-desktop@paper` Claude plugin is disabled; Grok's MCP list
  now shows only Executor. Fresh hosts using this plugin default also need the
  local Executor setup to access Paper.
- **Local processes:** use stable executable locations for background services.
  Avoid shell-session-specific fnm paths. Playwright now launches the resolved
  installed Node binary with its npm CLI and an explicit stable PATH. Verify
  this registration again after replacing or removing that Node version.

## Recovery and maintenance

```sh
executor service status
executor service restart
executor tools integrations
```

Keep `~/.executor` outside Git. It contains the runtime database and credential
state; provider/keychain access may also depend on this Mac. Use an encrypted
backup and a SQLite-consistent backup process, or stop the service before copying
its data. Do not copy just a live `data.db` while ignoring its WAL. A restore to
another machine may require new provider/OAuth authorization.

Config changes create adjacent `*.backup.<timestamp>` files with mode 0600.
Migrated direct definitions are removed from the active config. Check the service,
tool discovery, and a real read after upgrades; configuration presence alone is
not a health check. Do not uninstall Executor while clients still depend on it.

The [Cloudflare deployment](cloud.md) provides shared access across devices.
Its `executor_cloud` entry is configured alongside `executor` on this Mac.
Fourteen hosted internet services passed reads, including all five Google
services, and a fresh Codex conversation completed a cloud GitHub read. Canva
remains blocked by its hosted callback rejection. All fourteen verified local
duplicates are removed. All current credential references and encrypted data restoration passed the
latest recovery check. Local Worker startup and a restored GitHub read passed;
Access settings are exported and the encrypted backup is verified on the VM.
Fresh cloud deployment and Access recreation remain untested. Paper, local Playwright and desktop
1Password continue to need this Mac; another device's localhost is not this Mac.

## Sources

- [Executor docs](https://executor.sh/docs)
- [Executor 1.6.8 source](https://github.com/UsefulSoftwareCo/executor/tree/v1.6.8)
- [Figma MCP access restrictions](https://developers.figma.com/docs/figma-mcp-server/)
- [PostHog MCP documentation](https://posthog.com/docs/model-context-protocol)
- [Claude managed MCP controls](https://code.claude.com/docs/en/managed-mcp)
