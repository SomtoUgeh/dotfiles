#!/usr/bin/env bash
#
# Sets up GitLab access and signed commits on the work Mac, with keys held in
# the work 1Password vault. Private keys never touch the disk.
#
#   work/setup_gitlab.sh --email you@company.com [options]
#
#   --email EMAIL     work email for commits (required)
#   --host HOST       GitLab host in remote URLs (default: gitlab.com)
#   --ssh-host HOST   SSH endpoint when it differs from --host
#   --ssh-port PORT   SSH port when it is not 22
#   --name NAME       commit name (default: user.name in ~/.gitconfig.local)
#   --vault VAULT     1Password vault for the keys (default: Employee)
#   --account ACCT    1Password account, when the app has more than one
#   --no-upload       do not upload the public keys to GitLab
#   --check           report what would change; change nothing
#   --force           also overwrite an existing ~/.gitconfig-work
#
# What it does:
#   1. creates (or reuses) two SSH keys in the vault: gitlab_auth_ed25519 and
#      gitlab_sign_ed25519
#   2. writes their public halves to ~/.ssh, and ~/.ssh/allowed_signers_work
#   3. writes ~/.ssh/config.d/gitlab-work and includes it from ~/.ssh/config
#   4. adds the vault to ~/.config/1Password/ssh/agent.toml
#   5. writes ~/.gitconfig-work (identity and signing for ~/code/work)
#   6. signs glab in to the host (browser login) and uploads both public keys
#   7. checks SSH access and the identity inside ~/code/work
#
# Exit status: 0 when everything is in place, 1 when something failed or
# (with --check) would change, 2 for a usage error.

set -u
set -o pipefail

HOST=gitlab.com
SSH_HOST=""
SSH_PORT=""
EMAIL=""
NAME=""
VAULT=Employee
ACCOUNT=""
UPLOAD=1
MODE=apply

usage() { sed -n '2,31p' "$0"; }
need_value() { [ "$#" -ge 2 ] && [ -n "$2" ] || { echo "$1 needs a value" >&2; exit 2; }; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --email)    need_value "$@"; EMAIL="$2"; shift 2 ;;
    --host)     need_value "$@"; HOST="$2"; shift 2 ;;
    --ssh-host) need_value "$@"; SSH_HOST="$2"; shift 2 ;;
    --ssh-port) need_value "$@"; SSH_PORT="$2"; shift 2 ;;
    --name)     need_value "$@"; NAME="$2"; shift 2 ;;
    --vault)    need_value "$@"; VAULT="$2"; shift 2 ;;
    --account)  need_value "$@"; ACCOUNT="$2"; shift 2 ;;
    --no-upload) UPLOAD=0; shift ;;
    --check)    MODE=check; shift ;;
    --force)    MODE=force; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$EMAIL" in
  ?*@?*.?*) ;;
  *) echo "--email is required, for example --email you@company.com" >&2; exit 2 ;;
esac
case "$HOST" in
  *[!A-Za-z0-9.-]*|"") echo "--host must be a bare hostname, such as gitlab.example.com" >&2; exit 2 ;;
esac
if [ -n "$SSH_HOST" ]; then
  case "$SSH_HOST" in *[!A-Za-z0-9.-]*) echo "--ssh-host must be a bare hostname" >&2; exit 2 ;; esac
fi
if [ -n "$SSH_PORT" ]; then
  case "$SSH_PORT" in *[!0-9]*) echo "--ssh-port must be a number" >&2; exit 2 ;; esac
fi
if [ -z "$NAME" ]; then
  NAME="$(git config --file "$HOME/.gitconfig.local" user.name 2>/dev/null || true)"
fi
[ -n "$NAME" ] || { echo "--name is required (no user.name in ~/.gitconfig.local)" >&2; exit 2; }

