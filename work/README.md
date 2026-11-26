# Work Mac setup

Runbook for setting up a work Mac from this repository. Hand this file to the
coding agent on the new Mac: "Follow work/README.md."

The work Mac gets the same shell, editors, keyboard settings and daily apps as
the personal Mac. It does not get the personal identity or infrastructure.

| Comes across | Stays on the personal Mac |
| --- | --- |
| Zsh, Oh My Zsh, Starship, shared aliases (`shell/aliases.zsh`) | `boat`, `hitch`, Grok, OpenCode, LM Studio shell blocks |
| Shared git settings (`git/.gitconfig` as `~/.config/git/config`) | `~/.gitconfig-personal`, the SomtoUgeh keys, `gh-personal` |
| Zed, VS Code, cmux/Ghostty config | Zed `ssh_connections` to the personal VMs |
| Claude Code: shared instructions, `bro` style, roles, status line, git guard | The personal Executor gateway, skills index hook, plugins |
| Raycast, Hidden Bar, AltTab, Alcove, BetterDisplay, Spark, Spotify, Slack | Dropbox, Discord, Telegram, WhatsApp, Surfshark, Tailscale |
| GitLab: `glab`, keys in the work 1Password vault, signed commits | Cloud CLIs (`hcloud`, `rclone`, `gcloud`), Executor, Codex config |

Files: [`install.sh`](install.sh), [`setup_gitlab.sh`](setup_gitlab.sh),
[`Brewfile`](Brewfile), [`zsh/`](zsh), [`git/gitconfig`](git/gitconfig),
[`claude/settings.json`](claude/settings.json).

## Rules for the agent

- This repository is public. Never write a company name, GitLab host, email,
  token or internal URL into it. Those values go in untracked files:
  `~/.gitconfig-work`, `~/.zshrc.private`, `~/.zshenv.local`.
- Do not commit or push from the work Mac. The checkout there is read-only.
- Do not sign in to anything for the user. Sign-ins, the 1Password unlock,
  licences and policy questions are user steps. Ask, then wait.
- Do not run the root `install.sh` or the root `Brewfile` on this Mac. They
  install the personal setup.
- `sudo` needs a real terminal. When a step needs it, ask the user to run the
  command in a terminal tab and tell you the result.
- Verify each phase with the checks below before you go to the next one.

## Phase 0: user steps before the agent starts

The user does these by hand, in this order.

1. Finish the company's device enrollment (MDM) and the macOS updates.
2. Ask the company about these points, because they change later steps:
   - Is 1Password provided (1Password Business)? Is a personal 1Password
     account allowed on this Mac? If not sure, use only the work account.
   - Are OrbStack, TablePlus and CleanShot licensed? Is Granola (meeting
     recording) allowed? These lines stay commented in `work/Brewfile` until
     the answer is yes.
   - The GitLab host, and whether GitLab SSH uses a different host or port.
3. Install the Command Line Tools: `xcode-select --install`.
4. Install Homebrew in Terminal (it asks for the password):
   `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
   Then run the two `eval` lines that the installer prints.
5. Install 1Password first, so the passwords are ready for every later sign-in:
   `brew install --cask 1password 1password-cli`
   - Sign in to the work account.
   - Settings > Developer: turn on **Use the SSH agent** and
     **Integrate with 1Password CLI**.
6. Get this repository. It is public, so no GitHub sign-in is needed:
   `git clone https://github.com/SomtoUgeh/dotfiles.git ~/code/personal/dotfiles`
7. Install Claude Code and start it in the checkout:
   `curl -fsSL https://claude.ai/install.sh | bash`, then
   `cd ~/code/personal/dotfiles && claude`, and say "Follow work/README.md".

## Phase 1: install (agent)

```sh
cd ~/code/personal/dotfiles
git pull --ff-only
./work/install.sh
```

It runs the work Brewfile, Oh My Zsh with the pinned plugins, the Node LTS,
Claude Code, VS Code extensions, and links the configs. It is safe to run
again. After a later `git pull`, `./work/install.sh --links-only` refreshes the
links and the rendered files without downloads.

If casks fail on a password prompt, ask the user to run
`brew bundle install --file=work/Brewfile` in a terminal, then run
`./work/install.sh` again.

Check:

```sh
readlink ~/.zshrc ~/.gitconfig ~/.config/git/config   # work/zsh/zshrc, work/git/gitconfig, git/.gitconfig
zsh -i -c 'alias gs; node --version; starship --version'
test ! -e ~/.gitconfig-personal && echo "no personal identity"
```

## Phase 2: GitLab (agent, with the user)

Ask the user for the GitLab host and the work email. Then preview, and apply:

```sh
./work/setup_gitlab.sh --host <gitlab-host> --email <work-email> --check
./work/setup_gitlab.sh --host <gitlab-host> --email <work-email>
```

Options: `--ssh-host` and `--ssh-port` when GitLab SSH differs from the web
host, `--vault` when the keys go in a vault other than `Employee`, and
`--account` when the 1Password app has more than one account
(`op account list`).

The script creates two Ed25519 keys in the vault (`gitlab_auth_ed25519`,
`gitlab_sign_ed25519`), writes their public halves and the SSH and git config,
opens the browser for the `glab` sign-in, and uploads both public keys to
GitLab. 1Password asks the user to approve key use. The script ends with an
SSH check and an identity check in `~/code/work`.

If the company disables personal access tokens or OAuth for `glab`, run the
script with `--no-upload`. The user then adds the two `.pub` files in GitLab >
Preferences > SSH Keys, with the usage type "Authentication" and "Signing".

Then the user signs a test commit in a work repository (clone it under
`~/code/work`) and approves the 1Password prompt:

```sh
git commit --allow-empty -m "signing test" && git log --show-signature -1
```

## Phase 3: apps (user, the agent guides)

- **Raycast**: on the personal Mac, Raycast Settings > Advanced > Export. On
  the work Mac, import the file and pick only the extensions, hotkeys and
  snippets wanted at work. Personal quicklinks and snippets come along if
  everything is imported.
- **Hidden Bar**: set by hand (start at login, the items to hide).
- **Spark**: the Brewfile installs Spark Desktop, which needs no App Store
  sign-in. Classic Spark is App Store only. Sign in with the work email.
- **Spotify, Slack, Chrome, Claude**: sign in.
- **1Password browser extension**: install it in the browser in use.

## Phase 4: macOS settings (user, in a terminal)

```sh
./macos/defaults.sh        # needs sudo; restart afterwards
enable_touchid_sudo.sh     # Touch ID for sudo
```

Tell the user first: `defaults.sh` removes every pinned app from the Dock,
sets the en-GB locale and dark mode, and sets a very fast key repeat. Company
device management can override some of these settings.

## Finished when

- `./work/setup_gitlab.sh --host <host> --email <email> --check` exits 0.
- `ssh -T git@<host>` greets the user, and a signed commit shows "Verified"
  in GitLab after the push.
- A new terminal shows the Starship prompt with no errors.
- `rg -l 'SomtoUgeh|smugeh' ~/.gitconfig* ~/.ssh 2>/dev/null` prints nothing.
