# shellcheck shell=bash
# Fragment: append to base-common.sh (cat base-common.sh base-coworkers.sh | boat ssh <id> -- bash -s).
# Coworkers base (appended after base-common.sh)
R=$HOME/code/personal/coworkers
echo "pnpm $(pnpm --version), node $(node --version)"

clone_from_bundle "$HOME/coworkers.bundle" "$R" git@github.com:SomtoUgeh/coworkers.git

# Anchored: an unanchored "dist/" also matches package folders inside node_modules.
printf '%s\n' '/dist/' '/installer/dist/' '/.output/' '/.wrangler/' '/installer/.wrangler/' '/coverage/' > .boatignore
grep -qx '.boatignore' .git/info/exclude || echo '.boatignore' >> .git/info/exclude

time pnpm install --frozen-lockfile 2>&1 | tail -5
rm -f ~/coworkers.bundle
df -h /home/user | tail -1
du -sh "$R/node_modules" "$R/.git"
