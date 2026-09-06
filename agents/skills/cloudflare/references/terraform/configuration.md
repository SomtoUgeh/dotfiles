# Terraform v5 configuration

These are composable snippets for provider 5.24.0. Supply referenced variables/resources from the project and run `terraform validate`; account permissions and service entitlements still need a plan. HCL uses newlines between arguments, not semicolons. v5 nested configuration usually uses objects/lists (`field = {}` / `field = [{}]`), not v4 blocks.

## Zone and DNS

```hcl
resource "cloudflare_zone" "example" {
  account = { id = var.account_id }
  name    = "example.com"
  type    = "full"
}
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = cloudflare_zone.example.id
  setting_id = "ssl"
  value      = "strict"
}
resource "cloudflare_dns_record" "www" {
  zone_id = cloudflare_zone.example.id
  name    = "www.example.com"
  content = "192.0.2.1"
  type    = "A"
  ttl     = 1
  proxied = true
}
```

Use one `cloudflare_zone_setting` per setting instead of removed `cloudflare_zone_settings_override`. For MX records set `proxied = false`, a numeric priority and a valid TTL.

## Worker and storage bindings

```hcl
resource "cloudflare_workers_kv_namespace" "cache" {
  account_id = var.account_id
  title      = "cache"
}
resource "cloudflare_r2_bucket" "assets" {
  account_id = var.account_id
  name       = "example-assets"
  location   = "WNAM"
}
resource "cloudflare_d1_database" "app" {
  account_id = var.account_id
  name       = "app-db"
}
resource "cloudflare_queue" "events" {
  account_id = var.account_id
  queue_name = "events-queue"
}
resource "cloudflare_workers_script" "api" {
  account_id         = var.account_id
  script_name        = "api-worker"
  content            = file("${path.module}/worker.js")
  main_module        = "worker.js"
  compatibility_date = var.compatibility_date
  bindings = [
    { name = "KV", type = "kv_namespace", namespace_id = cloudflare_workers_kv_namespace.cache.id },
    { name = "BUCKET", type = "r2_bucket", bucket_name = cloudflare_r2_bucket.assets.name },
    { name = "DB", type = "d1", id = cloudflare_d1_database.app.id },
    { name = "QUEUE", type = "queue", queue_name = cloudflare_queue.events.queue_name },
    { name = "API_KEY", type = "secret_text", text = var.api_key }
  ]
}
resource "cloudflare_workers_route" "api" {
  zone_id = cloudflare_zone.example.id
  pattern = "api.example.com/*"
  script  = cloudflare_workers_script.api.script_name
}
resource "cloudflare_workers_cron_trigger" "task" {
  account_id  = var.account_id
  script_name = cloudflare_workers_script.api.script_name
  schedules   = [{ cron = "*/5 * * * *" }]
}
```

The Worker artifact must be built first and export the handlers its routes/triggers use. `main_module` identifies a module Worker; `module = true`, `name`, and `kv_namespace_binding {}` are not the v5 script schema. If using `content_file`, supply `content_sha256` as required by the pinned provider. D1 resource creation does not apply application migrations.

Other binding records use the same `bindings` list. Verify their exact fields in the [versioned script schema](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs/resources/workers_script): service (`service`), Vectorize (`index_name`), Hyperdrive (`id`), AI (`type = "ai"`), browser (`type = "browser"`), Analytics (`dataset`), mTLS (`certificate_id`). Secret values in bindings remain sensitive state.

## Pages

```hcl
resource "cloudflare_pages_project" "site" {
  account_id        = var.account_id
  name              = "site"
  production_branch = "main"
  build_config = {
    build_command   = "npm run build"
    destination_dir = "dist"
  }
  deployment_configs = {
    production = {
      compatibility_date = var.compatibility_date
      env_vars = { NODE_ENV = { type = "plain_text", value = "production" } }
      kv_namespaces = { KV = { namespace_id = cloudflare_workers_kv_namespace.cache.id } }
      d1_databases = { DB = { id = cloudflare_d1_database.app.id } }
    }
  }
}
resource "cloudflare_pages_domain" "custom" {
  account_id   = var.account_id
  project_name = cloudflare_pages_project.site.name
  name         = "site.example.com"
}
```

A project resource does not upload a site artifact. Configure the intended Git integration or existing deployment pipeline, and manage required DNS/certificate validation separately.

## Rulesets

```hcl
resource "cloudflare_ruleset" "redirects" {
  zone_id = cloudflare_zone.example.id
  name    = "Redirects"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"
  rules = [{
    action     = "redirect"
    enabled    = true
    expression = "http.request.uri.path eq \"/old\""
    action_parameters = {
      from_value = {
        status_code = 301
        target_url  = { value = "https://example.com/new" }
      }
    }
  }]
}
```

WAF, redirects and cache rules use different phases/actions. Preserve an existing phase's other rules when managing its ruleset. Do not substitute nonexistent fields such as `cf.verified_bot`; use the product's expression reference and entitlement checks. A filename suffix alone is not sufficient to declare a response publicly cacheable.

## Load balancing and Access

```hcl
resource "cloudflare_load_balancer_monitor" "http" {
  account_id     = var.account_id
  type           = "https"
  path           = "/health"
  expected_codes = "200"
}
resource "cloudflare_load_balancer_pool" "api" {
  account_id = var.account_id
  name       = "api-pool"
  monitor    = cloudflare_load_balancer_monitor.http.id
  origins = [
    { name = "api-1", address = "origin1.example.com" },
    { name = "api-2", address = "origin2.example.com" }
  ]
}
resource "cloudflare_load_balancer" "api" {
  zone_id       = cloudflare_zone.example.id
  name          = "api.example.com"
  default_pools = [cloudflare_load_balancer_pool.api.id]
  fallback_pool = cloudflare_load_balancer_pool.api.id
  proxied       = true
}
resource "cloudflare_zero_trust_access_policy" "admins" {
  account_id = var.account_id
  name       = "Administrators"
  decision   = "allow"
  include    = [{ email = { email = "admin@example.com" } }]
}
resource "cloudflare_zero_trust_access_application" "admin" {
  account_id       = var.account_id
  name             = "Admin"
  domain           = "admin.example.com"
  type             = "self_hosted"
  session_duration = "24h"
  policies = [{ id = cloudflare_zero_trust_access_policy.admins.id, precedence = 1 }]
}
```

Use an existing identity provider or configure `cloudflare_zero_trust_access_identity_provider` with the current provider-specific `config` object. Confirm that all public aliases and the origin itself enforce the intended access boundary. Load-balancer regions use a `region_pools` map and require the relevant steering plan; do not treat replica distribution as geographic steering.

## Gradual Worker deployments

The separate `cloudflare_worker`, `cloudflare_worker_version` and `cloudflare_workers_deployment` resources are documented as beta in this provider. Adopt them only when the project needs their lifecycle. `worker_version` takes `worker_id`, `main_module` and a `modules` list; deployment takes `script_name`, `strategy = "percentage"` and a `versions` list. Follow the [versioned resource schema](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs/resources/worker_version), not v4 `bindings {}` or invented `worker_name` fields.

The installed 5.24.0 provider schema requires `schedules` for cron triggers even where generated website examples show `body`. Prefer `terraform providers schema -json` plus `terraform validate` for the selected binary.
