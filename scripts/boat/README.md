# boat per-project setup

One always-on boat VM per project runs `t3 serve`. Heavy checks go to throwaway
machines started from a per-project saved snapshot through `boat-check`.

| File | Runs on | Does |
| - | - | - |
| `boat-check` | project VM (`/usr/local/bin/boat-check`) | Runs a command on a throwaway machine from `<project>-base` and prints output, time and cost |
| `base-common.sh` + `base-<project>.sh` | a new build machine | Installs the toolchain, clones the repo from a git bundle, installs deps |
| `clean-base.sh` | a throwaway copy of a project VM | Removes the Tailscale node, T3 server, keepalive and sign-ins so the copy can be saved as `<project>-base` |
| `vm-new` | the Mac | One command for a new project VM or a replica: creates the sandbox, runs `vm-setup`, GitHub key, Tailscale, T3 links, Mac ssh config, VM list and Executor bridge. See "New project VM" |
| `vm-setup` | project VM (`~/.local/bin/vm-setup`, linked to this clone) | The one setup every project VM shares: base tools, zsh and prompt, T3, keepalive, git key, dotfiles, agent config, Executor, the Aside CLI (pointed at the Mac, updated daily), repos, boat-check, vm-heal, idle stop, hourly `vm-setup sync` timer. Safe to re-run. `vm-setup <p> status` shows what is done |
| `projects/<p>.env` (+ `<p>.sh`) | read by `vm-setup` and `vm-new` | The only per-project part: VM name, boat environment, repos and install commands, extra `~/.zshenv.local` lines, and optional `project_setup` (icb: Java, Android SDK, emulators) |
| `link-agent-config.sh` | run by `vm-setup` (agents stage) | Clones dotfiles and p3-stack, links the skills that stay on disk and retires Skillhub, Claude and Codex config like `install.sh`, adds `~/.claude/rules/boat-project-vm.md` |

## Agent config on a project VM

`vm-setup` runs `link-agent-config.sh` in its agents stage, and `vm-setup sync` runs it
again after each boot and every hour, so skills pushed from the Mac reach every VM within an
hour. It keeps boat's own `boat` and `synced` folders in `~/.claude/skills` and adds one link
per shared skill. The same stage writes the Executor bridges and registers `executor_v2` and
`executor_v2_local` for Claude and `executor_v2` for Codex.

## Skills on a project VM

Each run of `link-agent-config` keeps the tool skill folders (`~/.agents`,
`~/.claude`, and OpenCode, Grok and Cursor where they exist) to the skills that
stay on disk: the p3-stack skills, through `scripts/link_skills.sh`. Every other
skill loads through Executor, from the app `skills` that
[services/skills-mcp](../../services/skills-mcp/README.md) serves at
`mcp.julds.com`. `skill-fetch <skill>` (in `~/.local/bin`) puts a whole skill on
disk when it runs scripts. The SessionStart hook `~/.claude/hooks/skills-index.sh`
lists the library for Claude Code; Codex gets the same hook from
`sync_agent_config.py`.

Skillhub is retired. The first run on a VM runs `scripts/retire_skillhub.sh`:
`skillhub uninstall --yes`, then it removes `skillhub-sync.timer`, the
`skillhub` command, `~/.skillhub` and the `~/code/personal/skillhub` checkout
(a checkout with work that is not pushed stays). Later runs find nothing to do.
## Rebuild a base

1. On julds: `git bundle create /tmp/<p>.bundle --remotes=origin --tags` in the repo, copy it to the Mac.
2. `boat new --type default --environment <p> --name <p>-base-build --ttl 7200`, `boat scp` the bundle to `/home/user/`.
3. `cat base-common.sh base-<p>.sh | boat ssh <id> -- bash -s`, run the project's checks once.
4. `boat snapshot <id> <p>-base` (same name replaces it), then `boat delete <id> --yes`.

Never save a live project VM straight to `<project>-base`. The snapshot keeps the VM's
Tailscale node key, T3 service and keepalive, so every boat-check machine joins the tailnet
as that VM and runs a second T3 server: T3 times out and the VM looks offline (erivault,
12 Nov 2026). Build bases on a fresh machine as above, or start a throwaway copy, run
`clean-base.sh <project>` on it, then snapshot that copy. Never run `tailscale logout` on a
copy: the node key is shared with the live VM. boat-check also stops Tailscale and T3 on a
check machine and prints a warning when a base still carries them.

