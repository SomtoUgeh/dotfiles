# Executor on Cloud

The hosted gateway is configured alongside the local gateway in all five Mac
agents. The original fourteen internet services and eight additional OpenCode
integrations passed real cloud reads. Figma REST profile and file reads also
passed through the saved cloud connection. Canva remains local by user choice after
its hosted callback was rejected. The local catalog contains Paper, Playwright,
desktop 1Password, Canva, Agentation and shadcn. OpenCode now connects only through
the two Executor gateways.

## Complete service audit, 12 September 2026

All 18 initially configured local services passed harmless reads before cleanup.
Fourteen cloud services subsequently passed real reads. These checks verify current connectivity
and representative read permissions; they do not exercise every write operation,
all accounts, or every service tool.

| Service | Verified read | Local before cleanup | Cloud |
| --- | --- | --- | --- |
| 1Password | Authenticate and list environments | Passed | Desktop only |
| Canva | Search designs | Passed | Blocked: invalid redirect URI |
| Cloudflare | Documentation search and authenticated Workers list (HTTP 200) | Passed | Passed |
| Context7 | Resolve React library | Passed | Passed |
| Exa | Web search | Passed | Passed with API key |
| GitHub | Authenticated user | Passed | Passed |
| Google Drive | Account metadata | Passed | Passed, HTTP 200 |
| Gmail | Profile metadata | Passed | Passed, HTTP 200 |
| Google Docs | Existing document metadata | Passed | Passed, HTTP 200 |
| Google Sheets | Existing spreadsheet metadata | Passed | Passed, HTTP 200 |
| Google Slides | Existing presentation metadata | Passed | Passed, HTTP 200 |
| Granola | Account information | Passed | Passed with registered OAuth client |
| Notion | Fetch self | Passed | Passed |
| OpenAI Docs | Documentation search | Passed | Passed |
| Paper | Open design basic information | Passed | Desktop only |
| Playwright | List tabs | Passed | Local only |
| PostHog | Read projects | Passed | Passed |
| Postman | Authenticated user | Passed | Passed |

Paper initially failed because no design was open; the repeat read passed once
an open file was available. Cloudflare's local authenticated API read returned
31 Workers. No emails, documents, designs or service resources were modified.

Granola consent and account-info read passed with the registered
`dcr-mcp-auth-granola-ai` workspace client. The unused `granola-cimd` client
points at Access-protected metadata and awaits reference-checked cleanup.
The earlier `invalid_client` URL alone does not establish which client failed.

Grok's cloud MCP doctor passed, Claude reported Connected, and Cursor listed
seven cloud root tools. Local reads above ran through this Codex session's
Executor MCP. Cloud reads ran through hosted Executor executions; Exa also
passed through the configured MCP adapter. A fresh Codex conversation completed
a cloud GitHub read. Full conversational checks in the other agents remain
unverified.

## Deployment

- Console: https://executor-cloudflare.somto.workers.dev
- MCP: https://executor-cloudflare.somto.workers.dev/mcp
- Release: `v1.6.8`, commit `2dc399e51094fccd2a45103a38d77179c6d648ff`
- Worker: `executor-cloudflare`
- D1: `executor`, ID `106e2ccd-22b7-421f-8455-fc5fa75b66db`
- R2: `executor-blobs`
- Durable Objects: `McpSessionDO`, `McpExecutionOwnerDirectoryDO`
- Access application: `Executor MCP`
- Access policy: `Executor Owner`, restricted to the owner's exact email
- Managed OAuth: enabled; production and preview Worker URLs are protected

This release also uses the Worker Loader binding for isolated code execution.
The brief website deployment summary omits R2 and Durable Objects; inspect the
release's actual Wrangler config before upgrading.

## Reproduce or maintain

Use a dedicated checkout of the official repository. Preserve its release pin
and lockfile; never deploy a moving default branch without checking the changes.

```sh
git clone --branch v1.6.8 --depth 1 https://github.com/UsefulSoftwareCo/executor.git
```

From that checkout:

```sh
bun run bootstrap
bun run prepare
bun run --cwd apps/host-cloudflare build
```

The explicit `prepare` is necessary with the Bun 1.4 installation used for this
pilot: bootstrap installed dependencies but did not build the internal Vite
plugin. Running prepare fixed the missing-package build failure.

Before deploying, set the target account explicitly in the checkout's
`apps/host-cloudflare/wrangler.jsonc`, replace its upstream `database_id` with
the intended D1 ID, and verify the Worker and R2 names. The upstream config
contains an author-specific database ID; never use it unchanged.

From `apps/host-cloudflare`:

```sh
bunx wrangler whoami
bunx wrangler deploy --dry-run
bunx wrangler deploy
```

