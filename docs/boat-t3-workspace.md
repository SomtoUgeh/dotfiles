# boat.dev VM `julds` as a T3 Code environment

Runbook for the cloud dev workspace. Set up, migrated and audited 24 Oct 2026. No secrets in this file.

## Daily use (Mac)

| Command | What it does |
| --- | --- |
| `julds-up` | Resume the VM if stopped and wait until T3 Connect reaches it |
| `julds-down` | Stop it now (between agent turns only) and refresh the named snapshot `julds-latest` |
| `julds-tunnel` | Forward AltSchool ports 5050 and 8000-8007 to the Mac (Ctrl-C to stop) |
| `boat ssh bx_gbx664fj` | Shell on the VM |
| `boat usage bx_gbx664fj` / `boat limits` | Cost so far / plan time left |

T3 Code (desktop, web at app.t3.codes, iPhone) shows the VM as **julds** through T3 Connect.

## Box

| Item | Value |
| --- | --- |
| Provider | boat.dev, $20/mo plan (Julds Limited, GB VAT, Julds Amex), renews monthly from 24 Nov 2026, auto-refill off |
| Account | smugeh@gmail.com, signed in through GitHub (SomtoUgeh) |
| Sandbox | `bx_gbx664fj`, boat name `julds`, hostname `julds` (cloud-init `preserve_hostname: true`), `default` size (4 vCPU Ryzen 9 9950X, 8 GB, 50 GB data disk), Ubuntu 24.04 x86_64 |
| Stopping | boat's own auto-stop is off (`--no-auto-stop`); our idle check stops it after 30 idle minutes (below) |
| boat env `base` | GitHub injection off (`boat env set base --github false`); boat CLI credentials still injected (lets the VM stop and snapshot itself) |
| T3 | `t3` nightly (keep it on the same build as the Mac), user systemd service `t3code`, linger on, T3 Connect as admin@julds.com |
| Mac CLI | `boat` in `~/.ascii/bin` (also linked from `~/.local/bin`; on PATH via `shell/.zshenv`) |

## Cost and sizes

The plan price comes back as machine time: $20 = 555 h of `default`. With the idle stop the VM normally stays inside the plan. 24/7 would be about $26/mo; auto-refill is off, so boat stops the VM after a 24 h grace instead of charging more.

| Size | vCPU / RAM / disk | $/h | 8 h x 22 days | 24/7 |
| --- | --- | --- | --- | --- |
| `default` (current) | 4 / 8 GB / 50 GB | 0.036 | ~$6 | ~$26 |
| `large` | 8 / 16 GB / 125 GB | 0.072 | ~$13 | ~$53 |
| `xlarge` (needs $100 plan) | 16 / 32 GB / 251 GB | 0.200 | ~$35 | ~$146 |

Change size: `julds-down`, then `boat resume bx_gbx664fj --type large` (or `--type default` to go back). The disk and setup stay.

## Accounts on the VM (fresh sign-ins, nothing copied from other machines)

| Tool | Account |
| --- | --- |
| GitHub `gh` | SomtoUgeh; scopes repo, read:org, workflow, gist, admin:public_key, admin:ssh_signing_key; git protocol ssh |
| SSH key | `~/.ssh/id_ed25519_personal`, on GitHub as "julds-boat" (auth) and "julds-boat signing"; commits are SSH-signed |
| Claude Code | admin@julds.com, Claude Max |
| Codex | dedoyinaluko@gmail.com, ChatGPT Plus (gpt-6.x / gpt-5.6-*; gpt-5.5 is rejected on ChatGPT auth) |
| Grok Build | admin@julds.com |
| Cursor | admin@julds.com (CLI login plus T3's own Cursor sign-in) |
| OpenCode 2 | xAI API key "boat-t3-dev (OpenCode)" |
| Wrangler / `cf` | work@somtougeh.com (separate logins; `cf` is beta) |
| Executor cloud | Cloudflare Access as work@somtougeh.com, callback port 17908, tokens in `~/.mcp-auth` (0700/0600) |
| 1Password | service account `julds-boat-vm` (below) |

## Agents and tools

Agent CLIs resolve from `~/.local/bin`: Claude (native installer), Codex, Grok, Cursor (`cursor-agent`), OpenCode 2 (`@opencode/cli`), each linked from the nvm global bin where npm-installed. T3 providers: Codex, Claude, Cursor, Grok (`/home/user/.local/bin/grok`), OpenCode (`/home/user/.nvm/versions/node/v24.22.1/bin/opencode`).

Also installed: git (git-core PPA), gh, uv/uvx, node 24 (nvm), bun 1.4.2, pnpm, agent-browser (with Chrome), wrangler, cf, `op`. Unattended security upgrades are on.

## Dotfiles and skills

Clone at `~/code/personal/dotfiles` (origin `git@github.com:SomtoUgeh/dotfiles.git`), plus `~/code/personal/p3-stack` because the p3 skills are relative links into it.

- `scripts/install_cloud_dotfiles.sh` set up zsh, starship, git config, signing, Grok and OpenCode links. It titles the GitHub key from `CLOUD_HOST_TITLE` or the hostname.
- Claude and Codex are linked the way `install.sh` does on the Mac: CLAUDE.md, ETHOS.md, settings.json, commands, agents, output-styles, git_guard hook, statusline; Codex AGENTS.md, agents and `sync_agent_config.py`.
- Skills: `agents/skills` is the shared library (180 skills, identical on the Mac and the VM as of 24 Oct). `~/.claude/skills` holds one link per shared skill plus boat's own `boat` and `synced`. `agents/skills/synced/` (Claude's skill sync cache) and `agents/skills/boat/` (boat-injected) are git-ignored.
- OpenCode config is host-local (`~/.config/opencode/opencode.jsonc`, copied from `opencode.cloud.jsonc`) because Executor setup writes into it. boat's `opencode.json` (computer tool) sits alongside.
- Codex direct MCP entries that cannot work on the VM are `enabled = false`: paper, playwright, cloudflare, granola, posthog, postman (reachable through the gateways instead).

