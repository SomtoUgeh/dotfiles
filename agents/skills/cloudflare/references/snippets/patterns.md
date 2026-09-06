# Snippets Patterns

## Security Headers

```javascript
export default {
  async fetch(request) {
    const response = await fetch(request);
    const newResponse = new Response(response.body, response);
    newResponse.headers.set("X-Frame-Options", "DENY");
    newResponse.headers.set("X-Content-Type-Options", "nosniff");
    newResponse.headers.delete("X-Powered-By");
    return newResponse;
  }
}
```

**Rule:** `true` (all requests)

## Geo-Based Routing

```javascript
export default {
  async fetch(request) {
    const country = request.cf.country;
    if (["GB", "DE", "FR"].includes(country)) {
      const url = new URL(request.url);
      if (url.hostname !== "www.example.com") return fetch(request);
      url.hostname = "www.example.eu";
      return Response.redirect(url.toString(), 302);
    }
    return fetch(request);
  }
}
```

## A/B Testing

Configure the origin/cache key to separate variants (or disable caching for the experiment). Merely adding X-Variant does not vary Cloudflare cache entries. This example assumes that cache behavior has been configured.

```javascript
export default {
  async fetch(request) {
    const cookies = request.headers.get("Cookie") || "";
    const existing = cookies.match(/(?:^|;\s*)ab_test=([AB])(?:;|$)/)?.[1];
    const variant = existing || (Math.random() < 0.5 ? "A" : "B");

    const req = new Request(request);
    req.headers.set("X-Variant", variant);
    const response = await fetch(req);

    if (!existing) {
      const newResponse = new Response(response.body, response);
      newResponse.headers.append("Set-Cookie", `ab_test=${variant}; Path=/; Secure; HttpOnly; SameSite=Lax`);
      return newResponse;
    }
    return response;
  }
}
```

## Bot Detection

```javascript
export default {
  async fetch(request) {
    const botScore = request.cf.botManagement?.score;
    if (botScore && botScore < 30) return new Response("Denied", { status: 403 });
    return fetch(request);
  }
}
```

**Requires:** Bot Management plan

## Origin Authentication

Use a Worker secret binding when you need a private origin credential. Do not hardcode a shared secret in snippet source and inject it into every public request; that grants all callers the same upstream privilege. Authenticate and authorize the caller before accessing a privileged origin.

## CORS Headers

```javascript
export default {
  async fetch(request) {
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
          "Access-Control-Allow-Headers": "Content-Type, Authorization"
        }
      });
    }
    const response = await fetch(request);
    const newResponse = new Response(response.body, response);
    newResponse.headers.set("Access-Control-Allow-Origin", "*");
    return newResponse;
  }
}
```

## Maintenance Mode

```javascript
export default {
  async fetch(request) {
    return new Response("<h1>Maintenance</h1>", {
      status: 503,
      headers: { "Content-Type": "text/html", "Retry-After": "3600" }
    });
  }
}
```

## Pattern Selection

| Pattern | Complexity | Use Case |
|---------|-----------|----------|
| Security Headers | Low | All sites |
| Geo-Routing | Low | Regional content |
| A/B Testing | Medium | Experiments |
| Bot Detection | Medium | Requires Bot Management |
| Origin authentication | Use a Worker secret | Privileged backend access |
| CORS | Low | API endpoints |
| Maintenance | Low | Deployments |

[Current Snippets availability and limits](https://developers.cloudflare.com/rules/snippets/) · [Cache example](https://developers.cloudflare.com/rules/snippets/examples/custom-cache/) · [HTMLRewriter example](https://developers.cloudflare.com/rules/snippets/examples/rewrite-site-links/)
