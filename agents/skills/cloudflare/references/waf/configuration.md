# WAF configuration

Create an API token restricted to the required zone and the permissions listed by the specific Rulesets operation. Load it from a secret store or environment, and discover existing phase entrypoints before making changes. Do not expose an unauthenticated Worker endpoint that forwards account-management API requests.

## Terraform provider v5

Use the repository's provider lock and current schema; v5 uses lists/objects rather than v4 nested rule blocks. Import an existing phase ruleset before managing it. This resource owns the whole rule list.

```hcl
resource "cloudflare_ruleset" "waf_custom" {
  zone_id = var.zone_id
  name    = "Admin protection"
  kind    = "zone"
  phase   = "http_request_firewall_custom"
  rules = [{
    action      = "managed_challenge"
    expression  = "starts_with(http.request.uri.path, \"/admin/\")"
    description = "Challenge the protected admin area"
    enabled     = true
  }]
}
```

For rate limiting use `ratelimit = { ... }` inside the rule object; for managed rules use `action = "execute"` and `action_parameters = { id = managed_ruleset_id }`. See the validated provider examples in [terraform](../terraform/).

Pulumi uses its installed provider's typed `Ruleset` inputs. Supply `name`, `kind`, `phase`, and `zoneId`, and use `ratelimit` directly on the rule. Do not assume a copied Terraform schema is a Pulumi schema.

Review the proposed rule list and expression scope before deployment, test legitimate and unwanted requests in a test zone, and inspect Security Events afterward. Events show actual matches; they are not a standalone expression compiler or proof of all possible traffic paths.

[Ruleset resource](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/ruleset) · [WAF deployment](https://developers.cloudflare.com/waf/get-started/)
