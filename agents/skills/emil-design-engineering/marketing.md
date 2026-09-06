# Marketing Pages

Guidelines specific to marketing sites, landing pages, blogs, docs, and changelogs.

## Animations on Marketing Pages

Marketing pages can use more elaborate animations than product UI, but still with restraint.

### What to Avoid

**No scroll animations:** Don't add scroll animations like fade-ups, fade-ins, translate-Y on scroll.

**No disconnected motion:** Don't add animations or interactions that feel disconnected from user movement:
- Scroll hijacking
- Parallax that doesn't map 1:1 to scroll
- Auto-advancing carousels

### Intro Animations

Disable intro animations if they've been seen during the current session:

```jsx
useEffect(() => {
  const hasSeenIntro = sessionStorage.getItem('hasSeenIntro');
  if (hasSeenIntro) {
    setSkipIntro(true);
  } else {
    sessionStorage.setItem('hasSeenIntro', 'true');
  }
}, []);
```

Use `sessionStorage` (not `localStorage`) so animations play again on new sessions.

## Performance

### Font Preloading

Preload only critical fonts to improve discovery; verify fallback metrics and font-display separately for layout shift:

```jsx
import { preload } from 'react-dom';

// In your app initialization
preload('/fonts/inter-var.woff2', { as: 'font', type: 'font/woff2', crossOrigin: 'anonymous' });
```

### Image Preloading

Preload above-the-fold images:

```html
<link rel="preload" as="image" href="/hero-image.webp" />
```

### Static Generation

Use static generation/revalidation for public content when its freshness requirements permit it. Personalized or real-time content may require request-time work. This App Router example applies to compatible Next.js configurations; check whether Cache Components is enabled before using route-segment revalidate:

```jsx
// Next.js example
export async function generateStaticParams() {
  const posts = await getPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

export const revalidate = 3600; // Revalidate every hour
```

## Header Navigation

Keep header submenu content available to keyboard and touch users. A closed submenu must not remain focusable; synchronize hidden state and aria-expanded through the installed menu primitive. aria-hidden alone does not hide content visually or remove tab stops:

```html
<!-- Content exists in DOM, just visually hidden -->
<nav>
  <button type="button" aria-expanded="false" aria-controls="products-submenu">Products</button>
  <div id="products-submenu" class="submenu" hidden>
    <!-- Full content here, not dynamically loaded -->
  </div>
</nav>
```

## Call-to-Action Buttons

Ensure buttons have different CTAs based on whether a user is logged in:

| State | CTA |
| --- | --- |
| Logged out | "Get Started" or "Sign Up" |
| Logged in | "Go to Dashboard" or "Open App" |

```jsx
<Button href={isLoggedIn ? '/dashboard' : '/signup'}>
  {isLoggedIn ? 'Go to Dashboard' : 'Get Started'}
</Button>
```

## Documentation Sites

### Code Snippets

Provide a copy-to-clipboard button on all docs code snippets:

```jsx
<CodeBlock
  code={snippet}
  copyButton={true}
/>
```

### Markdown Export

Ensure all docs pages are copyable as markdown files:
- Have a "Copy as Markdown" button
- Support `.md` extension in URLs (e.g., `/docs/getting-started.md` returns markdown)

### Visual Examples

Ensure docs pages have many visual examples. Code alone isn't enough—show what the code produces.

## Blog & Changelog

### RSS Feed

Ensure RSS feed exists for blog and changelog:

```
/blog/rss.xml
/changelog/rss.xml
```

### Text Wrapping

Use `text-wrap: balance` on headings:

```css
article h1, article h2 {
  text-wrap: balance;
}
```

## Illustrations

Illustrations built in code should have:
- Proper `aria-label` attribute for accessibility
- Disabled text selection
- Disabled pointer events (if decorative)

```jsx
<div
  role="img"
  aria-label="Illustration showing data flow"
  className="illustration"
  style={{
    userSelect: 'none',
    pointerEvents: 'none',
  }}
/>
```