For a genuinely new installation, create the dedicated `executor-blobs` R2
bucket first, then use `bun run deploy:setup`. The setup script provisions D1,
generates the encryption secret if missing, builds the console, and deploys.
It does not create R2 or configure Access. Inspect existing resources first;
its generic resource names may collide with another installation.

## Authentication and secrets

Protect the entire Worker with Cloudflare Access, including preview URLs and
OAuth discovery paths. Use an exact-email Allow policy and enable Managed OAuth.
Set these installation-specific Worker variables from the saved Access app:

- `ACCESS_TEAM_DOMAIN`: the Zero Trust team hostname
- `ACCESS_AUD`: the application's public audience identifier
- `ADMIN_EMAILS`: the owner's exact login email

Keep `ENABLE_DEV_AUTH=false`. The Worker validates Access's signed JWT and
fails closed if its authentication settings are missing. `keep_vars=true`
preserves live installation variables across subsequent code deployments.

`EXECUTOR_SECRET_KEY` is a Worker secret, never a plain variable or tracked
file. Losing or replacing it makes stored integration secrets unreadable.
A recovery key was saved in the Personal 1Password vault as
`Executor Cloudflare encryption recovery`, then uploaded after clearing the
pilot's secret store. The first GitHub credential created during deployment
propagation failed decryption and was recreated; subsequent GitHub reads passed.

**Recovery check, 12 September 2026:** all 35 secret references from the
24 saved connections and OAuth clients resolved and decrypted with the saved
1Password key. Of 43 encrypted values, 42 decrypted; the one failure is not
referenced by those records. It was preserved, not deleted.

The completed encrypted snapshot is stored outside Git at
`~/.local/share/executor-backups/executor-cloud-20260912-complete.aesgcm`
on both the Mac and AltSchool VM. Adjacent `RESTORE.md` and `SHA256SUMS` describe
recovery and archive integrity. The recovery key stays separately in 1Password.
The archive contains the original D1 export, 13 R2 objects with metadata/checksums,
pinned source and working diff, Worker configuration, and the later same-day
Access application export with its embedded owner policy and Managed OAuth settings.
Reopening the completed archive verified all 24 file hashes, a fresh SQL import,
SQLite integrity/foreign keys, and the Access policy. The restored database has
23 integrations and 24 connections. The VM copy matched SHA-256 and was read
back byte-for-byte to the Mac for comparison.

Local application recovery also passed: the isolated restored Worker served its
integration/connection APIs and completed a credential-backed GitHub `get_me`
read. The loopback rehearsal used development auth with a fixed test principal;
it does not verify production Access or personal-subject routing. Access export
succeeded through the existing Cloudflare integration; Wrangler OAuth lacked
Access read permission. Access recreation and a fresh cloud deployment remain
untested. Existing live sessions are not backed up; no backup schedule is configured.
Wrangler 4.95.0 export failed authentication; installed 4.129.0 succeeded.
Its local SQL import hit SQLITE_TOOBIG; Python SQLite restored the export and
copied the verified database into the isolated emulator. Production remained
in place and a subsequent cloud Figma read returned HTTP 200. The rehearsal
Worker is stopped and temporary plaintext/key files are removed after verification.
Do not rotate the Worker key over existing encrypted records.

A restorable backup needs the matching encryption key, a consistent D1 export,
R2 blobs, the pinned source/configuration and Access settings. Store exports
privately and encrypted outside Git. Rehearse restoration into an isolated
installation before calling the backup verified. D1/R2 alone cannot recover
credentials without the matching key. Never run `deploy:setup` as a key-rotation
procedure over existing encrypted records.

See [Executor on a new computer](new-computer.md) for the full local/cloud
onboarding checklist.

## Device setup and acceptance checks

Each device uses the same hosted URL and signs in separately through Cloudflare
Access. Upstream service credentials stay in Executor. Do not copy OAuth caches
between devices.

Install Node, Bun and uv using the device's normal setup, then:

```sh
bun add --global mcp-remote@0.13.5
```

From the dotfiles repository, add the cloud gateway alongside local Executor:

```sh
uv run --script scripts/setup_executor.py --cloud-url https://executor-cloudflare.somto.workers.dev/mcp --check
uv run --script scripts/setup_executor.py --cloud-url https://executor-cloudflare.somto.workers.dev/mcp
```

For a new device that does not need desktop tools, add `--cloud-only` to both
commands. This does not require or install local Executor. It preserves any
existing local entry and refuses direct/plugin retirement flags. Setup writes
Codex, Claude Code, Grok Build, Cursor and OpenCode configuration; it does not install
the clients or prove that each is authenticated.

The `executor_cloud` entry runs the installed `mcp-remote` proxy with an absolute
Node path and the hosted URL. Supply `--node-path` and `--proxy-path` if discovery
cannot find the installed executables. Rerun setup after moving those runtimes.
The existing `executor` entry continues to run local Executor.

