# Artifacts Configuration

## Worker Binding

Configure the `artifacts` binding in your Wrangler config:

```toml
[[artifacts]]
binding = "ARTIFACTS"
namespace = "default"
```

This exposes Artifacts on `env.ARTIFACTS`. The binding is non-inheritable: repeat it in each named Wrangler environment. `remote = true` opts local development into the hosted service; those calls can mutate real repositories.

Authenticate Wrangler for local commands or CI and verify closed-beta access. Do not assume that a successfully generated type proves account entitlement.

## TypeScript

Regenerate Worker types after adding the binding:

```bash
npx wrangler types
```

Use the generated binding type in your environment definition:

```typescript
interface Env {
  ARTIFACTS: Artifacts;
}
```

Wrangler generates the `Artifacts` type from the binding. Treat the generated `worker-configuration.d.ts` file as the source of truth for your environment.

## Structure Repos for Isolation

Artifacts works best when autonomous work is isolated:
- Create one repo per agent, session, sandbox, or task when work should stay separate.
- Fork from a reviewed baseline instead of copying starter files into every new repo.
- Use branches only when collaborators share the same lifecycle and need to work in one repo.
- Use namespaces to separate environments, teams, or high-rate workloads.

## REST Configuration

For external systems, configure the account/namespace-scoped base URL and Cloudflare API token:

```bash
export ARTIFACTS_NAMESPACE="default"
export ACCOUNT_ID="<YOUR_ACCOUNT_ID>"
export CLOUDFLARE_API_TOKEN="<YOUR_API_TOKEN>"
export ARTIFACTS_BASE_URL="https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/artifacts/namespaces/$ARTIFACTS_NAMESPACE"
```

Use environment variables or your secret manager. Keep Cloudflare API tokens and repo tokens out of source control. Current public REST routes do not use the gateway-JWT or `/edge/v1` paths from older drafts.

## Repo Tokens

Artifacts workflows usually involve repo-scoped tokens returned by `create()` or minted later through the binding or REST API.

Keep the control plane and data plane separate:
- Use the **Workers binding** or **REST API** with a Cloudflare API token to create repos and mint tokens.
- Use repo-scoped tokens only for **Git operations** against the returned `remote`.

Recommended handling:
- Mint the narrowest scope you need: `read` or `write`
- Prefer short-lived tokens for handoff between systems
- Revoke tokens that are no longer needed

Verify the current token behavior and auth guidance in `https://developers.cloudflare.com/artifacts/` before building long-lived automation.

## Git Consumers

Artifacts is designed to work with standard git-over-HTTPS clients once you have a repo `remote` and an access token.

Prefer header-based auth for local tooling so the full token stays out of the remote URL:

```bash
git -c http.extraHeader="Authorization: Bearer $ARTIFACTS_TOKEN" clone "$ARTIFACTS_REMOTE" artifacts-clone
```

Use a credential helper when process-argument visibility matters; do not persist a token in the Git remote URL.

## Retrieval Checklist

Check the live docs before relying on:
- the current Workers binding surface
- exact token formats
- availability or product status
- route details for import, fork, and token-management flows
- the current account/namespace REST paths
- platform limits or pricing

[Current configuration](https://developers.cloudflare.com/artifacts/api/workers-binding/) · [REST authentication](https://developers.cloudflare.com/artifacts/api/rest-api/)
