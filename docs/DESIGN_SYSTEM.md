# Design System — shared source of truth

These tokens are implemented natively in each client (Flutter `ThemeData` in
`app/lib/core/theme/`, Tailwind theme extension in `website/tailwind.config.ts`) so the
mobile app and website read as one product without sharing UI code across two
incompatible frameworks. When either implementation drifts from this file, this file
wins — update the code, not the doc, unless the change is deliberate (then update both).

## Brand

Modern, premium, minimal. Warm-neutral surfaces, one confident accent color, generous
whitespace, restrained motion. Avoid default Material/Bootstrap boilerplate look —
no default indigo/blue Material seed color, no default shadcn zinc theme untouched.

## Color

Seed/accent: **`#FF5A3C`** (warm coral-orange — energetic, distinct from the generic
blue/purple used by most event apps, still reads well on light and dark surfaces).

| Token               | Light            | Dark             |
|---------------------|------------------|------------------|
| `brand`             | `#FF5A3C`        | `#FF6B4A`        |
| `brand-strong`      | `#E4472B`        | `#FF8563`        |
| `bg-base`           | `#FFFFFF`        | `#121212`        |
| `bg-surface`        | `#F7F6F4`        | `#1B1B1B`        |
| `bg-surface-raised` | `#FFFFFF`        | `#222222`        |
| `text-primary`      | `#171412`        | `#F5F3F1`        |
| `text-secondary`    | `#6B6560`        | `#A8A29C`        |
| `border`            | `#E8E5E1`        | `#2E2E2E`        |
| `success`           | `#1E9E5A`        | `#33C177`        |
| `warning`           | `#D97706`        | `#F0A93E`        |
| `danger`            | `#DC2626`        | `#F0554D`        |

Both clients generate full Material 3 / Tailwind tonal ramps from `brand` — don't
hand-pick extra shades ad hoc.

## Typography

- Flutter: `Inter` (via `google_fonts`, bundled offline for release builds).
- Web: `Inter` (via `next/font`, self-hosted — no external font CDN request).
- Scale (both clients, in logical/rem units): `display 32/40`, `title 24/32`,
  `heading 20/28`, `body 16/24`, `label 14/20`, `caption 12/16`. Weight: 600 for
  display/title/heading, 400 for body, 500 for label/caption.

## Spacing & radius

- Spacing scale: `4, 8, 12, 16, 24, 32, 48, 64` (px / logical pixels).
- Corner radius: `12` for cards/sheets, `8` for inputs/buttons, `999` for pills/avatars.
- Elevation: prefer subtle 1px borders (`border` token) over heavy drop shadows;
  reserve shadow for floating elements (FAB, bottom sheets, modals).

## Motion

- Standard transition: 200ms, `ease-out` for entrances, `ease-in` for exits.
- Page transitions: shared-axis / fade-through, not default platform slide, on both
  GoRouter (Flutter) and Next.js route transitions.
- Respect reduced-motion OS setting on both platforms.

## Dark mode

Both clients must ship light + dark from day one (`ThemeMode.system` in Flutter,
`prefers-color-scheme` + manual toggle in Next.js) — this is a Phase 1 requirement, not
a later polish pass.
