# boat.dev VM `julds` as a T3 Code environment

Runbook, set up and audited 24 Oct 2026. No secrets in this file.

## Box

| Item | Value |
| --- | --- |
| Provider | boat.dev, $20/mo plan (Julds Limited, GB VAT, Julds Amex), renews 24 Nov 2026, auto-refill off |
| Account | smugeh@gmail.com, signed in through GitHub (SomtoUgeh) |
| Sandbox | `bx_gbx664fj`, boat name `julds`, hostname `julds` (cloud-init `preserve_hostname: true`), `default` size (4 vCPU, 8 GB, 50 GB), Ubuntu 24.04 x86_64 |
| Auto-stop | Off. 24/7 is about $26/mo; idle stop is not set up yet |
| boat env `base` | GitHub injection off (`boat env set base --github false`); boat CLI credentials still injected (lets the VM stop itself) |
| T3 | `t3` nightly (same build as the Mac), user systemd service `t3code`, linger on, T3 Connect as admin@julds.com. T3 still lists it as `box-node-0b8a829898b3443e` |
| Mac CLI | `boat` in `~/.ascii/bin` (quarantine flag removed once) |

## Accounts on the VM (all fresh sign-ins, nothing copied)

| Tool | Account |
| --- | --- |
| GitHub `gh` | SomtoUgeh; scopes repo, read:org, workflow, gist, admin:public_key, admin:ssh_signing_key; git protocol ssh |
| SSH key | `~/.ssh/id_ed25519_personal`, on GitHub as "julds-boat" (auth) and "julds-boat signing" |
| Claude Code | admin@julds.com, Claude Max |
| Codex | dedoyinaluko@gmail.com, ChatGPT Plus (gpt-6.x / gpt-5.6-*; gpt-5.5 rejected on ChatGPT auth) |
| Grok Build | admin@julds.com |
| Cursor | admin@julds.com (CLI login plus T3's own Cursor sign-in) |
| OpenCode 2 | xAI API key "boat-t3-dev (OpenCode)" |
| Wrangler / `cf` | work@somtougeh.com (separate logins; `cf` is beta) |
| Executor cloud | Cloudflare Access as work@somtougeh.com, callback port 17908, tokens in `~/.mcp-auth` (0700/0600) |

## Dotfiles

Clone at `~/code/personal/dotfiles` (origin `git@github.com:SomtoUgeh/dotfiles.git`).

- `scripts/install_cloud_dotfiles.sh` was run with the key title changed to `julds-boat` (temporary copy, deleted).
- Claude and Codex were linked the way `install.sh` does on the Mac: CLAUDE.md, ETHOS.md, settings.json, commands, agents, output-styles, git_guard hook, statusline; Codex AGENTS.md, agents, `sync_agent_config.py`.
- `~/.claude/skills` keeps boat's own `boat` and `synced` skills; the 101 shared skills are per-skill symlinks.
- Claude plugins: all 7 enabled plugins installed after adding `anthropics/claude-plugins-official` as a marketplace. Claude wrote that marketplace into `agents/claude/settings.json` (only local change in the VM clone).
- boat drops a `boat` skill into `~/.agents/skills`; `agents/skills/boat/` is in `.git/info/exclude` on the VM.
- OpenCode config is host-local (`~/.config/opencode/opencode.jsonc`, copied from `opencode.cloud.jsonc`), because Executor setup writes into it. boat's `opencode.json` (computer tool) is kept alongside.
- Codex direct entries that cannot work on the VM are `enabled = false`: paper, playwright, cloudflare, granola, posthog, postman (all reachable through the gateways instead).

## MCP gateways (all five agents)

| Entry | What | How |
| --- | --- | --- |
| `executor_cloud` | Hosted Executor (GitHub, Google, Notion, PostHog, Postman, Cloudflare, Context7, Exa, ...) | `setup_executor.py --cloud-only --cloud-callback-port 17908`, mcp-remote 0.13.5 |
| `executor` | The Mac's local Executor: 1password, agentation, aside, canva, paper, playwright, shadcn | `~/.local/bin/executor-mac-mcp` -> mcp-remote -> `http://127.0.0.1:4789/mcp` on the VM, which is a boat reverse tunnel to the Mac's Executor. Bearer token in `~/.config/executor-mac/token` (0600) |
| `computer` | boat's Linux desktop / Chrome tools | boat rewrites it into each harness config at every sandbox start |

The Mac side of the tunnel is `~/Library/LaunchAgents/com.julds.boat-executor-bridge.plist` (runs `boat forward bx_gbx664fj --reverse --local 4789 --remote 4789`, KeepAlive). Loaded 24 Oct 2026. Files written by Aside get a `com.apple.quarantine` flag; launchd refuses the plist until `xattr -d com.apple.quarantine <plist>`. To reload from Terminal:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.julds.boat-executor-bridge.plist
```

The `executor` entry only works while the Mac is awake and the tunnel is up. Rotating the Mac token (`executor server rotate-token`) means rewriting the VM token file.

## Tools

git 2.56 (git-core PPA), gh 2.103, uv/uvx 0.13.5, node 24 (nvm), bun, pnpm, agent-browser 0.39 (with Chrome), wrangler 4.152, cf 1.0 beta. Unattended security upgrades on. Agent CLIs resolve from `~/.local/bin` (Claude native installer; codex, opencode, agent-browser, wrangler, cf linked from the nvm global bin).

## Verified 24 Oct 2026

- Claude, Codex, Grok, Cursor and OpenCode each returned `SomtoUgeh` through `executor_cloud` and listed the Mac integrations through `executor`.
- Codex `exec` can answer before the cloud gateway finishes starting; interactive T3 sessions are fine.
- Reboot: T3 service and T3 Connect came back by themselves; hostname stayed `julds`.
- Stop/resume: about 3 s / 1 s; T3 reconnected with no re-pairing.

## Gotchas

- `pkill -f mcp-remote...` inside `boat ssh -- 'bash -lc "..."'` kills the SSH command itself; use a `[m]cp-remote` pattern.
- Agent CLIs read stdin; give them `</dev/null` inside `bash -s` scripts.
- Wrangler's OAuth callback listens on `[::1]:8976`; `boat forward` targets 127.0.0.1, so bridge with socat for logins.
- Stop only between agent turns. Stopped disks are deleted after 14 days unless saved (`boat snapshot`).
- Security: agents here run with full access and can use claude.ai connectors (Gmail, Calendar, Docs), the Mac's desktop tools through `executor` (including 1Password and Playwright on the Mac browser), and boat's account-level CLI.

## Daily commands on the Mac

- `julds-up`: resume the VM if stopped and wait for T3 Connect.
- `julds-down`: stop it now (between agent turns only).
- `julds-tunnel`: forward AltSchool ports 5050 and 8000-8007 to the Mac.

## Idle auto-stop

`~/.local/bin/julds-idle-check` runs every 5 minutes (`julds-idle.timer`, user systemd). It stops the VM with `boat stop self` after 30 idle minutes. Active means any of: agent processes used CPU, an agent has an open TCP connection, system CPU >= 10%, an SSH login, or less than 20 minutes since boot. Log: `~/.local/state/julds-idle/log`. Pause it with `touch ~/.local/state/julds-idle/disabled`.

## 1Password

`op` 2.41 with service account `julds-boat-vm` (token in `~/.config/op/service-account-token`, exported by `~/.zshrc.private`, `~/.profile` and `~/.t3/service.env`). Read: AltSchool, Julds, Library, Shared with Grok Bot, Work. Read and write: Julds VM. Environments (read): Erivault Dev, Lami, Somto's website (`op run --environment <id> -- cmd`). Vault access is fixed; to change it, create a new service account. The token item is in the Personal vault.

## Migration from altschool-dev (24 Oct 2026)

- AltSchool repo cloned from GitHub, then all 26 local branches, the stash and the unpushed commit `c2f12615` restored from a `git bundle`.
- Ignored files carried by checksum: four env files (`apps/core/.env.local`, `apps/home/.env.local`, `apps/student/.env.local`, `apps/student/.env.development.local`), per-app AGENTS.md/CLAUDE.md, `.cursor/`; plus `~/.altschool` (portal QA evidence). `bun install --frozen-lockfile`, `bun run check` and `check-types` pass on bun 1.4.2.
- The droplet's uncommitted dotfiles edits were merged into main (`droplet-wip`).
- Agent histories on the droplet were not kept. The temporary migration copies were deleted after verification.
