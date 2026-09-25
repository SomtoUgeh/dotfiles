# Exploratory portal QA

Use this when the user asks to dogfood, QA, or bug-hunt the portal.
Load `agent-browser skills get dogfood` for evidence format, but keep
**this** skill's credential rules. Do not copy dogfood's example
`fill` of a raw password.

Default driver is agent-browser. For a Codex Desktop–visible tour, also
follow [in-app-browser.md](in-app-browser.md).

## Scope

Default: student portal production, authenticated happy paths in
[../references/surfaces.md](../references/surfaces.md) navigation.
Stay inside that origin. Skip Core unless asked. Skip Live Classes
(disabled). Skip Community (external).

For a post-deploy health check, prefer
[production-smoke.md](production-smoke.md) and the last verified
baseline in
[../references/production-regressions.md](../references/production-regressions.md)
instead of an open-ended tour.

If the user names a page, start there and only fan out when the
nearby flow is required to understand the bug.

## Setup

```bash
SKILL_DIR="$(readlink -f ~/.agents/skills/altschool-portal-qa)"
DATE="$(date -u +%Y-%m-%d)"
OUT="$HOME/.altschool/portal-qa/$DATE/explore"
mkdir -p "$OUT/screenshots" "$OUT/videos"
"$SKILL_DIR/scripts/preflight.sh"
"$SKILL_DIR/scripts/login.sh" --app portal --target prod
```

Optional video for a behavioral bug:

```bash
agent-browser --session portal-qa record start "$OUT/videos/repro.webm"
# …interact…
agent-browser --session portal-qa record stop
```

## Coverage checklist

Visit and snapshot each authenticated nav item:

1. Programs list and one program detail / apply entry
2. Application history
3. Applications billing
4. Scholarships
5. Study kit / assessment
6. Earn
7. My Learning (one course if enrolled)
8. Learning assessments
9. Learning billing
10. Records / academics

At each page: snapshot, annotated screenshot, `errors`, `console`.
Document issues immediately with repro steps. Prefer one deep broken
flow over a shallow tour.

Look for: dead clicks, layout overflow, empty/error states with no
message, 401/403/5xx from Actors, thumbnail/image fallbacks, payment
return URLs, session drop on refresh.

## Report

Write `$OUT/report.md`: environment, profile name, pages visited,
pass/fail per item, issues with screenshot paths. Paste a redacted
summary into the hub Codex task. No credentials, no `Authorization`
headers, no `.env` values.

Close the session when done (`agent-browser --session portal-qa close`)
unless the user wants to keep investigating.