# Overridable for tests only.
AGENT_SOCK="${OP_AGENT_SOCK:-$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock}"
SSH_SIGN="${OP_SSH_SIGN:-/Applications/1Password.app/Contents/MacOS/op-ssh-sign}"
AGENT_SOCK_CONFIG='~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock'

AUTH_ITEM=gitlab_auth_ed25519
SIGN_ITEM=gitlab_sign_ed25519
MARKER="Rendered by work/setup_gitlab.sh"

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }
short() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }

fail=0
pending=0
# Records a change. Returns 0 when the caller should make it now.
change() {
  if [ "$MODE" = check ]; then ylw "  ~ $1"; pending=1; return 1; fi
  return 0
}

op_acct=()
[ -n "$ACCOUNT" ] && op_acct=(--account "$ACCOUNT")
op_() { op "$@" ${op_acct[@]+"${op_acct[@]}"} </dev/null; }

# Writes content to a file with mode 0600 unless it already matches.
write_file() {
  local path="$1" content="$2" label="$(short "$1")"
  if [ -f "$path" ] && [ "$(cat "$path")" = "$content" ]; then grn "  = $label"; return; fi
  change "$label would be written" || return
  if mkdir -p "$(dirname "$path")" && printf '%s\n' "$content" > "$path" && chmod 600 "$path"; then
    grn "  + $label"
  else
    red "  ✗ could not write $label"; fail=1
  fi
}

# =============================================================================
hdr "Prerequisites"
for tool in op glab git ssh; do
  if command -v "$tool" >/dev/null 2>&1; then grn "  $tool: found"
  else red "  $tool missing — run work/install.sh first"; fail=1; fi
done
if [ -S "$AGENT_SOCK" ]; then grn "  1Password SSH agent: running"
else red "  1Password SSH agent not running — turn it on in 1Password: Settings > Developer > SSH agent"; fail=1; fi
if [ -x "$SSH_SIGN" ]; then grn "  op-ssh-sign: found"
else red "  op-ssh-sign missing — is the 1Password app installed?"; fail=1; fi
[ "$fail" -ne 0 ] && { echo; red "Prerequisites unmet. Nothing changed."; exit 1; }
if op_ vault get "$VAULT" >/dev/null 2>&1; then grn "  vault '$VAULT': readable"
else
  red "  op cannot read vault '$VAULT'."
  red "  Turn on Settings > Developer > Integrate with 1Password CLI, check the vault name (--vault),"
  red "  and pass --account when the app has more than one account (op account list)."
  exit 1
fi

# =============================================================================
hdr "SSH keys in 1Password ($VAULT)"
AUTH_PUB=""
SIGN_PUB=""
for item in "$AUTH_ITEM" "$SIGN_ITEM"; do
  if op_ item get "$item" --vault "$VAULT" >/dev/null 2>&1; then
    grn "  = $item exists"
  elif change "$item would be created (Ed25519)"; then
    if op_ item create --category "SSH Key" --title "$item" --vault "$VAULT" --ssh-generate-key ed25519 >/dev/null 2>&1; then
      grn "  + $item created"
    else
      red "  ✗ could not create $item"; fail=1; continue
    fi
  else
    continue
  fi
  if ! pub="$(op_ read "op://$VAULT/$item/public key" 2>/dev/null)" || [ -z "$pub" ]; then
    red "  ✗ could not read the public key of $item"; fail=1; continue
  fi
  pub="$(printf '%s\n' "$pub" | awk 'NR == 1 { print $1" "$2 }')"
  if [ "$item" = "$AUTH_ITEM" ]; then AUTH_PUB="$pub"; else SIGN_PUB="$pub"; fi
done

