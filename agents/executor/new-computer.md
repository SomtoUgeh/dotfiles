# Executor on a new computer

Use the existing Executor Cloud deployment for internet services. Install local
Executor only for tools that need this computer's projects or apps. Joining a
new computer does not require deploying Cloudflare again or restoring its backup.

These instructions match the versions verified on macOS and the AltSchool Linux
VM on 12 September 2026. Windows service setup has not been verified here.

## 1. Prepare the computer

Install the coding agents you actually use, plus Node.js, npm, Bun, and uv using
their official installers or the computer's normal package manager. Verify:

```sh
node --version
npm --version
bun --version
uv --version
```

Get the current dotfiles checkout through your existing SSH/Git workflow.
Run the following setup commands from its root. Confirm it includes
`scripts/setup_executor.py`, `scripts/sync_agent_config.py`, and, for shadcn,
`scripts/executor_shadcn.mjs`. Pull the latest dotfiles changes before setup.
Transfer source files only when needed; never transfer another device's credential
stores.
Do not run the entire dotfiles installer merely to connect Executor.

## 2. Choose cloud only or cloud plus local

### Cloud only

Suitable for a computer that only needs hosted services such as GitHub, Google,
PostHog, Cloudflare, or Figma REST.

```sh
bun add --global mcp-remote@0.13.5
uv run --script scripts/setup_executor.py --cloud-only \
  --cloud-url https://executor-cloudflare.somto.workers.dev/mcp --check
uv run --script scripts/setup_executor.py --cloud-only \
  --cloud-url https://executor-cloudflare.somto.workers.dev/mcp
```

`--check` exits 1 when changes are expected, 0 when current, and 2 on error.
Review errors before applying. Cloud-only mode does not remove an existing local
gateway and does not retire direct integrations.

### Cloud plus local

Use this for project tools such as Agentation/shadcn or supported desktop tools.

```sh
bun add --global executor@1.6.8 mcp-remote@0.13.5
executor install
executor service status
uv run --script scripts/setup_executor.py \
  --cloud-url https://executor-cloudflare.somto.workers.dev/mcp --check
uv run --script scripts/setup_executor.py \
  --cloud-url https://executor-cloudflare.somto.workers.dev/mcp
```

Ensure Bun's global bin directory is on PATH. If discovery fails, pass verified
absolute paths with `--executor-path`, `--node-path`, and `--proxy-path`.
With Bun's default installation the proxy is
`$HOME/.bun/install/global/node_modules/mcp-remote/dist/proxy.js`.
Never copy another computer's Node path into this computer's configuration.

The local service binds loopback only. macOS uses launchd; Linux uses a systemd
user service. On a Linux VM, check `systemctl --user status sh.executor.daemon.service`
and `loginctl show-user "$USER" -p Linger`. Continuous operation without a login
requires linger enabled by the host administrator. Do not expose port 4789 publicly.

The script configures Codex, Grok, OpenCode 2, Claude, and Cursor even if some are
not installed. It preserves unrelated settings and explicit disabled entries,
and refuses conflicting gateway definitions. It does not install agents, connect
upstream accounts, or populate the local catalog. Restart agent sessions afterward.

## 3. Sign this device into cloud

Start a gateway connection from an installed agent and complete its browser login
as the owner authorized by Cloudflare Access. Approve the device's MCP CLI Proxy
consent when shown. Existing hosted integrations become available after login;
service-by-service credentials do not need to be copied or entered again.

A first login can exceed a client's startup timeout. Complete login, then retry
the client. If necessary, run the installed adapter directly in a terminal:

```sh
node "$HOME/.bun/install/global/node_modules/mcp-remote/dist/proxy.js" \
  https://executor-cloudflare.somto.workers.dev/mcp --auth-timeout 300
```

Wait for successful connection, then stop this temporary process with Ctrl+C.
For the AltSchool VM, load the current dotfiles shell once with `source ~/.zshrc`,
then use this daily command on the Mac:

```sh
altschool-up --ssh
```

This checks SSH reachability, keeps the existing development port forwards,
starts/checks VM-local Executor, verifies a real cloud GitHub read, then enters
SSH through the normal shell wrapper. It does not power on a stopped VM.
With `--ssh`, an Executor failure prints a warning and still opens your shell;
plain `altschool-up` returns failure. SSH/forwarding failures and Ctrl+C stop the
sequence. Plain `ssh altschool` always opens a shell without Executor checks.
Running a dev server in another session does not prevent additional SSH sessions.

To renew/check only the VM cloud login:

```sh
executor-cloud-login altschool
# From a checkout without the shell function:
uv run --script scripts/executor_cloud_login.py altschool
```

Cached authentication needs no browser. Ordinary initialization and cloud reads
have 45-second limits; browser authorization gets 330 seconds. When renewal is required, the helper
opens the Mac browser and temporarily forwards the adapter's exact callback
port. Complete Cloudflare login/consent; the helper verifies GitHub and closes
its temporary connection. Cancellation also closes it. A busy callback port
stops login with an error; close the occupying process yourself and retry.

