# prisma db execute

Execute native commands (SQL) to your database.

## Command

```bash
prisma db execute [options]
```

## What It Does

- Connects to your database using the configured datasource
- Executes a script provided via file (`--file`) or stdin (`--stdin`)
- Useful for running raw SQL, maintenance tasks, or applying diffs from `migrate diff`
- Not supported on MongoDB

## Options

| Option | Description |
|--------|-------------|
| `--file` | Path to a file containing the script to execute |
| `--stdin` | Use terminal standard input as the script |
| `--config` | Custom path to your Prisma config file |

## Examples

### Execute from file

```bash
prisma db execute --file ./script.sql
```

### Execute from stdin

```bash
echo 'SELECT 1;' | prisma db execute --stdin
```

### Execute `migrate diff` output

For an authorized disposable target, a pipe can apply a diff. For persistent data, save the SQL, review it and verify backup/recovery first; use `set -o pipefail` when piping so a failed diff cannot look successful:

```bash
prisma migrate diff \
  --from-empty \
  --to-schema prisma/schema.prisma \
  --script \
| prisma db execute --stdin
```

## Configuration

Uses `datasource` from `prisma7.config.ts`:

```typescript
export default defineConfig({
  datasource: {
    url: env('DATABASE_URL'),
  },
})
```

## Use Cases

- **Manual Migrations**: Applying raw SQL changes
- **Data Maintenance**: Truncating tables, cleaning up data
- **Schema Synchronization**: Applying `migrate diff` scripts
- **Debugging**: Running test queries (though typically not for fetching data)

## Limitations

- **No Data Return**: The command reports success/failure, not query results (rows). Use Prisma Client or `prisma studio` to view data.
- **SQL Only**: Primarily for SQL databases.
