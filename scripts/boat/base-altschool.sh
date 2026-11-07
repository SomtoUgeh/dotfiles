# shellcheck shell=bash
# Fragment: append to base-common.sh (cat base-common.sh base-altschool.sh | boat ssh <id> -- bash -s).
# AltSchool base (appended after base-common.sh)
R=$HOME/code/TalentQL/altschool-web-platforms

# bun 1.4.4 (image has 1.3.14 in /usr/local); ours in ~/.bun/bin wins on PATH.
if [ "$(bun --version 2>/dev/null)" != "1.4.4" ]; then
  curl -fsSL https://bun.sh/install | bash -s "bun-v1.4.4" >/dev/null
fi
echo "bun $(bun --version) at $(command -v bun)"

clone_from_bundle "$HOME/altschool.bundle" "$R" git@github.com:TalentQL/altschool-web-platforms.git

# Build output stays out of snapshots; node_modules and .turbo stay in (checks skip install, turbo cache helps).
# Anchored: an unanchored "dist/" also matches package folders inside node_modules.
printf '%s\n' '/apps/*/.next/' '/apps/*/dist/' '/packages/*/dist/' '/coverage/' '/apps/*/coverage/' \
  '/packages/*/coverage/' '/e2e/playwright-report/' '/e2e/test-results/' > .boatignore
grep -qx '.boatignore' .git/info/exclude || echo '.boatignore' >> .git/info/exclude

time bun install --frozen-lockfile 2>&1 | tail -3

# Playwright browser for journey e2e (the image also has google-chrome-stable for CI=1 runs).
cd e2e || exit 1
time bunx playwright install --with-deps chromium 2>&1 | tail -3
ls "$PLAYWRIGHT_BROWSERS_PATH"
rm -f ~/altschool.bundle
df -h /home/user | tail -1
du -sh "$R/node_modules" "$R/.git"
