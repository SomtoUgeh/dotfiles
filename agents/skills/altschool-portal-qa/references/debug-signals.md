# Debug signals

Use with `diagnosing-bugs`. Build a red-capable loop before proposing a
fix.

## Auth / session

| Symptom | Likely seam | Check |
| --- | --- | --- |
| Sign-in toast "invalid login" | `{API}auth/login` body | Network 401 vs 200; do not log the password |
| Email not verified | student `EMAIL_NOT_VERIFIED` | Lands on `/auth/verify-email` |
| Infinite bounce to `/auth/signin` | `proxy.ts` + `getSession` | Session cookie present? `actorsToken` missing? |
| `SessionInvalid` | `fetcher` beforeRequest | Token cache vs Better Auth cookie |
| Works on HTTP localhost, fails on `*.localhost` HTTPS | `BETTER_AUTH_URL` / `NEXTAUTH_URL` | Must match the origin in the address bar |
| Preview tunnel login/HMR/font 403 | `allowedDevOrigins` | `NEXT_ALLOWED_DEV_ORIGIN` and restart preview |
| Core login "invalid role" | Actors profile roles | Expected: staff account, not student QA profile |
| 429 too many attempts | `TOO_MANY_REQUESTS` | Stop hammering production login |

Student session cookie cache is JWE with `refreshCache: false`. A stale
cached session will not self-heal; sign out and use `auth login` again.

## Data / UI

| Area | First files |
| --- | --- |
| Programs grid / apply | `apps/student/src/app/(dashboard)/applications/programs` |
| Video / thumbnail | program apply components, Cloudinary `res.cloudinary.com` |
| Billing / Paystack-ish flows | `applications/billing`, `student-center/billing` |
| Learning | `student-center/my-learning` |
| Assessment exam / entrance | `apps/student/src/app/(assessment)`, Study Kit |
| Assessment `startTime` / `meta.image` crashes | assessment store + exam UI; see [production-regressions.md](production-regressions.md) |
| Headerless JSON API errors | `apps/student/src/lib/api-error.ts` (`extractApiErrorMessage`) |
| Stopped entrance assessment | `GET …/assessment/{id}/find` HTTP 400, message `This assessment has already stoped.` |
| Core applicants | `apps/core/src/app/dashboard/applicants` |

## Evidence to capture (redacted)

In `$HOME/.altschool/portal-qa/<date>/<slug>/`:

- annotated screenshot
- `agent-browser get url`
- `agent-browser errors` and `console` (trim tokens)
- `agent-browser network requests` filtered to `/api/auth` and Actors
  `/auth/` — drop `Authorization` and `Set-Cookie` when quoting
- local server log excerpt from the app terminal, not `.env`

## Feedback loop examples

Portal signed-in page:

```bash
agent-browser --session portal-qa get url
agent-browser --session portal-qa snapshot -i
```

Red-capable when the URL or snapshot still shows the reported broken
state (wrong page, error toast, missing thumbnail, 4xx overlay).

Auth API without putting a password in argv: use the encrypted profile
and watch `POST /api/auth/sign-in/actors` and `POST …/auth/login` status
codes only.

Production `GET /api/auth/get-session` last verified HTTP 200 with
`user` and `token` **present**. Record presence only — never the body.
