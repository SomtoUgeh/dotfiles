# Bot Management Patterns

## E-commerce Protection

```txt
# High security for checkout
(cf.bot_management.score lt 50 and http.request.uri.path in {"/checkout" "/cart/add"} and not cf.bot_management.verified_bot and not cf.bot_management.corporate_proxy)
Action: Managed Challenge
```

## API Protection

```txt
# API clients may not execute JavaScript. Use score plus normal API authentication.
(starts_with(http.request.uri.path, "/api/") and cf.bot_management.score gt 0 and cf.bot_management.score lt 30 and not cf.bot_management.verified_bot)
Action: Block (only after evaluating false positives for the supported clients)
```

## SEO-Friendly Bot Handling

```txt
# Allow search engine crawlers
(cf.bot_management.score lt 30 and not cf.verified_bot_category in {"Search Engine Crawler"})
Action: Managed Challenge
```

## Block AI Scrapers

```txt
# Block training crawlers only (allow AI assistants/search)
(cf.verified_bot_category eq "AI Crawler")
Action: Block

# Block all AI-related bots (training + assistants + search)
(cf.verified_bot_category in {"AI Crawler" "AI Assistant" "AI Search"})
Action: Block

# Allow AI Search, block AI Crawler and AI Assistant
(cf.verified_bot_category in {"AI Crawler" "AI Assistant"})
Action: Block

# Or use dashboard: Security > Settings > Bot Management > Block AI Bots
```

## Rate Limiting by Bot Score

```txt
# Stricter limits for suspicious traffic
(cf.bot_management.score lt 50)
Rate: 10 requests per 10 seconds

(cf.bot_management.score geq 50)
Rate: 100 requests per 10 seconds
```

## Mobile clients

Authenticate mobile clients using verified credentials or a trusted attestation design. JA3/JA4 fingerprints are shared and reproducible; never skip all security rules based on a fingerprint. Use them only as one risk signal.

## Datacenter Detection

```typescript
import type { IncomingRequestCfProperties } from '@cloudflare/workers-types';

// A low score indicates automated-traffic risk; it does not identify a datacenter.
export default {
  async fetch(request: Request<unknown, IncomingRequestCfProperties>): Promise<Response> {
    const cf = request.cf;
    const botMgmt = cf?.botManagement;

    if (botMgmt?.score && botMgmt.score < 30 &&
        !botMgmt.corporateProxy && !botMgmt.verifiedBot) {
      return new Response('Traffic blocked by bot policy', { status: 403 });
    }

    return fetch(request);
  }
};
```

## Conditional Delay (Tarpit)

```typescript
import type { IncomingRequestCfProperties } from '@cloudflare/workers-types';

// Add delay proportional to bot suspicion
export default {
  async fetch(request: Request<unknown, IncomingRequestCfProperties>): Promise<Response> {
    const cf = request.cf;
    const botMgmt = cf?.botManagement;

    if (botMgmt?.score && botMgmt.score < 50 && !botMgmt.verifiedBot) {
      // Delay: 0-2 seconds for scores 50-0
      const delayMs = Math.max(0, (50 - botMgmt.score) * 40);
      await new Promise(r => setTimeout(r, delayMs));
    }

    return fetch(request);
  }
};
```

## Layered Defense

```txt
1. Bot Management (score-based)
2. JavaScript Detections (for JS-capable clients)
3. Rate Limiting (fallback protection)
4. WAF Managed Rules (OWASP, etc.)
```

## Progressive Enhancement

```txt
Public content: High threshold (score < 10)
Authenticated: Medium threshold (score < 30)
Sensitive: Low threshold (score < 50) + JSD
```

## Zero Trust for Bots

```txt
1. Choose score thresholds from observed traffic and the application policy
2. Exempt verified bots only where that policy permits
3. Authenticate mobile apps (fingerprints alone cannot authorize)
4. Evaluate narrowly scoped corporate-proxy exceptions for legitimate clients
5. Exempt static resources only where the content and abuse policy permit
```

## JavaScript detection scope

Apply JSD only to browser flows after an initial HTML visit. Native clients, API tools, first visits, and missing metadata must not be treated as failed authentication. Use Managed Challenge through WAF for eligible browser flows; use credential validation and rate limits for APIs.

## Rate Limiting by JWT Claim + Bot Score

```txt
# Enterprise: Combine bot score with JWT validation
Rate limiting > Custom rules
- Field: lookup_json_string(http.request.jwt.claims["{config_id}"][0], "sub")
- Matches: user ID claim
- Additional condition: cf.bot_management.score lt 50
```

## WAF Integration Points

- **WAF Custom Rules**: Primary enforcement mechanism
- **Rate Limiting Rules**: Bot score as dimension, stricter limits for low scores
- **Transform Rules**: Pass score to origin via custom header
- **Workers**: Programmatic bot logic, custom scoring algorithms
- **Page Rules / Configuration Rules**: Zone-level overrides, path-specific settings

## See Also

- [gotchas.md](./gotchas.md) - Common errors, false positives/negatives, limitations

Metadata source: [Bot Management variables](https://developers.cloudflare.com/bots/reference/bot-management-variables/). Bot classification, verified-bot status, and corporate-proxy status do not grant application authorization.
