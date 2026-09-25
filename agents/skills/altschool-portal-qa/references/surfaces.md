# Portal and Core surfaces

Source of truth is the current repo routes, not this file. Recheck
`apps/student/src/utils/routes.ts`, `apps/student/src/utils/navigation.ts`,
and `apps/core/src/utils/routes.ts` if a path 404s.

## Origins

| Name | Origin | Server |
| --- | --- | --- |
| Portal prod | https://portal.altschoolafrica.com | deployed student app |
| Portal local HTTPS | https://portal-altschool.localhost | Caddy → `:8006` |
| Portal local HTTP | http://localhost:8006 | `bun run dev --filter=student` |
| Core local HTTPS | https://core-altschool.localhost | Caddy → `:8007` |
| Core local HTTP | http://localhost:8007 | `bun run dev --filter=core` |
| Home local HTTPS | https://altschool.localhost | Caddy → `:8000` |
| Actors API | https://actors.thealtschool.com/api/v1/ | upstream |

Droplet preview: `bun run dev:preview --filter=student` (or `core`). URLs
land in `$HOME/.altschool-preview.json`. Set `NEXT_ALLOWED_DEV_ORIGIN` /
`allowedDevOrigins` for `*.trycloudflare.com`.

## Auth

Both apps use Better Auth + an Actors plugin, not the older NextAuth
comments in some READMEs.

| | Student | Core |
| --- | --- | --- |
| Sign-in | `/auth/signin` | `/auth/signin` |
| Client call | `authClient.signIn.actors` | `authClient.signIn.actors` |
| App route | `/api/auth/sign-in/actors` | `/api/auth/sign-in/actors` |
| Upstream | `{API}auth/login` | `{API}auth/login` |
| Session max age | 10 hours | 24 hours |
| Cookie cache | JWE, no refreshCache | JWE |
| Logged-in default | `/applications/programs` | `/dashboard` |
| Role gate | student | staff roles / permissions |

Student also has Google/social via `/api/auth/sign-in/actors-social` and
`{API}auth/{provider}/login`.

Visible student auth errors: `INVALID_CREDENTIALS`, `EMAIL_NOT_VERIFIED`
(redirects to `/auth/verify-email`), `TOO_MANY_REQUESTS`,
`AUTH_SERVICE_UNAVAILABLE`, `INVALID_AUTH_RESPONSE`. Core also uses
`INVALID_ROLE`.

Proxy (`apps/student/src/proxy.ts`) sends anonymous users to
`/auth/signin?callbackUrl=…`. Query `error=SessionExpired|SessionInvalid|AuthCheckFailed`
becomes a toast message.

## Student navigation (authenticated)

Programs

- `/applications/programs`
- `/applications/history`
- `/applications/billing`
- `/applications/scholarships`
- `/applications/study-kit` (also `/applications/assessment`)
- `/applications/earn`

Learning Center

- `/student-center/my-learning`
- `/student-center/assessments`
- `/student-center/billing`
- `/student-center/academics`

Other

- `/live-classes` (nav currently disabled)
- Community is an external link: `https://community.altschoolafrica.com/`
- `/logout`

Apply flow lives under `/applications/programs/[slug]/apply` with a
success route `/applications/programs/[slug]/apply/success`.

## Core navigation (authenticated)

Under `/dashboard`: applicants, payments, users, altlytics, schools,
certificates, discounts (codes, bulk, analytics), scholarships (lists,
applications, add/edit), student-center courses/assessments, settings
(organizations, roles). Permission misses go to `/not-allowed`.

## API clients

- Student: `apps/student/src/lib/fetcher.ts` — `ky` prefix
  `NEXT_PUBLIC_API_URL`, `Authorization: Bearer <actorsToken>`. Missing
  token signs out to `error=SessionInvalid`.
- Core: `apps/core/src/lib/req.ts` — Actors plus assessment, LMS, and
  course-tree bases.

When debugging, prefer `agent-browser network requests` / HAR in the
artifacts dir over pasting `Authorization` headers.

Assessment loads also hit `https://api-gateway.altschoolafrica.com`.
Quote those as method + sanitized URL + status only.

Verified production application-route and assessment results live in
[production-regressions.md](production-regressions.md). Re-run
[../workflows/production-smoke.md](../workflows/production-smoke.md)
after deploys that touch these surfaces.

## Local process control

```bash
make trust          # once, Caddy local CA
make dev apps=student
make dev apps=core,student
make stop
make preview        # print trycloudflare URLs if running
```

Do not kill unrelated `next dev` processes on other projects.
