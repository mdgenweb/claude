# Flask Fiasco — UI Design System

Built with the `design-system` skill. Every token below maps 1:1 to
[`src/client/UI/Theme.luau`](../src/client/UI/Theme.luau), and every component maps to a
constructor in [`src/client/UI/Components.luau`](../src/client/UI/Components.luau). UI code never
hardcodes colors, fonts or sizes; it reads them from `Theme`.

**Mood:** a magical alchemy lab at night. Deep-violet glass panels, gold for anything you can press
or earn, and neon potion colors that carry meaning (rarity, status, reward).

**Design resolution:** 1920×1080. A root `UIScale` maps it to the device
(`clamp(min(w/1920, h/1080), 0.55, 1.4)`, ×1.3 on touch screens).

---

## 1. Tokens

### Color — surfaces & text
| Token | Hex | Use |
|---|---|---|
| `Color.Surface.Base` | `#120D24` | Full-screen scrims, loading |
| `Color.Surface.Panel` | `#1E1638` (8% transparent) | Panels, cards |
| `Color.Surface.Raised` | `#2A2050` | Buttons (secondary), slots |
| `Color.Surface.Sunken` | `#150F2B` | Progress tracks, inputs |
| `Color.Stroke.Subtle` / `.Strong` / `.Gold` | `#3E3170` / `#6A55B8` / `#E8B653` | Borders |
| `Color.Text.Primary` | `#FFF7E8` | Body text (≈14:1 on Panel) |
| `Color.Text.Secondary` | `#C9BEEA` | Labels |
| `Color.Text.Muted` | `#8F84B8` | Hints, disabled |
| `Color.Text.Inverse` | `#1A1230` | Text on gold buttons (≈9:1) |
| `Color.Text.Outline` | `#120A22` | Text stroke over 3D scenes |

### Color — accents & states
| Token | Hex | Use |
|---|---|---|
| `Color.Accent.Gold` → `GoldDeep` | `#FFD45E` → `#E89A2C` | Primary CTA gradient, rewards |
| `Color.Accent.Magenta` | `#FF4FA3` | Social, highlights |
| `Color.Accent.Cyan` | `#4FE3FF` | Info, slow-mo |
| `Color.Accent.Lime` | `#8CFF6B` | Brewing, success |
| `Color.State.Success` / `Warning` / `Danger` / `Info` | `#6BFF8E` / `#FFB13B` / `#FF5A6A` / `#6BB8FF` | Toast bars, validation |
| `Color.State.Disabled` | `#4A4268` | Disabled fills |

### Color — rarity (never the only signal: always paired with a text label)
| Common | Uncommon | Rare | Epic | Legendary | Mythic |
|---|---|---|---|---|---|
| `#CDD4DE` | `#6BFF8E` | `#4FA8FF` | `#B36BFF` | `#FFB13B` | `#FF4F7A` (animated gradient) |

### Color — chaos combo
| x1 | x2 | x3 | x4 | x5 |
|---|---|---|---|---|
| `#8F84B8` | `#4FE3FF` | `#8CFF6B` | `#FFC94A` | `#FF4FA3` |

### Typography
| Token | Font | Size | Use |
|---|---|---|---|
| `Type.Display` | Luckiest Guy | 64 | Reveal titles, level up |
| `Type.Title` | Luckiest Guy | 36 | Panel titles |
| `Type.Heading` | Fredoka One | 26 | Section headers, card titles |
| `Type.Body` | Fredoka One | 20 | Body |
| `Type.Label` | Fredoka One | 16 | Buttons, chips |
| `Type.Caption` | Fredoka One | 14 | Badges, hints |

Text over the 3D scene always gets a 2 px `Text.Outline` stroke.

### Spacing, radius, stroke, elevation
| Spacing | XS 4 · SM 8 · MD 12 · LG 16 · XL 24 · XXL 32 |
|---|---|
| **Radius** | SM 8 · MD 12 · LG 18 · Pill 50% |
| **Stroke** | Hairline 1 · Default 2 · Emphasis 3 |
| **Elevation** | E1: shadow offset (0, 3) at 60% · E2: (0, 6) at 50%. Faked with an offset dark frame, since Roblox has no box-shadow. |

### Motion
| Token | Duration | Easing | Use |
|---|---|---|---|
| `Motion.Hover` | 0.12 s | Quad Out | Scale 1 → 1.06 |
| `Motion.Press` | 0.06 s | Quad Out | Scale → 0.94 |
| `Motion.Release` | 0.22 s | Back Out | Spring back |
| `Motion.PanelIn` / `PanelOut` | 0.24 s / 0.14 s | Back Out / Quad In | Modal scale 0.92 → 1 and fade |
| `Motion.ToastIn` / `Hold` / `Out` | 0.3 s / 3.2 s / 0.22 s | Quint Out | Toasts |
| `Motion.Reveal` | 0.45 s | Back Out | Discovery pop; light rays rotate 20°/s |
| `Motion.Count` | 0.5 s | Quart Out | Number count-ups |
| `Motion.Pulse` | 0.18 s | Back Out | Combo bump (scale 1.25 → 1) |

