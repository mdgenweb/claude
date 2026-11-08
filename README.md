# 🧪 Flask Fiasco: Ragdoll Potion Lab (Roblox)

An original 2.5D physics sandbox for Roblox. Brew potions from 15 ingredients, then **throw** or
**feed** them to **Clayton**, an indestructible clay-golem test dummy, and watch the ragdoll chaos.
Discover 31 potions and 10 hidden reactions, clear daily quests and 11 trials, and work toward the
endgame: brewing the **Philosopher's Elixir**.

The game was designed from an analysis of the Roblox hit *Ragdoll Playground* (see
[`docs/RESEARCH.md`](docs/RESEARCH.md)). It keeps the genre's addictive side-view sandbox loop and
adds what that game lacks: a crafting economy, goals and progression. All content (name,
character, potions, labs and UI) is original.

| | |
|---|---|
| **Genre** | Physics sandbox, ragdoll, crafting |
| **Players** | 6 per server, one private lab each (others can visit) |
| **Platforms** | PC, mobile (touch), console (gamepad virtual cursor) |
| **Code** | 75 Luau modules, about 23,700 lines; [Rojo](https://rojo.space) project |
| **Assets** | No external asset IDs needed. Only built-in Roblox textures, sounds and fonts (verified against the client manifest) |

---

## ✨ Features

**Physics**
* 2D gameplay on Roblox's 3D solver. `PlaneConstraint` keeps every part on the plane, a rigid
  `AlignOrientation` limits rotation to the Z axis, and Z-axis `HingeConstraint` joints with limits
  form the skeleton.
* **Active ragdoll**: golems stand, wobble, get knocked down, lie stunned and get back up. They take
  impact damage, can be knocked out, have limbs pop off (cartoon clay, no gore) and reform when healed.
* **Per-lab slow motion and pause**, even though `workspace.Gravity` is shared by the whole server.
  Slow motion scales velocities by *s* and gravity by *s²* using per-assembly `VectorForce`s; pause
  anchors parts and restores their velocities.
* **Lag-free grab and fling.** The grabbing player gets network ownership of the object, and a local
  `AlignPosition` drags the exact point you grabbed, so limbs dangle naturally.

**Content**
* **32 potions** (Inferno, Frost, Rocket Fuel, Black Hole, Zombie, Midas, Tornado, Supernova,
  Chaos…) and **10 reactions** (steam burst, shatter, overcharge, gold melt…).
* **Puddle materials** left by splashes: fire patches, ice, trampoline goo, glue, acid, sludge,
  healing pools.
* **8 labs** built procedurally: Alchemy Lab, Lava Forge, Crusher Works (physics pistons and a
  conveyor), Sky Shaft (230 studs tall), Bounce Castle, Frost Cavern, Storm Spire (tesla coils) and
  Void Observatory (low gravity).
* **12 golem skins** with gameplay traits (straw burns longer, iron conducts, crystal shatters…).
  **8 props**, including TNT and boom barrels that chain-react.

**Progression and retention**
* Codex, mastery (brew 5× for ∞ bottles), 50 levels with 7 ranks, 3 daily challenges, 11 trials
  with 3★ scoring, a 7-day login streak, Mystery Flask spins, codes, game passes and dev products.
* A guided first-session tutorial.

**Look and feel**
* Future lighting with per-lab mood presets, bloom, color grading, depth of field and atmosphere.
  Slow motion and pause have their own color grades.
* About 60 VFX events: splashes, glass shards, fireballs, shockwaves, lightning bolts, black-hole
  vortex, tornado, meteors, damage numbers, coin bursts, confetti and trauma-based screen shake.
* Golems follow your cursor with their eyes. Every player's live cursor is visible to everyone in
  the lab.
* A full UI design system ([`docs/UI_DESIGN_SYSTEM.md`](docs/UI_DESIGN_SYSTEM.md)): 3D potion bottles
  in the hotbar, a spinning reveal for each potion discovery, an animated Mystery Flask reel and
  springy buttons with key badges.

---

## 🚀 Open it in Roblox Studio

### Option A: just open the place file
1. Download [`release/FlaskFiasco.rbxlx`](release/FlaskFiasco.rbxlx).
2. Double-click it, or use **File → Open** in Roblox Studio.
3. Press **Play** (F5).

### Option B: build from source with Rojo (recommended for development)
```bash
rokit install
```
```bash
rojo build default.project.json -o FlaskFiasco.rbxlx
```
For live-syncing while you edit:
```bash
rojo serve
```
Then click **Connect** in the Rojo Studio plugin.

### Before publishing
1. **File → Publish to Roblox**, then **Game Settings → Security → Enable Studio Access to API
   Services**. This turns on DataStore saving. Without it, profiles are memory-only and the game
   shows a warning toast.
2. **Game Settings → Places → Max Players = 6** (one lab per player; `Config.MaxLabs = 6`).
3. *(Optional)* Create game passes, developer products and badges on the Creator Dashboard, then
   paste their IDs into [`src/shared/Config.luau`](src/shared/Config.luau) (`GamePasses`,
   `Products`, `ProductCatalog`, `BadgeIds`). Anything left at `0` stays hidden or shows "Coming soon".
4. *(Optional)* Add music: put `rbxassetid://…` IDs of licensed tracks from the Creator Store into
   `Config.MusicIds`.
5. *(Optional)* Add new codes in [`src/server/Data/Codes.luau`](src/server/Data/Codes.luau). This
   file is server-only, so unreleased codes stay secret.

---

## 🎮 Controls

| PC | Touch | Gamepad | Action |
|---|---|---|---|
| LMB drag | drag | A | Grab & fling |
| RMB | tap | X | Throw / feed potion, place item |
| 1–9 | tap slot | LB / RB | Select potion |
| Q | 🧪 button | Y | Throw ↔ Feed |
| G / Space | buttons | D-pad ↑ / ↓ | Slow-mo / stop time |
| H / R / N / Z / K | buttons | D-pad ← / → | Heal · Reset · Spawn · Undo · Cure zombies |
| B / C / J / O / M / F1 | rail buttons | Start / Select | Cauldron · Codex · Quests · Shop · World · Help |
| Wheel, WASD, MMB | pinch, 2-finger pan | right stick, triggers | Camera |
| F / P | — | — | Follow golem / photo mode |

---

## 🗂️ Project layout

```
default.project.json          Rojo tree + place settings (Future lighting, no characters, ...)
src/shared/                   → ReplicatedStorage.Shared
  Config.luau                 every tunable (physics, economy, IDs)
  Net.luau                    remote registry
  Data/                       Potions, Ingredients, Recipes (pure), Reactions, Skins, Maps,
                              Props, Challenges & Trials, Rarity, Spins
  Visual/                     PotionModel, GolemPreview (3D models for world + UI)
  Util/                       Signal, Trove, Spring, Format
src/server/                   → ServerScriptService.Server
  Main.server.luau            service bootstrap
  Services/                   Data, Economy, Shop, Lab, Golem, Prop, Grab, Effects, Potion,
                              Hazard, Challenge, Trial, Cursor
  Systems/                    Physics2D, GolemFactory, World, LabFurniture,
                              Effects/{Statuses, Fields, Puddles, Vfx}
  Maps/                       Builder + 8 procedural lab builders
  Data/Codes.luau             server-only codes
src/client/                   → StarterPlayer.StarterPlayerScripts.Client
  Main.client.luau            controller bootstrap
  Controllers/                State, Camera, Input, Sound, Lighting, VFX, Ambient, Grab, Tool, Cursor
  UI/                         Theme, Components, UIController, Hud, Hotbar, Notifications,
                              TrialHud, Brew/Codex/Challenges/Shop/Menu/Help panels, Tutorial
tests/                        pure-logic Luau tests (+ bundler for the luau CLI)
docs/                         RESEARCH.md · GAME_DESIGN.md · UI_DESIGN_SYSTEM.md
```

### Architecture in one paragraph
The server owns the simulation. Each lab is a room on the Z = 0 plane, offset 1200 studs along X.
One `Heartbeat` loop in `LabService` advances each lab's own clock (×time scale, 0 when paused) and
updates golems, props, effects, projectiles, hazards and trials in a fixed order. Gameplay state is
plain Lua tables. Instances only carry visuals and physics. Clients get compact FX events and render
every one-shot effect locally, including thrown bottles, which are simulated server-side as
ballistic raycasts and replayed client-side from their launch parameters, so they look perfectly
smooth. Profiles are session-locked with `UpdateAsync`, autosaved, reconciled against a template
and saved before purchase receipts are acknowledged.

---

## 🧰 Tooling & checks

| Check | Command | Status |
|---|---|---|
| Type check (Roblox API definitions) | `luau-lsp analyze --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src` | ✅ 0 errors |
| Formatting | `stylua --check src tests` | ✅ |
| Pure-logic tests | `python3 tests/run_tests.py` | ✅ 12 / 12 |
| Place build | `rojo build -o FlaskFiasco.rbxlx` | ✅ |
| Property names in table literals checked against the API dump | (custom script) | ✅ 1161 keys, 0 problems |
| Selene lint | `selene src` | ⚠️ not run; its Roblox std couldn't be downloaded in the build sandbox |

**Not yet playtested in Studio.** The build environment has no Roblox Studio, so everything above
is static analysis plus logic tests. Expect a tuning pass on feel values like grab force, standing
torque and impact damage. They all live in `Config.Physics`.

---

## 📚 Docs
* [`docs/RESEARCH.md`](docs/RESEARCH.md): analysis of the reference game (UI, content,
  monetization, why players stay), with sources
* [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md): design document (loop, goal, potions, economy, labs)
* [`docs/UI_DESIGN_SYSTEM.md`](docs/UI_DESIGN_SYSTEM.md): tokens and component specs
