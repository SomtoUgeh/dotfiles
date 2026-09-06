# Better Auth 1.7 schema changes and upgrades

Use the project's installed release as the contract. Verified on 2026-09-05:
`auth@1.7.2` supports `generate` and `migrate`, with migration limited to the
built-in Kysely adapter. Its parser rejects `migrate plan` and `migrate apply`.
The published runtime also has no `account.identityStrategy` option. Those
features appear on the live website but are absent from this release.

Use the [official v1.7.2 upgrade guide](https://github.com/better-auth/better-auth/blob/v1.7.2/docs/content/docs/guides/1-7-upgrade-guide.mdx)
and [released CLI implementation](https://github.com/better-auth/better-auth/blob/v1.7.2/packages/cli/src/commands/migrate.ts).
For a different installed version, consult its tag, types, and CLI help before
adopting a newer workflow. Keep `better-auth`, `auth`, and synchronized official
plugins on the same release; independently versioned packages such as
`@better-auth/utils` retain their own versions. The 1.7 CLI needs Node.js 22.12+.

## New database or plugin addition within 1.7

The commands below target an application using Better Auth 1.7.2. Substitute
the project's pinned version, config path, and an unused output path.

```bash
npx auth@1.7.2 --version
npx auth@1.7.2 generate --help
npx auth@1.7.2 migrate --help
```

For built-in Kysely, generate SQL for inspection before the interactive apply:

```bash
npx auth@1.7.2 generate --config ./auth.ts --output ./auth-schema-review.sql
# Inspect the generated SQL and confirm the target database before proceeding.
npx auth@1.7.2 migrate --config ./auth.ts
```

`generate` writes a file and can introspect the configured database; it does
not apply SQL. `migrate` displays changes and asks before writing. Do not add
`--yes` until the exact changes and target have been reviewed. For an existing
1.7 database, rehearse changes on a restored copy first.

For Prisma or Drizzle, run `auth generate` against the configured adapter,
review the generated schema diff, then create and review a migration with the
project's existing ORM tooling. Apply that migration using the project's
normal deployment procedure. The 1.7.2 `auth migrate` command rejects these
adapters. Other adapters need their own supported schema procedure.

## Populated 1.6 database

Do not apply the generated 1.7 account schema over populated 1.6 data. The
released CLI cannot infer account namespaces or migrate OAuth clients and
SCIM records. Use the manual sections in the tagged upgrade guide; do not add
the unsupported `account.identityStrategy` setting.

1. Restore a complete backup into an isolated environment and inventory the
   login providers, physical table/column mappings, and plugins in use.
2. Prepare account identities using the guide's **Account identity is scoped
   by issuer** section. Add a nullable `issuer`, establish its trusted value
   for every provider, and preserve the provider's stable subject. Credential
   accounts use the linked user's ID. Microsoft accounts require the guide's
   verified `sub`-to-`oid` mapping before sign-in resumes.
3. Resolve duplicate `(issuer, accountId)` identities before enforcing the
   unique constraint. Never infer ownership by email. Enforce the required
   columns explicitly: `auth migrate` does not make an existing nullable
   column non-nullable. Use the guide's database-specific DDL, adapted to the
   actual schema and indexes; SQLite requires a table rebuild.
4. Complete applicable OAuth-client, SCIM, and device-authorization preparation
   from the same guide, then generate and review the remaining schema changes.
   Apply them with Kysely's `auth migrate` or the project's ORM tooling.
5. Verify preserved account/user links and every configured authentication,
   2FA, organization, linking, and provisioning flow on the restored copy.
   Reconcile ORM migration history with the manual DDL.
6. For cutover, stop all authentication writers, take a final complete backup,
   and repeat the rehearsed migration before deploying matching 1.7 code to
   every instance. Reopen writes only after the smoke tests pass. Rollback
   before reopening writes requires restoring the complete backup and matching
   1.6 application together; a later restore would discard intervening writes.

If trusted provider mappings or collision ownership cannot be established,
leave that application's upgrade pending and obtain those inputs. This is
application-specific migration work, not a reason to run nonexistent CLI
actions or apply a schema-only upgrade.
