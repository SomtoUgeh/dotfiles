# Bot Management Gotchas

## Common Errors

### "Bot Score = 0"

**Cause:** Bot Management didn't run (internal Cloudflare request, Worker routing to zone (Orange-to-Orange), or request handled before BM (Redirect Rules, etc.))
**Solution:** Check request flow and ensure Bot Management runs in request lifecycle

### "JavaScript Detections Not Working"

**Cause:** `js_detection.passed` always false or undefined due to: CSP headers don't allow `/cdn-cgi/challenge-platform/`, using on first page visit (needs HTML page first), ad blockers or disabled JS, JSD not enabled in dashboard, or using Block action (must use Managed Challenge)
**Solution:** Add CSP header `Content-Security-Policy: script-src 'self';` and ensure JSD is enabled with Managed Challenge action

### "False Positives (Legitimate Users Blocked)"

**Cause:** Bot detection incorrectly flagging legitimate users
**Solution:** Check Bot Analytics for affected IPs/paths, identify detection source (ML, Heuristics, etc.), create exception rule like `(cf.bot_management.score lt 30 and http.request.uri.path eq "/problematic-path")` with Action: Skip (Bot Management), or allowlist by IP/ASN/country

### "False Negatives (Bots Not Caught)"

**Cause:** Bots bypassing detection
**Solution:** Raise the blocking threshold (30 → 50), which catches more traffic and can increase false positives, enable JavaScript Detections, add JA3/JA4 fingerprinting rules, or use rate limiting as fallback

### "Verified Bot Blocked"

**Cause:** Search engine bot blocked by WAF Managed Rules (not just Bot Management)
**Solution:** Create WAF exception for specific rule ID and verify bot via reverse DNS

### "JA3/JA4 Missing"

**Cause:** Non-TLS traffic, unavailable metadata, or a flow where Bot Management did not run
**Solution:** JA3/JA4 only available for HTTPS/TLS traffic; check request routing

**JA3/JA4 Not User-Unique:** Same browser/library version = same fingerprint
- Don't use for user identification
- Use for client profiling only
- Fingerprints change with browser updates

## Bot Verification Methods

Cloudflare verifies bots via:

1. **Reverse DNS (IP validation):** Traditional method—bot IP resolves to expected domain
2. **Web Bot Auth:** Modern cryptographic verification—faster propagation

When `verifiedBot=true`, bot passed at least one method.

**Inactive verified bots:** IPs removed after 24h of no traffic.

## Detection Engine Behavior

| Engine | Score | Timing | Plan | Notes |
|--------|-------|--------|------|-------|
| Heuristics | Always 1 | Immediate | All | Known fingerprints—overrides ML |
| ML | 1-99 | Immediate | All | Majority of detections |
| Anomaly Detection | Influences | After baseline | Enterprise | Optional, baseline analysis |
| JavaScript Detections | Pass/fail | After JS | Pro+ | Headless browser detection |
| Cloudflare Service | N/A | N/A | Enterprise | Zero Trust internal source |

**Priority:** Heuristics > ML—if heuristic matches, score=1 regardless of ML.

## Limits

| Limit | Value | Notes |
|-------|-------|-------|
| Bot Score = 0 | Means not computed | Not score = 100 |
| First request JSD data | May not be available | JSD data appears on subsequent requests |
| Score accuracy | Not 100% guaranteed | False positives/negatives possible |
| JSD on first HTML page visit | Not supported | Requires subsequent page load |
| JSD requirements | JavaScript-enabled browser | Won't work with JS disabled or ad blockers |
| JSD ETag stripping | Strips ETags from HTML responses | May affect caching behavior |
| JSD CSP compatibility | Requires specific CSP | Not compatible with some CSP configurations |
| JSD meta CSP tags | Not supported | Must use HTTP headers |
| JSD WebSocket support | Not supported | WebSocket endpoints won't work with JSD |
| JSD mobile app support | Native apps won't pass | Only works in browsers |
| JA3/JA4 traffic type | HTTPS/TLS only | Not available for non-HTTPS traffic |
| JA3/JA4 Worker routing | Missing for Worker-routed traffic | Check request routing |
| JA3/JA4 uniqueness | Not unique per user | Shared by clients with same browser/library |
| JA3/JA4 stability | Can change with updates | Browser/library updates affect fingerprints |
| WAF custom rules (Free) | 5 | Varies by plan |
| WAF custom rules (Pro) | 20 | Varies by plan |
| WAF custom rules (Business) | 100 | Varies by plan |
| WAF custom rules (Enterprise) | 1,000+ | Varies by plan |
| Workers CPU time | Varies by plan | Applies to bot logic |
| Bot Analytics sampling | 1-10% adaptive | High-volume zones sampled more aggressively |
| Bot Analytics history | 30 days max | Historical data retention limit |
| CSP requirements for JSD | Must allow `/cdn-cgi/challenge-platform/` | Required for JSD to function |

### Plan restrictions

Check [current product plans](https://developers.cloudflare.com/bots/plans/) rather than fixed rule-count or retention tables.

Metadata source: [Bot Management variables](https://developers.cloudflare.com/bots/reference/bot-management-variables/). Bot classification, verified-bot status, and corporate-proxy status do not grant application authorization.