To sync after changing skills or agent config on the Mac: commit and push, then on the VM:

```sh
cd ~/code/personal/dotfiles && git pull --ff-only
git -C ~/code/personal/p3-stack pull --ff-only
for s in ~/code/personal/dotfiles/agents/skills/*/; do b=$(basename "$s"); [ "$b" = synced ] || [ "$b" = boat ] || [ -e ~/.claude/skills/$b -a ! -L ~/.claude/skills/$b ] || ln -sfn "${s%/}" ~/.claude/skills/$b; done
find ~/.claude/skills -maxdepth 1 -xtype l -delete
```

## MCP gateways (all five agents)

| Entry | What | How |
| --- | --- | --- |
| `executor_cloud` | Hosted Executor (GitHub, Google, Notion, PostHog, Postman, Cloudflare, Context7, Exa, ...) | `setup_executor.py --cloud-only --cloud-callback-port 17908`, mcp-remote 0.13.5 |
| `executor` | The Mac's local Executor: 1password, agentation, aside, canva, paper, playwright, shadcn | `~/.local/bin/executor-mac-mcp` -> mcp-remote -> `http://127.0.0.1:4789/mcp` on the VM, a boat reverse tunnel to the Mac's Executor. Bearer token in `~/.config/executor-mac/token` (0600) |
| `computer` | boat's Linux desktop / Chrome tools | boat rewrites it into each harness config at every sandbox start |

The Mac end of the tunnel is `~/.local/bin/julds-executor-bridge`, run by `~/Library/LaunchAgents/com.julds.boat-executor-bridge.plist` (KeepAlive). It keeps `boat forward bx_gbx664fj --reverse --local 4789 --remote 4789` running while the VM is up, stops it when the VM stops, and restarts it when a probe from the VM (every 2 minutes) fails; a bare `boat forward` goes stale after a VM stop/resume without exiting. Log: `~/Library/Logs/boat-executor-bridge.log`. Restart with `launchctl kickstart -k gui/$(id -u)/com.julds.boat-executor-bridge`. The `executor` entry works only while the Mac is awake. Rotating the Mac token (`executor server rotate-token`) means rewriting the VM token file.

Approvals: the Mac Executor policies `1password.*` and `playwright.*` are `require_approval` (since 24 Oct 2026), so calls from the VM (and from Mac agents) pause until approved in the Mac's Executor UI. Paper, Aside, Canva, Agentation and shadcn keep their existing policies.

## 1Password

`op` with service account `julds-boat-vm` (token in `~/.config/op/service-account-token`, exported by `~/.zshrc.private`, `~/.profile` and `~/.t3/service.env`, so T3-started agents have it).

- Read: AltSchool, Julds, Library, Shared with Grok Bot, Work. Read and write: Julds VM.
- Environments (read): Erivault Dev, Lami, Somto's website (`op run --environment <id> -- cmd`; `op environment` does not exist in this CLI).
- Access is fixed at creation; to change it, create a new service account. The token item is in the Personal vault, which the account cannot read.

## Idle auto-stop and waking

