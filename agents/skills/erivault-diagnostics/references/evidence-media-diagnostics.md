# Evidence And Media Diagnostics

Use this for Erivault capture, handoff, upload, evidence, AI review, and media transformation bugs.

## Contents

- ID map
- State map
- Investigation sequence
- Media transformation checks
- Mobile and IndexedDB checks
- Fix design rules

## ID Map

Track these IDs explicitly:

| ID | Meaning |
|----|---------|
| `inspectionId` | product inspection |
| `targetId` | selected room, item, meter, or checkpoint |
| `handoffId` | live capture session correlation |
| `clientCaptureId` | mobile/browser local capture identity |
| `assetId` | durable media identity |
| `pendingUploadId` | product-side pending upload row |
| `evidenceItemId` | durable attached evidence row |
| `workflowId` | async processing instance when available |
| `requestId` | Cloudflare request correlation |

Use `assetId` for durable media identity. Use `handoffId` only for live capture correlation.

## State Map

Useful states to distinguish:
- local only
- upload prepared
- uploading
- uploaded
- asset ready
- verification queued
- processing
- attached
- needs attention
- retryable failed
- terminal failed
- discarded
- legacy or unknown

If the UI shows "pending" for legacy missing data, diagnose whether the row is truly in-flight or merely lacks historical verification metadata.

## Investigation Sequence

1. Capture the URL, target, media type, and visible status.
2. Check whether the page is guest handoff or authenticated mobile capture.
3. Inspect browser/mobile local state only if the bug involves recovery, refresh, duplicate cards, or retry.
4. Query product rows for pending uploads, evidence items, verification status, review flags, and asset IDs.
5. Check R2 object metadata and access path for the asset.
6. Check capture worker logs for upload registration, object verification, DO resets, and handoff state.
7. Check agent orchestration logs and AI Gateway for review requests and responses.
8. Check product write-back logs or rows for final status.
9. Reconcile what the UI should render from the durable read model.

## Media Transformation Checks

For video and image issues, verify:
- original object exists and is private
- content type and byte size are correct
- video duration is preserved where expected
- extracted frame count or derivative count matches policy
- fallback transformation path is logged and counted
- derivative object exists only if the path is designed to create one
- AI review used bounded model input, not public original evidence
- browser preview uses the correct signed or stable media route

Metrics should include environment, media type, status, reason, duration, frame count, fallback count, and processing time.

## Mobile And IndexedDB Checks

Mobile capture needs two truths:
- local IndexedDB for recovery before durable acceptance
- product read model after durable acceptance

The UI should not render both as separate evidence for the same `clientCaptureId`.

Check:
- queue scope includes handoff and target
- reload preserves local unsent captures
- switching photo/video does not remount in a way that loses queue state
- stopping and starting camera does not delete queued media
- attached product evidence suppresses duplicate local cards without deleting recovery bytes
- polling or query invalidation updates status without requiring manual refresh

## Fix Design Rules

- Keep Product Evidence as the durable owner of evidence rows, verification status, review flags, audit, and report behavior.
- Keep Assets as byte custody and derivative owner.
- Keep Capture as live coordination and progress, not durable evidence truth.
- Keep Agent Orchestration as AI opinion, not product policy.
- Preserve private media boundaries.
- Add a terminal product state for failures users must see.
- Add tests at the boundary that owns the state transition.
