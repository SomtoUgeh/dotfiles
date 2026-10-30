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

Also installed: git (git-core PPA), gh, uv/uvx, node 24.22.1 (nvm default, `/usr/local/bin/node` links to it; system `/usr/bin/node` from NodeSource `node_24.x`), bun 1.4.4 (`/usr/local/bin/bun` links to `~/.bun/bin/bun`), pnpm, agent-browser (with Chrome), wrangler, cf, `op`. Unattended security upgrades are on.

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

Since 26 Oct 2026 the VM uses Executor 2, the same as the Mac (see `agents/executor/v2.md`).
Set up with `setup_executor_v2.py --cloud-command ~/.local/bin/executor-v2-mcp --local-command ~/.local/bin/executor-v2-mac-mcp --retire-v1`.
The pre-change configs are in `~/.config/executor-v2/v1-agent-config-backup-*`.

| Entry | What | How |
| --- | --- | --- |
| `executor_v2` | Executor 2 in the cloud (`executor-v2.julds.com`): GitHub, Google, Notion, PostHog, Postman, Cloudflare, Figma, Granola, PlanetScale, Exa, Context7, ... | `~/.local/bin/executor-v2-mcp` -> mcp-remote (`--transport http-only`) with a bearer personal access token "julds-vm agents" (org Julds, expires 24 Jan 2027) in `~/.config/executor-v2/cloud.token` (0600). No browser sign-in. Renew the token in Executor (Account, Tokens) before it expires and rewrite the file |
| `executor_v2_local` | The Mac's local Executor 2: 1password, agentation, aside, canva, paper, playwright, shadcn | `~/.local/bin/executor-v2-mac-mcp` -> mcp-remote -> `http://127.0.0.1:4312/mcp` on the VM, a boat reverse tunnel to the Mac. The Mac's installation key (`~/.local/share/executor-v2-lab/data/keys.json` `apiKey`) is in `~/.config/executor-v2/mac.token` (0600) |
| `computer` | boat's Linux desktop / Chrome tools | boat rewrites it into each harness config at every sandbox start |

The Mac end of the tunnel is `~/.local/bin/julds-executor-bridge`, run by `~/Library/LaunchAgents/com.julds.boat-executor-bridge.plist` (KeepAlive). It keeps `boat forward bx_gbx664fj --reverse --local 4312 --remote 4312` (Executor 2) and a tunnel for the Mac's SSH (see iOS Simulators below) running while the VM is up, stops them when the VM stops, and restarts each when its probe from the VM (every 2 minutes) fails (the Executor 1 tunnel on 4789 was removed on 26 Oct 2026); a bare `boat forward` goes stale after a VM stop/resume without exiting. Log: `~/Library/Logs/boat-executor-bridge.log`. Restart with `launchctl kickstart -k gui/$(id -u)/com.julds.boat-executor-bridge`. The `executor_v2_local` entry works only while the Mac is awake.

boat self-updates on some commands (seen on `boat resume`). If that runs inside Aside's sandbox, macOS marks the new binary quarantined and kills it (exit 137), which also breaks the tunnel LaunchAgent. Fix: `xattr -d com.apple.quarantine ~/.ascii/bin/boat`.

Approvals (Executor 1 notes; in Executor 2 1Password asks on every call and the other local apps ask only for destructive tools): the Mac Executor policies `1password.*` and `playwright.*` are `require_approval` (since 24 Oct 2026), so those calls pause. Mac agents (stdio, `--elicitation-mode browser`) get a browser approval on the Mac. Calls from the VM go over HTTP, where Executor hands the approval back to the agent: it asks in the T3 thread and resumes after you reply, or you run `executor resume --execution-id <id> --action accept|cancel` on the Mac. On the VM this is a request, not a lock; set the policy to `block` for a hard stop. Paper, Aside, Canva, Agentation and shadcn keep their existing policies.

## iOS Simulators (T3 device host)

The VM cannot run iOS Simulators, so T3 on `julds` uses the Mac as an SSH **device host**. Set up 24 Oct 2026.

