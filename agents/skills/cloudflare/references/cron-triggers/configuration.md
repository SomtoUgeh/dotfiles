# Cron Triggers Configuration

## wrangler.jsonc

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "my-cron-worker",
  "main": "src/index.ts",
  "compatibility_date": "2025-01-01", // Use current date for new projects

  "triggers": {
    "crons": [
      "*/5 * * * *",     // Every 5 minutes
      "0 */2 * * *",     // Every 2 hours
      "0 9 * * MON-FRI", // Weekdays at 9am UTC
      "0 2 1 * *"        // Monthly on 1st at 2am UTC
    ]
  }
}
```

## Green Compute

Green Compute is an account-level Workers compute setting that selects eligible data centers powered by renewable energy. It is not `placement.mode = "smart"`, and does not add a documented 24-hour delay window. Configure it through the account dashboard.

## Environment-Specific Schedules

```jsonc
{
  "name": "my-cron-worker",
  "triggers": {
    "crons": ["0 */6 * * *"]  // Prod: every 6 hours
  },
  "env": {
    "staging": {
      "triggers": {
        "crons": ["*/15 * * * *"]  // Staging: every 15min
      }
    },
    "dev": {
      "triggers": {
        "crons": ["*/5 * * * *"]  // Dev: every 5min
      }
    }
  }
}
```

## Schedule Format

**Structure:** `minute hour day-of-month month day-of-week`

**Special chars:** `*` (any), `,` (list), `-` (range), `/` (step), `L` (last), `W` (weekday), `#` (nth)

## Managing Triggers

**Remove all:** `"triggers": { "crons": [] }`
**Preserve existing:** Omit `"triggers"` field entirely

## Deployment

```bash
# Deploy with config crons
npx wrangler deploy

# Deploy specific environment
npx wrangler deploy --env production

# View deployments
npx wrangler deployments list
```

**⚠️ Changes take up to 15 minutes to propagate globally**

## API Management

**Get triggers:**
```bash
curl "https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{script_name}/schedules" \
  -H "Authorization: Bearer {api_token}"
```

**Update triggers:**
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{script_name}/schedules" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '[{"cron": "*/5 * * * *"}, {"cron": "0 2 * * *"}]'
```

**Delete all:**
```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/{account_id}/workers/scripts/{script_name}/schedules" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  -d '[]'
```

## Combining Multiple Workers

For complex schedules, use multiple workers:

```jsonc
// worker-frequent.jsonc
{
  "name": "data-sync-frequent",
  "triggers": { "crons": ["*/5 * * * *"] }
}

// worker-daily.jsonc
{
  "name": "reports-daily",
  "triggers": { "crons": ["0 2 * * *"] },
  "placement": { "mode": "smart" } // Performance placement, not Green Compute
}

// worker-weekly.jsonc
{
  "name": "cleanup-weekly",
  "triggers": { "crons": ["0 3 * * SUN"] }
}
```

**Benefits:**
- Separate CPU limits per worker
- Independent error isolation
- Separate schedules and application responsibilities
- Easier to maintain and debug

## Validation

**Test cron syntax:**
- [crontab.guru](https://crontab.guru/) - Interactive validator
- Wrangler validates on deploy but won't catch logic errors

**Common mistakes:**
- `0 0 * * *` runs daily at midnight UTC, not your local timezone
- `*/60 * * * *` is invalid (use `0 * * * *` for hourly)
- `0 2 31 * *` only runs on months with 31 days

## See Also

- [README.md](./README.md) - Overview, quick start
- [api.md](./api.md) - Handler implementation
- [patterns.md](./patterns.md) - Multi-cron routing examples

Current source: [Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/). Local handler tests do not verify hosted scheduling, retries, or global propagation.
