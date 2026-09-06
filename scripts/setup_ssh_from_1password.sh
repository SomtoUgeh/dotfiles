#!/usr/bin/env bash
#
# setup_ssh_from_1password.sh — rebuild the SSH + commit-signing setup on a new
# machine from keys already held in 1Password.
#
#   setup_ssh_from_1password.sh --check     verify only, change nothing
#   setup_ssh_from_1password.sh             create what is missing
#   setup_ssh_from_1password.sh --force     also overwrite protected configs
#
# What it does:
#   1. exports the five PUBLIC keys from 1Password to ~/.ssh/*.pub
#   2. builds ~/.ssh/allowed_signers from the two SIGNING keys
#   3. installs ~/.ssh/config and ~/.config/1Password/ssh/agent.toml
#   4. installs ~/.gitconfig{.local,-personal,-work} from templates
#
# It never touches private keys. Those stay in the vault and are served only by
# the 1Password SSH agent. Nothing here can write private key material.
#
# Prerequisites: 1Password app with the SSH agent enabled, and the op CLI with
# desktop-app integration turned on.

set -u
set -o pipefail

# file stem | vault | public-key comment | role | item title (defaults to stem)
KEYS=(
  "somto_auth_ed25519|Personal|smugeh@gmail.com|auth"
  "somto_sign_ed25519|Personal|smugeh@gmail.com|sign"
  "swissblock_auth_ed25519|Swissblock|smedua@swissblock.net|auth"
  "swissblock_sign_ed25519|Swissblock|smedua@swissblock.net|sign"
  "altschool_vm_rsa|Personal|altschool development host|auth|AltSchool VM SSH Key"
)

MODE=create
[ "$#" -le 1 ] || { echo 'expected at most one option' >&2; exit 2; }
case "${1:-}" in
  --check) MODE=check ;;
  --force) MODE=force ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  "") ;;
  *) echo "unknown argument: $1" >&2; exit 2 ;;
esac

