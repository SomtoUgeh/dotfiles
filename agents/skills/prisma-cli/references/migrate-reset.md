# prisma migrate reset

Resets your database and re-applies all migrations.

## Command

```bash
prisma migrate reset [options]
```

## What It Does

1. **Drops** the database (if possible) or deletes all data/tables
2. **Re-creates** the database
3. **Applies** all migrations from `prisma/migrations/`
4. Stops after applying migrations; Prisma 7 does not automatically generate the client or run the seed script

**Warning: All data will be lost.**

## Options

| Option | Description |
|--------|-------------|
| `--force` / `-f` | Skip confirmation prompt |
| `--schema` | Path to schema file |
| `--config` | Custom path to your Prisma config file |

## Examples

### Basic reset

```bash
prisma migrate reset
```

Prompts for confirmation in interactive terminals.

### Force reset (CI/Automation)

```bash
prisma migrate reset --force
```

### With custom schema

```bash
prisma migrate reset --schema=./custom/schema.prisma
```

## When to Use

- **Development**: When you want a fresh start
- **Testing**: Resetting test database before suites
- **Drift Recovery**: When the database is out of sync and you can't migrate

## Behavior in v7

Prisma 7 removed automatic client generation and seeding from migration commands. A complete development reset that needs both is explicit:

```bash
prisma migrate reset
prisma generate
prisma db seed
```

The `migrations.seed` command in `prisma7.config.ts` tells `prisma db seed` what to execute; it does not make `migrate reset` invoke it automatically. The Prisma 7 CLI help has no `--skip-seed` option because reset does not seed.

## Agent execution

Prisma 7.10 can block this command when it detects an AI harness, including when `--force` is supplied. The flag skips the ordinary terminal prompt, not this guard. If that happens, identify the exact datasource and command, explain the deletion, and follow the CLI's request for fresh explicit consent. After consent, pass the user's exact response through `PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION`; do not fabricate consent or hide the agent environment to bypass detection. This was observed against a disposable local fixture as well as documented by Prisma.

See the [Prisma CLI guard documentation](https://docs.prisma.io/docs/orm/reference/prisma-cli-reference#ai-safety-guardrails-for-prisma-migrate-reset). Keep unrelated tests running while this operation awaits consent.
