# t3-events: T3 thread events for Aside

T3 Code (from v0.1.12, 25 Nov 2026) publishes thread milestones as MCP Events
(`io.modelcontextprotocol/events`): a turn ended, an agent waits on a person, a question was
answered, a guest asked something or was answered, a watched pull request woke a thread. Workflow
runs have their own events. Outside clients can poll, stream or take webhooks.

Aside's MCP client cannot subscribe to MCP Events, has no public address for webhooks, and its
tasks end with their turn. `t3-events` is the receiver on the Mac: it polls every signed-in T3
environment every 10 seconds and wakes the Aside task that is waiting on a thread.

## Pieces

- Script: `scripts/t3_events.mjs` (no dependencies, Node 20+). Wrapper `~/.local/bin/t3-events`.
- LaunchAgent: `com.julds.t3-events` (`scripts/install_t3_events.sh` installs both; safe to rerun).
  The poller exits when the script file changes and launchd starts the new code.
- Log: `~/Library/Logs/t3-events.log`.
- Config: `~/.config/t3-events/envs.json` (name, MCP URL, environmentId) and `tokens/<env>.json`
  (0600, never print). State: `~/.local/state/t3-events/` (`events.jsonl`, `cursors.json`,
  `watches.json`, `deliveries.jsonl`, `status.json`).
- Aside skill: `~/.aside/u/0/skills/user/t3-events/SKILL.md` tells Aside tasks to register a watch
  after launching a T3 thread and end their turn instead of blocking in `t3_thread_wait`.

## How it talks to T3

MCP protocol `2026-07-28` is stateless: no `initialize`; every request carries
`_meta["io.modelcontextprotocol/protocolVersion"]` and `clientCapabilities`, plus the
`MCP-Protocol-Version`, `Mcp-Method` and `Mcp-Name` headers. Missing any of these gives
`Required request metadata is missing` or `Mcp-Method header does not match`.

Each environment keeps only its own threads' milestones (latest 1,000, in memory), so every
environment is signed in separately. A sign-in is the normal MCP OAuth flow (dynamic client
registration, PKCE, `orchestration:read`), lasts 30 days and has no refresh.

## Commands

```sh
t3-events envs                     # sign-ins, expiry, last poll
t3-events watch <env> <threadId> --session <asideSessionId> [--note "..."] [--types a,b] [--keep]
t3-events watches | unwatch <env> <threadId>
t3-events recent [--env e] [--thread t]
t3-events wait <env> <threadId> --timeout 300   # block until an event (exit 1 on timeout)
t3-events once                     # one poll, for testing
```

A wake runs `aside session queue <id> "<note>"`, or `aside session resume` when the task is idle.
The note starts with `[t3-events]`. Default wake events: `thread.run_settled`,
`thread.needs_input`, `pr.watch_wake`. A watch ends after the turn ends unless `--keep`.

## Signing in an environment

```sh
t3-events login <env> <mcp-url> --environment-id <id>   # opens the approval page
```

- Mac: `http://127.0.0.1:3773/mcp`. The page wants a one-time code: `t3 auth pairing create --ttl 5m`.
  Pasting it switches the level to Auto; pick **Read only** again before approving.
- julds: T3 Connect address `https://prod-30d01c3c481664ad.t3coderelay.com/mcp`; approve on
  app.t3.codes, no code.
- Project VMs: `https://<vm>.taildbdfb2.ts.net/mcp`. A code from `ssh <vm> t3 auth pairing create`
  unless the browser is already signed in to that VM (icb was).

Signed in 25 Nov 2026 (expire 25 Dec 2026): mac, julds, icb, altschool, coworkers, erivault,
investor-os. Polling never counts as use, so it does not keep a VM awake (`boat-keep-awake` ignores
`bot` sessions); an asleep VM is retried with back-off up to every 5 minutes. A T3 older than
v0.1.12 answers `Method not found: events/poll` and is retried every 30 minutes until updated.

## Executor

Executor 2 can publish its own MCP Events to its clients (webhook delivery only). The cloud
Executor at executor-v2.julds.com is public, so it can receive T3's webhooks directly and does not
need the Mac awake. See the Executor `t3-events` app work for that path; this Mac bridge stays the
way Aside is woken, because Aside cannot take Executor's webhooks either.