red() { printf '\033[0;31m%s\033[0m\n' "$1"; }
grn() { printf '\033[0;32m%s\033[0m\n' "$1"; }
ylw() { printf '\033[1;33m%s\033[0m\n' "$1"; }
hdr() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# Resolve through the ~/bin symlink to find the repo.
SELF="$0"
while [ -L "$SELF" ]; do
  link="$(readlink "$SELF")"
  case "$link" in /*) SELF="$link" ;; *) SELF="$(dirname "$SELF")/$link" ;; esac
done
REPO="$(cd "$(dirname "$SELF")/.." && pwd)"
TPL="$REPO/templates"
AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

fail=0

hdr "Prerequisites"
if command -v op >/dev/null; then grn "  op CLI: $(op --version)"
else red "  op CLI missing — brew install --cask 1password-cli"; fail=1; fi
if [ -S "$AGENT_SOCK" ]; then grn "  1Password SSH agent: running"
else red "  1Password SSH agent NOT running — enable it in Settings > Developer > SSH agent"; fail=1; fi
if [ -x /Applications/1Password.app/Contents/MacOS/op-ssh-sign ]; then grn "  op-ssh-sign: present"
else red "  op-ssh-sign missing — is 1Password installed?"; fail=1; fi
if [ -d "$TPL" ]; then grn "  templates: $TPL"
else red "  templates not found at $TPL"; fail=1; fi
[ "$fail" -ne 0 ] && { echo; red "Prerequisites unmet. Nothing done."; exit 1; }

if op vault list >/dev/null 2>&1 </dev/null; then grn "  op can read vaults"
else red "  op cannot read vaults — enable CLI integration in 1Password (Settings > Developer)"; exit 1; fi

hdr "Public keys"
if [ "$MODE" != check ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" || exit 1
fi
signers=""
for entry in "${KEYS[@]}"; do
  IFS='|' read -r name vault email role item <<< "$entry"
  item="${item:-$name}"
  target="$HOME/.ssh/$name.pub"
  if ! pub="$(op read "op://$vault/$item/public key" </dev/null 2>/dev/null)" || [ -z "$pub" ]; then
    red "  ✗ $item — not found in vault '$vault'"; fail=1; continue
  fi
  if [ "$role" = sign ]; then
    signers+="$email namespaces=\"git\" $(printf '%s\n' "$pub" | awk '{print $1" "$2}')"$'\n'
  fi
  want="$pub $email"
  if [ -f "$target" ] && [ "$(cat "$target")" = "$want" ]; then
    grn "  = $name.pub (current)"
  elif [ "$MODE" = check ]; then
    ylw "  ~ $name.pub would be written"; fail=1
  else
    if printf '%s\n' "$want" > "$target" && chmod 644 "$target"; then
      grn "  + $name.pub written"
    else
      red "  ✗ could not write $name.pub"; fail=1
    fi
  fi
done

hdr "allowed_signers"
if [ "$(printf '%s' "$signers" | wc -l | tr -d ' ')" != 2 ]; then
  red "  ✗ both signing keys are required; allowed_signers left unchanged"; fail=1
elif [ -f "$HOME/.ssh/allowed_signers" ] && [ "$(cat "$HOME/.ssh/allowed_signers")" = "$(printf '%s' "$signers")" ]; then
  grn "  = allowed_signers (current)"
elif [ "$MODE" = check ]; then
  ylw "  ~ allowed_signers would be written"; fail=1
else
  if printf '%s' "$signers" > "$HOME/.ssh/allowed_signers" && chmod 644 "$HOME/.ssh/allowed_signers"; then
    grn "  + allowed_signers written (2 principals)"
  else
    red "  ✗ could not write allowed_signers"; fail=1
  fi
fi

hdr "Config files from templates"
# dest | template | clobber-safe?
install_tpl() {
  local dest="$1" tpl="$2" protect="$3"
  [ -f "$TPL/$tpl" ] || { red "  ✗ missing template $tpl"; fail=1; return; }
  if [ -f "$dest" ]; then
    if cmp -s "$TPL/$tpl" "$dest"; then grn "  = ${dest/#$HOME/~} (matches template)"; return; fi
    if [ "$protect" = protect ] && [ "$MODE" != force ]; then
      ylw "  ! ${dest/#$HOME/~} exists and differs — left alone (use --force to overwrite)"; return
    fi
  fi
  if [ "$MODE" = check ]; then ylw "  ~ ${dest/#$HOME/~} would be written"; fail=1; return; fi
  if mkdir -p "$(dirname "$dest")" && cp "$TPL/$tpl" "$dest"; then
    grn "  + ${dest/#$HOME/~} installed"
  else
    red "  ✗ could not install ${dest/#$HOME/~}"; fail=1
  fi
}
install_tpl "$HOME/.ssh/config"                        ssh-config.template            protect
install_tpl "$HOME/.config/1Password/ssh/agent.toml"   1password-agent.toml.template  protect
install_tpl "$HOME/.gitconfig.local"                   gitconfig-local.template       protect
install_tpl "$HOME/.gitconfig-personal"                gitconfig-personal.template    protect
install_tpl "$HOME/.gitconfig-work"                    gitconfig-work.template        protect
if [ "$MODE" != check ]; then
  chmod 600 "$HOME/.ssh/config" "$HOME"/.gitconfig.local "$HOME"/.gitconfig-personal "$HOME"/.gitconfig-work || fail=1
fi

hdr "Verification"
echo "  keys the agent serves:"
SSH_AUTH_SOCK="$AGENT_SOCK" ssh-add -l 2>/dev/null | awk '{print "    "$3}' || { echo "    (agent keys unavailable)"; fail=1; }
echo "  no private key material in ~/.ssh:"
if [ -d "$HOME/.ssh" ]; then
  grep -rl 'PRIVATE KEY' "$HOME/.ssh" 2>/dev/null
  private_rc=$?
  case "$private_rc" in
    0) red "    !! PRIVATE KEY ON DISK"; fail=1 ;;
    1) grn "    ✓ confirmed" ;;
    *) red "    ✗ could not inspect ~/.ssh"; fail=1 ;;
  esac
fi

hdr "Remaining manual steps"
cat <<'EOF'
  1. Upload the four public keys to GitHub — the Key type dropdown matters:
       somto_auth_ed25519.pub       -> SomtoUgeh         Authentication key
       somto_sign_ed25519.pub       -> SomtoUgeh         Signing key
       swissblock_auth_ed25519.pub  -> somto-swissblock  Authentication key
       swissblock_sign_ed25519.pub  -> somto-swissblock  Signing key
     Copy with:  pbcopy < ~/.ssh/<name>.pub
  2. Enable Vigilant mode on both GitHub accounts.
  3. Sign a test commit under ~/code/work and ~/code/personal, approving the
     1Password prompt once per key:
       git commit --allow-empty -m "signing test" && git verify-commit HEAD
EOF
[ "$MODE" = check ] && { echo; ylw "(--check: nothing was changed)"; }
exit "$fail"
