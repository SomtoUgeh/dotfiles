# Cloudflare Operations

Use this when Erivault diagnostics involve Cloudflare Workers, local worker logs, deployed tail logs, queues, Durable Objects, workflows, R2, AI Gateway, or media transforms.

## Contents

- Environment routing
- Tail worker logs
- Queues
- Durable Objects
- Workflows
- R2 and media transformation
- AI Gateway
- Evidence checklist

## Environment Routing

Do not assume the hostname tells the full story. Confirm:
- requested URL
- worker script name
- Cloudflare stage or Alchemy stage
- deploy commit or script version
- request ID and timestamp
- whether the path is local, dev, or production

| Environment | Where To Look First | What To Prove |
|-------------|---------------------|---------------|
| local | app terminal, worker dev terminal, local DB, browser network | code path, request shape, local state, errors before deployment |
| dev | Cloudflare tail logs, dev worker dashboards, dev queues/workflows/R2, dev database | deployed behavior before production |
| prod | production tail logs, dashboards, prod queues/workflows/R2, prod database | real user impact, current state, rollback or hotfix need |

Read repo deploy and dev scripts before running commands. Alchemy is the live topology authority.

## Tail Worker Logs

Tail logs are for correlation and timing. They are not the final product truth.

For deployed environments:
- tail the worker that actually handles the route, not the worker you expected
- capture request ID, timestamp, worker name, script version, path, status, and error message
- filter by safe IDs when possible: request ID, handoff ID, asset ID, evidence ID, workflow ID, target ID
- watch all involved workers when a flow crosses services, such as web app, capture, assets, and agent orchestration

For local:
- use the running dev server and worker terminal output
- keep the terminal session alive while reproducing
- compare local logs with browser network and local DB rows
- do not use deployed tail logs to explain a local-only issue

Good log evidence includes:
```text
time, environment, worker, requestId, path, productId, correlationId, status, reason, durationMs
```

Bad log evidence:
- unstructured text with no correlation ID
- raw secrets or private media data
- a provider response with no product write-back check

## Queues

For queue-related bugs, answer:
1. Which queue received the message?
2. What message type or schema version was used?
3. Was the message consumed, retried, dead-lettered, or dropped?
4. Which product row was updated after consumption?
5. What terminal state did the user see if the queue failed?

Evidence to gather:
- enqueue log with correlation ID
- consumer log with message ID or batch ID
- retry or failure reason
- product row after consumer completion
- queue dashboard count if available

Do not add queues for architecture theatre. A queue should cross a real latency, retry, ownership, or durability boundary.

## Durable Objects

Durable Objects are often live coordination, especially for capture handoff or websocket state.

Check:
- DO namespace and stage
- object ID or handoff ID used to route
- request path and request ID
- websocket connect, message, close, and reset events
- "code was updated" resets during deploys
- fallback behavior when DO state is unavailable

DO state should not be the only durable explanation for product evidence. If a DO reset makes the UI wrong after product state exists, inspect read-model reconciliation.

## Workflows

For Cloudflare Workflows:
- identify workflow name and instance ID
- inspect current status: queued, running, waiting, completed, failed, cancelled
- inspect step output and error reason
- compare workflow timestamps with queue logs and product rows
- confirm whether the workflow is actually wired into the current path

A workflow instance that ran quickly but did not touch product state may be obsolete, miswired, or only a helper. Verify usage from code before assuming it is active.

## R2 And Media Transformation

For assets and media transforms, verify:
- original object exists
- bucket and object key belong to the expected environment
- content type, byte size, checksum, and visibility are correct
- transformation input is private and bounded
- output derivative exists only when the path is designed to create one
- frame count, normalized frame count, duration, and fallback reason are logged
- product state reflects success, needs attention, or failure

Media transform log shape should include:
```text
environment, assetId, evidenceItemId or pendingUploadId, mediaType, status, reason, durationMs, frameCount, createdFrameCount, failedFrameCount, normalizedFrameCount, transformDurationMs
```

For local, inspect local worker logs and any local object/resource bindings. For dev and prod, use Cloudflare logs plus R2 dashboard or worker-mediated metadata reads.

## AI Gateway

AI Gateway evidence should answer:
- which request was sent
- which model or provider handled it
- whether the gateway returned a response, refusal, moderation, or error
- the safe structured response category
- the product write-back outcome

Collect:
- gateway request ID
- worker request ID
- evidence or asset correlation ID
- status code and provider/model
- structured review output if safe to show
- product verification status and review flags after write-back

Do not paste raw private media, full prompts with private data, or raw provider payloads containing user data. Summarize safe fields and store private details only in approved logs.

## Evidence Checklist

For Cloudflare diagnostics, close with:

```text
Environment:
Worker(s):
Request ID(s):
Queue message or workflow ID:
DO or handoff ID:
Asset or R2 object:
AI Gateway ID:
DB/product row:
User-visible result:
Not verified:
```
