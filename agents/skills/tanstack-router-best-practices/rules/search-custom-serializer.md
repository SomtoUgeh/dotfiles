# search-custom-serializer: Configure Custom Search Param Serializers

## Priority: LOW

## Explanation

Use Router's top-level `parseSearch` and `stringifySearch` options. The
`search` option does not contain `parse`/`serialize`. Preserve the default
JSON format unless the application needs another format. Test round trips,
Unicode, empty strings, nested data, and malformed URLs against its schema.

## Good Example: Default JSON or JSURL2 Values

The helpers preserve the leading `?`, escaping, and top-level parameter names.

```tsx
import { createRouter, parseSearchWith, stringifySearchWith } from '@tanstack/react-router'
import { parse, stringify } from 'jsurl2'

const router = createRouter({
  routeTree,
  parseSearch: parseSearchWith(parse),
  stringifySearch: stringifySearchWith(stringify),
})
```

For the default JSON representation use `parseSearchWith(JSON.parse)` and
`stringifySearchWith(JSON.stringify)`, or omit both options.

## Good Example: Flat query-string Parameters

```tsx
import { createRouter } from '@tanstack/react-router'
import queryString from 'query-string'

const router = createRouter({
  routeTree,
  stringifySearch: (search) => {
    const encoded = queryString.stringify(search, {
      arrayFormat: 'bracket',
      skipNull: true,
    })
    return encoded ? '?' + encoded : ''
  },
  parseSearch: (search) => queryString.parse(search, {
    arrayFormat: 'bracket',
    parseBooleans: true,
    parseNumbers: true,
  }),
})
```

This format is for flat values and arrays, not nested objects. Number/boolean
coercion intentionally changes strings such as `"001"` and `"true"`; enable
it only when it matches the route schema. `skipNull` intentionally drops nulls.

## Good Example: Nested qs Parameters

```tsx
import { createRouter } from '@tanstack/react-router'
import qs from 'qs'

const router = createRouter({
  routeTree,
  stringifySearch: (search) => qs.stringify(search, {
    addQueryPrefix: true,
    arrayFormat: 'brackets',
  }),
  parseSearch: (search) => qs.parse(search, {
    ignoreQueryPrefix: true,
    depth: 5,
    parameterLimit: 100,
  }),
})
```

`qs` returns strings for primitive values. Coerce and validate them in
`validateSearch`; do not use a decoder that skips percent decoding.

## Context

- Keep `validateSearch` on each consuming route; serialization is not validation.
- `stringifySearch` returns either an empty string or a string beginning with `?`.
- Base64 is not encryption and generally increases JSON length. If a protocol
  requires it, use the official Unicode-safe encoding example and test collisions.
- A custom hybrid format needs an explicit schema for every scalar and nested
  value. Prefer the built-in JSON format when both ends belong to this app.

Reference: [Official serialization guide](https://tanstack.com/router/latest/docs/guide/custom-search-param-serialization)
