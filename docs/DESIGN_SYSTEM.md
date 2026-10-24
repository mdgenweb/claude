# Pick Your Mech! — UI design system

The UI copies the look of today's top Roblox simulators (chunky outlined buttons, glossy
gradients, cartoon type, colour-coded cards, R$ price pills, red "!" badges, springy
animations) and themes it for a scrapyard robot game: orange mech plates, steel greys,
screen-blue eyes and hazard yellow.

Tokens live in `src/shared/Theme.luau`; components in `src/client/UI/UIKit.luau`;
wording in `src/client/UI/Copy.luau`.

## Tokens

### Colour swatches
Every coloured surface is a vertical gradient `Top → Bottom`; `Deep` is for pressed/shadow tints.

| Swatch | Top | Bottom | Use |
|---|---|---|---|
| Green | `#8CF55A` | `#2DBE2A` | Buy, confirm, affordable, Shop |
| Orange | `#FFB24A` | `#FF7417` | Brand, upgrades, mech, Boost |
| Blue | `#62CCFF` | `#1F7BEA` | Info, Garage, gates, Auto |
| Purple | `#CF92FF` | `#8B3FF0` | Rebirth, VIP |
| Yellow | `#FFE85E` | `#FFB300` | Scrap, rewards, Daily |
| Red | `#FF7070` | `#E02D2D` | Close, errors, badges |
| Lime | `#D4FF5A` | `#7BD81E` | Lime Paint |
| Steel | `#8A97AD` | `#535F75` | Disabled, owned, locked |
| Navy | `#34405A` | `#1E2638` | Panel bodies, HUD pills |

Single colours: Ink `#0E1118` (every outline, shadow and text stroke), Scrap gold `#FFD12E`,
Power cyan `#5BE7FF`, Good `#6CFF5C`, Muted text `#B8C4DA`. Lane colours 1–6: red, orange,
yellow, green, blue, purple.

### Type
| Role | Font | Size (ref px) |
|---|---|---|
| Display / numbers / buttons | Luckiest Guy | 48 · 34 · 26 |
| Labels / body | Fredoka One | 20 · 16 · 13 |

Text is always white (or a token colour) with an Ink `UIStroke`; stroke ≈ size / 9
(`Theme.strokeFor`). Labels use `TextScaled` with a max-size constraint so long
translations shrink instead of overflowing.

### Shape and depth
- Spacing 4 · 8 · 12 · 16 · 24 · 32
- Radius 8 · 12 · 18 · pill
- Outline 2 (chips) · 3 (buttons, cards) · 4 (panels)
- Hard drop shadow: Ink at 15% transparency, offset 5 px down (3 px on chips, 7 px on panels)
- Shine: white strip over the top 42% of a face at 78% transparency

### Motion
| Interaction | Animation |
|---|---|
| Hover | scale 1.07 + tilt −3° (0.12 s, Back) |
| Press | scale 0.92, face drops 3 px (0.07 s) |
| Release | spring back (0.25 s, Back) |
| Panel open / close | 0.7 → 1 (0.32 s, Back) / → 0.85 (0.16 s) |
| Badge | pulse 1 ↔ 1.18 |
| Featured items | idle bob 3–6 px, rotating sunburst |
| Disabled tap | shake + a toast saying what's missing |

All looping motion is skipped when Roblox's Reduced Motion setting is on.

## Components

| Component | Anatomy | States |
|---|---|---|
| **Surface** | holder › shadow + face (gradient, outline, shine) | — |
| **Button** | Surface + optional emoji icon + label | default · hover · pressed · disabled (Steel, shakes) |
| **IconButton** | square Surface, big emoji, label overlapping the bottom edge, Badge | default · hover · pressed · badge |
| **Chip** | pill Surface, small label | colour by meaning (green ON/active, steel off, navy info) |
| **Badge** | red circle "!" or "NEW", pulsing | hidden · visible |
| **Progress** | Ink pill track, gradient fill, centred label | yellow (in progress) · green (ready) · red (low HP) |
| **Panel** | Navy body, coloured title tab overlapping the top-left, red X top-right, dim backdrop | open · closed; blocking panels pause salvage |
| **Toast** | coloured card, emoji, title + one line | auto-dismiss 3 s; errors shake |
| **Celebration** | huge gradient title over a rotating sunburst | new form, gate, rebirth |
| **Pad label** (world) | yellow title, white subtitle, green live line | floats over each hub pad |

## Screen patterns

- **HUD:** Scrap and Power pills (top centre), five menu buttons (left), Boost and
  Auto (right), the *next upgrade* widget (bottom centre: what you get, progress, one
  UPGRADE button), and a goal chip above it showing the next gate or rebirth requirement.
- **Shop:** featured banner (Double Scrap, "x1 → x2") over a 3-column card grid; every card
  states the exact benefit, and the live R$ price comes from the Marketplace.
- **Upgrade:** live 3D mech preview + nine rows (owned · next · locked); form milestones are
  orange with a NEW FORM chip.
- **Rebirth:** five-step track, a ✅/❌ checklist, RESETS vs YOU KEEP cards, two-tap confirm.

## UX copy rules
- Fixed terms: **Scrap** (currency), **Power** (stat), **smash** (action), **junk**
  (targets), **yard** (area), **lane** (your strip).
- Buttons are verbs, 1–2 words, all caps: UPGRADE, UNLOCK, CLAIM, EQUIP, CRAFT, REBIRTH.
- Errors say what's missing and how to get it: "Need 12 more Scrap. Keep smashing!"
- Offers state the exact benefit and never pressure: "Exactly 600 Scrap. Never multiplied."
- Confirmations name the action and list consequences (Rebirth shows RESETS / YOU KEEP).

## Accessibility
- Every text has an Ink outline, so white text stays readable on any colour or the 3D world.
- Colour is never the only signal: ✅/❌ marks, OWNED/LOCKED text, 🔒 icons.
- Touch: the UI never scales below 0.62 on touch devices, so the 78 px menu buttons stay ≥ 48 px.
- Reduced Motion turns off bobbing, pulsing, tilts and camera shake.
- Escape / gamepad B closes panels; panels also close when the Roblox menu opens.
