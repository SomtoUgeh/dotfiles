# Credential handles

Store nothing but names here. Values live in 1Password or in encrypted
agent-browser auth profiles under `~/.agent-browser/auth/`.

## Encrypted agent-browser profiles

List metadata only:

```bash
agent-browser auth list
agent-browser auth show altschool-portal-diagnosis
```

Verified on this host:

| Profile | App | URL | Notes |
| --- | --- | --- | --- |
| `altschool-portal-diagnosis` | Student portal | `https://portal.altschoolafrica.com/auth/signin` | Encrypted (`encrypted: true`). Username is in profile metadata. |

Expected profiles to create when missing (same save method, never
`--password`):

| Profile | App | URL |
| --- | --- | --- |
| `altschool-portal-local` | Student portal | `https://portal-altschool.localhost/auth/signin` |
| `altschool-core-diagnosis` | Core admin | production Core `/auth/signin` — confirm origin with the user |
| `altschool-core-local` | Core admin | `https://core-altschool.localhost/auth/signin` |

Encryption at rest already exists: `~/.agent-browser/.encryption-key` mode
`600`. Do not print it. For `--session-name` state files, export
`AGENT_BROWSER_ENCRYPTION_KEY` from that file inside a script without
echoing. Never save plaintext `auth-state.json` into the repo or
`/tmp` without encryption.

Login:

```bash
agent-browser --session portal-qa --session-name portal-prod \
  auth login altschool-portal-diagnosis
```

If login fails, re-snapshot the form; do not dump the profile JSON.

## 1Password

Account shorthand on this host: `my` (`https://my.1password.eu`). The
1Password MCP server is not configured in Codex on this VM; use `op` after
`op signin` (desktop app integration) or ask the user to approve sign-in.

Do not use `op read` output in chat. Pipe password fields only:

```bash
op signin --account my
op item list --tags altschool
# username only; omit --reveal so concealed fields stay hidden
op item get "AltSchool Portal student (QA)" --fields username
```

Preferred item titles (create if missing; do not invent extra copies):

| Item title | Used for |
| --- | --- |
| `AltSchool Portal student (QA)` | Student portal login |
| `AltSchool Core admin (QA)` | Core admin login |
| `AltSchool web-platforms env` | `AUTH_SECRET` / API keys for local `.env` via Environments, names only |

Save a profile from 1Password without exposing the password:

```bash
USER="$(op item get "AltSchool Portal student (QA)" --fields username)"
op read "op://<vault>/AltSchool Portal student (QA)/password" \
  | agent-browser auth save altschool-portal-diagnosis \
      --url "https://portal.altschoolafrica.com/auth/signin" \
      --username "$USER" \
      --password-stdin
```

If `op` has no active session, use the existing encrypted profile instead of
asking the user to paste a password.

## Local env files

`apps/student/.env.local` and `apps/core/.env.local` are gitignored. Required
**names** (from `.env.example`, not from the local files):

- Shared: `NEXT_PUBLIC_API_URL`, `AUTH_SECRET`
- Student/Core origin: `BETTER_AUTH_URL` or fallback `NEXTAUTH_URL`
- Core extras: `NEXT_PUBLIC_ASSESSMENT_API_URL`, `NEXT_PUBLIC_LMS_API_URL`,
  `NEXT_PUBLIC_LMS_COURSE_TREE_API_URL`, `AUTH_TRUST_HOST`
- Preview: `NEXT_ALLOWED_DEV_ORIGIN`

Inspect names with 1Password Environments `list_variables` or by reading
`.env.example`. Do not read `.env.local` to "verify" values.

Local API base for both apps is
`https://actors.thealtschool.com/api/v1/` (trailing slash required).

## Forbidden

- `echo` / `cat` of passwords, tokens, encryption keys, cookie headers
- `agent-browser auth save … --password '…'`
- Committing `*.auth-state.json`, HAR files with `Authorization` headers, or
  agent-browser profile JSON
- Reusing a password that appeared in an old Codex transcript.
  Rotate that credential in 1Password and refresh
  `altschool-portal-diagnosis` with `--password-stdin`.
- Complete HAR exports, cookie dumps, or `get-session` payloads in the
  runbook or hub thread
