# Flask Fiasco — Game Design Document

*Roblox title suggestion:* `[🧪 NEW] Flask Fiasco — Ragdoll Potion Lab`

A 2.5D side-view physics sandbox. You **brew potions** in your own alchemy lab, then **throw** or
**feed** them to **Clayton**, an indestructible clay-golem test dummy, and watch ragdoll chaos. You
discover recipes, trigger reactions between potion effects, clear challenges and trials, and work
toward the final goal: brewing the **Philosopher's Elixir**.

See [`RESEARCH.md`](RESEARCH.md) for the reference-game analysis this design is built on.

---

## 1. Pillars

1. **Every click is funny.** Any action produces a physical, readable, exaggerated reaction within
   0.3 s, with juice on top: shake, particles, sound, numbers.
2. **"What if I mix…?"** Crafting and status reactions create emergent results that players want
   to discover and share.
3. **Always a next goal.** Codex completion, daily challenges, trials, ranks, skins and the endgame
   elixir.
4. **Looks premium.** Real 3D lighting, materials and VFX on top of a clean 2D gameplay plane.

## 2. Core loop

```
 gather ingredients ─▶ brew at cauldron ─▶ test on Clayton ─▶ earn Chaos/coins/XP
        ▲                  (discover!)        (throw / feed,       │
        │                                     reactions, maps)     │
        └──── unlock ingredients, labs, skins ◀── challenges ◀─────┘
```

Session micro-loop (from research): **pick → use → watch → heal/reset → repeat**, every 5–20 s.

## 3. Goal and progression

| Layer | Goal | Reward |
|---|---|---|
| Codex | Discover all **32 potions** and **10 reactions** | XP, coins, % completion badge |
| Mastery | Brew a potion 5× and it becomes **∞ use** with +25% potency | Sandbox freedom |
| Daily | 3 rotating challenges each UTC day | Coins, XP, a Mystery Flask for all 3 |
| Trials | 10 handcrafted objective levels, up to 3★ each | Coins, XP, skins, then the Philosopher's Stone |
| Rank | Levels 1–50: Apprentice → Brewer → Alchemist → Adept → Master Alchemist → Archmage → **Grand Alchemist** | Ingredients, labs, skins |
| **Endgame** | Clear the final trial *Magnum Opus* (needs 20★) to earn the **Philosopher's Stone**, then brew the **Philosopher's Elixir** | Ascended Golem skin, "Grand Alchemist" title |

## 4. Ingredients

| Ingredient | Rarity | Price | Unlock lvl |
|---|---|---|---|
| 🔥 Ember Root, ❄️ Frost Lotus, 🌪️ Gale Feather, 💚 Slime Gel | Common | 12 | 1 |
| 💧 Moon Dew | Common | 15 | 2 |
| 🍄 Boom Spore | Uncommon | 30 | 3 |
| ⚡ Storm Moss | Uncommon | 30 | 4 |
| 🌱 Giant's Bean | Uncommon | 35 | 5 |
| ✨ Pixie Dust | Rare | 70 | 7 |
| 💀 Bone Dust | Rare | 70 | 9 |
| 💰 Gold Nugget | Rare | 90 | 11 |
| 🌑 Void Salt | Epic | 160 | 14 |
| 🐉 Dragon Scale | Epic | 200 | 17 |
| ⭐ Star Shard | Legendary | 450 | 22 |
| 💎 Philosopher's Stone | Mythic | trial reward | — |

A free **Ingredient Rack** in every lab regrows one random common ingredient every 4 minutes
(cap 6), so there is always a reason to come back.

## 5. Potions (2–3 ingredients, order doesn't matter)

Any unknown mix makes **Murky Sludge**, a dud that is still funny, and the cauldron gives a hint.

