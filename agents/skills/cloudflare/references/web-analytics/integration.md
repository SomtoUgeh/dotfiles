# Web Analytics framework integration

Install one beacon at the application's stable document/root layout. Prefer existing framework script/head primitives over injecting a script in every route component.

| Framework | Typical location |
|---|---|
| React or Vue with Vite | Root `index.html` |
| Next.js App Router | `app/layout.tsx`, framework Script component |
| Next.js Pages Router | Persistent `pages/_app.tsx` for after-interactive Script |
| Nuxt | Root head configuration / `useHead` |
| SvelteKit | `src/app.html` |
| Astro | Shared document layout |
| Angular | `src/index.html` |
| Gatsby | Supported browser/SSR script integration |
| Docusaurus | Site configuration scripts |

Use the exact manual snippet and CSP guidance from [configuration.md](configuration.md). Do not suppress hydration warnings as a substitute for fixing duplicated or misplaced scripts.

SPA tracking is automatic: current beacon versions use the Soft Navigations API, Navigation API, or History API depending on browser support. `spa: false` disables it for manual installations; setting `spa: true` is not required. Test actual navigation behavior in the target browser, including any hash-routing requirements, instead of assuming one fallback mechanism describes every browser.

If the application requires consent before loading analytics, integrate with its existing consent manager. Load at most once after consent and apply that manager's withdrawal policy; removing a script element does not undo listeners already installed by executed JavaScript.

[SPA behavior](https://developers.cloudflare.com/web-analytics/get-started/web-analytics-spa/) · [FAQ](https://developers.cloudflare.com/web-analytics/faq/)
