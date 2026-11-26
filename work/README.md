# Work Mac setup

Runbook for setting up a work Mac from this repository. The coding agent on the
new Mac follows it. The user only does the steps marked **user**.

The work Mac gets the same shell, Zed, keyboard settings and daily apps as the
personal Mac. It does not get the personal identity or infrastructure.

| Comes across | Stays on the personal Mac |
| --- | --- |
| Zsh, Oh My Zsh, Starship, shared aliases (`shell/aliases.zsh`) | `boat`, `hitch`, Grok, OpenCode, LM Studio shell blocks |
| Shared git settings (`git/.gitconfig` as `~/.config/git/config`) | `~/.gitconfig-personal`, the SomtoUgeh keys, `gh-personal` |
| Zed and cmux/Ghostty config | Zed `ssh_connections` to the personal VMs, VS Code, Cursor |
| Claude Code: shared instructions, `bro` style, roles, status line, git guard | The personal Executor gateway, skills index hook, plugins |
| Raycast, Hidden Bar, AltTab, Alcove, BetterDisplay, Mole, Hex, Spark, Spotify, Slack, Zoom | Dropbox, Discord, Telegram, WhatsApp, Surfshark, Tailscale |
| T3 Code (Nightly), Paper, Bionic, with work accounts | The personal accounts and T3 environment links of those apps |
| GitLab: `glab`, two SSH keys, signed commits | Cloud CLIs (`hcloud`, `rclone`, `gcloud`), Executor, Codex config |

Files: [`install.sh`](install.sh), [`setup_gitlab.sh`](setup_gitlab.sh),
[`Brewfile`](Brewfile), [`zsh/`](zsh), [`git/gitconfig`](git/gitconfig),
[`claude/settings.json`](claude/settings.json).

## Rules for the agent

- This repository is public. Never write a company name, GitLab host, email,
  token or internal URL into it. Those values go in untracked files:
  `~/.gitconfig-work`, `~/.zshrc.private`, `~/.zshenv.local`.
- Do not commit or push from the work Mac. The checkout there is read-only.
- Do not sign in to anything for the user. Sign-ins, passwords, licences and
  policy questions are user steps. Tell the user what to do, then wait.
- Do not run the root `install.sh` or the root `Brewfile` on this Mac. They
  install the personal setup.
- Steps that open a macOS window (Command Line Tools, the Homebrew installer,
  the `glab` browser login) wait for the user. Tell the user before you start
  one. Run `work/install.sh` with a long timeout or in the background.
- Verify each phase with its check before you go to the next one.

## Phase 0 (user): before the agent starts

1. Finish the company's device enrollment (MDM) and the macOS updates.
2. Install Claude Code in Terminal: `curl -fsSL https://claude.ai/install.sh | bash`
3. Open a new Terminal window, run `claude`, and say:
   "Follow https://github.com/SomtoUgeh/dotfiles/blob/main/work/README.md"

## Phase 1 (agent): Command Line Tools, repository, install

1. Command Line Tools (git comes with them). If `xcode-select -p` fails, run
   `xcode-select --install`. Tell the user to click **Install** in the window
   and to say when it is done. Then check `xcode-select -p` again.
2. Get the repository. It is public, so no GitHub sign-in is needed:

   ```sh
   git clone https://github.com/SomtoUgeh/dotfiles.git ~/code/personal/dotfiles
   ```

   If it is already there: `git -C ~/code/personal/dotfiles pull --ff-only`.
3. Tell the user: "The macOS Installer opens for Homebrew. Follow it and type
   your Mac password there." Then run:

   ```sh
   ~/code/personal/dotfiles/work/install.sh
   ```

   Without a terminal, the script downloads Homebrew's signed `.pkg`. It checks
   that Apple notarized it and that Homebrew's Developer ID team signed it.
   Then it opens it and waits until the user closes the Installer. Next it runs
   the work Brewfile, Oh My Zsh with the pinned plugins, the Node LTS and
   Claude Code, and it links the configs. It is safe to run again. After a
   later `git pull`, `work/install.sh --links-only` refreshes the links
   without downloads.

   If casks fail on a password prompt, ask the user to run
   `brew bundle install --file=work/Brewfile` in Terminal, then run
   `work/install.sh` again.

Check:

```sh
readlink ~/.zshrc ~/.gitconfig ~/.config/git/config   # work/zsh/zshrc, work/git/gitconfig, git/.gitconfig
zsh -i -c 'alias gs; node --version; starship --version'
test ! -e ~/.gitconfig-personal && echo "no personal identity"
```

## Phase 2 (user, the agent guides): apps and accounts