- **Where it shows.** In a `julds` thread, right panel → Device lists the Mac's simulators labelled "MacBook Pro". The stream and controls go through the environment server, so they work from the desktop app, app.t3.codes and the iPhone app (device button above the composer) over T3 Connect. Agents on `julds` drive the same devices through `agent-device` (installed on first use; restart a running agent session to give it access).
- **T3 setting.** Settings → Integrations → Devices, scope `box-node-0b8a829898b3443e` → Device hosts: name "MacBook Pro", SSH target `mac-devices`. Test connection reports "iOS available" (Android unavailable, expected).
- **VM side.** Key `~/.ssh/t3_device_host` (ed25519, no passphrase, used only for this) and a `Host mac-devices` block (127.0.0.1:2222, user `somto`) in `~/.ssh/config`; the block is in `templates/ssh-config-cloud.template`.
- **Mac side.**
  - Remote Login on (System Settings → General → Sharing → Remote Login, access limited to `somto`).
  - The VM's public key in `~/.ssh/authorized_keys` as `from="127.0.0.1,::1",no-agent-forwarding,no-X11-forwarding ssh-ed25519 ... julds-vm t3 device host`, so it only works through the tunnel.
  - `shell/.zshenv` puts fnm's default Node (`~/.local/share/fnm/aliases/default/bin`) on PATH, because T3 needs Node 22+ and npm in non-interactive SSH, and fnm otherwise loads only from `.zshrc`.
  - `julds-executor-bridge` keeps `boat forward bx_gbx664fj --reverse --local 2222 --remote 22` up (Mac :22 → VM 127.0.0.1:2222) and restarts it when a probe from the VM does not get an SSH banner on 2222.
- **Check from the Mac:** `boat ssh bx_gbx664fj -- 'ssh mac-devices "node -v; xcrun simctl list devices booted"'`.
- **Limits.** The Mac must be awake with Remote Login and the bridge running. A simulator on the Mac cannot reach a dev server (Metro, Vite) on the VM's localhost; forward that port to the Mac separately, the way `julds-tunnel` does for the AltSchool ports. The Mac's own T3 environment uses its simulators directly and needs none of this.
- **Undo.** Remove the host in T3, delete the `authorized_keys` line, turn Remote Login off, and drop the second forward from the bridge script.

## 1Password

`op` with service account `julds-boat-vm` (token in `~/.config/op/service-account-token`, exported by `~/.zshrc.private`, `~/.profile` and `~/.t3/service.env`, so T3-started agents have it).

- Read: AltSchool, Julds, Library, Shared with Grok Bot, Work. Read and write: Julds VM.
- Environments (read): Erivault Dev, Lami, Somto's website (`op run --environment <id> -- cmd`; `op environment` does not exist in this CLI).
- Access is fixed at creation; to change it, create a new service account. The token item is in the Personal vault, which the account cannot read.

## Idle auto-stop and waking

**Stop.** `~/.local/bin/julds-idle-check` runs every 5 minutes (`julds-idle.timer`, user systemd). After 30 idle minutes it saves the named snapshot `julds-latest` and runs `boat stop self`. The script exports `BOAT_ID=bx_gbx664fj`, because `boat ... self` needs it and the systemd timer does not inherit it (before 24 Oct 2026 every idle stop failed with "self can only be used inside a sandbox shell"). Active means any of: agent processes used CPU, an agent has an open TCP connection, system CPU >= 10%, an SSH login, or less than 20 minutes since boot. Log: `~/.local/state/julds-idle/log`. Pause with `touch ~/.local/state/julds-idle/disabled`.

**Wake.** A stopped VM has no machine, so nothing wakes it by itself; T3 shows it offline until it is resumed.