| Potion | Recipe | Effect |
|---|---|---|
| Healing Elixir | Moon Dew ×2 | Reforms the golem and cleanses statuses |
| Inferno Brew | Ember ×2 | Burning: damage over time, flailing, spreads; puddle: fire patch |
| Frost Tonic | Frost ×2 | Frozen ice statue that **shatters** on a hard hit; puddle: ice patch |
| Levitation Elixir | Gale ×2 | Floats up and drifts |
| Bouncy Goo | Slime ×2 | Rubber body; puddle: trampoline goo |
| Rocket Fuel | Ember + Gale | Back-mounted rocket, then a pop |
| Steam Burst | Ember + Frost | Radial steam blast, makes things wet |
| Sticky Slime | Slime + Moon Dew | Sticks to whatever it touches; puddle: glue |
| Balloon Brew | Gale + Slime | Three balloons on ropes lift the golem |
| Kaboom Cocktail | Boom + Ember | Explosion |
| Storm in a Bottle | Gale + Storm | Lightning strike, shock chains between golems |
| Jumping Jelly | Slime + Storm | Hyper: wild random hops |
| Giant's Draught | Bean + Moon Dew | Grows ×2.4 |
| Shrinking Solution | Bean + Frost | Shrinks ×0.45 with a squeaky voice |
| Gravity Flip Serum | Gale + Pixie | Falls upward |
| Ghost Essence | Bone + Moon Dew | Intangible and floaty |
| Reanimation Serum | Bone + Slime | Zombie: hops at other golems and infects them |
| Midas Touch | Gold + Pixie | Gold statue that bursts into coins when shattered |
| Magnet Mixture | Gold + Storm | Pulls nearby objects |
| Disco Fever | Pixie + Slime | Rainbow dancing with disco lights |
| Acid Flask | Bone + Boom | Dissolves and limbs pop off; puddle: acid |
| Black Hole Brew | Pixie + Void | Singularity that sucks everything in |
| Stasis Elixir | Frost + Void | Time-freeze bubble |
| Dragon's Breath | Dragon + Ember | The golem breathes fire |
| Meteor Call | Boom + Dragon | Meteor shower |
| Clone Concoction | Moon Dew + Pixie + Slime | Duplicates the golem |
| Tornado Tonic | Gale ×2 + Storm | Tornado |
| Supernova | Boom + Ember + Star | Huge flash and blast |
| Chaos Potion | Boom + Star + Void | Three random effects at once |
| Philosopher's Elixir | Dragon + Stone + Star | **Ascension** (endgame) |
| Murky Sludge | anything else | Stink cloud |

**Throw** = splash. It affects everything in a radius and leaves a puddle on the floor.
**Feed** = drink. One target, with 1.5× duration.

### Reactions (discoverable, give bonus Chaos)

| Reaction | Trigger |
|---|---|
| Steam Burst | Burning + Frozen |
| Shatter | Frozen (or Crystal skin) + hard impact or explosion |
| Overcharge | Shocked + Wet/Slimed |
| Conductor | Shocked + Golden/Magnetic or Iron skin, chains to all metal |
| Pop! | Balloons + fire, shock or blast |
| Mega Blast | Explosion on a Giant |
| Cure | Healing on a Zombie |
| Gold Melt | Acid on a Golden golem, coin shower |
| Overdrive | Rocket + Shocked |
| Spirit Flame | Ghost + Burning |

## 6. Labs (maps)

| Lab | Unlock | Signature hazard |
|---|---|---|
| Alchemy Lab | 1 | Crates, barrels, chandelier |
| Lava Forge | 3 | Lava pool (ignites), embers |
| Crusher Works | 5 | Hydraulic crushers that flatten, conveyor |
| Sky Shaft | 7 | 200-stud tall shaft, height markers, updraft fans |
| Bounce Castle | 9 | Bouncy walls, pinball bumpers |
| Frost Cavern | 12 | Zero-friction ice, falling icicles |
| Storm Spire | 15 | Tesla coils, rain, thunder |
| Void Observatory | 20 | Low gravity, starfield |

Each player owns a private lab (6 per server). Labs can be visited (Everyone / Friends / Nobody),
and every player's cursor is shown live, with their name, to everyone in the lab.

## 7. Controls

