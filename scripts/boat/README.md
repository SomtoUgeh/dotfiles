# boat per-project setup

One always-on boat VM per project runs `t3 serve`. Heavy checks go to throwaway
machines started from a per-project saved snapshot through `boat-check`.

| File | Runs on | Does |
| - | - | - |
| `boat-check` | project VM (`/usr/local/bin/boat-check`) | Runs a command on a throwaway machine from `<project>-base` and prints output, time and cost |
| `base-common.sh` + `base-<project>.sh` | a new build machine | Installs the toolchain, clones the repo from a git bundle, installs deps |
| `clean-base.sh` | a throwaway copy of a project VM | Removes the Tailscale node, T3 server, keepalive and sign-ins so the copy can be saved as `<project>-base` |
| `devvm-setup.sh` | a new project VM | Hostname, Tailscale, T3 service, keepalive timer, `~/.boatignore`, git identity and key, `/etc/boat-check.env` |
| `link-agent-config.sh` | project VM (`~/.local/bin/link-agent-config`) | Clones dotfiles and p3-stack, links skills (or leaves them to Skillhub), Claude and Codex config like `install.sh`, adds `~/.claude/rules/boat-project-vm.md`, installs `agent-config-sync.timer` (after boot and hourly) |

## Agent config on a project VM

After `devvm-setup.sh`, and after the VM's key is on GitHub:

```sh
boat ssh <id> -- 'mkdir -p ~/.local/bin && cat > ~/.local/bin/link-agent-config && chmod 755 ~/.local/bin/link-agent-config && ~/.local/bin/link-agent-config' < link-agent-config.sh
```

It keeps boat's own `boat` and `synced` folders in `~/.claude/skills` and adds
one link per shared skill. The timer pulls dotfiles and relinks, so skills
pushed from the Mac reach the VM within an hour. It skips the parts of
`install_cloud_dotfiles.sh` that add GitHub keys or change the login shell.
Executor needs its own sign-in.

## Skillhub on a project VM

A VM with no Skillhub gets one link per shared skill, as above. To make its
tools load skills from the Skillhub library through Executor instead:

```sh
git clone git@github.com:SomtoUgeh/skillhub.git ~/code/personal/skillhub
cd ~/code/personal/skillhub
bun install --frozen-lockfile --production   # bun 1.4.4: the image's 1.3.14 cannot read this bun.lock
bun link                                     # puts skillhub into ~/.bun/bin
skillhub login                               # confirm the code in a browser on any machine
skillhub mode download                       # take every skill from the library, never from this dotfiles clone
skillhub sync                                # writes ~/.skillhub/managed.json
link-agent-config                            # removes the per-skill links
```

While `~/.skillhub/managed.json` exists, each run of `link-agent-config`
leaves the skill folders to Skillhub. It removes only the links that it made
itself, keeps the links that Skillhub owns and boat's `boat` and `synced`
folders, and runs `skillhub sync`, so a change of the active set reaches the
VM within an hour. A sync that fails does not stop the run.

Before the sync, each run pulls `~/code/personal/skillhub` and runs
`bun install`, so every VM has the `skillhub` command of the main branch.
Then it runs `skillhub mode download`: this dotfiles clone holds a copy of the
skills folder, and in link mode a sync links the tools to that copy, so the
VM would keep its own version of the library. When the mode cannot be set,
the run does not sync.

Codex reads `~/.agents/skills`. While that path is one link to the shared
folder, the script runs `skillhub adopt ~/.agents/skills --yes` before the
sync. The path then is a real folder with only the active skills, and
Codex loads the others through Executor, as Claude Code does. After the
adopt, a skill that is not active is not at `~/.agents/skills/<name>`: a
script that a skill names by that path runs only while the skill is active.
The Codex hooks run from the dotfiles repository, not from that path.

Codex needs two more steps on each VM, one time:

```sh
# The Executor entry: the bearer wrapper of the VM, no browser sign-in.
codex mcp remove executor_v2
codex mcp add executor_v2 -- "$HOME/.local/bin/executor-v2-mcp"
# The hooks: start Codex, open /hooks, approve the Skillhub hook and the
# shaping hook. Codex does not run a new or changed hook before that.
```

