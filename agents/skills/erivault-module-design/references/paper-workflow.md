# Paper MCP build workflow

How to drive the Paper desktop MCP to build module screens efficiently and
consistently. The big lever is **duplicate a real artboard and adapt it** — you
inherit the exact shell and never rebuild chrome.

## Contents
- [Session setup](#session-setup)
- [Inherit the shell (cross-page duplicate)](#inherit-the-shell-cross-page-duplicate)
- [Build the hero](#build-the-hero)
- [Duplicate-and-adapt loop](#duplicate-and-adapt-loop)
- [Mobile via clone](#mobile-via-clone)
- [Modals](#modals)
- [Reviewing and finishing](#reviewing-and-finishing)
- [Render gotchas](#render-gotchas)

## Session setup

1. `get_guide({ topic: "paper-mcp-instructions" })` once per session before any
   other Paper tool.
2. `open_file` (the `erivault-web` file or a page URL) → `get_basic_info` to see
   pages and artboards.
3. `get_font_family_info({ familyNames: ["TWK Lausanne"] })` — note it takes an
   **array**. Confirms weights 200/400/450.
4. `get_jsx` a sibling artboard's sidebar to capture the logo SVG + shell markup.
   Cross-page `get_jsx` works (the node need not be on the active page).

## Inherit the shell (cross-page duplicate)

The new module gets its own page (e.g. "Tenancies"). To put the real shell on a
blank page:

```
duplicate_nodes({ nodes: [{ id: "<sibling artboard>", parentId: "root_node_<PAGE>" }] })
```

This lands a full copy (sidebar + topbar + body) on the target page and returns
a `descendantIdMap` (every original node id → its clone id). Keep that map; it
lets you target the clone's sidebar, topbar, and content without re-querying.

Then strip the body: `delete_nodes` the duplicated content frame's children, and
`get_computed_styles` the content frame once to learn its padding/gap so your new
content matches the gutters.

`x-paper-clone` does **not** cross pages — use `duplicate_nodes` for that.

## Build the hero

Build the richest screen first (populated detail/hub for the primary staff role),
into the stripped content frame, with `write_html` (`mode: insert-children`).

- Write one visual group per call (header, then each card) — the user watches it
  build; keep groups small.
- Use inline styles only; pull values from `references/design-system.md`.
- Rebreadcrumb the topbar: `write_html` (replace) the title text node with
  `Parent › Record`.
- Layout: header block (eyebrow · title · lifecycle chip · meta), then a
  two-column `Body Split` (main column `flex-grow`; right rail ~360px) holding
  SurfaceCards.
- `get_screenshot` the finished artboard, review against the design checkpoints
  (spacing, hierarchy, alignment, chip wraps), fix, then treat it as the template.

## Duplicate-and-adapt loop

For every other state/role, duplicate the hero and change only what differs:

1. `duplicate_nodes({ nodes: [{ id: "<hero>" }] })` → grab the `descendantIdMap`.
2. `rename_nodes` the new artboard (`Role: Module Screen — State`).
3. Adapt with the lightest tool that works:
   - `set_text_content` — labels, dates, names, counts, chip text.
   - `update_styles` — chip bg/dot/text color for the lifecycle palette.
   - `write_html` (replace) — swap a whole sub-tree (timeline steps, action list,
     a row) when structure changes.
   - `delete_nodes` — remove affordances a state/role shouldn't have.
4. Use the `descendantIdMap` to find the clone of each node you edited on the
   hero (e.g. hero chip text `12BR-0` → look up its clone id in the map).

For a **role variant**, the sidebar changes too: `get_tree_summary` the cloned
sidebar to find the nav frame + workspace/user text nodes, `write_html` (replace)
the nav frame with that role's items, and `set_text_content` the workspace and
user identity.

## Mobile via clone

Mobile artboards are 390px wide, single column. Reuse the web cards instead of
rebuilding:

- `create_artboard` 390 wide, `flexDirection: column`, bg `#FBF9F3`.
- Paste the status bar from `get_guide({ topic: "mobile-status-bar" })` (black
  text/icons on the cream bg) as the first child.
- Add an app header (back chevron + title) and the header block.
- In a padded `Scroll Content` frame, `x-paper-clone` the web cards
  (`<x-paper-clone node-id="<web card>" style="width:100%;" />`) — they reflow to
  the column width.
- Add the bottom `TabBar` (5 agency tabs / role-specific tabs, active = parent).
- After cloning, chips on the now-narrower rows wrap — set their text
  `white-space:nowrap` and the chip frame `flex-shrink:0`.

## Modals

- **Web**: `create_artboard` (e.g. 880×640) with a dim scrim bg (`#2B2926`),
  `align/justify: center`. Add a 480px white card (`border-radius:14px`,
  soft shadow) with header (title + close), body, and a right-aligned footer
  (secondary + primary; destructive primary uses brick `#93402E`).
- **Mobile**: 390-wide artboard, scrim bg, status bar, a flex-grow spacer, then a
  bottom sheet (white, `border-radius:20px 20px 0 0`, grabber bar) with the same
  body and a full-width primary button.

## Reviewing and finishing

- `get_screenshot` each artboard after meaningful changes; `scale: 2` to read
  small text.
- Switch each artboard to `height: "fit-content"` via `update_styles` once
  content is final — never guess pixel heights.
- `finish_working_on_nodes` (no args releases all) when done.
- Do not surface raw node ids to the user; refer to screens by name.

## Render gotchas

- **Screenshots only render the foregrounded page.** After `open_page`,
  screenshots of that page can return empty even though edits succeed. Freshly
  built artboards on the active page render fine. When empty, use
  `get_tree_summary` (shows node names + text content) and `get_jsx` — both work
  off the active page.
- **Mobile artboards sometimes screenshot as 0×0** (auto-layout). Read them via
  `get_tree_summary`/`get_jsx`, or screenshot a child frame.
- **`get_screenshot` caps image size** — large/tall artboards return a resized
  image; that's fine for review.
- **Duplicate maps are large but cheap to scan** — you only need the handful of
  ids for nodes you're editing (chip, meta, timeline, actions, sidebar nav).
