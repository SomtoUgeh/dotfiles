# Homebrew shellenv (guarded — Mac/Linux portable; silently skip if brew isn't installed)
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# Added by OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Secrets (e.g. RESEND_API_KEY) live in ~/.zshrc.private, not here.
# This file is now tracked in git — never put API keys in it.
