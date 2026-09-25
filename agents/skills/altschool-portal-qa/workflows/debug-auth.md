# Debug portal or Core auth

Load [../references/debug-signals.md](../references/debug-signals.md)
and [../references/browser-drivers.md](../references/browser-drivers.md).
In-app browser is useful to watch the bounce; encrypted-profile login
and status-only `get-session` still prefer agent-browser.

## Confirm origin vs config names

For local HTTPS the browser origin is `https://portal-altschool.localhost`
or `https://core-altschool.localhost`. `BETTER_AUTH_URL` / `NEXTAUTH_URL`
must match that origin. HTTP `localhost:8006` is a different origin.

Do not open `.env.local`. Compare against `.env.example` names and,
if 1Password Environments is available, `list_variables`.

## Reproduce login with the named profile

```bash
SKILL_DIR="$(readlink -f ~/.agents/skills/altschool-portal-qa)"
"$SKILL_DIR/scripts/login.sh" --app portal --target local
```

Watch only status codes:

```bash
agent-browser --session portal-qa network requests
```

Interesting paths: `/api/auth/sign-in/actors`, `/api/auth/get-session`,
Actors `auth/login`, `auth/me`. Quote status and JSON error **codes**,
not tokens. Production `GET /api/auth/get-session` last verified HTTP
200 with `user` and `token` present; see
[../references/production-regressions.md](../references/production-regressions.md).

## Classify

- **401 INVALID_CREDENTIALS** — wrong profile for this env, or password
  rotated. Refresh the encrypted profile from 1Password via
  `--password-stdin`. Do not paste the new password.
- **INVALID_ROLE** on Core — student QA profile used on admin. Switch
  to `altschool-core-*`.
- **EMAIL_NOT_VERIFIED** — expected redirect to `/auth/verify-email`.
- **Browser origin mismatch** — cookies set for the other host.
- **API URL missing/invalid** — app throws at boot (`resolveApiUrl`).
  Check process logs, not the env file contents.
- **Preview 403 / HMR** — `allowedDevOrigins` / restart
  `bun run dev:preview`.

## Local vs prod split

A failure that exists only locally is an env/origin/session issue until
proven otherwise. A failure on production with a known-good encrypted
profile is an upstream or app regression — capture HAR (redact) and
the student `proxy.ts` / `fetcher.ts` path.

## After a fix

Sign out from the UI or `agent-browser --session portal-qa close`,
login again with the same named profile, and hit a protected route
twice (including refresh) so cookie-cache behavior is covered.
