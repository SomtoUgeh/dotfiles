# In-app browser (Codex Desktop)

Use the Codex Desktop embedded browser so the user can watch the same
tab. Load [../references/browser-drivers.md](../references/browser-drivers.md)
and [../references/credentials.md](../references/credentials.md) first.

This workflow does **not** replace production smoke. Encrypted-profile
login and network status capture stay on agent-browser unless this
turn’s in-app tools can do the same without printing secrets.

## When to use

- The user asked for the in-app browser, “open it here”, or “show me
  in Codex”.
- Ambient `<in-app-browser-context>` already has a portal tab.
- Local `https://portal-altschool.localhost` / preview URL the user
  should see in Desktop.

If Browser / `@Browser` / in-app tools are missing this turn: say so,
fall back to agent-browser, and still give the clickable origin.

## Bind the surface

Discover the live tool schema. Codex Desktop Product Design uses:

```text
@Browser
agent.browsers.get("iab")
```

Use that only when those APIs exist this turn. Otherwise use the
session’s `codex_app__*` or Browser plugin tools. Do not call a name
that is not in the current tool list.

Reuse an existing in-app tab on the target origin. Open a new tab only
when none is on that origin.

## Authenticate without leaking secrets

Production (`https://portal.altschoolafrica.com`):

1. Navigate to `/auth/signin` in the in-app tab **or** tell the user
   the tab is open there.
2. Do **not** fill the password field from chat, argv, or a decoded
   vault dump.
3. Preferred: user signs in in the in-app tab (they type the
   password). You wait until the URL is `/applications/programs`.
4. Alternative: run `scripts/login.sh --app portal --target prod` in
   agent-browser for the verified encrypted profile, and use in-app
   only for a parallel local/preview view.

Local: there is no `altschool-portal-local` profile until it is saved
with `--password-stdin`. Same rule — user types, or encrypted profile
login in agent-browser.

If a password was ever pasted into chat, do not reuse it. Rotate in
1Password and refresh the encrypted profile.

## Drive the flow

After the URL has left `/auth/signin`:

1. Confirm origin + route in notes (`driver: in-app`).
2. Walk the user-requested route or the smoke list. Snapshot/screenshot
   via the in-app tools when they exist; copy images into
   `$HOME/.altschool/portal-qa/<date>/<slug>/screenshots/`.
3. Check visible error boundaries and that reload does not bounce to
   `/auth/signin`.
4. Session check: HTTP status of `GET /api/auth/get-session` and
   presence of `user` / `token` only. If in-app cannot do that without
   dumping the body, mark those fields **unverified** or run the
   presence-only eval in agent-browser.
5. Do not complete payments, password changes, or certificate-warning
   bypasses in the in-app tab — hand those to the user.

## Completion

- Driver recorded as `in-app`.
- Origin stayed on the named portal/core host.
- No password/token/cookie/HAR in chat or notes.
- Screenshots or a stated tool gap are in the hub thread.
- If this was production smoke, also complete the agent-browser smoke
  path or list the session/network checks as unverified.