Do not run a plain `skillhub adopt` on a project VM: it moves `boat` and
`synced` out of `~/.claude/skills`. The script already clears that folder.
`skillhub uninstall --yes` removes the ledger, and the next run links every
skill again.

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

## New project VM checklist

A VM is not done until every line holds (investor-os, 14 Nov 2026, followed this list):

1. `boat env new <p>`, then `boat env set <p> --agents-credentials false --github false --secrets true --boat-credentials true`, and copy the shared secret files (`.config/op/service-account-token`, `.config/executor-v2/{cloud,mac}.token`) from another project environment. `boat env new` prints every environment with its secrets: do not paste its output anywhere.
2. `boat new --environment <p> --type large --name <p>-dev --no-auto-stop`.
3. Base tools: zsh (and `chsh`), fzf, jq, ripgrep, starship in `~/.local/bin`, `npm config set prefix ~/.local` then `mcp-remote cf wrangler portless`, bun 1.4.4.
4. `T3CODE_VERSION=<desktop version> devvm-setup.sh <p> <repo path> <install>`.
   Then `idle-stop-install.sh <id> 45 0` and vm-heal: `boat scp scripts/boat/vm-heal <id>:/tmp/vm-heal`, `boat ssh <id> -- 'install -m 755 /tmp/vm-heal ~/.local/bin/vm-heal && ~/.local/bin/vm-heal --setup <p> <id>'` (after step 5, so its copy includes the Tailscale node key).
5. `sudo tailscale up --hostname=<p> --accept-dns=true --operator=user`, sign in as smugeh@gmail.com.
6. T3: `t3 pair --tailscale --ttl 1h` once per client. Add it in T3 web and the desktop app (Settings > Environments > Add environment), and link it from the Mac and from julds with `t3 environment link https://<p>.taildbdfb2.ts.net --pairing-code <code> --access full-access`. The julds link is how Executor and Dev's T3 watch reach it. Links last 30 days.
7. Repo, then `t3 project add <path>`. The VM key goes on GitHub as an authentication and a signing key (github.com/settings/ssh/new, passkey).
8. Agents: `claude auth login --claudeai`, `link-agent-config`, Skillhub (above), Executor wrappers from another VM plus `claude mcp add --scope user executor_v2 / executor_v2_local` and `codex mcp add executor_v2`.
9. Mac: copy `~/Library/LaunchAgents/com.julds.boat-executor-bridge.<other>.plist` with the new sandbox id, and Somto runs `launchctl bootstrap gui/$(id -u) <plist>` in his Terminal (Aside cannot).
10. Aside CLI: install, `aside login --email smugeh@gmail.com`, approve the device, then `aside host use remote:266a3611-e171-4cec-b729-57b5dcfbb28c`.
11. Coworkers: tell Dev (job text) about the VM, its environment id and project id.

## Sleep when idle, wake on demand

Project VMs (not julds) stop themselves after 45 quiet minutes and keep their disk; boat's own
auto-stop is a timer from start and cannot see T3, so the check is ours (14 Nov 2026).

| File | Runs on | Does |
| - | - | - |
| `boat-idle-stop` | project VM (`/usr/local/sbin`, `boat-idle-stop.timer` every 5 min) | Stops the VM after `IDLE_MIN` (45) quiet minutes. Busy: an unfinished T3 run, new T3 activity, a pts terminal used in the last 30 min, user CPU over 40%, or a hold. A 15-minute gap between checks means it was resumed and starts a fresh window. Log: `journalctl -t boat-idle` |
| `vm-stay` | project VM | `vm-stay 8` keeps it awake 8 hours; `vm-stay 0` clears it |
| `idle-stop-install.sh` | project VM | `bash idle-stop-install.sh <sandbox id> 45 0` writes `/etc/boat-idle.env` (last arg 1 = dry run) and enables the timer |
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
  hostname, starts `t3code` and `agent-config-sync.timer`, re-adds `tailscale serve` for T3.
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
