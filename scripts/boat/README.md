# boat per-project setup

One always-on boat VM per project runs `t3 serve`. Heavy checks go to throwaway
machines started from a per-project saved snapshot through `boat-check`.

| File | Runs on | Does |
| - | - | - |
| `boat-check` | project VM (`/usr/local/bin/boat-check`) | Runs a command on a throwaway machine from `<project>-base` and prints output, time and cost |
| `base-common.sh` + `base-<project>.sh` | a new build machine | Installs the toolchain, clones the repo from a git bundle, installs deps |
| `devvm-setup.sh` | a new project VM | Hostname, Tailscale, T3 service, keepalive timer, `~/.boatignore`, git identity and key, `/etc/boat-check.env` |
| `devvm-tools.sh` | project VM | CLIs the skills call, pinned to julds versions: shellcheck, fd, bat, agent-browser (+ Chrome), wrangler, cf, op, Aside CLI. Then `aside login` (confirm in Aside on the Mac); op token as an environment secret file |
| `link-agent-config.sh` | project VM (`~/.local/bin/link-agent-config`) | Clones dotfiles and p3-stack, links skills, Claude and Codex config like `install.sh`, adds `~/.claude/rules/boat-project-vm.md`, installs `agent-config-sync.timer` (after boot and hourly) |

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

## Rebuild a base

1. On julds: `git bundle create /tmp/<p>.bundle --remotes=origin --tags` in the repo, copy it to the Mac.
2. `boat new --type default --environment <p> --name <p>-base-build --ttl 7200`, `boat scp` the bundle to `/home/user/`.
3. `cat base-common.sh base-<p>.sh | boat ssh <id> -- bash -s`, run the project's checks once.
4. `boat snapshot <id> <p>-base` (same name replaces it), then `boat delete <id> --yes`.

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
