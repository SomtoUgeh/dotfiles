---
name: bro
description: Restate the last message in plain human language, action-first. Use when the user says bro, /bro, "say that simply", "in plain English", or wants the last answer without jargon and without buried next steps.
disable-model-invocation: true
---

# bro

Restate the last assistant message so a tired human can act on it.

Two jobs, one voice:

1. **Plain** — talk like a person, not a doc site
2. **Action-first** — lead with what to do, not a lecture

No ADHD diagnosis needed. No "Great question." No "Hope this helps."

## When invoked

Do **not** re-solve the problem. Do **not** research more. Rewrite only.

Source material: the **previous assistant message** in this conversation (and only enough user context to keep meaning).

## Output shape

```
[One line: the next thing to do, or the answer if there is no action]

[Optional: short plain-English why — 1–3 sentences max]

[If multi-step:]
1. ...
2. ...
3. ...

Next: [one concrete thing under ~2 minutes]
```

If the last message was already a finished answer with nothing left to do, drop the steps and the `Next:` line. Just say the thing simply.

## Rules

### 1. Lead with the point

First line is the action or the answer. Not setup. Not "so basically."

Bad: "Looking at what I said earlier, there are a few moving pieces around auth…"  
Good: "Update the token check in `src/auth.ts`, then rerun the auth tests."

### 2. Human words only

Swap jargon for normal language. Keep real names the user needs (file paths, commands, error codes, product names).

| Instead of | Say |
| --- | --- |
| leverage / utilize | use |
| instantiate | create |
| idempotent | safe to run twice |
| orthogonal | separate / unrelated |
| surface area | how much you have to touch |
| telemetry | logs / metrics |
| refactor the abstraction | simplify this code |
| paradigm / ecosystem / pipeline | (delete or name the real thing) |

If a technical term is the actual answer (e.g. `401 Unauthorized`), keep it — then say what it means in one short clause.

### 3. Number the steps

More than one step → numbered list. One step per line. No "and then" stuffed into one bullet.

### 4. One next step at the end

If work remains, end with **one** thing they can do in under two minutes.

Bad: "Let me know if you want to dig deeper."  
Good: "Next: run `npm test` and paste the first failing line."

### 5. Cut tangents

One topic only. Side issues become one line at most:

"Separately: X is also off. Want that after?"

### 6. Restate where we are

If the last message was mid-task, open or close with progress in plain words:

"Step 3 of 5 done: schema updated. Next: backfill the column."

### 7. Specific time, if you mention time

Not "a bit." Say "about 10 minutes" or "maybe an afternoon if tests are missing."

### 8. Wins in the open

If something already works, say it straight:

"Login with magic links works. Try: `npm run dev`, open `/login`."

### 9. Errors, no drama

Cause → fix. No "uh oh."

"Test fails at `auth.spec.ts:42`: expected 200, got 401. Missing auth header. Add `Authorization: Bearer ${token}`."

### 10. Cap lists at 5

More than five → split into **do now** vs **later**, or rank top five.

### 11. No fluff

Forbidden openers: "Great question," "Sure!," "Let me…," "So basically," "In other words," "To put it simply," "Looking at…"

Forbidden closers: "Hope this helps," "Let me know," "Happy to clarify," "Feel free to ask."

Forbidden filler: "essentially," "basically," "interesting," "robust," "seamless," "just," "simply" as padding.

Start with the answer. Stop when the answer is done.

## Length

Default: **half the length** of the last message, or less. Prefer short sentences. Prefer "you" and "we" over passive voice.

## When not to oversimplify

- Destructive steps (`rm -rf`, force push, drop table, prod migrate): keep the warning; still plain words; confirm before acting if this skill is shaping live work.
- User asked for a full explain/walkthrough: plain language, still no fluff, use short headers so they can skim.
- Last three turns were "still broken": do not invent a new fix in the restatement. Name the stuck assumption in plain words and one check to run.

## Pre-send check

Before sending, delete:

1. Any first sentence that only announces a rewrite ("Here's a simpler version…")
2. Any last sentence that offers more help
3. Any "by the way" sidebar
4. Hedge words that add nothing ("perhaps," "might want to consider")

Then verify: if they only read the **first line** and the **last line**, do they know (a) what to do next, and (b) what the point was?

If yes, send.

## Examples

### Coding answer → bro

**Last message (dense):**  
Great question! Your auth flow has a few moving pieces… `verifyToken` seems to use an older jsonwebtoken API… you might also want to look at dependency versions overall. Hope this helps!

**bro:**

```
Run `npm install jsonwebtoken@latest`, then fix `verifyToken` in `src/auth.ts`.

1. Open `src/auth.ts`
2. Replace `verifyToken` (lines 42–58) with the new version
3. Run `npm test -- auth.spec.ts`

Next: paste the first failing line if a test breaks.
```

### Concept answer → bro

**Last message (dense):**  
Idempotency means the operation can be applied multiple times without changing the result beyond the initial application; in distributed systems this is critical for at-least-once delivery…

**bro:**

```
Idempotent means safe to run twice — second run doesn't mess things up.

Use it when a request might be retried (network blip, double-click, queue redelivery).

Next: if you want, point me at one endpoint and I'll say whether it already is.
```

### Already simple → bro

**Last message:**  
`git status` then commit.

**bro:**

```
Run `git status`, then commit.
```

Do not pad a short answer to look like a skill ran.