- Mac: `~/.local/bin/julds-autowake` runs every 20 s (`~/Library/LaunchAgents/com.julds.autowake.plist`, loaded). When T3 Code is the frontmost app and `julds` is stopped, it runs `boat resume` (at most once every 2 minutes). Log: `~/Library/Logs/julds-autowake.log`. Fixed 27 Oct 2026: `lsappinfo` prints the app name quoted (`"T3 Code (Nightly)"`) plus extra lines, and the old parsing kept the quote, so the match never fired in 13.5k runs. It now takes the first quoted string. `touch ~/Library/Caches/julds-autowake/probe` logs one `probe: ... matched` line on the next run to confirm detection. It only helps at the Mac (awake, T3 in front); away from it use the iPhone Shortcut or the dashboard.
- iPhone: Shortcut "Wake julds": Get Contents of URL, POST `https://boat.dev/api/v1/sandboxes/bx_gbx664fj/resume`, header `Authorization: Bearer <key>`. The key is the 1Password item "boat julds wake key" (Julds VM vault): boat API key `julds-wake-phone`, limited to this sandbox with `sandbox.resume` and `sandbox.read`, expires Oct 2027.
- Anywhere: boat.dev/dashboard, Sandboxes, Resume.
- Phone/anywhere (27 Oct 2026): **https://wake.julds.com** (Worker `julds-wake`, source `services/julds-wake/`, deployed from the VM with the token in `~/.config/executor-v2-julds/env`). Opening the page resumes julds if it is stopped (`?peek` only shows status) and shows when T3 is ready. Gated by Cloudflare Access app "julds wake" (policies: Executor Owner = work@somtougeh.com, and "julds wake - personal (WARP)" = smugeh@gmail.com; 1-month session) and the Worker re-checks the Access JWT (AUD + ALLOWED_EMAILS) and fails closed. Secret `BOAT_KEY` = the `julds-wake-phone` key (resume + read only). boat's API reports a stopped VM as `archived`, not `stopped`.
- WARP: dropped on 30 Oct 2026 (Somto uses Tailscale instead). With WARP off, wake.julds.com uses its one-month email-code login. The smugeh WARP policy on the "julds wake" Access app is harmless and can stay.

**Routes to T3 (30 Oct 2026).** julds has two routes, Tailscale first:
- Tailscale: tailnet `taildbdfb2.ts.net` (owner smugeh@gmail.com, MagicDNS + HTTPS on). The VM is node `julds` (100.90.30.81, key expiry disabled, `--accept-dns=false`, operator `user`). `t3 pair --tailscale` set Tailscale Serve `https://julds.taildbdfb2.ts.net/` -> `127.0.0.1:3773` (persists; remove with `tailscale serve --https=443 off`). After a wake it answers about a minute before T3 Connect.
- T3 Connect (relay) as fallback. The account has 3 of 3 tunnels in use (Mac, julds, FM-UK-LAP-185); Tailscale needs none.
- Routes are per client. Add the Tailscale route in each app: in a julds terminal run `t3 pair --tailscale`, then Settings > Environments > julds > Routes > Add route and paste the Pairing URL (the phone can scan the QR). The web app (app.t3.codes) has it.
- Mac/iPhone need the Tailscale app signed in as smugeh@gmail.com. WARP on the Mac blocked Tailscale sign-in, which is why WARP was dropped.

