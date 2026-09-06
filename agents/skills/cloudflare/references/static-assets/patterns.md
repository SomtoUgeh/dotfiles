### Common Patterns

**1. Forward request to assets:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    return env.ASSETS.fetch(request);
  }
};
```

**2. Fetch specific asset by path:**

```typescript
const response = await env.ASSETS.fetch("https://assets.local/logo.png");
```

**3. Modify request before fetching asset:**

```typescript
const url = new URL(request.url);
url.pathname = "/index.html";
return env.ASSETS.fetch(new Request(url, request), { redirect: 'follow' });
```

**4. Transform asset response:**

```typescript
const response = await env.ASSETS.fetch(request);
const modifiedResponse = new Response(response.body, response);
modifiedResponse.headers.set("X-Custom-Header", "value");
modifiedResponse.headers.set("Cache-Control", "public, max-age=3600");
return modifiedResponse;
```

**5. Conditional asset serving:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/') {
      return env.ASSETS.fetch(new URL('/index.html', request.url));
    }
    return env.ASSETS.fetch(request);
  }
};
```

**6. SPA with API routes:**

Most common full-stack pattern - static SPA with backend API:

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname.startsWith('/api/')) {
      return handleAPI(request, env);
    }
    return env.ASSETS.fetch(request);
  }
};

async function handleAPI(request: Request, env: Env): Promise<Response> {
  return new Response(JSON.stringify({ status: 'ok' }), {
    headers: { 'Content-Type': 'application/json' }
  });
}
```

**Config:** Set `run_worker_first: ["/api/*"]` (see configuration.md:66-106)

**7. Auth gating for protected assets:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === '/admin' || url.pathname.startsWith('/admin/')) {
      const session = await validateSession(request, env);
      if (!session) {
        return Response.redirect(new URL('/login', request.url).href, 302);
      }
    }
    return env.ASSETS.fetch(request);
  }
};
```

**Config:** Set `run_worker_first: ["/admin", "/admin/*"]`. Cover every protected asset and its HTML aliases; do not exclude private files from authentication. Test direct asset URLs and navigation requests.

**8. Custom headers for security:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const response = await env.ASSETS.fetch(request);
    const secureResponse = new Response(response.body, response);
    secureResponse.headers.set('X-Frame-Options', 'DENY');
    secureResponse.headers.set('X-Content-Type-Options', 'nosniff');
    secureResponse.headers.set('Content-Security-Policy', "default-src 'self'");
    return secureResponse;
  }
};
```

**9. A/B testing via cookies:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const cookies = request.headers.get('Cookie') || '';
    const variant = cookies.split(';').some(cookie => cookie.trim() === 'variant=b') ? 'b' : 'a';
    const url = new URL(request.url);
    if (url.pathname === '/') {
      const response = await env.ASSETS.fetch(new URL(`/index-${variant}.html`, request.url));
      const varied = new Response(response.body, response);
      varied.headers.set('Cache-Control', 'private, no-store');
      return varied;
    }
    return env.ASSETS.fetch(request);
  }
};
```

**10. Locale-based routing:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const preferred = request.headers.get('Accept-Language')?.split(',')[0]?.split('-')[0]?.toLowerCase();
    const locale = preferred === 'fr' || preferred === 'es' ? preferred : 'en';
    const url = new URL(request.url);
    if (url.pathname === '/') {
      return env.ASSETS.fetch(new URL(`/${locale}/index.html`, request.url));
    }
    if (!url.pathname.startsWith(`/${locale}/`)) {
      url.pathname = `/${locale}${url.pathname}`;
    }
    return env.ASSETS.fetch(url);
  }
};
```

**11. OAuth callback handling:**

Route `/auth/*` to the existing authentication library with `run_worker_first`. The library must validate state against the initiating browser session, enforce PKCE where applicable, validate callback/provider errors, and set the session cookie with `Path=/`, `HttpOnly`, `Secure`, and the chosen SameSite policy. Do not implement a callback that accepts any `code` without verifying the login transaction.

**12. Cache control override:**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const response = await env.ASSETS.fetch(request);
    const url = new URL(request.url);
    // Immutable assets (hashed filenames)
    if (response.ok && /\.[a-f0-9]{8,}\.(js|css|png|jpg)$/.test(url.pathname)) {
      const headers = new Headers(response.headers);
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers
      });
    }
    return response;
  }
};
```

Worker response transforms only apply when the Worker is invoked. Use `_headers` for static headers without Worker execution; configure `run_worker_first` for cookie/locale routing and test every route variant.
