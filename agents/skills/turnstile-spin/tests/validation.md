# Skill validation cases

These cases match the assertions in the Turnstile Spin PRD. Run them after editing this skill to confirm an agent loading it can still execute the wizard end-to-end.

## Offline auth-probe regression tests

From this skill's directory:

```sh
uv run --no-project python tests/test_auth_probe.py
bun test tests/siteverify.test.ts
```

These tests replace `curl` with a local stub and use an isolated PATH and dummy credentials. They make no network requests. Cases cover Edit-scope validation without creation, accidental creation with confirmed deletion, failed or unconfirmed cleanup, auth/network failures, malformed probe responses, and missing tokens. They also verify that only the accidentally created public sitekey is deleted and credentials do not appear in curl arguments, its environment, or script output.

An unconfirmed cleanup must return `status: "cleanup_failed"` with `account_id`, public `sitekey`, `reason`, and `http_code`. The agent must stop setup and resolve that widget before retrying the probe. HTTP success without the API's `success: true` is not confirmation of deletion. This follows the [Cloudflare DELETE response contract](https://developers.cloudflare.com/api/resources/turnstile/subresources/widgets/methods/delete/).

A successful creation response must contain a nonempty `result.sitekey` so the probe can clean up that exact widget, as specified by the [Cloudflare POST response contract](https://developers.cloudflare.com/api/resources/turnstile/subresources/widgets/methods/create/). A rejected probe must contain structured API errors; an empty failure envelope provides no scope evidence. Malformed or incomplete responses return `upstream_failure` rather than `ok`.

The deploy checks below use real Cloudflare resources and are separate from this offline suite.

## Test 1: Dummy Siteverify returns a structured error

Step 10's `validate.sh` sends a deliberately-invalid token directly to `challenges.cloudflare.com/turnstile/v0/siteverify` using the captured secret. The expected response is `success: false` with `error-codes: ["invalid-input-response"]`. Other responses leave this probe unverified; distinguish network, HTTP, and response errors before diagnosing configuration.

```sh
printf '%s' "$WIDGET_SECRET" |
  python3 -I -c 'import sys,urllib.parse; print(urllib.parse.urlencode({"secret":sys.stdin.read(),"response":"XXXX.DUMMY.TOKEN.XXXX"}),end="")' |
  curl --disable --fail --silent --show-error \
    "https://challenges.cloudflare.com/turnstile/v0/siteverify" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-binary @- |
  jq -e '.success == false and (.["error-codes"] | index("invalid-input-response"))'
```

Expected exit code: 0.

## Test 2: Metadata matches the sitekey and secret

```sh
printf '%s' "$WIDGET_SECRET" |
  scripts/validate.sh \
    --sitekey "$SITEKEY" \
    --account-id "$ACCOUNT_ID" \
    --expected-domains '["example.com","localhost","127.0.0.1"]'
```

Expected exit code: 0 for all valid clearance levels: `no_clearance`, `interactive`, `managed`, and `jschallenge`. A secret from another sitekey must fail.

## Test 3: Runtime checks match the protected surface

Inspect every generated frontend and backend pair:

- The widget has a meaningful action such as `signup`, `login`, or `contact`.
- The backend requires the same `result.action` value.
- The backend requires `result.hostname` to match its deployment-specific frontend hostname allowlist.
- A production hostname allowlist does not contain `localhost` or `127.0.0.1`.

## Test 4: Same-page retries reset the correct widget

Native forms that navigate do not need reset logic. For each same-page flow, verify that the code retains the widget ID returned by `turnstile.render()` and calls `turnstile.reset(widgetId)` after the request completes. Multiple protected surfaces must not share a widget ID or reset without an ID.

## Test 5: Skill persists to a bundle location

After Step 11:

```sh
test -f .claude/skills/turnstile-spin/SKILL.md \
  || test -f .codex/skills/turnstile-spin/SKILL.md \
  || test -f .opencode/skills/turnstile-spin/SKILL.md
```

Expected exit code: 0. File-oriented rules targets point to the installed bundle. Persistence copies this locally maintained bundle; it does not download upstream code.

## Running all cases

The consuming test harness must pass the widget secret through standard input. It must not export it or place it in a command argument.

(`run-all.sh` is not bundled with this skill; the cases above are intended to be wired into the consuming agent's own test harness, or run by hand after a deploy.)
