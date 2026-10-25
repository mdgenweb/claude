# Elmore Defense: Game Design Document (v0.1)

*"The Void is leaking into Elmore. Assemble the weirdest defenders in town."*

A Roblox co-op tower defense set in the world of *The Amazing World of Gumball*. Its structure is modelled on
Candy Kingdom Defense and the anime-TD genre (see `docs/research/01-RESEARCH-REPORT.md`). Every system is
re-themed around Elmore and school life, and the code is built to be fully data-driven.

> **Source of truth:** all numbers live in `src/shared/Config/*.luau`. This document explains the *why*.
> When the two disagree, the config wins.

---

## 1. Pillars

1. **Instantly familiar, wonderfully weird.** Genre-standard controls and systems, with every label and moment
   written in the voice of the show.
2. **Every action has a payoff you can see.** Each hit, kill, upgrade, roll and win has a visible, audible reaction.
3. **Always a next goal on screen:** a pity bar, BP level, index %, quest bar, star rating or next banner.
4. **Fair and transparent.** Odds are shown everywhere, pity is visible, the first copy of every unit is never lost,
   and Roblox paid-random-item policy is followed.

## 2. Fiction → system mapping (diegetic naming)

| System | Elmore name | Lobby station |
|---|---|---|
| Premium soft currency (gems) | **Gumballs** | – |
| Summoning | **The Gumball Machine** (a giant capsule machine) | Centre plaza |
| Trait reroll currency | **Void Shards** | **The Void Rift** |
| Stat grade reroll currency | **Report Cards** | **Principal Brown's Office** |
| Stat grades | Literal school grades **D … A+, S** | – |
| Evolution | **Glow-Up** | **Joyful Burger** (evolution counter) |
| Evolution items | Joyful Coupons, Rainbow Sprinkles, Void Cores, Sticker Pages | – |
| Unit index | **The Yearbook** | – |
| Battle pass | **Elmore Pass** | – |
| In-match money | **Elmore Bucks ($)** | – |
| Base | Elmore Junior High's front door / the Watterson house | – |
| Enemies | Things that escaped **the Void** (Elmore's dumping ground for forgotten stuff) | – |

## 3. Core loop

```
            ┌──────────── LOBBY (Elmore Plaza) ────────────┐
            │ Gumball Machine → units                      │
            │ Void Rift → traits   Principal → grades      │
            │ Joyful Burger → Glow-Ups   Yearbook → index  │
            │ Elmore Pass / Shop / Quests / Daily / Codes  │
            └───────────────▲──────────────┬───────────────┘
                 rewards    │              │  team of 6
            ┌───────────────┴──────────────▼───────────────┐
            │ MATCH: Story (5 worlds × 5 acts), Infinite,  │
            │ Challenges (3 rotate every 30 min)           │
            │ place → upgrade (4–7 tier ladder) → boss     │
            └──────────────────────────────────────────────┘
```

## 4. Units

### 4.1 Rarities

| Rarity | ★ | Colour | Summon odds | Default placement limit |
|---|---|---|---|---|
| Rare | 3 | Blue | 69.85% | 5 |
| Epic | 4 | Purple | 25.00% | 4 |
| Legendary | 5 | Gold | 4.50% | 3 |
| Mythic | 6 | **Rainbow** | 0.60% (75% of these are the featured unit) | 3 |
| Secret | 7 | **Black glitch** | 0.05% | 2 |

**Shiny:** 1 in 80 summons is Shiny. Shiny units get +5% damage, sparkle VFX and a gold card frame.

### 4.2 Roster (v0.1)

| Unit | Rarity | Role | Signature ladder (in-match) |
|---|---|---|---|
| Gumball | Rare | Splash DPS | Dude Punch → Prank Bomb → Prank Bomb+ → **What the What?!** (full AoE + stun) |
| Darwin | Rare | Fast DPS / slow | Fish Slap → Water Spit (slow) → Bubble Barrage (3 targets) → **Darwin Dash** (line) |
| Banana Joe | Rare | Control | Peel Toss (slow) → Slippery Floor → **Joke Bomb** (stun) |
| Tobias | Rare | Cone DPS | Show-off Kick → Rainbow Roundhouse → **Ego Blast** |
| Alan | Rare | Support | Good Vibes aura (+dmg to allies), Static Pop |
| Anais | Epic | Splash + armour shred | Science Beaker → Acid Mix → **Theory of Everything** (beam) |
| Penny | Epic | Chain | Antler Charge → Fairy Spark (chain) → **Shapeshift Storm** |
| Bobert | Epic | Pierce, **detects hidden** | Laser Eye → Twin Lasers → **Overclock Beam** |
| Tina Rex | Epic | Stun AoE | Stomp → Roar → **Extinction Stomp** |
| Carrie | Epic | Burn, **detects hidden** | Spooky Hex → Possession → **Poltergeist** |
| Masami | Legendary | Chain lightning | Drizzle → Thunderstorm → **Category 5** |
| Miss Simian | Legendary | Stun / control | Detention → Pop Quiz → **Expelled!** |
| Mr. Small | Legendary | Support + slow aura | Peace Aura (allies +spd/+range, enemies slowed) |
| Nicole | Mythic | Boss killer | Mom Glare → Car Keys of Doom → **Watterson Fury** |
| Richard | Mythic | **Farm** + splash | Pizza Delivery ($/wave) + Belly Flop |
| Hector | Mythic | Giant AoE | Giant Step → Earthquake → **Mountain Fall** |
| Rob | **Secret** | **Knock-back** + shred | Void Rift → Void Collapse (pushes enemies *back* along the path) |
| Pumpkin Darwin | Legendary *(Pass, Limited)* | Burn splash | free Elmore Pass level 50 |
| Vampire Gumball | Mythic *(Pass, Limited, always Shiny)* | Multi + burn | premium Elmore Pass level 50 |

**Glow-Ups (evolutions)** keep level, trait and grades (see research §2.4, which notes this protects player investment):

| From | To | Requires |
|---|---|---|
| Gumball | Gumball Prime (Mythic) | Lv 15, 20 Joyful Coupons, 10 Rainbow Sprinkles, 1,500 Gumballs |
| Darwin | Mecha Darwin (Mythic) | Lv 15, 20 Joyful Coupons, 2 Void Cores, 1,500 Gumballs |
| Anais | Professor Anais (Mythic) | Lv 20, 25 Rainbow Sprinkles, 3 Void Cores, 2,500 Gumballs |
| Nicole | Nicole Unleashed (Mythic) | Lv 30, 10 Sticker Pages, 5 Void Cores, 5,000 Gumballs |

### 4.3 Final stat formula (shared `UnitStats.compute`)

```
damage   = tier.damage × grade(Damage) × (1 + trait.damage) × (1 + 0.02 × (level−1)) × shiny(1.05) × (1 + auraBuffs)
range    = tier.range  × (1 + 0.5 × (grade(Range) − 1)) × (1 + trait.range) × (1 + auraRange)
cooldown = tier.cooldown / (grade(SPA) × (1 + trait.speed) × (1 + auraSpeed))
cost     = tier.cost × (1 − trait.cost)
```

### 4.4 Stat grades (Report Cards at Principal Brown's)

| Grade | D | D+ | C- | C | C+ | B- | B | B+ | A- | A | A+ | S |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Multiplier | .88 | .92 | .96 | 1.00 | 1.03 | 1.06 | 1.09 | 1.12 | 1.15 | 1.18 | 1.22 | 1.28 |
| Roll weight % | 6 | 8 | 11 | 14 | 13 | 12 | 11 | 9 | 7 | 5 | 3 | 1 |

Reroll all three for 1 Report Card, or lock one stat and reroll the other two for 2.

### 4.5 Traits (Void Shards at the Void Rift)

| Tier | Trait | Effect | Odds |
|---|---|---|---|
| Common (grey) | Snappy | +8% attack speed | 17% |
| Common (grey) | Eagle-Eyed | +8% range | 17% |
| Uncommon (blue) | Penny Pincher | −12% place & upgrade cost | 12% |
| Uncommon (blue) | Hyperactive | +14% attack speed | 12% |
| Uncommon (blue) | Tough Cookie | +15% damage | 11% |
| Rare (purple) | Hall Monitor | +18% range, **detects hidden** | 7% |
| Rare (purple) | Dude! | +10% damage, +15% range | 6% |
| Rare (purple) | Nerd Mode | +25% damage | 5.5% |
| Epic (pink) | Moneybags | +5% damage, kills pay +50% $ | 4% |
| Epic (pink) | Overclocked | +8% damage, +22% attack speed | 3.5% |
| Epic (pink) | Mischief | +12% damage, 15% chance to stun 0.6 s | 2.5% |
| Epic (pink) | Wonderfully Weird | +40% damage, +15% attack speed | 1.5% |
| Legendary (gold) | Elmore Legend | +30% dmg, +15% range, +10% spd | **0.8%** |
| Mythic (rainbow) | **AMAZING** | **+200% dmg, +20% range, +20% spd** | **0.2%** |

* **Auto-roll:** pick target traits and the server keeps rolling (up to your shard balance, max 100 per request)
  until it hits one. This removes 100 clicks of chore without changing the odds.
* **VIP pass:** 2× Legendary and Mythic trait odds and 1.5× Epic. Odds are renormalised and the *displayed* table
  updates for VIP players.
* **Trait VFX** (always visible in matches, the main status display):
  grey = ground ring · blue = ring + rising sparkles · purple = double counter-rotating ring + swirl ·
  pink = orbiting stars · gold = light pillar + floating crown + gold sparkles ·
  rainbow = hue-cycling ring, rainbow particles, orbiting rainbow orbs, a pulsing light and an "AMAZING!" sticker.

## 5. Summoning (The Gumball Machine)

* x1 = 50 Gumballs, **x10 = 450 Gumballs (1 free)**. VIP gets 20% off.
* **Hourly featured Mythic.** The rotation is deterministic from UTC hour, so every server agrees. The UI shows
  "NEW BANNER IN mm:ss" and "Next up: …".
* **Pity:** Legendary-or-better guaranteed within **50** summons, and Mythic-or-better within **400**. Both bars are visible.
* **Lucky Summons pass:** 2× Mythic odds and 1.5× Legendary odds (taken from Rare). Again the displayed table updates.
* **Auto-delete** per rarity (Rare / Epic / Legendary). The first copy of any unit is **always** kept, and Mythic
  and Secret are never deleted. Deleted pulls pay Gumballs back (Rare 3, Epic 8, Legendary 40).
* Inventory cap 150 (300 with the Big Backpack pass).
* **Halloween Banner** (event): the standard pool plus boosted Pumpkin Darwin odds while the event runs.
* **Reveal sequence:** the machine shakes and its crank turns, then gumballs drop out coloured by rarity, then crack open
  and the cards flip. If the batch contains a Mythic or better, the shake lasts longer and the screen flashes rainbow
  before the reveal. Titles: *Nice!* (Rare), *Dude!* (Epic), *What the What?!* (Legendary), *AMAZING!!!* (Mythic),
  *…the Void stares back* (Secret).

## 6. Matches

### 6.1 Flow

`Lobby → Play menu (Story / Infinite / Challenges) → party room (≤4, 20 s countdown or host Start)
→ Prep (15 s, place units) → Waves → Boss → Victory/Defeat screen → Lobby`

### 6.2 Economy

* Start cash **$600** per player.
* Wave clear bonus: **$100 + $25 × wave**, paid to every player.
* Each enemy pays a bounty to the player whose unit landed the kill. The Moneybags trait adds +50%.
* Selling refunds **60%** of everything spent on that unit.
* **Vote skip:** if all players vote, the next wave starts now and everyone gets +$50.
* Speed **1× / 2×**, and **3×** if anyone in the match owns the 3× Speed pass.

### 6.3 Controls

| Action | PC | Mobile / gamepad |
|---|---|---|
| Select hotbar unit | 1–6 | tap slot |
| Place | click (green ghost = valid, red = invalid; range circle shown) | tap ground |
| Rotate ghost | R | – |
| Cancel | Q / right click | ✕ button |
| Upgrade selected | **Z** | panel button |
| Sell selected | **X** | panel button |
| Cycle targeting | **T** | panel button |
| Speed toggle | F | button |

Targeting modes: **First, Last, Strongest, Weakest, Closest.**

### 6.4 Enemies (escaped from the Void)

| Enemy | Trait | Notes |
|---|---|---|
| Glitchling | basic | pixel blob |
| Static Blob | fast | TV static |
| Lost Sock | basic, tanky | the Void keeps every lost sock |
| Pixel Bat | very fast, fragile | |
| Splitter | splits into 2 Glitchlings on death | |
| Floppy Golem | **armoured 35%** | obsolete tech from the Void |
| Ghost Pixel | **hidden** (needs Bobert, Carrie or Hall Monitor) | |
| Healer Bug | heals nearby enemies | |
| Void Knight | armoured + fast | world 5 |
| **Bosses** | Hall Monster (W1), Gnome King (W2), Mall-Bot 3000 (W3), Woods Kraken (W4), The Void Heart (W5) | boss abilities: stun pulse, minion summon, shield phase, enrage |

### 6.5 Worlds

| # | World | Look | New enemy |
|---|---|---|---|
| 1 | Elmore Junior High | school yard, lockers, school bus | Glitchling, Static Blob, Lost Sock |
| 2 | Watterson Street | suburb, houses, picket fences | Pixel Bat, Splitter |
| 3 | Elmore Mall | tiled floor, shop fronts, fountain | Floppy Golem, Ghost Pixel |
| 4 | Elmore Woods | trees, lake, rocks | Healer Bug |
| 5 | The Void | floating junk in purple darkness | Void Knight |

Acts 1–5 have 10/12/14/16/18 waves, and HP multipliers rise by act and by world. The last wave is the boss, and acts
3+ add a mid-act mini-boss. **Stars:** 3★ = no leaks · 2★ = ≥50% base HP · 1★ = cleared.

### 6.6 Modes

* **Infinite:** endless waves at ×1.15 HP per wave, a boss every 10 waves, Gumballs per 5 waves, and a global
  leaderboard for best wave.
* **Challenges:** 3 slots rotate every 30 minutes, each = world + act + modifier. Modifiers: *Speedy* (+35% speed),
  *Tanky* (+60% HP), *Broke* (−40% income), *Rares Only*, *Ghost Town* (40% hidden), *Glass Door* (base HP 40).
  This mode is the faucet for evolution items.

## 7. Progression and retention systems

* **Account level** (from matches) unlocks worlds and titles.
* **Unit level** 1–50 from match XP (equipped units), at +2% damage per level.
* **Daily login:** a 7-day calendar (100 / 150 / 2 Shards / 250 / 3 Report Cards / 400 / **750 + 5 Shards**). Missing
  a day resets the streak.
* **Daily quests** (3 per day, UTC reset) and **weekly quests** (3), paying Gumballs, Shards and Pass XP.
* **Yearbook:** discovering a unit pays 25–1,000 Gumballs by rarity, and there are completion milestones.
* **Elmore Pass, Season 1 "Halloweenie":** 50 levels, free and premium tracks. Premium costs 799 R$, +1 tier costs 29 R$.
* **Codes:** `RELEASE`, `DUDE`, `WHATTHEWHAT`, `AMAZING`, plus milestone codes (likes/CCU) that the team adds in config.

## 8. Monetisation (all prices are placeholders to tune)

| Product | Type | Price (R$) | Effect |
|---|---|---|---|
| Starter Pack | product (one time) | 69 | 3,000 Gumballs, 20 Shards, 10 Report Cards, 3 Sticker Pages |
| VIP | pass | 299 | 20% off summons, trait luck, VIP chat tag, gold name |
| 2× Gumballs | pass | 449 | double Gumballs from matches |
| Lucky Summons | pass | 349 | 2× Mythic, 1.5× Legendary summon odds |
| 2× Drops | pass | 449 | double item drops |
| Big Backpack | pass | 99 | 300 unit slots |
| 3× Speed | pass | 149 | 3× match speed |
| Elmore Pass Premium | product | 799 | premium track |
| +1 Pass Tier | product | 29 | skip a level |
| Gumball packs | product | 25 / 49 / 99 / 199 / 399 / 749 | 450 / 1,000 / 2,200 / 4,800 / 10,500 / 21,000 |

Odds are displayed for every random purchase. Players flagged `ArePaidRandomItemsRestricted` can spend only
*earned* Gumballs on summons and rerolls. Paid and earned balances are tracked separately (see `ComplianceService`).

## 9. UI art direction: "Elmore Scrapbook"

The show mixes media (2D, 3D, photo and puppet) on school notebooks, and our UI leans into that.

* **Typography:** display text in **Luckiest Guy** with a 3 px dark-ink outline. Body text in **Fredoka One**.
  Hand-written notes and tags in **Permanent Marker**.
* **Palette:** Gumball Blue `#4FB7F2`, Darwin Orange `#FF8A1F`, Anais Pink `#FF8FC3`, Elmore Yellow `#FFD43B`,
  Void Purple `#5B2A86`, Ink `#1E1433`, Paper `#FFF8E7`, Go Green `#57D163`, Danger Red `#FF4F5E`.
* **Panels:** a rounded "paper" card with a thick ink stroke and a 4 px drop shadow offset down. The header is a "tape
  label" (yellow tag, slightly rotated), and the body has a soft diagonal candy-stripe gradient tinted per feature.
* **Buttons:** fat pill shapes with a gradient top highlight, an ink stroke and a darker "lip" below. On press they squish
  to 92% and spring back. Hover grows them to 104%.
* **Rarity frames:** Rare blue, Epic purple, Legendary gold, Mythic animated rainbow gradient (rotating),
  Secret black with a glitch flicker.
* **Motion:** every window opens with a back-ease scale from 0.85 to 1 plus a fade, and closes faster. Lists stagger
  in by 25 ms per item. Numbers count up rather than snapping.
* **Tags:** NEW!, BEST VALUE, POPULAR, LIMITED, SHINY, 1 FREE. Tags are slightly rotated stickers.

## 10. Audio direction

Bouncy pizzicato and ukulele lobby music (license-safe library tracks). Cartoon SFX: boing on placement, a cash
register on sell, a rising chime per summon rarity, and a slide whistle on enemy death. All IDs live in
`Config/Sounds.luau`, and the built-in `rbxasset://sounds/...` files are used as fallbacks.

## 11. Technical architecture (summary)

* **Server-authoritative simulation.** Enemies are pure data (distance along the path), so the server never moves
  enemy parts.
* **Client rendering.** Clients build enemy, unit and VFX visuals locally from shared configs and interpolate enemy
  snapshots (10 Hz, packed `buffer` over `UnreliableRemoteEvent`). This scales to hundreds of enemies.
* **One request router** (`RemoteFunction`) with per-action validation and rate limiting.
* **Session-locked DataStore profiles** with autosave, receipt idempotency and an in-memory fallback in Studio.
* **Everything is generated at runtime**: lobby, maps, characters, VFX and UI. The project runs from an empty
  baseplate via Rojo.

## 12. Asset pipeline (how to make it look like a top-10 game)

1. **Now:** procedural, stylised characters built from primitives (big googly eyes, bold silhouettes). They read well at TD distance.
2. **Override slot:** put a Model named after a unit id in `ReplicatedStorage/Assets/Units` (or an enemy id in
   `Assets/Enemies`) and the renderer uses it instead of the procedural one. If the model contains an
   `AnimationController`, it plays `Idle` and `Attack` animations from `Assets/Animations/<UnitId>`.
3. **Producing real assets:** Roblox Assistant / `GenerationService:GenerateModelAsync` for first-pass meshes, then
   Blender clean-up (≤ 3k triangles per unit), and animations made in Moon Animator 2 or the Roblox Animation Editor.
   Do **not** take assets from other games. Free Creator Store models must be sandboxed and audited.
