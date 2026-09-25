# Production regression history

Living incident and regression-test record for the student portal. Keep
verified production results separate from checks that are **pending**
until they pass again after a later deployment.

This file stores no passwords, cookies, bearer tokens, session payloads,
authentication-state files, or complete HAR exports. Network evidence is
method + sanitized URL + status only.

Hub Codex task: `01a099f2-a024-7881-995e-f673f4b95007`
(title **AltSchool Portal QA runbook**).

## How to use

- Before reproducing a “new” production bug, search this file for the
  route, assessment id, or crash string.
- After a related deploy, treat the matching rows as **pending** until
  the reusable smoke (or a narrower recheck) passes again.
- Append dated results to **Run log** below. Do not rewrite the baseline
  until the full relevant set has passed.
- Prefer the encrypted profile `altschool-portal-diagnosis`. If a
  credential was ever pasted into chat, rotate it in 1Password and
  refresh that profile with `--password-stdin`.

## Environment

| Item | Value |
| --- | --- |
| Repository | `/home/altschool/code/TalentQL/altschool-web-platforms` |
| Production portal | `https://portal.altschoolafrica.com` |
| Sign-in | `https://portal.altschoolafrica.com/auth/signin` |
| Encrypted agent-browser profile | `altschool-portal-diagnosis` |
| Credentials | 1Password items or the encrypted agent-browser vault only |
| Assessment gateway | `https://api-gateway.altschoolafrica.com` |

## Evidence rules

Allowed in this file and in the hub thread:

- Route / sanitized URL
- HTTP method and status
- Presence of session `user` and `token` fields (`present` / `absent`)
- Visible UI copy, including backend typos
- Screenshot paths under `$HOME/.altschool/portal-qa/`
- PR numbers

Never record: passwords, cookies, `Authorization` headers, bearer
tokens, `get-session` bodies, `.env` values, or full HAR/request dumps.

## Verified production baseline

Status: **verified** after PRs #463–#467 (merged 2026-09-08 UTC).
Exact wall-clock of the original QA pass was not recorded; later smoke
runs must log UTC in the run log.

These results apply only to production portal +
`altschool-portal-diagnosis`. They are not a local or Core baseline.

### Authentication

| Check | Result |
| --- | --- |
| Production login | completed |
| Landing route | `/applications/programs` |
| `GET /api/auth/get-session` | HTTP 200 |
| Session `user` field | present (value not recorded) |
| Session `token` field | present (value not recorded) |
| Full browser reload | session preserved |
| Unexpected redirect to `/auth/signin` | none |

### Authenticated application routes

| Route | Result |
| --- | --- |
| `/applications/programs` | loaded |
| `/applications/history` | loaded |
| `/applications/billing` | loaded; **9 billing rows** for this QA account (account snapshot, not a product invariant) |
| `/applications/scholarships` | loaded |
| `/applications/study-kit` | loaded |
| `/applications/earn` | loaded |
| Runtime / console errors on the final deployed pass of these routes | none unexpected |

Not in this baseline (still **pending** unless a later run log says
otherwise): Learning Center (`/student-center/*`), Live Classes, Core
admin, local/preview origins.

### Assessment

| Check | Result |
| --- | --- |
| Valid exam assessment | loaded with 100 answers |
| `Cannot read properties of undefined (reading 'startTime')` | did not recur |
| Null assessment `meta.image` crash | did not recur |
| Stopped entrance assessment | `GET` assessment find → HTTP 400 |
| Backend message | `This assessment has already stoped.` (typo is upstream) |
| UI | displayed that backend message |
| Error state | showed a Retry action |
| Failed direct assessment | returned to Study Kit or Assessments, not a broken page |
| Headerless JSON errors | parsed and shown when the gateway omitted a correct `Content-Type` |

## Reproduction URLs

Sanitized only. Do not attach cookies or HAR.

Billing:

- `https://portal.altschoolafrica.com/applications/billing`

Study Kit:

- `https://portal.altschoolafrica.com/applications/study-kit`

Valid exam (portal):

- `https://portal.altschoolafrica.com/assessment/61e94082-fa97-4d4f-ace2-262110e411ce?schoolId=4337f1dc-c86a-4094-96c6-57c683d880c2&cohortId=9e8e5328-c5c5-4af4-b265-37d5b45c2084&type=exam&courseId=19cac8a4-6417-11f1-9b54-0e2d06e97381`

Stopped entrance assessment API:

- Method: `GET`
- URL: `https://api-gateway.altschoolafrica.com/assessment/659bb825c7f2bdc8a5333367/find`
- Query: `type=entrance`, `schoolId=64771756e5b512048476a1c8`,
  `cohortId=690e36f6003262a444b10ca4`,
  `applicationId=69a56fbec6f89f63a3b0ea5c`,
  `courseId=64771756e5b512048476a1cc`, `courseType=Diploma`,
  `relations=cohort,school`
