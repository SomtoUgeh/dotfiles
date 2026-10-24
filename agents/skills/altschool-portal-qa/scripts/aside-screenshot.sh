#!/usr/bin/env bash
# Screenshot a URL in Aside Browser (default Aside host) and save the PNG on this host.
# Prints the final origin + path so a sign-in redirect is visible. Never prints page data.
set -euo pipefail

usage() {
  printf 'usage: %s <https-url> <out.png>\n' "$(basename "$0")" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
url="$1"
out="$2"
[[ "$url" =~ ^https?:// ]] || usage

for cmd in aside jq base64; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'fail  %s is not on PATH\n' "$cmd" >&2; exit 1; }
done

url_json="$(jq -Rn --arg u "$url" '$u')"
raw="$(mktemp)"
trap 'rm -f "$raw"' EXIT

# Each one-shot REPL call is a fresh session; the browser profile keeps cookies.
# Aside returns the viewport only; fullPage is ignored.
timeout 150 aside repl "
const shotTab = await openTab(${url_json});
const shotUrl = new URL(page.url());
console.log('FINAL ' + shotUrl.origin + shotUrl.pathname);
const shotPng = await page.screenshot();
console.log('B64START' + Buffer.from(shotPng).toString('base64') + 'B64END');
await closeTab(shotTab);
" >"$raw" 2>&1 || { rg -v 'B64START' "$raw" >&2 || true; exit 1; }

rg -o '^FINAL .*' "$raw" || true
mkdir -p "$(dirname "$out")"
rg -o 'B64START(.*)B64END' -r '$1' "$raw" | base64 -d >"$out"
if [[ ! -s "$out" ]]; then
  printf 'fail  no screenshot returned\n' >&2
  rg -v 'B64START' "$raw" >&2 || true
  exit 1
fi
printf 'ok    %s\n' "$out"
