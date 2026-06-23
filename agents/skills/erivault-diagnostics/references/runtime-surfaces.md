# Runtime Surfaces

Use this to map an Erivault bug to the right owner and proof.

## Contents

- Ownership map
- Common runtime paths
- Proof matrix
- Questions to answer

## Ownership Map

| Surface | Owns | Does Not Own |
|---------|------|--------------|
| Web app product/domain | product commands, DB writes, read models, audit, user-visible state | raw byte custody or AI opinion |
| Assets worker | private bytes, R2 custody, upload/download signing, metadata, derivatives | product verdicts or report inclusion |
| Capture worker | live handoff, QR/manual claim, socket state, upload session progress | durable evidence truth |
| Agent orchestration | prompts, model calls, response parsing, structured AI opinion | product rows or final product policy |
| Neon Postgres | durable product state and migrations | private object bytes |
| Cloudflare queues/workflows | retry, latency, failure isolation, async orchestration | hidden product state without write-back |
| Browser/mobile | user interaction, cache, local recovery state, media capture | durable truth after server acceptance |

## Common Runtime Paths

### Authenticated Inspection Edit

```text
UI -> TanStack Query/server function or RPC -> domain command -> Postgres -> read model -> UI
```

Proof should include the command/read model or DB row, not only the UI.

### Guest Or Mobile Capture Handoff

```text
desktop creates handoff
-> guest or mobile claims handoff
-> camera and IndexedDB queue
-> upload intent
-> R2 original
-> pending upload row
-> verification and review path
-> evidence row or terminal failure
-> draft read model and preview
```

Proof should show local recovery state reconciles with durable product evidence.

### Evidence AI Review

```text
evidence or pending upload
-> review request queue
-> agent orchestration
-> AI Gateway/model
-> structured review result
-> product write-back
-> review flags and UI status
```

Proof should include the model response category and product write-back status.

### Media Transformation

```text
original private asset
-> deterministic media prep or derivative
-> review units or playback derivative
-> R2 output and metadata
-> product status or review result
```

Proof should include duration, frame count or derivative metadata, and whether fallback processing happened.

## Proof Matrix

| Symptom | First Proof | Second Proof |
|---------|-------------|--------------|
| UI stale until refresh | query key, invalidation, polling, browser network | DB/read model state at the same time |
| duplicate mobile cards | IndexedDB record and product evidence IDs | queue view reconciliation logic |
| upload says failed but evidence exists | pending upload row, evidence row, audit | worker logs and terminal failure reason |
| AI review missing | review request/result rows or queue logs | AI Gateway log and product write-back |
| video preview broken | asset metadata and content type | transform logs, derivative object, browser media request |
| DO socket error | request ID and DO logs | fallback read model or recovery behavior |
| deploy mismatch | worker script version and commit | GitHub branch and Alchemy deploy output |

## Questions To Answer

1. Which product object is affected?
2. Which surface currently owns the visible state?
3. Which durable row should explain the outcome?
4. Which ID connects UI, DB, worker, object storage, and logs?
5. Is this a current failure, stale legacy data, or a deploy transition?
6. What should happen after refresh, reconnect, retry, or worker reset?
7. What user-visible terminal state exists if the background path fails?
