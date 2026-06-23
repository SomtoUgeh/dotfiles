# Erivault design system (extracted)

The authoritative values for designing in the `erivault-web` Paper file. Verify
against code before relying — `packages/ui/css/base.css` is the source of truth;
the written doc can lag it.

## Contents
- [Sources of truth](#sources-of-truth)
- [Palette](#palette)
- [Status-chip lifecycle palette](#status-chip-lifecycle-palette)
- [Typography](#typography)
- [Spacing, radius, sizing](#spacing-radius-sizing)
- [Component vocabulary](#component-vocabulary)
- [Reusable inline values](#reusable-inline-values)
- [The shell](#the-shell)
- [Register per role](#register-per-role)
- [Standing rules](#standing-rules)

## Sources of truth

- `packages/ui/css/base.css` — base CSS variables (authoritative).
- `apps/web-app/src/styles.css` — web override (warms neutrals ~20%, adds
  `--brand-*`).
- `apps/mobile-app/src/lib/theme.ts` — same palette as hex for React Native.
- `docs/design/dashboard-design-system.md` — intent + component naming; may lag.
- Paper file `erivault-web`, page **Token and Components** — visual token board,
  component specs, address-lookup states, the shared upload-lifecycle pipeline.

## Palette

Hex ≈ oklch. Names match `base.css` variables.

| Role | Hex | Notes |
|------|-----|-------|
| App ground (cream) | `#FBF9F3` | `--background`; artboard bg |
| Container card (beige) | `#F1ECE4` | `--card`/`--muted`; SurfaceCard bg |
| Sidebar | `#F7F2EA` | `--sidebar` |
| Inner row / inputs | `#FFFFFF` | white rows on beige |
| Hairline border | `#E5E2DC` | `--border`; sidebar/topbar/card-outline |
| Row hairline | `#F2EEE7` | between table/list rows |
| Active nav pill (sage) | `#DAEBDF` bg / `#003416` text | sidebar active item |
| Primary ink / dark buttons | `#023528` | `--brand-coach-green` (web) / `--hero` |
| Interactive green | `#155C48` | `--interactive`; links, progress, success |
| Mint wash | `#E0F5E6` | `--accent`; mint chips |
| Mint icon slot | `#EEF6EF` | 32–34px tinted icon backgrounds |
| Body ink | `#211F1A` | `--foreground` |
| Muted text | `#62605B` / `#86837C` | secondary / tertiary |
| Warning (ochre) | `#A36A1C` on `#F6EDDC` | `--warning` / `--warning-soft` |
| Critical (brick) | `#93402E` on `#F7E8E2` | `--critical` / `--critical-soft` |
| Destructive (action red) | `#C53030` | `--destructive`; distinct from brick |
| Progress track | `#E2DCD0` | timeline connectors, progress rails |
| Logo teal | `#2DD4A8` | brand mark accent only |

`--warning*` and `--critical*` are **real CSS vars in `base.css`** and the
`StatusChip` component implements them — the doc claiming otherwise is stale.

## Status-chip lifecycle palette

The approved mapping for lifecycle states (cascades to every screen):

| State | Chip | Tokens |
|-------|------|--------|
| Active | mint dot + label | `#E0F5E6` / `#155C48` |
| Scheduled | ochre | `#F6EDDC` / `#A36A1C` (upcoming/awaiting) |
| Ended | neutral grey | `#ECE8E1` / `#62605B` (calm, closed) |
| Cancelled | brick | `#F7E8E2` / `#93402E` (void/non-proceeding) |

`StatusChip` (`packages/ui/components/status-chip.tsx`) is `tone × emphasis`:
- tone: `neutral | mint | warning | critical`
- emphasis: `solid` (urgent action) | `tinted` (status) | `outline` (passive fact)

## Typography

TWK Lausanne only, weights **200 / 400 / 450(=medium) — never semibold/bold**.
Tiempos Headline is brand/marketing display, **not used in product UI**.

| Use | Size / weight | Color |
|-----|---------------|-------|
| Page heading | 26/450 desktop, 21–22/450 mobile, tracking -0.01em | `#211F1A` |
| Stat numeral | 34/200 (mobile 30, strip 22) | `#211F1A` |
| Card title | 15/450 | `#211F1A` |
| Row title | 13.5/450 | `#211F1A` |
| Label | 13/450 | `#211F1A` |
| Body / input | 14/400 | `#211F1A` |
| Row meta | 12.5/400 | `#86837C` |
| Caption / helper | 12/400 | `#86837C` |
| Eyebrow | 11/450 uppercase, tracking 0.12–0.16em | `#86837C` |

## Spacing, radius, sizing

- Radius: **12px** cards, **8px** inner rows/inputs/buttons, **6px** chips/badges.
- SurfaceCard padding: **20px** (dashboard rhythm); form cards 24px.
- Form card width **560–640px**; min touch target **44px**.
- Field gap 20px; section gap 24px; content gutters 40px; topbar height 57px;
  sidebar width 264px.

## Component vocabulary

One name each — reuse, don't fork. All in `packages/ui/components/`.

- `Shell` / `Sidebar` (+ `SidebarMenu*`) — 264px sidebar + 57px topbar.
- `StatCard`, `CoverageStat`, `MiniStatStrip` — stats; coverage is the north star.
- `SurfaceCard` (beige container) + `InnerRow` (white row: icon slot / content /
  trailing slot, tone variants neutral|mint|warning|critical).
- `StatusChip` — tone × emphasis (see above).
- `Badge`, `CountBadge` — count badge is a dark-green pill.
- `SetupStep`, `StepProgress` — done | active | locked stepper.
- `DarkHero` — the only dark surface (tenant record / invitation).
- `EmptyState` (centered passive), `QuietState` (single quiet row), `ExplainerRow`.
- `ActivityRow` (dot + relative time), `GroupLabel` (eyebrow with tone).
- `Drawer` (440px right panel / mobile bottom sheet), `Sheet`, `DropdownMenu`.
- `TabBar` (mobile bottom nav).

## Reusable inline values

When hand-writing HTML in Paper, these match the live components:

- SurfaceCard: `background:#F1ECE4; border-radius:12px; padding:20px;`
- White inner row: `background:#FFFFFF; border-radius:8px; padding:12px 14px;`
  with `gap:12px`, an icon slot, a `flex-grow` content stack, a trailing chip.
- Icon slot (mint): `34px square; border-radius:8px; background:#EEF6EF;` green
  lucide icon stroke `#155C48`, 2px stroke.
- Row title `13.5px/450 #211F1A`; meta `12.5px/400 #86837C`.
- Tinted chip: `border-radius:6px; padding:4px 9px;` bg `#E0F5E6` text `#155C48`
  (mint), or `#F6EDDC`/`#A36A1C` (ochre), or `#F7E8E2`/`#93402E` (brick), or
  `border:1px solid #E5E2DC` text `#62605B` (outline neutral).
- Dark primary button: `background:#023528; color:#FBF9F3; border-radius:8px;
  padding:10px 18px;` 13.5/450.
- Secondary button: `background:#FFFFFF; border:1px solid #E5E2DC;` text `#211F1A`.
- First-run affordance: `background:#FFFFFF; border:1.5px dashed #D8D2C7;
  border-radius:8px;` icon + label in `#155C48`.

## The shell

`get_jsx` the sidebar of a sibling artboard to copy the exact logo SVG. Key
facts: sidebar `#F7F2EA`, 264px, 1px right border `#E5E2DC`, `py-4 px-3`. Order:
logo → workspace switcher (32px dark-green avatar, name 14/450, type 12/400,
chevrons) → nav (16px lucide icons, 14px labels, active = `#DAEBDF` pill with
`#003416`) → settings → user row. Topbar: 57px, sidebar-toggle, 1px divider,
then a 15/450 page title or a breadcrumb (`Parent › Record`).

Nav per surface:
- Agency / Landlord: Dashboard · Properties · Inspections · Reports · People.
- Tenant: My tenancy · Evidence · Documents · Profile.
- Client: My properties · Reports.

## Register per role

Same system, different breathing room:
- **Agency** — densest (portfolio ops), full staff actions.
- **Landlord** — same layout at small scale; no client-landlord party (they own
  the unit).
- **Tenant** — airiest, read-mostly, the one dark hero moment, verbs limited.
- **Client landlord** — read-only, verbs limited to view / sign / request.

Mobile artboards (390px) double as the responsive-web reference; only chrome
differs (bottom tab bar vs collapsed sidebar).

## Standing rules

- A module lives under its parent nav; topbar breadcrumbs back to the parent.
- Only two dark surfaces (record hero, invitation banner) — add no others.
- AI is always labelled (`AI-SUGGESTED` mint badge) and never auto-applies.
- Web/mobile parity by default (additive RPC + shared server fns underneath).
- Tabular figures for stat numerals.