On first connection, complete the browser login on that device. The adapter
shares its local OAuth cache across these five agents, under `~/.mcp-auth`;
keep directories private and token files mode 0600. Do not use
`codex mcp login executor_cloud`: this entry is a stdio OAuth adapter, not a
native HTTP entry. Open a new agent session after changing configuration.

```sh
grok mcp doctor executor_cloud
cursor agent mcp list-tools executor_cloud
claude mcp get executor_cloud
codex mcp get executor_cloud
```

Discovery proves transport; `get` alone proves configuration. Follow it with a
real read such as GitHub `get_me` through Executor's execute tool.

### Migration evidence, 12 September 2026

| Integration | Hosted evidence |
| --- | --- |
| Context7 | Library resolution passed |
| OpenAI Docs | Documentation search passed |
| GitHub | `github.org.personal.get_me` returned the expected login |
| PostHog | `posthog-key.org.personal.exec` returned five projects; credentials omitted from output |
| Google Drive | `drive.about.get` returned HTTP 200 |
| Gmail | `gmail.users.getProfile` returned HTTP 200 |
| Google Docs | Read of an existing document returned HTTP 200 |
| Google Sheets | `google-sheets.user.personal` read an existing spreadsheet successfully |
| Google Slides | `google-slides.user.personal` read an existing presentation successfully |
| Cloudflare | Approved OAuth grant; authenticated Workers list returned HTTP 200 |
| Granola | `granola.org.personal.get_account_info` passed after registered-client consent |
| Notion | `notion.org.personal.notion_fetch` with `id: "self"` passed |
| Postman | `postman.org.personal.getauthenticateduser` passed |
| Exa | `exa.user.personal.web_search_exa` passed through the configured cloud MCP adapter |
| Cloudflare Docs | Documentation search passed, including a fresh OpenCode conversation |
| Cloudflare Bindings | D1 database listing passed |
| Cloudflare Builds | Worker list and build list passed; the selected Worker had no builds |
| Cloudflare Observability | Observability-key read passed |
| DigitalOcean Accounts | Account information passed |
| DigitalOcean Droplets | Droplet listing passed |
| DigitalOcean Networking | VPC peering listing passed |
| DigitalOcean Docs | Documentation-page read passed; hosted endpoint required the existing API token |
| Figma REST API | `figma_api.user.personalFigma.users.getMe` and `files.getFile` returned HTTP 200 |
| Canva | Original and fresh dynamic registrations echo the exact hosted callback, but authorization returns HTTP 400 `Invalid redirect URI` |

Google uses the existing `google-workspace` OAuth client and separate
`org.personal` connections for Drive, Gmail and Docs; Sheets and Slides use
`user.personal`. The Google Cloud client remains named
`Executor local`. Both approved callbacks are saved:

- `http://localhost:4789/api/oauth/callback`
- `https://executor-cloudflare.somto.workers.dev/api/oauth/callback`

Drive, Gmail and Docs used the existing Google account grant. Review the actual
scopes before any new consent. Keep the localhost callback while local Google
connections still depend on it.

Fourteen existing local user policies were copied for integrations installed in
the cloud, preserving owner, pattern, action and position. In Executor 1.6.8,
`approve` means automatic permission; `require_approval` means pause for consent.
Imported plugin defaults are not a guarantee that every available call is safe.

Client evidence:

- Grok Build's cloud MCP doctor passed. A subsequent adapter connection refreshed
  the expired Access token, and a fresh hosted GitHub read passed.
- Claude lists both gateways as Connected while its account is signed out;
  a conversation after sign-in remains unverified.
- Cursor's CLI lists seven cloud root tools. A protocol check using Cursor's
  exact configured adapter completed a real GitHub read.
- Codex completed a fresh conversation using cloud Executor and returned the
  expected GitHub login. This verifies the configured adapter path as well as
  the earlier native HTTP pilot.
- OpenCode 2.0.2 completed a fresh standalone conversation through the shared
  cloud adapter, including its execute skill and a GitHub `get_me` read. Later
  conversations verified Cloudflare Docs through cloud Executor and Agentation
  plus project-aware shadcn through local Executor. All eleven standard direct
  entries are now removed; `--retire-opencode-direct` reproduces this cleanup.
- The AltSchool VM now uses both gateways in its everyday agent configuration.
  A fresh OpenCode conversation completed cloud GitHub and VM-local Agentation
  reads. Grok cloud discovery and the configured cloud adapter read also passed.
  Codex configuration is verified; a Codex conversational call remains unverified.
- Cloud console build, deployment and eighteen focused host tests passed during
  the pilot. Unauthenticated MCP access returned an OAuth 401 challenge, and
  the permitted owner authenticated successfully.