Rule for accounts: an app that holds work data gets a work account, created
with the work email (or the company's SSO). Personal accounts stay off this
Mac, except for apps that hold no work data (Spotify). The agent asks the user
before each sign-in and never types a password.

| App | Account | Notes |
| --- | --- | --- |
| Raycast | Work account, or none | Export on the personal Mac (Settings > Advanced > Export). Import only the extensions, hotkeys and snippets wanted at work; personal quicklinks and snippets come along otherwise. |
| Hidden Bar | None | Set by hand: start at login, the items to hide. |
| Spark | Work email | Spark Desktop needs no App Store sign-in. Classic Spark is App Store only. |
| Slack, Zoom | Company SSO | Zoom installs from a `.pkg`, so it needs the password: run the bundle in Terminal if it failed. |
| Claude, Claude Code | Work account, if the company provides one | Claude Code signs in on first `claude` run. |
| T3 Code (Nightly) | None of its own | It uses the Claude Code and Codex sign-ins on this Mac. Do not link this Mac to the personal T3 environments (Settings > Labs > Linked environments, device hosts): a link lets one Mac run agents on the other. |
| Paper | Work account, if the team uses Paper | Designs live in Paper's cloud. Keep personal files in the personal account. |
| Bionic | None needed for local models | Models run on this Mac and take a lot of disk space. Sign in only for features that need an account. |
| Hex | None | On-device dictation. It asks for the Microphone and Accessibility permissions. |
| Mole | None | It cleans caches and logs. Check with IT before a deep clean on a managed Mac. |
| Spotify | Personal | No work data. |

Before you uncomment the "check first" lines in `work/Brewfile`, ask the
company. OrbStack, TablePlus and CleanShot need licences for work use.
Granola records meetings. Aside's AI reads every page you open, including
pages signed in to work accounts.

## Phase 3 (user, in Terminal): macOS settings

```sh
~/code/personal/dotfiles/macos/defaults.sh   # needs sudo; restart afterwards
enable_touchid_sudo.sh                       # Touch ID for sudo
```

The agent tells the user first: `defaults.sh` removes every pinned app from
the Dock, sets the en-GB locale and dark mode, and sets a very fast key
repeat. Company device management can override some of these settings.

## Phase 4 (agent, with the user): GitLab

Wait for this phase until the user has the work email and a GitLab account.
Phases 1 to 3 do not need them. Ask the user for the GitLab host and the email.
Then preview, and apply:

```sh
work/setup_gitlab.sh --host <gitlab-host> --email <work-email> --check
work/setup_gitlab.sh --host <gitlab-host> --email <work-email>
```

It makes two Ed25519 keys, `gitlab_auth_ed25519` and `gitlab_sign_ed25519`.
It writes the SSH and git config and opens the browser for the `glab` sign-in.
Then it uploads both public keys to GitLab. It ends with an SSH check, a
signing-key check and an identity check in `~/code/work`.

Where the private keys live (`--keys`):

- `file` (default): in `~/.ssh`. Each key has a random passphrase, which goes
  straight into the macOS Keychain. Nobody types or sees it. The work shell
  loads the keys into the macOS ssh-agent after a restart.
- `1password`: in a 1Password vault, with nothing private on disk. Use it only
  if the company uses 1Password. First:
  `brew install --cask 1password 1password-cli`. The user signs in to the work
  account, then turns on Settings > Developer > **Use the SSH agent** and
  **Integrate with 1Password CLI**. Add `--keys 1password`, plus `--vault` when
  the vault is not `Employee`, and `--account` when the app has more than one
  account (`op account list`). To move from `file` later, run it again with
  `--keys 1password`. Then delete the old keys in GitLab and `~/.ssh`.

Other options: `--ssh-host` and `--ssh-port` when GitLab SSH differs from the
web host. If the company blocks `glab` sign-in, use `--no-upload`. The user
then adds the two `.pub` files in GitLab > Preferences > SSH Keys, with the
usage type "Authentication" and "Signing".

Then the user signs a test commit in a work repository (clone it under
`~/code/work`):

```sh
git commit --allow-empty -m "signing test" && git log --show-signature -1
```

## Finished when

- A new terminal shows the Starship prompt with no errors.
- `rg -l 'SomtoUgeh|smugeh' ~/.gitconfig* ~/.ssh 2>/dev/null` prints nothing.
- After Phase 4: `work/setup_gitlab.sh --host <host> --email <email> --check`
  exits 0, `ssh -T git@<host>` greets the user, and a signed commit shows
  "Verified" in GitLab after the push.
