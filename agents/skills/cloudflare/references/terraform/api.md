# Terraform data sources and import

Resolve IDs deliberately; do not silently select the first of several accounts or zones. These examples use provider 5.24.0.

```hcl
data "cloudflare_zone" "example" {
  zone_id = var.zone_id
}
data "cloudflare_accounts" "matching" {
  name = var.account_name
}
data "cloudflare_workers_script" "existing" {
  account_id  = var.account_id
  script_name = "existing-worker"
}
data "cloudflare_workers_kv_namespace" "existing" {
  account_id   = var.account_id
  namespace_id = var.namespace_id
}
data "cloudflare_list" "blocked_ips" {
  account_id = var.account_id
  list_id    = var.list_id
}
data "cloudflare_ip_ranges" "cloudflare" {}
output "ipv4_cidrs" {
  value = data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs
}
output "ipv6_cidrs" {
  value = data.cloudflare_ip_ranges.cloudflare.ipv6_cidrs
}
```

`cloudflare_zone` supports an explicit `zone_id` or its documented `filter` object; `name` is not a top-level v5 argument. `cloudflare_accounts` returns `result`, not `accounts`; check the number and identity of matches before selecting one. A list lookup uses `list_id`, not a guessed name argument. Worker service and KV bindings use the list/object shapes in [configuration.md](configuration.md).

## Import

Verify the pinned resource's Import section before touching state. Common v5 formats:

| Resource | Format |
|---|---|
| `cloudflare_zone` | `zone_id` |
| `cloudflare_dns_record` | `zone_id/record_id` |
| `cloudflare_workers_script` | `account_id/script_name` |
| `cloudflare_workers_kv_namespace` | `account_id/namespace_id` |
| `cloudflare_d1_database` | `account_id/database_id` |
| `cloudflare_pages_project` | `account_id/project_name` |

Use explicit import blocks or the project's import workflow, then review a plan for unexpected replacements. Resource-type migration is not necessarily supported by `terraform state mv`; follow the provider's migration guide.

Export IDs for dependent modules, and keep secret outputs sensitive. Cloudflare IP-range data identifies published HTTP proxy address ranges; it does not authorize all traffic from those ranges or replace authenticated origin access.

[Versioned data sources](https://registry.terraform.io/providers/cloudflare/cloudflare/5.24.0/docs) · [Provider upgrade guidance](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/guides/version-5-migration)
