# Production portal smoke

Reusable authenticated smoke for `https://portal.altschoolafrica.com`.
Load [../references/production-regressions.md](../references/production-regressions.md)
for the last verified baseline and pending checks. Load
[../references/credentials.md](../references/credentials.md) for profile
names only.

Do not store or request plaintext passwords, cookies, bearer tokens,
session payloads, authentication-state files, or complete HAR exports.

## When to run

- After a production deploy that touches auth, applications, billing,
  scholarships, study kit, assessments, or program media.
- When the user asks to confirm the portal is healthy.
- Before treating a “new” production bug as new — compare against the
  baseline first.

Local and preview are out of scope. Core is out of scope unless the
user names it.

Driver: **agent-browser** is required for the encrypted-profile login
and for sanitized `get-session` / assessment network status. If the
user also wants Codex Desktop visibility, open the same origin in the
in-app browser **after** agent-browser login, or have the user sign in
in-app without you typing the password. See
[../references/browser-drivers.md](../references/browser-drivers.md).
Do not treat an in-app-only walk as a full smoke pass unless session
status and both assessment cases were still captured without leaking
secrets.

## Procedure

```bash
SKILL_DIR="$(readlink -f ~/.agents/skills/altschool-portal-qa)"
DATE="$(date -u +%Y-%m-%d)"
STAMP="$(date -u +%Y-%m-%dT%H%MZ)"
OUT="$HOME/.altschool/portal-qa/$DATE/prod-smoke-$STAMP"
mkdir -p "$OUT/screenshots"
"$SKILL_DIR/scripts/preflight.sh"
"$SKILL_DIR/scripts/login.sh" --app portal --target prod
```

1. Start agent-browser with encrypted profile
   `altschool-portal-diagnosis` (the login script does this).
2. Confirm the landing route is `/applications/programs`.
3. Verify `GET /api/auth/get-session` is HTTP 200. Record only whether
   `user` and `token` fields exist — never print the body or token.
4. Reload the page. Confirm the session persists and there is no
   redirect to `/auth/signin`.
5. Visit, snapshot, and screenshot:
   - `/applications/programs`
   - `/applications/history`
   - `/applications/billing` (this QA account last showed 9 rows)
   - `/applications/scholarships`
   - `/applications/study-kit`
   - `/applications/earn`
6. Check for unexpected sign-in redirects, global error boundaries,
   runtime errors, and console errors.
7. Exercise both:
   - a valid exam (see the exam URL in the regression file)
   - a stopped or invalid assessment (stopped entrance `GET …/find`
     last verified HTTP 400 with `This assessment has already stoped.`)
8. Close the browser session:
   `agent-browser --session portal-qa close`
9. Append a run-log row: UTC, deployment or PR, symptom (`smoke` if
   none), reproduction URL, sanitized HTTP status, result, rollback
   decision. Copy the same row into the hub Codex task.

Use [../templates/qa-notes.md](../templates/qa-notes.md) for the
per-run notes file in `$OUT`.

## Pass / fail

Pass only if every baseline authentication and applications-route check
succeeds and both assessment cases behave as in the regression file.
A blocked login, missing profile, or 1Password/session issue is
`blocked`, not `pass`.

If a related deploy has not been smoke-tested, keep those rows
**pending** in the regression file rather than quoting the old baseline
as current.