**Stop.** `~/.local/bin/julds-idle-check` runs every 5 minutes (`julds-idle.timer`, user systemd). After 30 idle minutes it saves the named snapshot `julds-latest` and runs `boat stop self`. Active means any of: agent processes used CPU, an agent has an open TCP connection, system CPU >= 10%, an SSH login, or less than 20 minutes since boot. Log: `~/.local/state/julds-idle/log`. Pause with `touch ~/.local/state/julds-idle/disabled`.

**Wake.** A stopped VM has no machine, so nothing wakes it by itself; T3 shows it offline until it is resumed.

- Mac: `~/.local/bin/julds-autowake` runs every 20 s (`~/Library/LaunchAgents/com.julds.autowake.plist`, loaded). When T3 Code is the frontmost app and `julds` is stopped, it runs `boat resume` (at most once every 2 minutes). Log: `~/Library/Logs/julds-autowake.log`.
- iPhone: Shortcut "Wake julds": Get Contents of URL, POST `https://boat.dev/api/v1/sandboxes/bx_gbx664fj/resume`, header `Authorization: Bearer <key>`. The key is the 1Password item "boat julds wake key" (Julds VM vault): boat API key `julds-wake-phone`, limited to this sandbox with `sandbox.resume` and `sandbox.read`, expires Oct 2027.
- Anywhere: boat.dev/dashboard, Sandboxes, Resume.

Away from the Mac, everything on the VM works except the `executor` (Mac local) tools: Paper, Aside, Playwright, desktop 1Password and Canva need the Mac awake.

## Data retention

boat deletes a stopped sandbox's disk 14 days after the stop (email on day 11). The idle check and `julds-down` refresh the named snapshot `julds-latest` before every stop; named snapshots never expire and 10 are included in the plan. If the disk ever expires, recover with `boat new --from julds-latest --no-auto-stop`, then update the sandbox id in `julds-up`, `julds-down`, `julds-tunnel`, `julds-autowake`, the bridge plist, the wake key and this runbook.

## Gotchas

- Revoking the GitHub CLI OAuth app (github.com/settings/applications) signs out every `gh` and also deletes SSH keys that were uploaded through `gh`. Re-add with `gh ssh-key add ~/.ssh/id_ed25519_personal.pub --title julds-boat --type authentication`.
- Files Aside writes on the Mac can carry `com.apple.quarantine`; launchd and Gatekeeper refuse them until `xattr -d com.apple.quarantine <file>`. Load LaunchAgents as yourself (`launchctl bootstrap gui/$(id -u) ...`), never with sudo; error 5 also means "already loaded".
- `pkill -f mcp-remote...` inside `boat ssh -- 'bash -lc "..."'` kills the SSH command itself; use a `[m]cp-remote` pattern.
- Agent CLIs and `op` read stdin; give them `</dev/null` inside `bash -s` scripts.
- Wrangler's OAuth callback listens on `[::1]:8976`; `boat forward` targets 127.0.0.1, so bridge with socat for logins.
- Codex `exec` can answer before the cloud gateway finishes starting; interactive T3 sessions are fine.
- Stop only between agent turns: a stop ends running processes (no hibernate). Enabled systemd services start again on resume.
- Security: agents run with full access and can use claude.ai connectors (Gmail, Calendar, Docs), the `gh` login, the 1Password service account, the Mac's desktop tools through `executor` (1Password and Playwright need approval), and boat's account-level CLI. Patterns to adopt later: credentials kept outside the sandbox (Cloudflare outbound Workers for Sandboxes, boat's secret proxy) and a repo-scoped GitHub token.
- Scheduled or always-on work (T3 Scheduled Tasks on julds, proactive agents) does not run while the VM is stopped; run it from the Mac's T3, from Cloudflare (Agents SDK / Pi Durable), or pause the idle check during those windows.

## History

- 24 Oct 2026: replaced the DigitalOcean droplet `altschool-dev`. The AltSchool repo (main and staging-* branches), its four env files (checksums matched), per-app AGENTS.md/CLAUDE.md, `.cursor/` and `~/.altschool` were carried over; other local branches were dropped by choice. The droplet, its firewall, API tokens and SSH key, the Cloudflare tunnel, private route and split-tunnel entry, the old GitHub keys, the Executor DigitalOcean integrations and the DigitalOcean tooling in these dotfiles were removed. The droplet's uncommitted dotfiles edits were merged (`droplet-wip`).
- Verified 24 Oct 2026: all five agents read GitHub through `executor_cloud` and listed the Mac integrations through `executor`; reboot and stop/resume keep T3 Connect without re-pairing; `bun run check` and `check-types` pass.