---

## 2. Components

### Button: `Components.Button(props)`
| Variant | Use when | Visual |
|---|---|---|
| `primary` | The main action in a view (BREW, Start Trial, Claim) | Gold gradient, `Text.Inverse` label, E1 shadow |
| `secondary` | Supporting actions | `Surface.Raised` fill, `Stroke.Strong` |
| `ghost` | Low emphasis (Cancel, Close) | Transparent fill, `Stroke.Subtle` |
| `danger` | Destructive (Reset, Quit trial) | `State.Danger` gradient |

| Prop | Type | Default |
|---|---|---|
| `text` | string | — |
| `icon` | string (emoji) | nil |
| `variant` | `primary\|secondary\|ghost\|danger` | `secondary` |
| `size` | `sm` (36) / `md` (48) / `lg` (64) | `md` |
| `keybind` | string | nil: shows a key badge in the top-right corner |
| `onClick` | function | — |

| State | Visual | Behavior |
|---|---|---|
| Default | As variant | — |
| Hover | Scale 1.06, stroke brightens | UI hover tick sound |
| Pressed | Scale 0.94 | Click sound, Release spring |
| Disabled | `State.Disabled` fill, 50% text | Not interactive, no sound |
| Loading | Label replaced by "…" pulse | Not interactive |

### Icon button: `Components.IconButton(props)`
A 72×72 rounded square (80 on touch) with a 30 pt emoji, an optional caption under it and a key
badge. The `active` toggle state adds a gold stroke and glow (used for slow-mo, pause and the
throw/feed mode).

### Panel / modal: `Components.Modal(props)`
Scrim (`Surface.Base` 45%) plus a background blur. The panel (default 1100×680) has a header with
the title, an optional tab row and a close button, then a scrolling body. Opens with
`Motion.PanelIn` and closes with Esc, the gamepad B button or the close button. Gamepad focus is
contained with a `SelectionGroup`.

### Tabs: `Components.Tabs(props)`
Pill tabs. The selected tab is a gold fill with `Text.Inverse`; the others are ghost.

### Hotbar slot: `Components.Slot(props)`
| Part | Spec |
|---|---|
| Size | 84×84 (72 on touch), gap 8 |
| Content | `ViewportFrame` with the real 3D bottle; it rotates while hovered or selected |
| Rarity | 3 px stroke in the rarity color |
| Count | Bottom-right pill: a number, or a gold `∞` when mastered |
| Key | Top-left caption `1`–`9` |
| Selected | Scale 1.1, gold stroke, glow underneath |
| Empty / out | 40% transparent, count shown in `State.Danger` |

### Toast: `Notifications.toast(text, kind)`
360×64 with a left accent bar colored by kind: `info` cyan, `success` green, `error` red, `reward`
gold, `social` magenta. An emoji icon always comes with the color. At most 4 toasts stack in the
top-right corner.

### Progress bar: `Components.Progress(props)`
`Surface.Sunken` track with a gradient fill (accent color) and an optional centred label. The
width animates with `Motion.Count`.

### Chaos meter: `Hud.chaos`
Top centre. Shows the "CHAOS" label, a count-up number and a multiplier badge colored by combo
level, with a thin decay bar for the time left in the combo window. Each gain plays a pulse. It
fades out after 4 s idle.

### Tooltip: `Components.Tooltip`
`Surface.Panel` with a `Stroke.Strong` border. The title is in the rarity color, followed by
body text. It follows the pointer at an offset of (18, 18) and is clamped on screen.

### Discovery reveal: `Notifications.reveal(potionId)`
A full-screen scrim, two counter-rotating ray fans in the rarity color, the bottle spinning in a
viewport, a rarity chip, the name in `Type.Display`, the description and a "Continue" primary
button. Confetti bursts in the rarity color.

---

## 3. Accessibility & platform rules
* **Keyboard first.** Every action has a key, and the key badge is printed on the control. Esc
  closes the top modal, and keybinds are ignored while a TextBox has focus.
* **Gamepad.** A virtual cursor (left stick); buttons are `Selectable`, and modals use
  `SelectionGroup` so focus can't escape.
* **Touch.** Targets are at least 48 px at design resolution (60+ physical px after scaling). Tap
  uses the item; drag grabs. Pinch zooms and two fingers pan.
* **Contrast.** Body text is ≥ 7:1 on panels, and the CTA label is ≥ 4.5:1 on gold.
* **Color + icon + text.** Rarity and status are never shown by color alone.
* **Motion.** The "Screen shake" slider (0 to 100%) scales camera shake and FOV punches.

## 4. Do / Don't
| ✅ Do | ❌ Don't |
|---|---|
| Use one `primary` button per view | Put two gold CTAs side by side |
| Read every value from `Theme` | Hardcode `Color3.fromRGB` in panels |
| Pair rarity colors with their label | Rely on red/green alone |
| Keep the HUD at the screen edges | Cover the middle of the lab |
