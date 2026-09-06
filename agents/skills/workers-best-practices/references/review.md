# Code Review — Workers

How to review Workers code for type correctness, API usage, config validity, and best practices. This is self-contained — do not assume access to other skills.

## Retrieval

Prefer retrieval over pre-training. Types, config schemas, and APIs change with compatibility dates and new bindings.

### Workers types

Check the project lockfile, installed Wrangler, generated runtime types, and installed `@cloudflare/workers-types` first. They define the deployed compatibility target. Use current docs to identify potential upgrades; do not judge an existing project against a different package version silently.

```bash
mkdir -p /tmp/workers-types-latest && \
  npm pack @cloudflare/workers-types --pack-destination /tmp/workers-types-latest && \
  tar -xzf /tmp/workers-types-latest/cloudflare-workers-types-*.tgz -C /tmp/workers-types-latest
# Types are at /tmp/workers-types-latest/package/index.d.ts
```

Search this file for the specific type, class, or interface under review. Do not guess type names.

Use the installed `wrangler types` to generate runtime and `Env` types from local config. The package download above is optional research for an authorized upgrade, not a review prerequisite.

Fallback: read `node_modules/@cloudflare/workers-types/index.d.ts`. Note the installed version.

### Wrangler config schema

The authoritative schema is bundled with wrangler as `config-schema.json` (JSON Schema draft-07).

```bash
# Read from local node_modules
cat node_modules/wrangler/config-schema.json
```

Do not guess field names or structures — look them up.

### Cloudflare docs

Use the Cloudflare docs search tool if available, or fetch from `https://developers.cloudflare.com/workers/`. The best practices page lives at `/workers/best-practices/workers-best-practices/`.

---

## Type Validation

### Env interface

- Every binding must have a specific type. Flag `any`, `unknown`, `object`, or `Record<string, unknown>` on bindings.
- Binding types that accept generic parameters (Durable Object namespaces, Queues, Service bindings for RPC) must include them. Read the type definition to confirm which types are generic.
- Binding names must match the wrangler config exactly.
- Prefer generated types from `wrangler types` over hand-written interfaces.

### Handler and class signatures

Verify against current type definitions — do not assume signatures are stable.

- Correct import path (most Workers platform classes import from `"cloudflare:workers"`)
- Generic type parameter on base classes (e.g., `DurableObject<Env>`)
- Binding access pattern: `env.X` in module export handlers, `this.env.X` in classes extending platform base classes
- `ExecutionContext` as the third param in module export handlers (needed for `ctx.waitUntil()`)
- `fetch()` handlers return `Response` or `Promise<Response>`; verify the installed `ExportedHandler` type

### Binding access — the most common error

- **Module export handlers** (`fetch`, `scheduled`, `queue`, `email`): bindings via `env.X` parameter
- **Platform base classes** (`WorkerEntrypoint`, `DurableObject`, `Workflow`, `Agent`): bindings via `this.env.X`

Check scope before flagging `env.X`: a constructor or method can legitimately receive an `env` parameter. Use `this.env.X` for the inherited class environment. Module export handlers receive `env` as a parameter.

### Type integrity rules

| Rule | Detail |
|------|--------|
| No `any` | Never on binding types, handler params, or API responses |
| No double-casting | `as unknown as T` hides real incompatibilities — fix the underlying design |
| Justify suppressions | `@ts-ignore`/`@ts-expect-error` must include a comment explaining why |
| Prefer `satisfies` | Use `satisfies ExportedHandler<Env>` over `as` — validates without widening |
| Validate, do not assert | Schema or type guard for untyped data (JSON, parsed bodies), not `as` |

### Stale class patterns

Old patterns survive in codebases long after APIs change.

- **`extends` vs `implements`**: platform classes use `extends`, not `implements`. The `implements` pattern is legacy and loses `this.ctx`, `this.env`.
- **Import paths**: verify module specifiers match what types actually export. Common mistake: wrong path for `"cloudflare:workers"` vs `"cloudflare:workflows"`.
- **Renamed properties**: e.g., `this.state` to `this.ctx` in Durable Objects. Search types to confirm.
- **Constructor signatures**: base class constructors change. Verify expected parameters.

