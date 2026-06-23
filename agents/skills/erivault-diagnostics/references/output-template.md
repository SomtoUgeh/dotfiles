# Output Template

Use this when reporting an Erivault diagnostic result.

## Investigation Report

```markdown
**Finding**
[Direct answer in one or two sentences.]

**Surface Map**
- Environment:
- User-visible surface:
- Product owner:
- Runtime services:
- Durable IDs:

**Evidence**
- Browser/mobile:
- DB/read model:
- Cloudflare:
- R2/media:
- AI/worker:
- Repo/tests:
- Not verified:

**Why It Happened**
[Explain the state transition or missing transition. Separate fact from inference.]

**Fix**
[Smallest complete product or diagnostic change.]

**Verification**
- Commands:
- Live proof:
- Remaining gap:
```

## Test And Diagnostic Plan

```markdown
**Behavior**
[Product behavior in user terms.]

**Risk**
[Data loss, privacy, stale state, bad decision, failed upload, etc.]

**Test Plan**
- Unit or mapper:
- Domain or DB:
- API contract:
- Worker or queue:
- Browser/mobile:
- Live smoke:

**Diagnostics To Add**
- Correlation IDs:
- Product statuses:
- Logs:
- Metrics:
- Admin or DB query:

**Acceptance**
- [Observable proof that the behavior works.]
- [Observable proof that failure is understandable.]
```

Keep concise for chat. Use the full template for handoff documents, PR descriptions, or incident notes.