Keep repo `.boatignore` patterns anchored (`/apps/*/dist/`, not `dist/`). An
unanchored `dist/` also matches package folders inside `node_modules`, and the
saved snapshot then has broken packages.

Secrets stay in the boat environment (`boat env set-file`), never in a snapshot.
Add a secret file only after the base is saved.

## boat-check

- Config: `/etc/boat-check.env`. Key: `~/.config/boat-check/key`, a `ci`-preset
  key scoped to the project's environment (`boat api-key create <p>-ci --preset ci --ttl 90d --env <environment id>`).
- The CLI reads `BOAT_API_KEY`, so the VM's own boat login stays untouched.
- When boat refuses the start (`rate_limited`, `no_ready_machine`), the command runs locally.

## New project VM (or a replica)

From the Mac, in the dotfiles clone:

```sh
scripts/boat/vm-new icb                 # a new VM for a project that has projects/icb.env
scripts/boat/vm-new icb --name icb2     # a replica: same project and secrets, its own name
scripts/boat/vm-new icb --dry-run       # print the plan only
scripts/boat/vm-new icb --resume bx_... # carry on after a stop (every step is safe to repeat)
```

It runs every step of the old checklist. You only: open the Tailscale sign-in link it prints
(or set `TS_AUTHKEY`), add the VM in the T3 desktop app (Settings > Environments, select it on
the map, Add), sign Claude in on the VM (`claude auth login --claudeai`), and do the follow-ups it
lists at the end (julds wake list and key, the Executor "Boat VMs" app, telling Dev). It also signs the
Aside CLI in: confirm the VM in Aside > Settings > Account > Devices with the code it prints.

### A new project

1. `projects/<p>.env`: copy another one. Repos are `"<path under ~>|<git url>|<install command>"`.
   Anything special (toolchains, emulators) goes in `projects/<p>.sh` as `project_setup`.
2. The boat environment holds the project's secret files, so a replica needs no copying:
   `boat env new <p>`, then `boat env set <p> --agents-credentials false --github false --secrets true --boat-credentials true`,
   and add the shared secret files (`.config/op/service-account-token`, `.config/executor-v2/{cloud,mac}.token`)
   and the project's `.env` files with `boat env set-file`. `boat env new` and `boat env list` print every
   environment with its secrets: never paste their output anywhere.
3. `scripts/boat/vm-new <p>`.

### Existing VMs

`vm-setup <p>` on the VM brings it in line with the current setup and only restarts T3 when its
unit changed. `vm-setup <p> status` lists anything still missing.

## Sleep when idle, wake on demand

Project VMs (not julds) stop themselves after 45 quiet minutes and keep their disk; boat's own
auto-stop is a timer from start and cannot see T3, so the check is ours (14 Nov 2026).

| File | Runs on | Does |
| - | - | - |
| `boat-idle-stop` | project VM (`/usr/local/sbin`, `boat-idle-stop.timer` every 5 min) | Stops the VM after `IDLE_MIN` (45) quiet minutes. Busy: an unfinished T3 run, new T3 activity, a pts terminal used in the last 30 min, user CPU over 40%, or a hold. A 15-minute gap between checks means it was resumed and starts a fresh window. Log: `journalctl -t boat-idle` |
| `vm-stay` | project VM | `vm-stay 8` keeps it awake 8 hours; `vm-stay 0` clears it |
| `vm-heal` | project VM (`~/.local/bin`) | Puts the VM back together after a resume: see "Repair after resume" below |

Waking: the Mac's `com.julds.autowake` (`~/.local/bin/julds-autowake`) resumes every stopped VM in
`~/.config/boat-vms` when T3 Code comes to the front, and wakes any VM stopped 10+ days so boat's
14-day disk retention never runs out. `vm` on the Mac shows and wakes them. Agents use the Executor
app `boat-vms` (`vms.list`, `vms.status`, `vms.wake`) with a key limited to `sandbox.read` and
`sandbox.resume` on the project VMs; julds has `vm-wake` with its own such key. boat sends
error/degraded/recovered events to Dev's Coworkers webhook.

A new project VM also needs: this Mac's key in its `~/.ssh/authorized_keys` and a Host entry
(templates/ssh-config.template, used by Zed), its line in `~/.config/boat-vms`, its id in the `boat-vms` Executor app
and in julds's `vm-wake`, and new wake keys that include it (boat keys cannot gain sandboxes).

## Repair after resume (vm-heal)