| PC | Mobile | Gamepad | Action |
|---|---|---|---|
| LMB drag | drag | A (hold) | Grab and fling |
| RMB | tap | RT | Throw or feed the selected potion, or place the selected item |
| 1–9, wheel+Shift | hotbar tap | LB/RB | Select slot |
| Q | button | Y | Throw / Feed mode |
| G / Space | buttons | DPad | Slow-mo / Pause |
| H / R | buttons | DPad | Heal all / Reset room |
| N / Z / K | buttons | — | Spawn golem / Undo / Clear zombies |
| B / C / J / M | buttons | Menu | Cauldron / Codex / Challenges / Menu |
| Wheel, WASD, MMB | pinch, two-finger pan | right stick, triggers | Camera zoom and pan |
| F1 / P | — | — | Keybinds / Photo mode |

## 8. Economy

* **Chaos Points (CP):** damage, airtime, height, reactions and shatters, multiplied by a combo
  meter (x1–x5). 40 CP = 1 coin, 100 CP = 1 XP. Only CP earned within 12 s of a player action
  counts (no AFK farms).
* **Coins** buy ingredients, skins and spins. Robux only speeds things up and never gates the goal.
* **Mystery Flask** spins: weighted coins, ingredient bundles, potions and exclusive skins.
* **Codes:** `FIRSTBREW`, `KABOOM`, `BUBBLES`, `GOLEMGANG`. Ship new ones on like and visit milestones.
* **Daily streak:** a 7-day cycle; day 7 gives a Mystery Flask and an Epic ingredient.

### Monetization (IDs configured in `Config.luau`; 0 = hidden)

| Pass | Price | Perk |
|---|---|---|
| VIP | 249 | 2× coins and XP, Gold Golem skin, gold name |
| Alchemist's Satchel | 299 | +2 bottles per brew |
| Lab Expansion | 199 | 12 golems per lab |
| Master Key | 399 | All labs unlocked |

Developer products: coin packs and Mystery Flask packs.

## 9. Art and VFX direction

* **Camera:** perspective, FOV 30–55, 70–150 studs from the plane (close to orthographic). Smooth
  zoom and pan, trauma-based shake, FOV punch on big hits.
* **Lighting:** Future technology, per-lab presets applied client-side (ambient, fog/atmosphere,
  bloom, color grading, depth of field, sun rays). Warm candles with flicker, neon potion glow,
  moonlight beams.
* **Materials:** brick, slate, wood planks, cobblestone, basalt, ice, glass and neon. Built-in only,
  no external asset dependencies.
* **VFX library:** splash rings, droplets, glass shards, impact dust, clay chunks, fire, smoke,
  frost, lightning arcs (beams), steam, sparkles, coin bursts, damage numbers, speed trails,
  shockwaves, black-hole vortex.
* **UI:** deep-violet glass panels, gold accents, rarity colors, chunky friendly fonts
  (Luckiest Guy and Fredoka One), 3D potion bottles rendered in ViewportFrames, springy hover and press.

## 10. Technical architecture

* **Rojo project.** Server services and client controllers are bootstrapped by a single
  `Main.server.luau` and `Main.client.luau`.
* **2D physics.** Every dynamic part is locked to its lab's plane with a `PlaneConstraint`.
  Root parts also get a rigid `AlignOrientation` (`PrimaryAxisParallel`), so rotation is only
  around Z. Joints are Z-axis `HingeConstraint`s with limits and motor friction.
* **Active ragdoll.** An upright `AlignOrientation`, hip and knee servos and a stun/get-up state
  machine. Impact damage comes from per-step Δv.
* **Per-lab time.** Slow motion scales velocities by *s* and gravity by *s²* through per-part
  `VectorForce`s. Pause anchors and restores velocities. Effects run on a lab-local clock.
* **Network ownership.** The server owns physics, and grabbing temporarily hands the object to the
  grabbing client for zero-latency dragging.
* **Data.** Session-locked DataStore profiles with autosave, retries, schema reconcile and receipt
  idempotency.
* **Security.** All rewards are server-side, remotes are rate-limited and type-checked, and labs
  have permission checks.
