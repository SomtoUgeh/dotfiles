#!/usr/bin/env bash
# Runs work/install.sh --links-only and work/setup_gitlab.sh against a temporary
# home. op, glab, ssh and ssh-add are stubs: no network, no 1Password, no
# GitLab, and nothing is written to the real Keychain or ssh-agent.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME=$fixture/home
unset XDG_CONFIG_HOME GITLAB_HOST
export GIT_CONFIG_NOSYSTEM=1
mkdir -p "$HOME"

fail() { echo "FAIL: $*" >&2; exit 1; }
is_link_to() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || fail "$1 is not a link to $2"; }

# --- work/install.sh --links-only --------------------------------------------
out=$(bash "$root/work/install.sh" --links-only)
is_link_to "$HOME/.zshrc" "$root/work/zsh/zshrc"
is_link_to "$HOME/.zshenv" "$root/work/zsh/zshenv"
is_link_to "$HOME/.gitconfig" "$root/work/git/gitconfig"
is_link_to "$HOME/.config/git/config" "$root/git/.gitconfig"
is_link_to "$HOME/.claude/output-styles" "$root/agents/claude/output-styles"
is_link_to "$HOME/bin/setup_gitlab.sh" "$root/work/setup_gitlab.sh"
[ -f "$HOME/.zshrc.private" ] || fail "no ~/.zshrc.private"
[ -f "$HOME/.claude/settings.json" ] || fail "no Claude settings"

# Nothing personal comes across.
[ ! -e "$HOME/.gitconfig-personal" ] || fail "personal git identity written"
[ ! -e "$HOME/.config/gh-personal" ] || fail "gh-personal written"
! grep -q 'ssh_connections' "$HOME/.config/zed/settings.json" || fail "Zed still lists the personal VMs"
grep -q '"agent_servers"' "$HOME/.config/zed/settings.json" || fail "Zed settings lost other keys"
! grep -q 'Executor' "$HOME/.claude/CLAUDE.md" || fail "CLAUDE.md still routes MCP through Executor"
grep -q '^## Ethos' "$HOME/.claude/CLAUDE.md" || fail "CLAUDE.md lost the shared sections"
! grep -rq 'julds\|boat' "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md" || fail "personal infrastructure in Claude config"

# A second run changes nothing.
again=$(bash "$root/work/install.sh" --links-only)
! printf '%s' "$again" | grep -qE 'wrote|backed up' || fail "second run changed files: $again"

# A file the user owns is kept.
printf '{}\n' > "$HOME/.config/zed/settings.json"
out=$(bash "$root/work/install.sh" --links-only)
printf '%s' "$out" | grep -q 'kept your own ~/.config/zed/settings.json' || fail "user Zed settings not kept"
[ "$(cat "$HOME/.config/zed/settings.json")" = "{}" ] || fail "user Zed settings overwritten"

# The shell starts and has the shared aliases.
(cd "$HOME" && zsh -i -c 'alias gs >/dev/null && whence -w killport >/dev/null') 2>/dev/null || fail "work zsh lacks the shared aliases"

# Identity: work folders and agent worktrees use the work file; other folders have none.
printf '[user]\n\temail = work@example.com\n' > "$HOME/.gitconfig-work"
for d in code/work/app .t3/worktrees/app .codex/worktrees/app; do
  git init --quiet "$HOME/$d"
  [ "$(git -C "$HOME/$d" config user.email)" = work@example.com ] || fail "$d does not use the work identity"
done
git init --quiet "$HOME/code/other"
[ -z "$(git -C "$HOME/code/other" config user.email || true)" ] || fail "a folder outside ~/code/work has an identity"
[ "$(git -C "$HOME/code/work/app" config pull.rebase)" = true ] || fail "shared git settings not read"
rm "$HOME/.gitconfig-work"

# The personal identity file triggers a warning.
touch "$HOME/.gitconfig-personal"
out=$(bash "$root/work/install.sh" --links-only)
printf '%s' "$out" | grep -q 'gitconfig-personal exists' || fail "no warning for ~/.gitconfig-personal"
rm "$HOME/.gitconfig-personal"

# --- work/setup_gitlab.sh ---------------------------------------------------
stubs=$fixture/bin
state=$fixture/state
mkdir -p "$stubs" "$state"
cat > "$stubs/op" <<'EOF'
#!/usr/bin/env bash
state=$STUB_STATE
case "$1 $2" in
  "vault get") exit 0 ;;
  "item get") [ -f "$state/item-$3" ] ;;
  "item create") shift 2; while [ "$#" -gt 0 ]; do [ "$1" = --title ] && touch "$state/item-$2"; shift; done ;;
  "read op:"*) item=${2#op://*/}; item=${item%%/*}; [ -f "$state/item-$item" ] && echo "ssh-ed25519 AAAA$item" ;;
  *) echo "op stub: $*" >&2; exit 9 ;;
