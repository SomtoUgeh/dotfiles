---
title: Hoist Static I/O to Module Level
impact: HIGH
impactDescription: avoids repeated file/network I/O per request
tags: server, io, performance, next.js, route-handlers, og-image
---

## Hoist Static I/O to Module Level

Cache immutable assets per process when repeated reads are a measured cost. Node fetch does not read file URLs. Use Node file I/O in a Node route, and pass a string data URL to an image's src. Include these files in deployment tracing/bundling.

```tsx
// app/api/og/route.tsx — requires the two public assets shown below
import { ImageResponse } from 'next/og'
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
export const runtime = 'nodejs'

async function loadAssets() {
  const [font, logo] = await Promise.all([
    readFile(join(process.cwd(), 'public/fonts/Inter.ttf')),
    readFile(join(process.cwd(), 'public/images/logo.png')),
  ])
  return { font, logo: 'data:image/png;base64,' + logo.toString('base64') }
}
let assets: ReturnType<typeof loadAssets> | undefined
function getAssets() {
  return assets ??= loadAssets().catch(error => {
    assets = undefined // permit retry after a transient failure
    throw error
  })
}
export async function GET() {
  const { font, logo } = await getAssets()
  return new ImageResponse(
    <div style={{ display: 'flex', fontFamily: 'Inter' }}>
      <img src={logo} width={64} height={64} alt="" />Hello World
    </div>,
    { fonts: [{ name: 'Inter', data: font }] },
  )
}
```

The first request loads assets; warm requests reuse them. Cold starts and other instances load independently. Do not share user-specific assets this way. Runtime-editable content needs invalidation; large files need a memory budget. Adapt paths to the framework's actual deployment layout.