hdr "Files in ~/.ssh"
[ "$MODE" = check ] || { mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"; }
[ -n "$AUTH_PUB" ] && write_file "$HOME/.ssh/$AUTH_ITEM.pub" "$AUTH_PUB $EMAIL"
[ -n "$SIGN_PUB" ] && write_file "$HOME/.ssh/$SIGN_ITEM.pub" "$SIGN_PUB $EMAIL"
[ -n "$SIGN_PUB" ] && write_file "$HOME/.ssh/allowed_signers_work" "$EMAIL namespaces=\"git\" $SIGN_PUB"

ssh_block="# $MARKER. Rerun it to change this file.
Host $HOST
    HostName ${SSH_HOST:-$HOST}
    User git"
[ -n "$SSH_PORT" ] && ssh_block="$ssh_block
    Port $SSH_PORT"
ssh_block="$ssh_block
    IdentityAgent \"$AGENT_SOCK_CONFIG\"
    IdentityFile ~/.ssh/$AUTH_ITEM.pub
    IdentitiesOnly yes"
write_file "$HOME/.ssh/config.d/gitlab-work" "$ssh_block"

# The Include must come before any Host block, so it goes on the first line.
include_line="Include ~/.ssh/config.d/gitlab-work"
if [ -f "$HOME/.ssh/config" ] && grep -qxF "$include_line" "$HOME/.ssh/config"; then
  grn "  = ~/.ssh/config includes config.d/gitlab-work"
elif change "~/.ssh/config would include config.d/gitlab-work"; then
  existing="$(cat "$HOME/.ssh/config" 2>/dev/null || true)"
  if printf '%s\n%s\n' "$include_line" "$existing" > "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"; then
    grn "  + ~/.ssh/config includes config.d/gitlab-work"
  else
    red "  ✗ could not update ~/.ssh/config"; fail=1
  fi
fi

# =============================================================================
hdr "1Password SSH agent"
agent_toml="$HOME/.config/1Password/ssh/agent.toml"
entry="[[ssh-keys]]
vault = \"$VAULT\""
[ -n "$ACCOUNT" ] && entry="$entry
account = \"$ACCOUNT\""
if [ -f "$agent_toml" ] && grep -qF "vault = \"$VAULT\"" "$agent_toml"; then
  grn "  = agent.toml serves vault '$VAULT'"
elif change "agent.toml would serve vault '$VAULT'"; then
  mkdir -p "$(dirname "$agent_toml")"
  if [ -f "$agent_toml" ]; then
    printf '\n%s\n' "$entry" >> "$agent_toml"
  else
    printf '# Which vaults the 1Password SSH agent serves. %s.\n\n%s\n' "$MARKER" "$entry" > "$agent_toml"
  fi && grn "  + agent.toml serves vault '$VAULT' (restart 1Password if keys do not appear)" \
     || { red "  ✗ could not write agent.toml"; fail=1; }
fi

# =============================================================================
hdr "Git identity"
gitconfig_work="# $MARKER. Applies in ~/code/work and the agent worktree folders.
[user]
	name = $NAME
	email = $EMAIL
	signingkey = ~/.ssh/$SIGN_ITEM.pub
[gpg]
	format = ssh
[gpg \"ssh\"]
	program = $SSH_SIGN
	allowedSignersFile = ~/.ssh/allowed_signers_work
[commit]
	gpgsign = true
[tag]
	gpgSign = true
[url \"git@$HOST:\"]
	insteadOf = https://$HOST/"
if [ -f "$HOME/.gitconfig-work" ] && ! grep -q "$MARKER" "$HOME/.gitconfig-work" && [ "$MODE" != force ]; then
  if [ "$(cat "$HOME/.gitconfig-work")" = "$gitconfig_work" ]; then grn "  = ~/.gitconfig-work"
  else ylw "  ! ~/.gitconfig-work is your own file — left alone (use --force to replace it)"; fi
else
  write_file "$HOME/.gitconfig-work" "$gitconfig_work"
fi
[ "$MODE" = check ] || mkdir -p "$HOME/code/work"

# =============================================================================
hdr "glab ($HOST)"
# Outside any repository, so glab does not pick a host from a Git remote.
cd "$HOME" || exit 1
export GITLAB_HOST="$HOST"
if glab auth status --hostname "$HOST" >/dev/null 2>&1; then
  grn "  = glab is signed in"
  authed=1
elif change "glab would sign in (browser login)"; then
  login=(glab auth login --hostname "$HOST" --web --git-protocol ssh)
  [ -n "$SSH_HOST" ] && login+=(--ssh-hostname "$SSH_HOST")
  if "${login[@]}"; then grn "  + glab signed in"; authed=1
  else
    red "  ✗ glab sign-in failed. Run it yourself in a terminal:"
    red "      ${login[*]}"
    fail=1; authed=0
  fi
else
  authed=0
fi

if [ "$UPLOAD" = 1 ] && [ "$authed" = 1 ]; then
  if ! registered="$(glab api --hostname "$HOST" --paginate user/keys 2>/dev/null)"; then
    red "  ✗ could not list your GitLab SSH keys"; fail=1; registered=""
  fi
  device="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
  for spec in "auth|$AUTH_ITEM|$AUTH_PUB" "signing|$SIGN_ITEM|$SIGN_PUB"; do
    IFS='|' read -r usage item pub <<< "$spec"
    [ -n "$pub" ] || continue
    body="${pub#* }"
    if [[ "$registered" == *"$body"* ]]; then
      grn "  = $item is on GitLab"
    elif [ -n "$registered" ] && change "$item would be uploaded to GitLab ($usage)"; then
      if glab ssh-key add "$HOME/.ssh/$item.pub" --title "$device $usage" --usage-type "$usage" >/dev/null; then
        grn "  + $item uploaded ($usage)"
      else
        red "  ✗ could not upload $item"; fail=1
      fi
    fi
  done
elif [ "$UPLOAD" = 0 ]; then
  ylw "  upload skipped (--no-upload). Add the keys in GitLab > Preferences > SSH Keys."
fi

# =============================================================================
hdr "Verification"
if [ "$MODE" = check ]; then
  ylw "  skipped in --check mode"
else
  out="$(ssh -T -o BatchMode=yes -o ConnectTimeout=10 "git@$HOST" 2>&1)"
  if [[ "$out" == *"Welcome to GitLab"* ]]; then
    grn "  ✓ ssh: $(printf '%s' "$out" | grep -o 'Welcome to GitLab[^!]*!')"
  else
    red "  ✗ ssh git@$HOST did not greet you: $(printf '%s' "$out" | head -1)"
    red "    Approve the 1Password prompt, and check that the auth key is on GitLab."
    fail=1
  fi
  probe="$(mktemp -d "$HOME/code/work/.setup-check.XXXXXX")"
  git -C "$probe" init --quiet
  got_email="$(git -C "$probe" config user.email || true)"
  got_format="$(git -C "$probe" config gpg.format || true)"
  rm -rf "$probe"
  if [ "$got_email" = "$EMAIL" ] && [ "$got_format" = ssh ]; then
    grn "  ✓ commits in ~/code/work use $EMAIL, signed with SSH"
  else
    red "  ✗ git in ~/code/work uses '${got_email:-no email}' (format '${got_format:-none}')."
    red "    Check that ~/.gitconfig links to work/git/gitconfig (run work/install.sh)."
    fail=1
  fi
  if grep -rl 'PRIVATE KEY' "$HOME/.ssh" >/dev/null 2>&1; then
    red "  ✗ a private key file is in ~/.ssh"; fail=1
  else
    grn "  ✓ no private keys in ~/.ssh"
  fi
fi

hdr "Manual step"
echo "  Sign a test commit in a work repo and approve the 1Password prompt:"
echo "    git commit --allow-empty -m 'signing test' && git log --show-signature -1"
echo "  GitLab shows 'Verified' on the commit after you push it."

[ "$MODE" = check ] && { echo; ylw "(--check: nothing was changed)"; [ "$pending" = 1 ] && fail=1; }
exit "$fail"