**Reliability setup (30 Oct 2026).**
- `t3 service protect --yes`: memory protection for T3, ssh and tailscaled (`90-t3code-protect.conf` drop-ins under /etc/systemd/system and ~/.config/systemd/user).
- `~/.boat/pre-stop`: boat runs it before every stop; it stops t3code.service cleanly so its SQLite state is checkpointed, then a transient timer restarts T3 after 20 s in case the stop is refused or the VM is re-woken on the same machine. A wake within 10 min of a stop reuses the machine without a reboot, and boat can hold it paused for minutes while it supersedes the stop.
- `julds-idle-check` logs `WARNING: still running 120s after stop request` if a stop does not complete (boat refuses stops whose snapshot fails, keeps the VM up unbilled, retries and emails).
- Fixed hostname `julds` from `/etc/systemd/system/julds-hostname.service` (boat does not snapshot /etc/hostname). T3 now labels the environment `julds`.
- `~/.boatignore` leaves `.npm/` and `.bun/install/cache/` (~9.7 GB) out of snapshots. Unused Docker images were pruned (they are not restored anyway).
- T3 channel: nightly. The Mac app pushes server updates to the VM ("Server update prepared"), so client and server stay on the same version; the activeVersion launcher drop-in keeps an update from stranding the service. Moving to stable would need the stable Mac app and may be refused by the DB.
- Mac autowake notifies "julds is ready" only when T3 Connect answers for julds (state file `~/Library/Caches/julds-autowake/pending`), or warns after 10 min.
- Weekly snapshots: the julds-wake Worker cron (Sundays 03:00 UTC) saves `julds-weekly-YYYY-MM-DD` and keeps 4, alongside `julds-latest` (up to 5 of 10 free). Key: boat `julds-weekly-snapshot` (snapshot.read/write + sandbox.read on bx_gbx664fj, expires Oct 2027; 1Password "boat julds weekly snapshot key"), Worker secret `BOAT_SNAPSHOT_KEY`.
- Alerts: boat webhook `julds-alerts` (wh_1a1dd916cb1d795dbd978f7b; error, degraded, recovered) -> `https://wake.julds.com/hooks/boat` (Access bypass app "julds wake - boat webhooks (bypass)"; the Worker checks the boat HMAC signature and rejects anything else) -> email to smugeh@gmail.com from julds@alerts.julds.com. Cloudflare Email Sending is onboarded on the `alerts.julds.com` subdomain only, so julds.com iCloud MX/SPF/DMARC are untouched. Wake failures and weekly-snapshot failures also email. Secrets: Worker `BOAT_WEBHOOK_SECRET`, 1Password "boat julds alerts webhook secret". boat itself still emails for refused stops, unresponsive VMs, disk 85/95% and the 14-day expiry.

Away from the Mac, everything on the VM works except the `executor` (Mac local) tools: Paper, Aside, Playwright, desktop 1Password and Canva need the Mac awake.

## Data retention

boat deletes a stopped sandbox's disk 14 days after the stop (email on day 11). The idle check and `julds-down` refresh the named snapshot `julds-latest` before every stop; named snapshots never expire and 10 are included in the plan. If the disk ever expires, recover with `boat new --from julds-latest --no-auto-stop`, then update the sandbox id in `julds-up`, `julds-down`, `julds-tunnel`, `julds-autowake`, the bridge plist, the wake key and this runbook.

## Gotchas