### Figma REST API

The cloud integration `figma_api` uses Figma's official REST OpenAPI specification.
The saved connection is `figma_api.user.personalFigma`. In the connection UI,
`apikey-0` means PersonalAccessToken and `apikey-1` means PlanAccessToken; both
use `X-Figma-Token`, so the identical API-key labels do not mean duplicate keys.
Use the personal-token option for a token generated in Figma Settings > Security.
Keep the token in Executor's encrypted credential store, never client configs or
tracked documentation.

The user-generated `executor-cloud` token passed the UI health check and a saved
cloud `users.getMe({})` call. A `files.getFile({file_key, depth: 1})` call read the
existing disposable synthetic note-card design with HTTP 200 on 12 September
2026. No design was changed. The generated token's final expiry and full scope
set were not independently rechecked; consult Figma's token settings before
expiry and replace the saved credential when needed, then repeat both reads.
Profile and file reads need `current_user:read` and `file_content:read` respectively.
Other endpoint permissions and writes remain unverified.

This REST connection does not remove Figma's approved-client restriction on
`https://mcp.figma.com/mcp` and is not a replacement for native MCP design editing.

### Cleanup status

All fourteen verified internet-service duplicates have been removed locally:
Context7, OpenAI Docs, GitHub, PostHog, all five Google services, Granola, Notion,
Cloudflare, Postman and Exa. The final database inventory and a fresh CLI catalog
initially contained Paper, Playwright, desktop 1Password and Canva. Agentation
and shadcn were subsequently added locally; eight additional integrations were
added to the cloud as listed above. Start a fresh agent session to discard any
cached local catalog from before these removals.

Executor's browser approval mode requires the user to approve each removal in
its own UI. Resuming consumes that decision and can pause at the next tool call.
A displayed "Approve sent" confirms a decision, not completion of the batch;
verify the resulting integration inventory. Do not bypass the approval policy
when a client transport disconnects. Removing a connection can leave provider
secret values behind; credential cleanup remains a separate, reference-checked
step.

Exa uses an API key named `executor-cloudflare`, stored in the hosted encrypted
credential provider and supplied with the `x-api-key` header. One verification
search passed; no credits were purchased. A fresh connection inventory shows
only `exa.user.personal`; the older unauthenticated connection is absent.
Unused diagnostic OAuth clients
and the unreferenced old pilot ciphertext also await cleanup.

Canva remains local by the user's decision. Canva's official MCP documentation
requires allowlisting custom callback URLs; its metadata-based flow also cannot
read our Access-protected client document. A newly registered client did not fix its
hosted redirect rejection, so repeat registration is not an established remedy.
Do not disable browser protections, expose protected metadata routes, or copy a
static OAuth access token as a substitute for a working refreshable cloud grant.
Do not resume Canva migration unless requested.

Connection health alone is insufficient: require a real hosted read and verify
the intended client path. Data and local application recovery passed; a fresh
cloud deployment and Access recreation remain untested as described above.

Keep Paper, local Playwright and desktop 1Password on a local runtime. The
Cloudflare host disables stdio MCP and does not host those desktop processes.

Official references:

- https://executor.sh/docs/hosted/cloudflare
- https://developers.cloudflare.com/cloudflare-one/access-controls/ai-controls/secure-mcp-servers/

## AltSchool VM setup, 12 September 2026

`ssh altschool` reaches `/home/altschool`. Executor 1.6.8 runs under the enabled
`sh.executor.daemon.service` systemd user unit on loopback port 4789; user linger
is enabled. The VM has its own runtime state and OAuth cache. Its cloud adapter
uses Node `/usr/bin/node` and mcp-remote 0.13.5, with a separately approved login.
OAuth cache directories are mode 0700 and files mode 0600.

Codex, Grok, and OpenCode are installed and configured with `executor_cloud` and
`executor`. Claude/Cursor config files are prepared, but those CLIs were not
installed during this migration. Grok's gateway allow rules match the Mac.
The prior direct Context7, Cloudflare Docs and shadcn entries were removed from
Grok/OpenCode after verification. OpenCode's host-local config is preserved by
the VM installer; the Codex sync script skips migrated direct defaults.

VM-local Executor contains Agentation 1.2.0 and project-aware shadcn 4.19.1,
using SDK 1.30.0 and the shared `scripts/executor_shadcn.mjs` adapter. Session
listing and a disposable project-registry read passed. A fresh OpenCode
conversation also passed cloud GitHub and local Agentation reads. Setup check
is idempotent. No Mac desktop services, credentials, or OAuth caches were copied
to the VM; Paper, desktop 1Password and the Mac-local Canva connection remain
available from the Mac only. The VM's local gateway means this Linux VM.
