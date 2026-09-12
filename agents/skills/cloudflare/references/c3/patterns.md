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

To download a deployed Worker into a new directory:

```bash
npm create cloudflare@latest my-worker-copy -- --existing-script=my-existing-worker
```

For an existing local Worker or framework app, inspect its source, adapter, scripts, and Wrangler configuration before changing them. Follow the matching [Workers framework guide](https://developers.cloudflare.com/workers/framework-guides/) or [Pages-to-Workers migration](https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/) when that migration is requested. C3 deployed-script cloning is not a local migration command.

## Post-Creation Checklist

Use the generated project scripts and provision only resources required by the chosen template; these commands are examples.

1. Review `wrangler.jsonc` - set `compatibility_date`, verify `name`
2. Reuse or create required bindings: `wrangler kv namespace create`, `wrangler d1 create`, `wrangler r2 bucket create`
3. Generate types: `npm run cf-typegen`
4. Test: `npm run dev`
5. Provision required secrets: `wrangler secret put SECRET_NAME`
6. Deploy when ready: `npm run deploy`