Configure a stable callback port across all agents on each SSH-only device.
AltSchool uses 17907 (the Mac's adapter uses its own port):

```sh
uv run --script scripts/setup_executor.py --cloud-only \
  --cloud-url https://executor-cloudflare.somto.workers.dev/mcp \
  --cloud-callback-port 17907
```

Run that setup command on the VM, using its installed executable paths if needed.
Omitting the callback option on subsequent runs preserves the configured port.
Do not switch ports between manual login and agent startup: mcp-remote associates
client registration with the callback URI. OpenCode's cloud startup timeout is
at least 330 seconds, allowing the adapter's 300-second authentication window;
this alone cannot open a browser on a headless VM.

The helper requires Mac uv, VM Python 3.11+, GNU timeout, the existing Codex cloud
adapter definition, and the hosted `github.org.personal.get_me` connection.
The local readiness check covers service startup and HTTP, not every local tool.
Keep both helper Python files together when transferring dotfiles to a new Mac.
Never share authorization URLs or copy `~/.mcp-auth` between machines. Keep its
directory private (0700) and credential files 0600. Do not use `codex mcp login`
for this stdio adapter. Unattended service-token setup is a separate choice.

## 4. Add the local tools needed here

Open `executor web` on the local computer. Its URL may contain a login token;
keep it private. Register tools in Executor's Integrations UI, not separately in
every agent. A fresh local installation starts with its own catalog and policies.

| Tool | Setup and verification |
| --- | --- |
| Agentation | Install pinned dependencies below. Stdio command: absolute Node path; arguments: `<modules>/agentation-mcp/dist/cli.js`, `server`. Verify session listing. |
| shadcn | Same dependencies. Stdio command: absolute Node path; arguments: `<dotfiles>/scripts/executor_shadcn.mjs`, `<modules>`. Verify a project-registry read with an absolute `projectDirectory`. |
| Paper | Supported desktop app running with a design open; remote MCP URL `http://127.0.0.1:29979/mcp`. Verify basic file information. Not available on the headless Linux VM. |
| Playwright | Install the intended server/browser dependencies and register their stable executable paths. Verify tab listing; this controls this computer's browser. |
| Desktop 1Password | Install/authenticate the supported desktop MCP integration on this host, then register it locally. The credential provider and Environment MCP are separate features. |
| Canva | Currently local on the Mac by choice. A new local install needs its own OAuth grant and a real read. Cloud callback support remains unresolved. |

```sh
npm install --prefix "$HOME/.local/share/executor-local-tools" --save-exact \
  agentation-mcp@1.2.0 shadcn@4.19.1 @modelcontextprotocol/sdk@1.30.0
```

`<modules>` means this computer's absolute
`~/.local/share/executor-local-tools/node_modules` path; `<dotfiles>` means this
checkout's absolute path. Review the upstream CLI help for version-specific
Playwright/1Password installation rather than guessing an executable or version.
Complete each registration's approval and inspect its policy. No Mac keychain,
Paper session, or local Canva grant automatically becomes available on a VM.

## 5. Verify before removing duplicates

Run whichever diagnostics match installed agents:

```sh
codex mcp list
grok mcp doctor executor_cloud
grok mcp doctor executor
cursor agent mcp list-tools executor_cloud
```

Then start a fresh conversation in each agent you intend to use. Ask it to read
the selected gateway's execute skill, discover GitHub's authenticated-user tool,
and make that harmless cloud read. For local Executor, verify Agentation session
listing or shadcn project registries. Inspect failures at the client-permission,
gateway, authentication, and upstream-service layers separately.

Grok may need the established gateway rules in `~/.grok/config.toml`:

```toml
[permission]
allow = ["MCPTool(executor_cloud__*)", "MCPTool(executor__*)"]
```

Merge these into existing rules rather than overwriting the table. These permit
gateway invocation at the Grok layer; Executor policies still apply. The setup
script does not seed these rules. Do not enable blanket always-approve to repair
a failed connection.

After every affected replacement passes a real read, use the relevant opt-in
retirement flags described in the [main guide](README.md#integration-ownership-and-migration).
Do not run bulk retirement for local services that have not been set up here.
Custom definitions may need individual review. Re-run setup in check mode to
confirm it is current. Use the [shared routing workflow](../skills/RUNTIME_TOOLS.md#executor-routing)
for normal agent calls and native-tool exceptions.

## 6. Maintenance and replacement computers

Cloud credentials remain on the existing server. New-computer onboarding normally
means fresh device login and recreating only necessary local integrations.
Rerun setup after moving/upgrading executable paths, then repeat a real read.
Keep host-local configs and credential stores outside Git. Local `~/.executor`
contains sensitive state; use a consistent encrypted backup if preserving it,
and expect host-specific providers to need reauthorization after restoration.

Cloud disaster recovery is separate: see the [cloud recovery record](cloud.md#authentication-and-secrets).
The completed encrypted snapshot and recovery instructions are available on both
the Mac and AltSchool VM. Data restoration, local Worker startup, a restored
GitHub read, and off-device archive integrity passed. Access settings are exported;
recreating Access and a fresh cloud deployment remain untested. Do not redeploy
cloud or replace its encryption key while onboarding a laptop. A local development
restore configuration must never be deployed.