- T3 self-updates prune old runtime versions, but `t3code.service` pins one exact version in ExecStart. On 27 Oct 2026 the pinned 20261024.3630 was gone, so after a resume the service failed with 203/EXEC and T3 showed julds offline. Fix: the drop-in `~/.config/systemd/user/t3code.service.d/julds-stable-launcher.conf` runs `~/.local/bin/t3-service-launcher`, which starts the `activeVersion` from `~/.t3/runtime/service-state.json` (or the newest version present) and relinks `~/.local/bin/t3`. If T3 is offline after a resume, check `systemctl --user status t3code.service`; `t3 service install` repairs it.
- Revoking the GitHub CLI OAuth app (github.com/settings/applications) signs out every `gh` and also deletes SSH keys that were uploaded through `gh`. Re-add with `gh ssh-key add ~/.ssh/id_ed25519_personal.pub --title julds-boat --type authentication`.
- Files Aside writes on the Mac can carry `com.apple.quarantine`; launchd and Gatekeeper refuse them until `xattr -d com.apple.quarantine <file>`. Load LaunchAgents as yourself (`launchctl bootstrap gui/$(id -u) ...`), never with sudo; error 5 also means "already loaded".
- `pkill -f mcp-remote...` inside `boat ssh -- 'bash -lc "..."'` kills the SSH command itself; use a `[m]cp-remote` pattern.
- Agent CLIs and `op` read stdin; give them `</dev/null` inside `bash -s` scripts.
- `boat forward --reverse` reads the ports opposite to its help text: `--local` is the port inside the VM and `--remote` is the Mac port (check the `localPort`/`sandboxPort` it prints). With equal ports (4789) it does not matter. Reversed, it fails with "remote port forwarding failed for listen port 22".
- Wrangler's OAuth callback listens on `[::1]:8976`; `boat forward` targets 127.0.0.1, so bridge with socat for logins.
- Codex `exec` can answer before the cloud gateway finishes starting; interactive T3 sessions are fine.
- T3's self-update can leave `~/.local/bin/t3` pointing at a removed runtime (24 Oct 2026: `.3604` after the service moved to `.3630`). The service keeps running, but `t3` is "command not found" and `julds-up` never sees T3 Connect. The active version is in `~/.t3/runtime/service-state.json`; `julds-up` now repoints the link to it before each check. By hand: `ln -sfn ~/.t3/runtime/versions/<activeVersion>/t3 ~/.local/bin/t3`.
- The VM's `executor_cloud` token can go missing (26 Oct 2026: no `*_tokens.json` under `~/.mcp-auth/mcp-remote-v1`). The adapter then waits for a browser login and agents time out. Re-authorize: start the configured adapter on the VM, run `boat forward bx_gbx664fj --local 17908 --remote 17908` on the Mac, open the printed Cloudflare Access URL in the Mac browser, approve "MCP CLI Proxy http://localhost:17908", then stop the forward. `executor-cloud-login` needs plain SSH and does not reach julds.
- `boat ssh <id> -- cmd < file` hangs because stdin never closes; pass small files as inline base64. Use `python3 -u` under `timeout`, or the output is lost.
- Stop only between agent turns: a stop ends running processes (no hibernate). Enabled systemd services start again on resume.
- Security: agents run with full access and can use claude.ai connectors (Gmail, Calendar, Docs), the `gh` login, the 1Password service account, the Mac's desktop tools through `executor` (1Password and Playwright need approval), and boat's account-level CLI. Patterns to adopt later: credentials kept outside the sandbox (Cloudflare outbound Workers for Sandboxes, boat's secret proxy) and a repo-scoped GitHub token.
- Scheduled or always-on work (T3 Scheduled Tasks on julds, proactive agents) does not run while the VM is stopped; run it from the Mac's T3, from Cloudflare (Agents SDK / Pi Durable), or pause the idle check during those windows.

## History

- 24 Oct 2026: replaced the DigitalOcean droplet `altschool-dev`. The AltSchool repo (main and staging-* branches), its four env files (checksums matched), per-app AGENTS.md/CLAUDE.md, `.cursor/` and `~/.altschool` were carried over; other local branches were dropped by choice. The droplet, its firewall, API tokens and SSH key, the Cloudflare tunnel, private route and split-tunnel entry, the old GitHub keys, the Executor DigitalOcean integrations and the DigitalOcean tooling in these dotfiles were removed. The droplet's uncommitted dotfiles edits were merged (`droplet-wip`).
- 24 Oct 2026: iOS Simulators for `julds` through the Mac as a T3 device host. Verified: Test connection "iOS available", and the Mac's iPhone 18 Pro (iOS 27.0) streamed in a `julds` thread on app.t3.codes.
- Verified 24 Oct 2026: all five agents read GitHub through `executor_cloud` and listed the Mac integrations through `executor`; reboot and stop/resume keep T3 Connect without re-pairing; `bun run check` and `check-types` pass.

## Security patches

- 24 Oct 2026, CVE-2026-111497 (Brotli decoder out-of-bounds write, "Node2Shell"; fixed in Node 22.23.4 / 24.22.1 / 26.12.1 and Bun 1.4.4). julds: Bun 1.4.2 -> 1.4.4, `/usr/local/bin/bun` 1.3.14 replaced by a link, nvm v22.23.2 and v24.18.1 removed, NodeSource moved from `node_20.x` to `node_24.x`, then `julds-down` + `boat resume` onto a patched host. Already patched: T3 (Node 26.12.1 SEA), Claude Code and OpenCode (Bun 1.4.4), cursor-agent (bundled Node 24.22.1). Still open: Ubuntu `libbrotli1` 1.1.0 (Ubuntu status "needs evaluation"; unattended-upgrades will pick up the fix). AltSchool's `packageManager` still says `bun@1.4.2`.
