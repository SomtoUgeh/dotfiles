# CNI Patterns

See [README.md](README.md) for overview.

## High Availability

**Critical:** Design for resilience from day one.

**Requirements:**
- Device-level diversity (separate hardware)
- Backup Internet connectivity (no SLA on CNI)
- Network-resilient locations preferred
- Regular failover testing

**Architecture:**
```
Your Network A ──10G CNI v2──> CF CCR Device 1
                                     │
Your Network B ──10G CNI v2──> CF CCR Device 2
                                     │
                            CF Global Network (AS13335)
```

**Capacity Planning:**
- Plan across all links
- Account for failover scenarios
- Your responsibility

## Pattern: Magic Transit + CNI v2

**Use Case:** DDoS protection, private connectivity, no GRE overhead.

Follow [api.md](api.md) to create the approved physical or GCP interconnect, retrieve its connection identifier, and poll status with a bounded timeout. Configure routes only after the account-team provisioning steps and health checks are complete.

**Benefits:** 1500 MTU both ways, simplified routing.

## Pattern: Multi-Cloud Hybrid

**Use Case:** AWS/GCP workloads with Cloudflare.

**AWS Direct Connect:**
```typescript
// 1. Order Direct Connect in AWS Console
// 2. Get LOA + VLAN from AWS
// 3. Send to CF account team (no API)
// 4. Configure static routes in Magic WAN

await configureStaticRoutes(id, {
  prefix: '10.0.0.0/8',
  nexthop: 'aws-direct-connect',
});
```

**GCP Cloud Interconnect:**
```
1. Get VLAN attachment pairing key from GCP Console
2. Create via Dashboard: Interconnects → Create → Cloud Interconnect → Google
   - Enter pairing key, name, MTU, speed
3. Configure static routes in Magic WAN (BGP routes from GCP ignored)
4. Configure custom learned routes in GCP Cloud Router
```

**Note:** Current CNI APIs support GCP pairing-key creation. Check [api.md](api.md); cloud-side ordering and activation still have their own workflow.

## Pattern: Multi-Location HA

**Use Case:** Improve availability through device and location diversity; the design alone does not guarantee an uptime percentage.

Choose three independently provisioned interconnects: primary and secondary on distinct devices, then a third in another geography. Retrieve real slot IDs; do not invent facility/name fields in API create requests. Assign BGP local preferences according to the failover policy (for example 200/150/100), and retain an Internet fallback. See [api.md](api.md) for the current request schema.

## Pattern: Partner Interconnect (Equinix)

**Use Case:** Quick deployment, no colocation.

**Setup:**
1. Order virtual circuit in Equinix Fabric Portal
2. Select Cloudflare as destination
3. Choose facility
4. Send details to CF account team
5. CF accepts in portal
6. Configure BGP

**No API automation** – partner portals managed separately.

## Failover & Security

**Failover Best Practices:**
- Use BGP local preferences for priority
- Configure BFD for fast detection (v1)
- Test regularly with traffic shift
- Document runbooks

**Security:**
- BGP route/session controls; the current CNI API explicitly does not treat its MD5 key as a security boundary
- BGP route filtering
- Monitor unexpected routes
- Magic Firewall for DDoS/threats
- Minimum API token permissions
- Rotate credentials periodically

## Decision Matrix

| Requirement | Recommended |
|-------------|-------------|
| Collocated with CF | Direct |
| Not collocated | Partner |
| AWS/GCP workloads | Cloud |
| 1500 MTU both ways | v2 |
| VLAN tagging | v1 |
| Public peering | v1 |
| Simplest config | v2 |
| BFD fast failover | v1 |
| LACP bundling | v1 |

## Resources

- [Magic Transit Docs](https://developers.cloudflare.com/magic-transit/)
- [Magic WAN Docs](https://developers.cloudflare.com/magic-wan/)
- [Argo Smart Routing](https://developers.cloudflare.com/argo/)