esac
EOF
cat > "$stubs/glab" <<'EOF'
#!/usr/bin/env bash
state=$STUB_STATE
case "$1 $2" in
  "auth status") [ -f "$state/glab-auth" ] ;;
  "auth login") echo "$*" > "$state/glab-login"; touch "$state/glab-auth" ;;
  "api --hostname") printf '['; cat "$state/glab-keys" 2>/dev/null; printf ']' ;;
  "ssh-key add") printf '{"key":"%s","usage":"%s"},' "$(cat "$3")" "$7" >> "$state/glab-keys"; echo "$GITLAB_HOST" > "$state/glab-host" ;;
  *) echo "glab stub: $*" >&2; exit 9 ;;
esac
EOF
cat > "$stubs/ssh" <<'EOF'
#!/usr/bin/env bash
echo "Welcome to GitLab, @tester!"
EOF
printf '#!/bin/sh\n' > "$stubs/op-ssh-sign"
chmod +x "$stubs"/*
sock_dir=$(mktemp -d /tmp/wsock.XXXX)
trap 'rm -rf "$fixture" "$sock_dir"' EXIT
python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$sock_dir/a.sock"
export PATH="$stubs:$PATH" STUB_STATE=$state OP_AGENT_SOCK=$sock_dir/a.sock OP_SSH_SIGN=$stubs/op-ssh-sign
gl() { bash "$root/work/setup_gitlab.sh" --host gitlab.example.com --email me@example.com --name "Test User" --keys 1password "$@"; }

# Usage errors.
set +e
bash "$root/work/setup_gitlab.sh" --host gitlab.example.com >/dev/null 2>&1; [ $? = 2 ] || fail "missing --email accepted"
gl --host 'bad host/x' >/dev/null 2>&1; [ $? = 2 ] || fail "bad --host accepted"
gl --keys keychain >/dev/null 2>&1; [ $? = 2 ] || fail "unknown --keys accepted"
set -e

printf 'Host other\n    HostName other.example.com\n' > "$HOME/.ssh/config"

# --check reports and changes nothing.
set +e; gl --check >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] || fail "--check with pending changes returned $rc"
rm -rf "$HOME/code/work"
set +e; gl --check >/dev/null 2>&1; set -e
[ ! -e "$HOME/.gitconfig-work" ] && [ ! -e "$HOME/code/work" ] && [ -z "$(ls "$state")" ] || fail "--check changed something"

# Apply.
gl >"$fixture/apply.log" 2>&1 || { cat "$fixture/apply.log"; fail "apply failed"; }
[ "$(head -1 "$HOME/.ssh/config")" = "Include ~/.ssh/config.d/gitlab-work" ] || fail "Include not first in ~/.ssh/config"
grep -q '^Host other$' "$HOME/.ssh/config" || fail "existing ~/.ssh/config lost"
grep -q '^Host gitlab.example.com$' "$HOME/.ssh/config.d/gitlab-work" || fail "no GitLab host block"
grep -q 'vault = "Employee"' "$HOME/.config/1Password/ssh/agent.toml" || fail "agent.toml lacks the vault"
[ "$(cat "$HOME/.ssh/gitlab_sign_ed25519.pub")" = "ssh-ed25519 AAAAgitlab_sign_ed25519 me@example.com" ] || fail "signing key not written"
grep -q 'insteadOf = https://gitlab.example.com/' "$HOME/.gitconfig-work" || fail "no SSH rewrite for the host"
[ "$(stat -f %Lp "$HOME/.gitconfig-work")" = 600 ] || fail "~/.gitconfig-work is not 0600"
grep -q -- '--hostname gitlab.example.com --web --git-protocol ssh' "$state/glab-login" || fail "glab login not run as expected"
[ "$(grep -o '"usage":"auth"' "$state/glab-keys" | wc -l | tr -d ' ')" = 1 ] || fail "auth key not uploaded once"
[ "$(grep -o '"usage":"signing"' "$state/glab-keys" | wc -l | tr -d ' ')" = 1 ] || fail "signing key not uploaded once"
[ "$(cat "$state/glab-host")" = gitlab.example.com ] || fail "keys uploaded to the wrong host"
grep -q 'commits in ~/code/work use me@example.com' "$fixture/apply.log" || fail "identity check did not pass"
[ -z "$(ls -A "$HOME/code/work" | grep setup-check || true)" ] || fail "probe repo left behind"

# A second run is current and uploads nothing.
gl --check >/dev/null 2>&1 || fail "--check after apply is not current"
gl >/dev/null 2>&1 || fail "second apply failed"
[ "$(grep -o '"usage"' "$state/glab-keys" | wc -l | tr -d ' ')" = 2 ] || fail "keys uploaded twice"
[ "$(grep -c 'gitlab-work' "$HOME/.ssh/config")" = 1 ] || fail "Include added twice"
[ "$(grep -c 'vault = "Employee"' "$HOME/.config/1Password/ssh/agent.toml")" = 1 ] || fail "vault added twice"

# A hand-written ~/.gitconfig-work is kept.
printf '[user]\n\temail = mine@example.com\n' > "$HOME/.gitconfig-work"
gl >/dev/null 2>&1 || true
grep -q 'mine@example.com' "$HOME/.gitconfig-work" || fail "own ~/.gitconfig-work overwritten"

# --- work/setup_gitlab.sh --keys file (the default) --------------------------
export HOME=$fixture/home-file
mkdir -p "$HOME"
bash "$root/work/install.sh" --links-only >/dev/null
state=$fixture/state-file
mkdir -p "$state"
export STUB_STATE=$state SSH_AUTH_SOCK=$fixture/macos-agent
# ssh-add stub: checks that the askpass helper returns the key's real
# passphrase, then lists the loaded keys like ssh-add -l.
cat > "$stubs/ssh-add" <<'EOF'
#!/usr/bin/env bash
state=$STUB_STATE
case "$1" in
  --apple-use-keychain)
    key=${!#}
    pass=$("$SSH_ASKPASS") || exit 1
    ssh-keygen -y -P "$pass" -f "$key" >/dev/null 2>&1 || { echo "wrong passphrase" >&2; exit 1; }
    echo "$key" >> "$state/agent" ;;
  -l) while read -r key; do ssh-keygen -lf "$key.pub"; done < "$state/agent" 2>/dev/null ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$stubs/ssh-add"
glf() { bash "$root/work/setup_gitlab.sh" --host gitlab.example.com --email me@example.com --name "Test User" "$@"; }

set +e; glf --check >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] && [ ! -e "$HOME/.ssh/gitlab_auth_ed25519" ] || fail "file --check created keys"
glf >"$fixture/file.log" 2>&1 || { cat "$fixture/file.log"; fail "file apply failed"; }
for k in gitlab_auth_ed25519 gitlab_sign_ed25519; do
  [ "$(stat -f %Lp "$HOME/.ssh/$k")" = 600 ] || fail "$k is not 0600"
  ! ssh-keygen -y -P "" -f "$HOME/.ssh/$k" >/dev/null 2>&1 || fail "$k has no passphrase"
done
[ "$(wc -l < "$state/agent" | tr -d ' ')" = 2 ] || fail "keys not added to the agent with the Keychain"
grep -q '^    IdentityFile ~/.ssh/gitlab_auth_ed25519$' "$HOME/.ssh/config.d/gitlab-work" || fail "SSH config does not use the key file"
grep -q 'UseKeychain yes' "$HOME/.ssh/config.d/gitlab-work" || fail "SSH config lacks UseKeychain"
! grep -q 'IdentityAgent\|1Password' "$HOME/.ssh/config.d/gitlab-work" || fail "file mode uses the 1Password agent"
! grep -q 'op-ssh-sign' "$HOME/.gitconfig-work" || fail "file mode signs with 1Password"
[ ! -e "$HOME/.config/1Password" ] || fail "file mode wrote 1Password config"
grep -q 'signing key is loaded in the ssh-agent' "$fixture/file.log" || fail "signing key check did not pass"
[ "$(grep -o '"usage"' "$state/glab-keys" | wc -l | tr -d ' ')" = 2 ] || fail "file keys not uploaded"
before=$(cat "$HOME/.ssh/gitlab_sign_ed25519.pub")
glf --check >/dev/null 2>&1 || fail "file --check after apply is not current"
glf >/dev/null 2>&1 || fail "second file apply failed"
[ "$(cat "$HOME/.ssh/gitlab_sign_ed25519.pub")" = "$before" ] || fail "file key regenerated"
[ "$(grep -o '"usage"' "$state/glab-keys" | wc -l | tr -d ' ')" = 2 ] || fail "file keys uploaded twice"

# 1Password's agent socket in SSH_AUTH_SOCK would hide the file keys.
set +e; SSH_AUTH_SOCK=$OP_AGENT_SOCK glf >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] || fail "file mode accepted the 1Password agent"

echo "test_work_setup: ok"
