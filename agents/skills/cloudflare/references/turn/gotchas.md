# TURN troubleshooting

- **401/403 during issuance:** distinguish account API credentials from the TURN key secret. Verify the key ID and secret belong together; never send the secret to a browser.
- **Invalid credential lifetime:** `ttl` must be a positive integer at most 172800 seconds. Use a duration that covers the expected call and renew for longer sessions. Expiry does not prove an existing allocation ended immediately.
- **TLS fallback disappeared:** filtering `":53"` also matches `":5349"`. Match `/:53(?:\?|$)/` instead and preserve the remaining returned URLs.
- **Browser receives undefined username:** the application contract is `{ iceServers: [...] }`, not top-level `username`/`credential`.
- **Intermittent ICE failures:** check signaling completeness, candidate exchange, time synchronization, transport restrictions, and stale credentials. Avoid immediate restarts for brief disconnects.
- **Revocation appears ineffective:** use the username in the revoke URL, check for HTTP 204, and test allocation behavior. Do not interpret deleting a cache entry as service-side revocation.
- **Unexpected usage:** authorize and rate-limit the issuance endpoint, use per-session credentials, and record non-sensitive request/usage identifiers. A secret server endpoint with public unauthenticated issuance is still abusable.
- **Local cache misses or duplicates:** isolate memory is neither durable nor shared; handle distributed issuance deliberately.

Review [credential semantics](https://developers.cloudflare.com/realtime/turn/faq/) and [current service limits](https://developers.cloudflare.com/realtime/turn/) before interpreting failures as browser bugs.
