# C3 Usage Patterns

## Quick Workflows

```bash
# TypeScript API Worker
npm create cloudflare@latest my-api -- --type=hello-world --lang=ts --deploy

# Next.js on Workers
npm create cloudflare@latest my-app -- --framework=next --platform=workers --lang=ts --deploy

# Astro static site
npm create cloudflare@latest my-blog -- --framework=astro --platform=pages --lang=ts
```

## CI/CD (GitHub Actions)

```yaml
- name: Deploy
  run: npm run deploy
  env:
    CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

**Non-interactive requires:**
```bash
--type=<value>       # Required
--no-git             # Recommended (CI already in git)
--no-deploy          # Deploy separately with secrets
--framework=<value>  # For web-app
--lang=ts / --lang=js       # Required
```

## Monorepo

C3 detects workspace config (`package.json` workspaces or `pnpm-workspace.yaml`).

```bash
cd packages/
npm create cloudflare@latest my-worker -- --type=hello-world --lang=ts --no-deploy
```

## Custom Templates

```bash
# GitHub repo
npm create cloudflare@latest -- --template=username/repo
npm create cloudflare@latest -- --template=cloudflare/templates/worker-openapi

# Local path
npm create cloudflare@latest my-app -- --template=../my-template
```

Templates are repositories in a supported degit URL format. Inspect the template and its dependency scripts before creation. `c3.config.json` with copies/transforms is not a supported public template contract; use the [C3 template documentation](https://developers.cloudflare.com/workers/get-started/prompting/).

## Existing Projects

```bash
# Add Cloudflare to existing Worker
npm create cloudflare@latest . -- --type=pre-existing --existing-script=my-existing-worker

# Add to existing framework app
npm create cloudflare@latest . -- --framework=next --platform=workers --lang=ts
```

## Post-Creation Checklist

1. Review `wrangler.jsonc` - set `compatibility_date`, verify `name`
2. Create bindings: `wrangler kv namespace create`, `wrangler d1 create`, `wrangler r2 bucket create`
3. Generate types: `npm run cf-typegen`
4. Test: `npm run dev`
5. Provision required secrets: `wrangler secret put SECRET_NAME`
6. Deploy when ready: `npm run deploy`

`--existing-script` downloads a deployed Worker; it does not convert local source or migrate an existing framework app. For an existing app, follow its current Workers framework guide. Workers Static Assets also support static sites, and Workers Builds supports Git workflows; Pages is an explicit framework-dependent choice. Inspect generated package scripts instead of assuming every framework uses the same names.