What happened on 18 Nov 2026: on a resume boat boots the machine from its base image and only then
restores the saved disk, lazily (`ascii-agents-server ... [restore] STEP 1: ... lazyfs staging` in
the journal, after systemd has already started). systemd never sees our units, so `tailscaled`,
`<p>-keepalive.timer`, `boat-idle-stop.timer` and `agent-config-sync.timer` stay down: coworkers was
running for four hours with T3 up but unreachable and no idle-stop. On erivault the restore went
further wrong: `/etc`, `/usr` and `/var` came back as the base image (Tailscale uninstalled, node key
gone, our timers and scripts gone, `/var/log/dpkg.log` starting 31 Jul) while `/home/user` was intact.
Separately, resuming five VMs at once got investor-os `Resume failed: Failed to restore snapshot:
Please reduce your request rate`, and a later stop was refused because the final snapshot failed.

`vm-heal` lives in `/home` (the part that always survives) and fixes this:

- Keeps `~/.local/share/vm-heal/system.tgz` (our units, scripts, `/etc/boat-idle.env`,
  `/etc/boat-check.env`, the apt sources for Tailscale and 1Password, the memory-protection drop-ins)
  and a copy of `/var/lib/tailscale/tailscaled.state`, refreshed every 6 h while all is healthy.
- Each run: restores missing files, reinstalls Tailscale or the 1Password CLI if gone, restores the
  node key if missing, starts `tailscaled`, reloads systemd and starts our timers, resets the
  hostname, starts `t3code` and `vm-setup-sync.timer`, re-adds `tailscale serve` for T3.
- Only the real VM takes the identity back: it compares the IPv6 boat reports for its sandbox id with
  the machine's own (a fork or check copy has another). `clean-base.sh` deletes the copies.
- Triggers: `~/.config/autostart/vm-heal.desktop` (boat restarts the desktop session after the
  restore), `/etc/cron.d/vm-heal` every minute (cron rescans, systemd does not), and the Mac:
  `vm up` heals a VM that is running but silent after 45 s, and `julds-autowake` after 60 s.
- `vm-heal --status` shows what it checks; log `~/.local/state/vm-heal.log`.

What happened on 19 to 21 Nov 2026 (found 21 Nov): later restores also lost files under `/home`.
coworkers, erivault and investor-os came back without `~/.gitconfig`, the per-VM GitHub key, the
`gh` login, T3's unit and `~/.t3/runtime/service-state.json`, the npm tools in `~/.local/lib`, half of
`~/.local/share/vm-heal`, and every repo's `.git/HEAD` and `config` (plus hundreds of tracked files).
Outside `/home`: `/etc/group` and `/etc/gshadow` (erivault, so apt failed), `ubuntu.sources`
(coworkers, so Tailscale could not be reinstalled), and zsh (investor-os, so sshd refused every
login). T3 had been down on coworkers and erivault since about 19 Nov.

How it was fixed: files were copied back from each VM's last good boat snapshot with
`GET https://boat.dev/api/v1/snapshots/<id>/files?path=<abs path>` (a folder comes back as a .tar;
`boat snapshots <sandbox> --all --json` lists them, and a big drop in `fileCount` marks the bad
restore). Damaged repos got fresh history from GitHub, were put on the branch their surviving files
matched exactly, and the missing tracked files were checked out; the old folder is kept as
`.git.broken-20261121`.

vm-heal now also:
- keeps `/etc/group` and `/etc/gshadow` copies and puts them back if missing;
- reinstalls the login shell if it is missing;
- keeps the first SSH host keys (`sshhost.tgz`) and puts them back after a fresh boot, so the Mac
  does not refuse the VM with "Host key verification failed";
- keeps `home.tgz` (git config, GitHub key, `gh`, user units, Executor tokens, T3 launcher, runtime
  state and identity files) and restores it if `~/.gitconfig`, the T3 unit, the T3 environment id or
  T3's runtime state is missing;
- adds `ubuntu.sources` to `system.tgz`;
- mirrors `~/.local/share/vm-heal` to `/var/lib/vm-heal-mirror` (root only) and fills gaps from it;
- logs repos that lost `.git/HEAD` (rebuilding needs GitHub, so it only reports).

Mac side (not in this repo, backups `*.bak-20261118` next to them): `vm up all` resumes one VM every
4 s, retries once when boat marks the resume as error and gives up after 3 minutes; new `vm heal
<name|all>` and `vm snapshot <name|all>` (saved snapshot `<name>-weekly`, replaced each week).
`julds-autowake` spaces resumes 4 s apart and runs `vm snapshot all` once a week.