---

## Config Validation

### Required fields

For executable examples, verify: `name`, `compatibility_date`, `main`. Check the schema for current required fields.

### Config format

- **JSONC** (`wrangler.jsonc`) — preferred for new projects
- **JSON** (`wrangler.json`) — valid but no comments
- **TOML** (`wrangler.toml`) — legacy; acceptable in existing content, flag in new projects

### Binding-code consistency

1. Every `env.X` reference in code has a corresponding binding declaration in config
2. Every binding in config is referenced in code (warn on unused)
3. Names match exactly (case-sensitive)
4. For Durable Objects: `class_name` matches the exported class name

### Common config mistakes

| Check | What to look for |
|-------|-----------------|
| Stale `compatibility_date` | Should be recent; use `$today` placeholder in docs |
| Missing DO lifecycle | Every new DO class needs a SQLite `exports` entry; preserve migrations in existing migration-based deployments |
| Binding name mismatch | Config `binding`/`name` must match `env.X` in code |
| Secrets in config | Never in `vars` — use `wrangler secret put` |
| Wrong binding key | Verify top-level key name against the schema |
| Missing entrypoint | `main` required for executable Workers |

---

## Anti-Patterns to Flag

See the full anti-patterns table in `SKILL.md`. The type-specific ones to watch for during review:

- **`any` on `Env` or handler params** — defeats type safety for all downstream binding access
- **`as unknown as T`** — hides real type incompatibilities; fix the underlying design
- **`@ts-ignore`/`@ts-expect-error` without explanation** — masks errors silently; require a justifying comment
- **`implements` instead of `extends` on platform base classes** — legacy pattern; loses `this.ctx`, `this.env`
- **`env.X` inside class body** — should be `this.env.X` in platform base classes
- **`this.env.X` in module export handler** — should be `env.X` parameter
- **Non-serializable values across boundaries** — `Response`, `Error` in step/queue compiles but fails at runtime

---

## Serialization Boundaries

Each boundary has its own serialization contract. Do not apply one blanket list:

- **Queue messages**: check `contentType` and the producer/consumer encoding.
- **Workflow step return values**: follow the installed `RpcSerializable` types and current Workflows docs.
- **DO KV storage**: structured clone supports types such as `Map`, `Set`, `Date`, and `ArrayBuffer`; do not reject them categorically.
- **SQL bindings**: only SQLite scalar/blob values accepted by `sql.exec`, not arbitrary objects.
- **WebSockets**: `send()` accepts text or binary payloads, not arbitrary structured-clone objects.

Functions, symbols, request/response objects, and class behavior need boundary-specific handling. Validate with the actual runtime when unsure.

---

## Review Process

1. **Retrieve** — inspect project types/schema and fetch the current best-practices page
2. **Read full files** — not just diffs; context matters for binding access patterns
3. **Categorize code** — determines what to check:
   - **Illustrative** (concept demo, comments for most logic): verify correct API names and realistic signatures
   - **Demonstrative** (functional snippet, would work in context): verify syntax, correct APIs, correct binding access
   - **Executable** (standalone, runs without modification): verify compiles, runs, includes imports and config
4. **Check types** — binding access pattern, handler signatures, no `any`, no unsafe casts
5. **Check config** — compatibility_date, nodejs_compat, observability, secrets, binding-code consistency
6. **Check patterns** — streaming, floating promises, global state, serialization boundaries
7. **Check security** — crypto usage, secret handling, timing-safe comparisons, error handling
8. **Validate with tools** — use the project typecheck/lint scripts; do not download a floating tool for review
9. **Assess risk** — HIGH (auth, crypto, bindings), MEDIUM (business logic, config), LOW (style, comments)

### Output format

```
**[SEVERITY]** Brief description
`file.ts:42` — explanation with evidence
Suggested fix: `code`
```

Severity: **CRITICAL** (security, data loss, crash) | **HIGH** (type error, wrong API, broken config) | **MEDIUM** (missing validation, edge case) | **LOW** (style, minor improvement)
