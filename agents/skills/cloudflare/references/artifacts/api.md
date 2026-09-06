# Artifacts API Reference

Use Artifacts through the **Workers binding**, the **REST control plane**, and **Git-compatible remotes**.

**Prefer retrieval** for exact request and response details. Verify current behavior at `https://developers.cloudflare.com/artifacts/` before relying on specific auth flows, route details, or generated binding types.

## Workers Binding

Artifacts exposes a Worker binding on `env.ARTIFACTS`.

### Namespace Methods

| Method | Use For |
|--------|---------|
| `create(name, opts?)` | Create a repo and receive its initial remote and token |
| `get(name)` | Resolve a repo handle for repo-scoped operations |
| `import(params)` | Import a public HTTPS remote using source/target options |
| `list(opts?)` | List repos in a namespace |
| `delete(name)` | Delete a repo |

```typescript
const created = await env.ARTIFACTS.create("starter-repo", {
  description: "Repository for automation experiments",
  setDefaultBranch: "main"
});
const repo = await env.ARTIFACTS.get("starter-repo");
const page = await env.ARTIFACTS.list({ limit: 10 });
```

The binding also supports imports:

```typescript
const imported = await env.ARTIFACTS.import({
  source: { url: "https://github.com/cloudflare/workers-sdk", branch: "main", depth: 1 },
  target: { name: "workers-sdk-copy", opts: { readOnly: true } }
});
```

Only import an intended, authorized source. The service import does not authorize local checkout or dependency execution.

### Repo Handle Methods

`get()` returns the repo handle and throws for missing or still-importing/forking repos. `create()`, `import()`, and `fork()` return metadata plus the initial token, not a handle.

| Method | Use For |
|--------|---------|
| `remote`, `name`, `defaultBranch` | Metadata properties on the handle |
| `createToken(scope?, ttl?)` | Mint a repo-scoped read or write token |
| `listTokens()` | Inspect active tokens |
| `revokeToken(tokenOrId)` | Revoke a token by ID or value |
| `fork(name, opts?)` | Fork one repo into another |

```typescript
const repo = await env.ARTIFACTS.get("starter-repo");
const remote = repo.remote;
const token = await repo.createToken("read", 3600);
// token.plaintext is the Git credential; token.expiresAt is its expiry.
const forked = await repo.fork("starter-repo-copy", {
  defaultBranchOnly: true
});
```

### Binding Notes

The examples are checked against `@cloudflare/workers-types` 5.20260905.1. Regenerate types with `wrangler types` for the target project. `info()` and `validateToken()` are not methods in these types. The live binding docs also describe commit/tree methods absent from this type release; verify the generated runtime surface before using those additions.

Catch binding errors at the route boundary, distinguish `NOT_FOUND` from in-progress and service failures, and authorize callers before creating repos or returning tokens. Never log plaintext credentials.

## REST API

Artifacts currently documents a namespace-scoped control plane:

```txt
https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/artifacts/namespaces/$ARTIFACTS_NAMESPACE
```

Requests use a Cloudflare API token with Bearer authentication. The gateway JWT and `/edge/v1` routes in older drafts are not the current public API.

Returned repo tokens authenticate **Git operations** against the repo `remote`. They do not authenticate REST control-plane requests.

JSON results use the standard Cloudflare v4 envelope. Check HTTP status and `success`; file/blob/raw endpoints return bytes on success.

### Repo Routes

| Route | Use For |
|-------|---------|
| `POST /repos` | Create a repo |
| `GET /repos` | List repos |
| `GET /repos/:name` | Read repo metadata and remote |
| `DELETE /repos/:name` | Delete a repo |
| `POST /repos/:name/fork` | Fork a repo |
| `POST /repos/:name/import` | Import a public HTTPS remote |

```bash
curl --request POST "$ARTIFACTS_BASE_URL/repos" \
  --header "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"name":"starter-repo"}'
```

Current REST details:
- `POST /repos/:name/import` accepts a full HTTPS remote URL such as GitHub or GitLab.
- Import supports options such as `branch`, `depth`, and `read_only`.
- Repo metadata includes fields such as description, default branch, timestamps, and the Git `remote`.

### Token Routes

| Route | Use For |
|-------|---------|
| `GET /repos/:name/tokens` | List repo tokens |
| `POST /tokens` | Create a token for a repo |
| `DELETE /tokens/:id` | Revoke a token by ID |

Current docs show list-token filtering and pagination by token state. Retrieve the exact query shape from the live docs when you need token audit or cleanup workflows.

Use **read** tokens for clone, fetch, pull, and indexing workflows. Use **write** tokens only when a workflow must push or otherwise mutate a repo.

## Git-Compatible Access

Artifacts returns repo `remote` URLs that work with standard git-over-HTTPS tooling.

Recommended current auth pattern for local workflows:

```bash
git -c http.extraHeader="Authorization: Bearer $ARTIFACTS_TOKEN" clone "$ARTIFACTS_REMOTE" artifacts-clone
```

Keep credentials out of persisted remote URLs. Header-based command arguments can still be visible in process listings; use an appropriate credential helper for long-running shared environments.

`read` tokens support `clone`, `fetch`, and `pull`. `git push` requires a `write` token.

For large repos where startup time matters more than a full clone, Artifacts also documents **ArtifactFS**. Retrieve current details from `https://developers.cloudflare.com/artifacts/` when you need mount-style access.

[Current binding API](https://developers.cloudflare.com/artifacts/api/workers-binding/) · [Current REST API](https://developers.cloudflare.com/artifacts/api/rest-api/) · [Authentication](https://developers.cloudflare.com/artifacts/guides/authentication/)