- Verified status: **400**
- Verified body message: `This assessment has already stoped.`

## Program UI regressions

| Check | Result |
| --- | --- |
| Marketing, Brand Positioning and Customer Acquisition Workshop video thumbnail | uses the repository image when no remote thumbnail exists |
| Masterclass / Diploma / Nano-Diploma grids | consistent responsive card sizing and spacing |

Detail:

- `https://portal.altschoolafrica.com/applications/programs/marketing-brand-positioning-customer-acquisition-workshop`

Grid:

- `https://portal.altschoolafrica.com/applications/programs?type=masterclass`

## Deployment history

All merged to `TalentQL/altschool-web-platforms` on 2026-09-08 UTC:

| PR | Title | What it covered |
| --- | --- | --- |
| [#463](https://github.com/TalentQL/altschool-web-platforms/pull/463) | improve program media and grid rendering | thumbnail fallback; Masterclass/Diploma/Nano-Diploma grid layout |
| [#464](https://github.com/TalentQL/altschool-web-platforms/pull/464) | migrate applications to Better Auth | Better Auth + Actors session |
| [#465](https://github.com/TalentQL/altschool-web-platforms/pull/465) | prevent billing and assessment crashes | billing currency fallback; null assessment-image crash |
| [#466](https://github.com/TalentQL/altschool-web-platforms/pull/466) | recover from assessment load errors | error recovery, visible API errors, safe redirects |
| [#467](https://github.com/TalentQL/altschool-web-platforms/pull/467) | surface headerless API error messages | parse JSON errors without a correct `Content-Type` |

After any later production deploy, mark the overlapping rows **pending**
in the run log until smoke (or a scoped recheck) passes.

## Reusable production smoke

Procedure lives in
[../workflows/production-smoke.md](../workflows/production-smoke.md).
Minimum pass criteria match the baseline tables above.

Each run must record: UTC time, deployment or PR, symptom (or
`smoke`), reproduction URL, sanitized HTTP status, result
(`pass` / `fail` / `blocked`), rollback decision.

## Pending after future deployments

Until a new dated **pass** is logged:

- Re-verify auth + reload + `GET /api/auth/get-session` HTTP 200
  (presence of `user` and `token` only).
- Re-walk Programs, History, Billing, Scholarships, Study Kit, Earn.
- Re-exercise one valid exam and the stopped entrance assessment
  (expect HTTP 400 and the backend message in the UI).
- Re-check workshop thumbnail fallback and program grids if the deploy
  touched program media or listing layout.
- Learning Center and Core remain pending until explicitly tested.

Do not treat local or preview results as a replacement for this
production baseline.

## Run log

| UTC | Deploy / PR | Symptom | URL | Status | Result | Rollback |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-09-08 (day of PRs #463–#467; clock not recorded) | #463–#467 | post-deploy production QA | `https://portal.altschoolafrica.com/applications/programs` | `GET /api/auth/get-session` 200; stopped assessment `GET …/find` 400 | **pass** (baseline above) | none |

| 2026-09-13 10:29 UTC | [#468](https://github.com/TalentQL/altschool-web-platforms/pull/468), `4032357` | programs crash with non-string profile field | `https://portal.altschoolafrica.com/applications/programs` | normal `GET /api/auth/get-session` 200; browser-only synthetic numeric dob reproduces error before fix, editable onboarding with blank dob after fix | **pass** (programs regression only; encrypted QA profile; exact affected learner field unconfirmed; no stored data changed) | none |

| 2026-09-13 10:41 UTC | #468, `4032357` | scoped post-deploy portal smoke + onboarding regression | production Programs, History, Billing, Scholarships, Study Kit, Earn, My Learning | fresh auth/session 200; valid-exam GET 200 (25 questions/100 answers) and instructions render; stopped assessment 400 with message + Retry; zero uncaught runtime exceptions; malformed numeric dob safely blank and editable | **pass** (encrypted QA profile; browser-only malformed fixture; no profile/application/payment/assessment submissions; quiz timer/submission not exercised) | none |

| 2026-09-13 11:39 UTC | #469, `18c8e3c` | post-deploy profile hardening + portal smoke | production Programs, History, Billing, Scholarships, Study Kit, Earn, My Learning | fresh auth/session 200 + reload; valid exam GET 200 (25 questions/100 answers), instructions render; stopped assessment 400 with message + Retry; synthetic malformed profile safely opens editable onboarding; zero uncaught runtime exceptions | **pass** (QA account; fixture removed; no data submissions; pre-existing broken ASIC logo remains; evidence: `~/.altschool/portal-qa/2026-09-13/pr469-production-smoke/notes.md`) | none |

Add new rows above this line. Keep failures here even after a fix so
the mothership retains the incident trail.
