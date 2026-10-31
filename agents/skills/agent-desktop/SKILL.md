---
name: agent-desktop
description: Operate macOS desktop apps on Somto's Mac through the accessibility tree with agent-desktop, reached only through the executor_v2_local Executor app. Use to read or act on a native app UI (click, type, fill forms, menus, checkboxes, scroll, windows, screenshots) when no app-specific tool exists.
---

# agent-desktop (through local Executor)

agent-desktop observes and operates desktop apps through the macOS accessibility tree. On this
setup it is the `agent-desktop` app in **`executor_v2_local`** (Mac only). Do not run the
`agent-desktop` CLI in a shell and do not add a direct MCP entry: Executor holds the approvals.
The julds VM and the cloud `executor_v2` cannot reach it.

Find the tools with `search({ namespace: "agent-desktop" })`, read signatures with `describe`, and
call them with `call` or `execute` (paths look like `tools["agent-desktop"].snapshot`).

| Kind | Tools | Approval |
|---|---|---|
| Read | `snapshot`, `find`, `get`, `is`, `screenshot`, `list_apps`, `list_windows`, `list_surfaces`, `list_displays`, `wait`, `status` | none |
| Act | `click`, `right_click`, `type`, `set_value`, `clear`, `focus`, `select`, `toggle`, `check`, `uncheck`, `expand`, `collapse`, `scroll`, `scroll_to`, `press`, `launch`, `run` | asks every call |

Every result is agent-desktop's JSON envelope as text: `{ ok, data }` or `{ ok, error }`.

## The loop

1. Observe. A small app: `snapshot { app, interactiveOnly: true, compact: true }`. A large app:
   add `skeleton: true`, then drill into one region with `root: "@<snapshot_id>:eN"`. When you
   know the role or name, use `find` instead.
2. Act on one qualified ref, such as `click { ref: "@s8f3k2p9:e5" }`.
3. Verify. Snapshot the same region again (or `get` / `is`). AX return codes do not prove an
   effect.
4. Repeat. After an async step use `wait` (element, text, window, menu or `event`), not a sleep.

Refs are valid for one snapshot. `STALE_REF` or `SNAPSHOT_NOT_FOUND`: snapshot again.
`AMBIGUOUS_TARGET`: narrow with `find` (`exact`, `root`). `WINDOW_NOT_FOUND`: the app has no open
window; check `list_windows`. Menus, sheets and alerts that an action opens are listed in
`data.surfaces`; read them with `snapshot { surface: "menu" }` (never skeleton a surface). Use
`surface: "menubar"` for File/Edit/View menus and menu bar apps.

## Retries

Act results carry `data.disposition` (errors carry `error.disposition`) with `delivery` and
`retry`. Repeat an action only when `retry` is `"safe"` (`not_delivered`). Otherwise the action
may have landed: read the live state first. A repeated click can submit twice and `toggle` can
undo itself; prefer `check` / `uncheck`. Branch on `error.code`, not on message text.

## Headless only, unless asked

Actions are headless: semantic accessibility calls that never move the pointer, take focus or
type physical keys. If no semantic path exists the action fails closed (`POLICY_DENIED`); do not
switch to physical input to recover. `--headed` and the raw mouse/keyboard commands (`hover`,
`drag`, `double-click`, `mouse-*`, `key-down`, `key-up`) exist only through
`run { args, allowPhysicalInput: true }`, and only when the user explicitly asked for physical
input. `--screenshot`, `--debug`, `--trace` and `--verbose` are always refused.

Use `run` for other commands, such as `["close-app","Notes"]`, `["focus-window","--app","Notes"]`,
`["list-notifications"]`, or `["skills","get","desktop","references/workflows.md"]` for upstream
worked patterns. `run` always asks for approval.

## Privacy

Snapshots and screenshots can show private content (mail, messages, passwords on screen). Return
only what the task needs, and never copy desktop content into the cloud executor, tickets or
logs. Refs are kept in `~/.agent-desktop` (mode 0700) on the Mac.

## Permissions

`status` reports `accessibility` and `screen_recording`. `PERM_DENIED` means the
agent-desktop binary lacks the grant; tell the user, do not try to work around it. Setup and the
exact binary to grant: `agents/executor/v2.md` in the dotfiles repository.

Adapted from the agent-desktop skill by Vercel Labs (Apache-2.0),
https://github.com/vercel-labs/agent-desktop.
